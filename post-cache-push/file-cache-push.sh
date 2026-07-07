#!/usr/bin/env bash
set -euo pipefail

# Copy every valid store path into the local file:// binary cache.
#
# Whole-store, not just devShell closures: build-time deps (fixed-output fetches like npm
# tarballs) and packages built during the job are exactly what macOS re-builds from source
# every run when they're missing from the cache. `nix copy` checks narinfos first and skips
# paths already present, so after the first push this is incremental — new paths only.

cache_path="${1:?Usage: $0 <cache-path>}"
nix="${NIX_BIN:-nix}"

# The nix daemon (root) creates the store layout (nar/, nix-cache-info) inside the cache
# the first time it opens the file:// substituter during the build — AFTER the setup-time
# chown — leaving root-owned dirs that EACCES the push (which runs as this non-root user).
# Re-own the whole tree now, then probe the nar/ dir (where the copy actually writes).
sudo chown -R "$(id -un)" "${cache_path}/" 2>/dev/null ||
  echo "::warning::could not chown ${cache_path}; attempting push anyway" >&2
mkdir -p "${cache_path}/nar"
if ! touch "${cache_path}/nar/.write-probe" 2>/dev/null; then
  echo "::warning::${cache_path}/nar is not writable by $(id -un); skipping cache push." >&2
  exit 1
fi
rm -f "${cache_path}/nar/.write-probe"

echo "🫸 Pushing all valid store paths to file://${cache_path} (incremental)"
"$nix" copy --all --to "file://${cache_path}?compression=zstd"
echo "✅ Pushed store to local binary cache"
