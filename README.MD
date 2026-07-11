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
