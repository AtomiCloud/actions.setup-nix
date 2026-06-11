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
3. At **end of job** (only on success), a bundled post hook realizes every devShell closure
   and `nix copy`s it back into the `file://` cache. `nix copy` is incremental, so warm
   runs cost seconds; the one-time cold push of a multi-GB closure is ~1–3 min.

This write-back is automatic — callers do **not** add a trailing step.

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
