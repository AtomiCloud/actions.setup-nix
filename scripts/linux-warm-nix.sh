#!/usr/bin/env bash
# Linux (Namespace) warm-store fast path for AtomiCloud/actions.setup-nix.
#
# On a Namespace Linux runner the cache volume persists /nix (store + db + the
# installer's own receipt). The VM itself is fresh, so everything the Determinate
# installer puts OUTSIDE /nix is gone: /etc/nix, /usr/local/bin/determinate-nixd, the
# nixbld users and the daemon process. Re-running the installer just to recreate those
# costs ~6s (download + "Provision Nix"). This script recreates them directly.
#
#   bootstrap  Verify the persisted store, recreate the out-of-/nix state, spawn the
#              daemon, export PATH. Prints `bootstrapped=true|false` to $GITHUB_OUTPUT.
#              Any failure rolls back everything it wrote and reports false, so the
#              caller falls back to the real installer.
#   capture    Run once after a real install: snapshot the installer's out-of-/nix
#              files into /nix/atomi-bootstrap (on the cache volume) for `bootstrap`.
#
# Environment:
#   NIX_CONF            computed extra nix config (same text the installer receives)
#   MAX_AGE_DAYS        refuse a snapshot older than this and reinstall (default 7), so
#                       the Determinate Nix version still follows the installer's stable
#   GITHUB_TOKEN_VALUE  optional; becomes `access-tokens = github.com=...` like the
#                       installer action does
#   ATOMI_NIX_STATE_DIR / ATOMI_NIX_ETC_DIR / ATOMI_NIX_BIN_DIR override locations (tests)
set -euo pipefail

STATE_DIR="${ATOMI_NIX_STATE_DIR:-/nix/atomi-bootstrap}"
ETC_DIR="${ATOMI_NIX_ETC_DIR:-/etc}"
BIN_DIR="${ATOMI_NIX_BIN_DIR:-/usr/local/bin}"
PROFILE="/nix/var/nix/profiles/default"
SOCKET="/nix/var/nix/daemon-socket/socket"
DAEMON_LOG="${RUNNER_TEMP:-/tmp}/atomi-nix-daemon.log"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-7}"
NIXBLD_GID=30000
NIXBLD_UID_BASE=30000
NIXBLD_COUNT=32

log() { echo "[warm-nix] $*"; }
emit() { [ -z "${GITHUB_OUTPUT:-}" ] || echo "$1" >>"$GITHUB_OUTPUT"; }

# Why the fast path cannot be used (read-only checks; nothing has been written yet).
unsuitable() {
  local f
  for f in determinate-nixd nix.conf stamp; do
    [ -e "$STATE_DIR/$f" ] || {
      echo "no snapshot ($f missing)"
      return 0
    }
  done
  [ -x "$STATE_DIR/determinate-nixd" ] || {
    echo "snapshot daemon not executable"
    return 0
  }

  local stamp now age
  stamp="$(cat "$STATE_DIR/stamp" 2>/dev/null || true)"
  case "$stamp" in '' | *[!0-9]*)
    echo "snapshot stamp unreadable"
    return 0
    ;;
  esac
  now="$(date +%s)"
  age=$((now - stamp))
  if [ "$age" -lt 0 ] || [ "$age" -gt $((MAX_AGE_DAYS * 86400)) ]; then
    echo "snapshot is $((age / 86400)) days old (max ${MAX_AGE_DAYS})"
    return 0
  fi

  [ -d /nix/store ] || {
    echo "/nix/store missing"
    return 0
  }
  if [ ! -x "$PROFILE/bin/nix" ] || [ ! -x "$PROFILE/bin/nix-daemon" ]; then
    echo "default profile has no nix"
    return 0
  fi
  "$PROFILE/bin/nix" --version >/dev/null 2>&1 || {
    echo "persisted nix does not run on this machine"
    return 0
  }
  [ -f /nix/var/nix/db/db.sqlite ] || {
    echo "store db missing"
    return 0
  }
  if command -v sqlite3 >/dev/null 2>&1; then
    sudo sqlite3 /nix/var/nix/db/db.sqlite 'PRAGMA quick_check;' 2>/dev/null | grep -q '^ok$' ||
      {
        echo "store db failed quick_check"
        return 0
      }
  fi
  # A pre-existing nix (baked into the image, or a half-finished earlier attempt) is
  # the installer's business: it knows how to detect and refuse/repair it.
  [ ! -e "$ETC_DIR/nix/nix.conf" ] || {
    echo "$ETC_DIR/nix/nix.conf already exists"
    return 0
  }
  [ ! -e "$BIN_DIR/determinate-nixd" ] || {
    echo "$BIN_DIR/determinate-nixd already exists"
    return 0
  }
  return 1
}

write_users() {
  # Same ids/names as nix-installer: group nixbld = 30000, users nixbld1..32 = 30001..
  if getent group nixbld >/dev/null 2>&1; then
    return 0
  fi
  local i members="" passwd="" shadow=""
  for i in $(seq 1 "$NIXBLD_COUNT"); do
    members="${members:+$members,}nixbld$i"
    passwd+="nixbld$i:x:$((NIXBLD_UID_BASE + i)):$NIXBLD_GID:Nix build user $i:/var/empty:/sbin/nologin"$'\n'
    shadow+="nixbld$i:!:19000:0:99999:7:::"$'\n'
  done
  printf 'nixbld:x:%s:%s\n' "$NIXBLD_GID" "$members" | sudo tee -a "$ETC_DIR/group" >/dev/null
  printf 'nixbld:!::%s\n' "$members" | sudo tee -a "$ETC_DIR/gshadow" >/dev/null 2>&1 || true
  printf '%s' "$passwd" | sudo tee -a "$ETC_DIR/passwd" >/dev/null
  printf '%s' "$shadow" | sudo tee -a "$ETC_DIR/shadow" >/dev/null
}

remove_users() {
  [ "${USERS_ADDED:-0}" = 1 ] || return 0
  sudo sed -i -E '/^nixbld([0-9]+)?:/d' "$ETC_DIR/passwd" "$ETC_DIR/group" "$ETC_DIR/shadow" "$ETC_DIR/gshadow" 2>/dev/null || true
}

write_custom_conf() {
  local user tags
  user="$(id -un)"
  {
    echo "# Written by AtomiCloud/actions.setup-nix (warm /nix bootstrap)."
    echo "# Mirrors what DeterminateSystems/nix-installer-action writes at install time."
    echo
    if [ -n "${GITHUB_TOKEN_VALUE:-}" ]; then
      echo "access-tokens = github.com=${GITHUB_TOKEN_VALUE}"
    fi
    echo "trusted-users = root ${user}"
    if command -v jq >/dev/null 2>&1; then
      tags="$(jq -cn --arg a "${GITHUB_WORKFLOW_REF:-}" --arg b "${GITHUB_WORKFLOW_SHA:-}" \
        --arg c "${GITHUB_SHA:-}" --arg d "${GITHUB_RUN_ATTEMPT:-}" --arg e "${GITHUB_RUN_ID:-}" \
        --arg f "${GITHUB_RUN_NUMBER:-}" --arg g "${GITHUB_JOB:-}" --arg h "${GITHUB_REF:-}" \
        --arg i "${GITHUB_REPOSITORY:-}" --arg j "${GITHUB_SERVER_URL:-}" \
        '{github_workflow_ref:$a,github_workflow_sha:$b,github_sha:$c,github_run_attempt:$d,github_run_id:$e,github_run_number:$f,github_job:$g,github_ref:$h,github_repository:$i,github_server_url:$j}
         | with_entries(select(.value != "")) + {builder:"github-actions"}')"
      echo "build-provenance-tags = ${tags}"
    fi
    printf '%s\n' "${NIX_CONF:-}"
  }
}

install_files() {
  sudo mkdir -p "$ETC_DIR/nix" "$BIN_DIR"
  sudo install -m 0555 "$STATE_DIR/determinate-nixd" "$BIN_DIR/determinate-nixd"
  sudo install -m 0644 "$STATE_DIR/nix.conf" "$ETC_DIR/nix/nix.conf"
  [ ! -f "$STATE_DIR/sentry-endpoint" ] || sudo install -m 0644 "$STATE_DIR/sentry-endpoint" "$ETC_DIR/nix/sentry-endpoint"
  write_custom_conf | sudo tee "$ETC_DIR/nix/nix.custom.conf" >/dev/null
  sudo chmod 0644 "$ETC_DIR/nix/nix.custom.conf"
}

spawn_daemon() {
  # No systemd on these runners (same as the installer action's spawnDetached): detach
  # the daemon fully so it outlives this step.
  : >"$DAEMON_LOG"
  # The log is opened by the runner user on purpose (the redirect is not meant to be root's).
  # shellcheck disable=SC2024
  sudo setsid nohup "$BIN_DIR/determinate-nixd" daemon >>"$DAEMON_LOG" 2>&1 </dev/null &
  local i
  for i in $(seq 1 600); do
    [ -S "$SOCKET" ] && return 0
    sleep 0.05
  done
  return 1
}

rollback() {
  log "rolling back"
  sudo pkill -f "$BIN_DIR/determinate-nixd daemon" 2>/dev/null || true
  sudo pkill -x nix-daemon 2>/dev/null || true
  sleep 0.2
  sudo rm -rf "$ETC_DIR/nix" "$BIN_DIR/determinate-nixd" "$SOCKET" /nix/var/determinate/determinate-nixd.socket /nix/var/determinate/determinate-nixd-logger.socket 2>/dev/null || true
  remove_users
}

bootstrap() {
  local why
  if why="$(unsuitable)"; then
    log "fast path unavailable: ${why}; using the installer"
    emit "bootstrapped=false"
    return 0
  fi

  USERS_ADDED=0
  getent group nixbld >/dev/null 2>&1 || USERS_ADDED=1
  export USERS_ADDED
  if ! { write_users && install_files && spawn_daemon &&
    PATH="$PROFILE/bin:$PATH" nix store info --store daemon >/dev/null 2>&1 &&
    PATH="$PROFILE/bin:$PATH" nix --version >/dev/null; }; then
    log "::warning::warm bootstrap failed; falling back to the installer"
    [ ! -s "$DAEMON_LOG" ] || sed 's/^/[daemon] /' "$DAEMON_LOG" | tail -n 20
    rollback
    emit "bootstrapped=false"
    return 0
  fi

  {
    echo "/usr/local/bin"
    echo "$PROFILE/bin"
    echo "${HOME}/.nix-profile/bin"
  } >>"${GITHUB_PATH:-/dev/null}"
  # Determinate's KVM hint (best effort; only matters for kvm-feature builds).
  if [ -e /dev/kvm ]; then
    sudo chmod 0666 /dev/kvm 2>/dev/null || true
    [ -r /dev/kvm ] && [ -w /dev/kvm ] && echo "DETERMINATE_NIX_KVM=1" >>"${GITHUB_ENV:-/dev/null}" ||
      echo "DETERMINATE_NIX_KVM=0" >>"${GITHUB_ENV:-/dev/null}"
  else
    echo "DETERMINATE_NIX_KVM=0" >>"${GITHUB_ENV:-/dev/null}"
  fi
  log "$("$PROFILE/bin/nix" --version) bootstrapped from the persisted store (no installer)"
  emit "bootstrapped=true"
}

capture() {
  local tmp="$STATE_DIR.tmp.$$"
  if [ ! -x "$BIN_DIR/determinate-nixd" ] || [ ! -f "$ETC_DIR/nix/nix.conf" ]; then
    log "nothing to capture (installer output missing); next job will run the installer again"
    return 0
  fi
  sudo rm -rf "$tmp"
  sudo mkdir -p "$tmp"
  sudo cp "$BIN_DIR/determinate-nixd" "$tmp/determinate-nixd"
  sudo cp "$ETC_DIR/nix/nix.conf" "$tmp/nix.conf"
  [ ! -f "$ETC_DIR/nix/sentry-endpoint" ] || sudo cp "$ETC_DIR/nix/sentry-endpoint" "$tmp/sentry-endpoint"
  "$PROFILE/bin/nix" --version | sudo tee "$tmp/nix-version" >/dev/null
  date +%s | sudo tee "$tmp/stamp" >/dev/null
  sudo rm -rf "$STATE_DIR"
  sudo mv "$tmp" "$STATE_DIR"
  log "captured installer state for the next warm job: $(cat "$STATE_DIR/nix-version")"
}

case "${1:-}" in
bootstrap) bootstrap ;;
capture) capture ;;
*)
  echo "usage: $0 bootstrap|capture" >&2
  exit 2
  ;;
esac
