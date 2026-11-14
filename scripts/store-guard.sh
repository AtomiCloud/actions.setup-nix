#!/usr/bin/env bash
# store-guard.sh: keep a Namespace cache volume that holds /nix usable when it is shared
# (setup-nix runs it on Namespace Linux only).
#
#   store-guard.sh start   after Nix is available, before any dev shell runs
#   store-guard.sh end     end of job, on success (setup-nix's post hook)
#
# Namespace commits a job's copy of the volume whenever the job succeeds (last write wins),
# and a generation larger than the configured size is not cloned: the next job on the tag
# starts from an EMPTY volume. Nothing here can stop or gate a commit (only runs-on labels
# can); it frees space, warns before the limit, and points at jobs whose commits add nothing.
#
# Environment (all optional):
#   CACHE_SIZE_GB             the volume size the job's nscloud-cache-size label sets (default 20)
#   STORE_GC_AT_PERCENT       start: run a store GC when /nix uses at least this percent of
#                             CACHE_SIZE_GB (default empty = never)
#   STORE_GC_TARGET_PERCENT   ... and free down to this percent (default 60)
#   IDLE_COMMIT_NOTICE_MINUTES  end: notice when the job changed nothing in /nix and ran at
#                             least this many minutes (default 0 = always; off = never)
#   STORE_GUARD_STATE         state file shared by start and end (default $RUNNER_TEMP/...)
#   STORE_GUARD_USED_BYTES    tests only: pretend /nix uses this many bytes
#
# GC roots: every env durian-shell keeps is an indirect GC root (see bin/durian-shell), and
# Nix's own profiles are roots, so the GC frees only what no kept env or profile needs.
# Never fails the job: every problem is a warning and exit 0.
set -uo pipefail

state="${STORE_GUARD_STATE:-${RUNNER_TEMP:-/tmp}/atomi-store-guard.state}"
devshell_dir="${DURIAN_SHELL_DIR:-/nix/durian-shell}"
size_gb="${CACHE_SIZE_GB:-20}"
case "$size_gb" in '' | *[!0-9]*) size_gb=20 ;; esac
size_gb=$((10#$size_gb)) # decimal even with a leading zero
[ "$size_gb" -gt 0 ] || size_gb=20
limit=$((size_gb * 1024 * 1024 * 1024))

log() { echo "[store-guard] $*"; }
gib() { awk -v b="$1" 'BEGIN { printf "%.1f GiB", b / 1073741824 }'; }

used_bytes() {
  if [ -n "${STORE_GUARD_USED_BYTES:-}" ]; then
    echo "$STORE_GUARD_USED_BYTES"
    return 0
  fi
  df -B1 --output=used /nix 2>/dev/null | tail -n1 | tr -d ' '
}

# What a commit of this job would change: the store's entries and the cached dev shells.
fingerprint() {
  {
    find /nix/store -mindepth 1 -maxdepth 1 -printf '%f\n' 2>/dev/null | LC_ALL=C sort | sha256sum
    find "$devshell_dir" \( -name '*.sh' -o -name '*.nocache' -o -name '*.root' \) -printf '%P %l\n' 2>/dev/null | LC_ALL=C sort | sha256sum
  } | sha256sum | cut -c1-32
}

size_report() {
  local used="$1" when="$2" pct
  [ -n "$used" ] || return 0
  pct=$((used * 100 / limit))
  if [ "$used" -ge "$limit" ]; then
    echo "::error title=Nix cache volume over its size::/nix uses $(gib "$used") of the ${size_gb} GB cache volume ($pct%, $when). Namespace still commits this copy but will not clone it: the NEXT job on this cache tag starts from an EMPTY volume (full Nix install and store download). Free space (store-gc-at-percent), raise nscloud-cache-size together with cache-size-gb, or split the tag."
  elif [ "$pct" -ge 85 ]; then
    echo "::warning title=Nix cache volume nearly full::/nix uses $(gib "$used") of the ${size_gb} GB cache volume ($pct%, $when). At ${size_gb} GB the next job on this cache tag starts from an EMPTY volume. Enable store-gc-at-percent or raise nscloud-cache-size together with cache-size-gb."
  else
    log "/nix uses $(gib "$used") of ${size_gb} GB ($pct%, $when)"
  fi
}

gc_if_needed() {
  local used="$1" at="${STORE_GC_AT_PERCENT:-}" target="${STORE_GC_TARGET_PERCENT:-60}" want free t0 t1 after
  case "$at" in '' | *[!0-9]*) return 0 ;; esac
  case "$target" in '' | *[!0-9]*) target=60 ;; esac
  at=$((10#$at))
  target=$((10#$target))
  [ -n "$used" ] || return 0
  if [ $((used * 100)) -lt $((limit * at)) ]; then
    log "no GC: below $at% of ${size_gb} GB"
    return 0
  fi
  want=$((limit * target / 100))
  free=$((used - want))
  [ "$free" -gt 0 ] || free=1
  log "GC: /nix at $(gib "$used") >= $at% of ${size_gb} GB; freeing up to $(gib "$free") (target $target%)"
  t0="$(date +%s.%N)"
  if ! nix store gc --max "$free" >/dev/null 2>"${state}.gc-err"; then
    echo "::warning title=Nix store GC failed::$(tail -n 3 "${state}.gc-err" | tr '\n' ' ')"
  fi
  t1="$(date +%s.%N)"
  after="$(used_bytes)"
  log "GC done in $(awk -v a="$t0" -v b="$t1" 'BEGIN { printf "%.1f", b - a }') s: $(gib "$used") -> $(gib "${after:-0}") (freed $(gib $((used - ${after:-$used}))))"
}

case "${1:-}" in
start)
  # before the GC: a GC that freed something is a change worth committing
  printf '%s %s\n' "$(date +%s)" "$(fingerprint)" >"$state" 2>/dev/null || true
  used="$(used_bytes)"
  gc_if_needed "$used"
  used="$(used_bytes)"
  size_report "$used" "job start"
  ;;
end)
  size_report "$(used_bytes)" "end of job, about to be committed"
  min="${IDLE_COMMIT_NOTICE_MINUTES:-0}"
  [ "$min" != off ] || exit 0
  case "$min" in '' | *[!0-9]*) min=0 ;; esac
  min=$((10#$min))
  [ -f "$state" ] || exit 0
  read -r started fp <"$state" || exit 0
  [ -n "${fp:-}" ] || exit 0
  mins=$((($(date +%s) - started) / 60))
  if [ "$(fingerprint)" = "$fp" ] && [ "$mins" -ge "$min" ]; then
    echo "::notice title=Cache volume commit adds nothing::This job changed nothing in /nix, but Namespace will still commit its copy of the cache volume when it succeeds. That copy was cloned ${mins} min ago, so it can overwrite newer dev shells and store paths other jobs on this cache tag committed meanwhile (last write wins). If this job never needs to store anything, add the runs-on label nscloud-cache-exp-do-not-commit (keep at least one job per workflow committing)."
  fi
  ;;
*)
  echo "usage: store-guard.sh start|end" >&2
  ;;
esac
exit 0
