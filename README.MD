# Setup AtomiCloud's Nix Action

Setup AtomiCloud CI Nix (Compatible with Namespace, on Linux **and macOS**).

# Get Started

Instruction

```yaml
name: Example Workflow
on: push
jobs:
  Test:
    runs-on: ubuntu-latest
    steps:
      # change this
      - uses: AtomiCloud/actions.setup-nix@v3
```

## macOS on Namespace runners

`namespacelabs: 'true'` now works on macOS runners (previously macOS callers had to use
`namespacelabs: 'false'` and cold-realize their whole dev-shell closure from
`cache.nixos.org` every run).

macOS's APFS root volume is sealed, so `/nix` cannot be a cache-volume mount the way it is
on Linux. Instead, on macOS the action persists a **local `file://` binary cache** on a
Namespace cache volume:

1. The Namespace cache volume is mounted at `darwin-cache-path` (default `/tmp/nix-cache`).
2. Nix is installed via the Determinate Systems installer with
   `extra-substituters = file://<darwin-cache-path>?priority=10` (plus the usual remote
   caches), `require-sigs = false`, and `fallback = true`.
3. At **end of job** (only on success), a bundled post hook `nix copy --all`s **every valid
   store path** — devShell closures, build-time deps (fixed-output fetches), and anything
   built during the job — back into the `file://` cache. `nix copy` is incremental (already
   -present paths are skipped), so warm runs cost seconds; the one-time cold push of a
   multi-GB store is a few minutes.

This write-back is automatic — callers do **not** add a trailing step.

### Store image fast path (macOS)

On top of the `file://` cache, the action maintains an APFS sparse image
(`<darwin-cache-path>/nix-store.sparseimage`) that **is** a ready-to-use `/nix`:

- **Attach** (job start): if the image exists and passes verification (`sqlite quick_check`
  on the nix db), it is mounted at `/nix` in ~1s — replacing the multi-GB NAR unpack that
  otherwise dominates warm macOS jobs. Any failure discards the image and falls back to the
  plain substitution flow.
- **Detach** (job end, success only): the daemon is stopped and the image detached cleanly
  before the volume commits. Namespace commits volumes only on success, so a crashed job's
  dirty image dies with its fork. The one remaining path to committing a dirty image — a
  successful job whose detach fails — poisons the image with a `.dirty` marker, and the
  next run discards and rebuilds it instead of attaching.
- **Bootstrap**: when no image exists, the post hook creates one from the live store
  (one-time `rsync` at NVMe speed); the next run attaches it.
- The `file://` binary cache stays authoritative as the fallback that can always rebuild
  the image from scratch.

### Required runner labels (caller side)

macOS callers need the same cache-volume label scheme Linux already requires:

```yaml
jobs:
  build:
    runs-on:
      - nscloud-macos-... # your macOS runner, suffixed -with-cache where applicable
      - nscloud-cache-size-20gb # minimum cache size label is 20GB
      - nscloud-cache-tag-atomi-nix-darwin-cache # org convention for darwin
    steps:
      - uses: AtomiCloud/actions.setup-nix@v3
        with:
          namespacelabs: 'true'
      - run: nix develop .#default -c true
```

- `<runner>-with-cache`, `nscloud-cache-size-<N>gb` (min **20**), `nscloud-cache-tag-<name>`.
- Org convention for darwin: `nscloud-cache-tag-atomi-nix-darwin-cache`.

### Operational semantics

- **Commit on success only**: the cache volume commits its new state only when the job
  exits 0. A failed job pushes nothing (the post hook is gated on `success()`) and the
  volume does not commit.
- **Idle expiry**: idle volumes expire after ~14 days. Tag-only release cadences may go
  cold — consider a scheduled warm-up job that runs the shell to refresh the volume.
- **Concurrent matrix jobs** fork the volume and commit last-writer-wins. This is fine when
  the jobs share a closure.
- **No GC**: the `file://` cache is never garbage-collected; it resets only on volume expiry.
- **Safe everywhere**: the post hook is a no-op `notice` (never a failure) on runners
  without the cache volume (e.g. `namespacelabs: 'false'`), if nix is missing, or if the
  cache path is absent/unwritable.

### Other caches persisted

- `~/.cache/nix` (both OSes, Namespace runners): the flake **eval cache** and flake-input
  fetcher cache, so repeat `nix develop`/`nix eval` invocations skip re-evaluation. Note the
  eval cache is keyed by the flake's content hash — it helps repeat invocations of the
  *same* tree (multiple steps in a job, re-runs of a commit), not new commits.
- `lazy-trees = true` on every path: evaluation no longer copies/hashes the whole source
  tree into the store. The **Determinate** installer now runs everywhere (it is the only
  installer whose nix supports the setting); on Namespace Linux the stale install receipt
  persisted on the warm `/nix` volume is dropped before installing over the existing store.

### macOS checkout & case-insensitive APFS

With `fetch-depth: 0`, ALL branch refs are fetched; on case-insensitive APFS, two branches
differing only in case (`Alice/feat-1` vs `alice/feat-2`) collide as loose-ref files and
corrupt the checkout. On macOS the action therefore checks out **shallow, single-ref**
(`fetch-depth: 1`), then deepens only the current ref to full history and fetches tags —
foreign branch refs are never written, so they can never collide. Linux keeps the plain
`fetch-depth: 0` behavior.

> Why not reftable? It would sidestep casing entirely, but nix reads git flakes through
> libgit2, which cannot open reftable repositories (`unsupported extension name
> extensions.refstorage`) — a reftable workspace breaks every flake eval on the runner.

### Security trade-off

The macOS path sets `require-sigs = false`, because paths copied into the local `file://`
cache via `nix copy` are unsigned. This is CI-acceptable and is called out here so it is a
conscious choice. The Linux Namespace path and all `namespacelabs: 'false'` paths are
unchanged and still require signatures.

<!-- prettier-ignore-start -->
<!-- action-docs-inputs -->
## Inputs

| parameter | description | required | default |
| --- | --- | --- | --- |
| namespacelabs | Using Namespace Lab's runners | `false` | true |
| darwin-cache-path | Mount path for the Namespace cache volume used as a file:// binary cache on macOS | `false` | /tmp/nix-cache |
| checkout | Whether to checkout the repository | `false` | true |
| short-length | length for short values | `false` | 7 |
<!-- action-docs-inputs -->

<!-- action-docs-outputs -->

<!-- action-docs-outputs -->

<!-- action-docs-runs -->
## Runs

This action is a `composite` action.
<!-- action-docs-runs -->

<!-- prettier-ignore-end -->

## Faster warm jobs on Namespace Linux

Three opt-out / opt-in knobs cut the fixed per-job cost. Defaults keep every existing caller
working.

### Warm Nix bootstrap (automatic, `warm-bootstrap: 'true'`)

On a Namespace Linux runner the cache volume persists `/nix` (the store, the db and the
installer's receipt) but the VM is fresh, so everything the Determinate installer puts
_outside_ `/nix` is gone. Re-running the installer to recreate it costs ~6 s. Instead:

1. The **first** job (no snapshot yet) runs the installer as before and then snapshots what the
   installer wrote outside `/nix` (`/usr/local/bin/determinate-nixd`, `/etc/nix/nix.conf`) into
   `/nix/atomi-bootstrap` on the volume.
2. Later jobs verify the persisted store (snapshot present and younger than
   `warm-max-age-days`, `nix` runs, store db passes `PRAGMA quick_check`, nothing pre-installed in
   the image), then recreate the build users, `/etc/nix/nix.conf` + `nix.custom.conf` (same computed
   config the installer receives: substituters, keys, `lazy-trees`, `trusted-users`, `access-tokens`,
   provenance tags), start `determinate-nixd daemon` directly (no systemd on these runners) and
   export `PATH`. ~0.4 s.
3. Any failure rolls back what it wrote and falls through to the installer steps. A snapshot older
   than `warm-max-age-days` (default 7) is also refreshed by the installer so the Determinate Nix
   version keeps following the installer's `stable`.

It is the same Determinate Nix, the same `nix.conf`, the same daemon as an installer run.

### `github-slug: 'false'`

`rlespinasse/github-slug-action` (~1 s) exports the `GITHUB_*_SLUG` / `GITHUB_*_SHORT` variables
that release/tagging jobs use. Plain test jobs can turn it off.

### `atomi-develop`: `nix develop -c` without re-evaluating

The action puts `atomi-develop` on `PATH`:

```yaml
- uses: AtomiCloud/actions.setup-nix@v3
- run: atomi-develop .#ci -c ./scripts/ci/test.sh unit
```

`nix develop` re-evaluates the flake on every commit (the eval cache is keyed on the source tree)
and looks up `nixpkgs#bashInteractive` through the registry. `atomi-develop` runs
`nix print-dev-env` (the script `nix develop` itself sources) once per key and stores it under
`/nix/atomi-devenv` on the cache volume; on a hit it sources it directly: same environment, same
`shellHook`, no evaluation (`NIX_GCROOT` included; verified byte-for-byte against `nix develop -c env`).

- **Key:** nix version, architecture, the installable, the flake directory and the content of
  `flake.nix`, `flake.lock` and `nix/**`. If your `.nix` files read anything else (a `readFile`, a
  `src = ./x`), list it in `ATOMI_DEVENV_PATHS` (space separated, relative to the flake dir).
- **Safety:** a cached env whose store paths are no longer in the store is a miss. `ATOMI_DEVENV_VERIFY=1`
  additionally evaluates fresh on a hit and fails if the two differ. `ATOMI_DEVENV_CACHE=0` bypasses.
- **Fallback:** anything other than `<local flake>#<shell> -c <cmd...>` (extra flags, remote flake
  refs, no cache dir, macOS/GitHub-hosted runners) runs plain `nix develop`.
