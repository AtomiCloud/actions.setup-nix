#!/usr/bin/env bash
set -euo pipefail

# Discover every devShell for the current system, realize its closure (instant — the job
# already built them), and copy the store paths into a local file:// binary cache.
#
# Discovery mirrors scripts/cache-shell.sh; kept self-contained here so the post hook has
# no cross-directory dependencies when it runs from a workspace symlink.

cache_path="${1:?Usage: $0 <cache-path>}"
nix="${NIX_BIN:-nix}"

# Preflight: nix copy runs as this (non-root) user; if the mounted cache volume isn't
# writable (e.g. the chown step was skipped), fail fast with an actionable message
# instead of erroring mid-copy with an opaque EACCES.
if ! touch "${cache_path}/.write-probe" 2>/dev/null; then
  echo "::warning::${cache_path} is not writable by $(id -un); skipping cache push." \
    "Ensure setup-nix's 'Own Darwin cache path' step ran (sudo chown -R \$USER ${cache_path}/)." >&2
  exit 1
fi
rm -f "${cache_path}/.write-probe"

echo "🔍 Discovering devShells for current system..."
system="$("$nix" eval --raw --impure --expr 'builtins.currentSystem')"
shells="$("$nix" eval --raw --impure --expr "builtins.concatStringsSep \" \" (builtins.attrNames (builtins.getFlake (toString ./.)).outputs.devShells.${system})")"
echo "📦 Found shells: $shells"

targets=""
for shell in $shells; do
  targets="$targets .#devShells.$system.$shell"
done

echo "🔨 Realizing closures:$targets"
# shellcheck disable=SC2086
paths="$("$nix" build $targets --print-out-paths --no-link)"

echo "🫸 Pushing store paths to file://${cache_path}"
# shellcheck disable=SC2086
"$nix" copy --to "file://${cache_path}?compression=zstd" $paths
echo "✅ Pushed devShell closures to local binary cache"
