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

| name | description | required | default |
| --- | --- | --- | --- |
| `namespacelabs` | <p>Using Namespace Lab's runners</p> | `false` | `true` |
| `darwin-cache-path` | <p>Mount path for the Namespace cache volume used as a file:// binary cache on macOS</p> | `false` | `/tmp/nix-cache` |
| `checkout` | <p>Whether to checkout the repository</p> | `false` | `true` |
| `short-length` | <p>length for short values</p> | `false` | `7` |
| `github-slug` | <p>Export the GITHUB<em><em></em>SLUG / GITHUB<em></em></em>SHORT environment variables (rlespinasse/github-slug-action, ~1s). Only release/tagging jobs need them: set 'false' for plain test jobs. The default keeps today's behaviour.</p> | `false` | `true` |
| `warm-bootstrap` | <p>Namespace Linux only. Re-create Nix from the persisted /nix cache volume without running the Determinate installer (~0.4s instead of ~6s). Any verification failure falls back to the installer. Set 'false' to always run the installer.</p> | `false` | `true` |
| `warm-max-age-days` | <p>Namespace Linux only. A persisted Nix install older than this many days is refreshed by the installer instead of being re-used, so the Determinate Nix version still follows the installer</p> | `false` | `7` |
| `devshell-cache` | <p>Namespace Linux only. Opt in to durian-shell's dev-shell cache. A repo that sets 'true' asserts its dev shell depends only on flake.nix, flake.lock and nix/** (plus DURIAN<em>SHELL</em>PATHS): not on <code>self</code>/git metadata, nor on other files. Off by default: durian-shell is then plain <code>nix develop</code>.</p> | `false` | `false` |
| `devshell-prewarm` | <p>With devshell-cache only. Space-separated installables (e.g. '.#ci .#cd'), written exactly as the jobs pass them to durian-shell. Every job makes sure ALL of them are cached (a miss is evaluated and stored), so a shell used by few jobs is not lost when parallel jobs write the cache volume back last-writer-wins. Empty: each job caches only the shell it runs.</p> | `false` | `""` |
| `flakehub-login` | <p>Log in to FlakeHub with the job's OIDC token on the warm-bootstrap path (only happens when the job has <code>id-token: write</code>). Set 'false' when the job needs OIDC for something else but uses no FlakeHub cache or private flakes: a login without FlakeHub access fails after ~10-30s of retries. The Determinate installer action (cold volume, GitHub-hosted) has no such switch and still logs in whenever the job has OIDC: drop <code>id-token: write</code> from jobs that do not need it.</p> | `false` | `true` |
| `auth-bot-app-id` | <p>App Id for auth bot</p> | `false` | `""` |
| `auth-bot-secret-key` | <p>Private key for auth bot</p> | `false` | `""` |
| `attic` | <p>Configure attic as a substituter. Reads need no token (the cache is public); pushes additionally require attic-token.</p> | `false` | `true` |
| `attic-user` | <p>Local server alias used by <code>attic login</code></p> | `false` | `primordial` |
| `attic-url` | <p>Pull URL (Cloudflare-proxied; NARs are edge-cached)</p> | `false` | `https://attic.primordial.atomi.cloud` |
| `attic-push-url` | <p>Push URL (DNS-only, bypasses the Cloudflare 100MB request-body limit that 413s large NAR uploads)</p> | `false` | `https://attic-direct.primordial.atomi.cloud` |
| `attic-public-key` | <p>Public key for attic</p> | `false` | `primordial:puK/sRe9wgfcreXNCR+rym2gwLuICwIWyAwTSG9ctkU=` |
| `attic-cache` | <p>Attic cache name</p> | `false` | `primordial` |
| `attic-token` | <p>Token for attic</p> | `false` | `""` |
<!-- action-docs-inputs -->

<!-- action-docs-outputs -->

<!-- action-docs-outputs -->

<!-- action-docs-runs -->
## Runs

This action is a `composite` action.
<!-- action-docs-runs -->

<!-- prettier-ignore-end -->

## Faster warm jobs on Namespace Linux

Five opt-out / opt-in knobs cut the fixed per-job cost. Defaults keep every existing caller
working.

**Which defaults change for existing callers?** Exactly one: on Namespace Linux runners the
Determinate installer is no longer run when the persisted `/nix` is valid (`warm-bootstrap`,
default `'true'`). The result is the same Determinate Nix, `nix.conf` and daemon, and any failure
falls back to the installer. **Opt out** with `warm-bootstrap: 'false'` (the installer runs
every job, as before). `github-slug` (default `'true'`), `devshell-cache` (default `'false'`),
`devshell-prewarm` (default empty) and `flakehub-login` (default `'true'`) change nothing unless a repo sets
them. macOS and GitHub-hosted runners are unaffected.

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

### `durian-shell`: `nix develop -c` without re-evaluating

The action puts `durian-shell` on `PATH`:

```yaml
- uses: AtomiCloud/actions.setup-nix@v3
  with:
    devshell-cache: 'true' # asserts the dev shell depends only on flake.nix, flake.lock, nix/** (see below)
- run: durian-shell .#ci -c ./scripts/ci/test.sh unit
```

`nix develop` re-evaluates the flake on every commit (the eval cache is keyed on the source tree)
and looks up `nixpkgs#bashInteractive` through the registry. `durian-shell` runs
`nix print-dev-env` (the script `nix develop` itself sources) once per key and stores it under
`/nix/durian-shell` on the cache volume; on a hit it sources it directly: same environment, same
`shellHook`, no evaluation (`NIX_GCROOT` included; verified byte-for-byte against `nix develop -c env`).

- **Opt-in contract (`devshell-cache: 'true'`, off by default):** the input exports
  `DURIAN_SHELL_CACHE=1`, only on Namespace Linux (persisted `/nix`). By setting it a repo **asserts
  that its dev shell depends only on `flake.nix`, `flake.lock`, `nix/**` and anything listed in
  `DURIAN_SHELL_PATHS`**, the same contract as any `hashFiles(...)` cache key. Without it (and on every
  other runner, and for anything the wrapper does not fully understand) it runs plain `nix develop "$@"`.
- **Key:** nix version, architecture, effective `system`/`extra-platforms`/`NIX_CONFIG`/`NIX_PATH`, the
  installable, the flake directory, the caller's cwd and, for `flake.nix`, `flake.lock`, `nix/**` and
  `DURIAN_SHELL_PATHS` (which extends, never replaces, those): file contents (symlinks followed) plus
  every entry's type, mode and link target (so adding a directory entry or `chmod +x` changes it).
- **Safety net, not a proof:** on a miss the wrapper also evaluates the same flake from a throw-away
  copy that differs in everything the key does not cover (a new commit: rev, revCount, lastModified,
  source path; and every tracked file outside the declared inputs, repo-relative so sub-directory
  flakes are handled). If the envs differ (`self`, `src = ./.`, `self.shortRev`, a `readFile` of an
  undeclared file ...) the env is never cached (a `.nocache` marker skips the attempt next time).
  This catches accidental violations of the contract but cannot prove independence (e.g. arithmetic on
  `self.revCount` that happens to agree for the probe), which is why the repo opts in explicitly and
  `DURIAN_SHELL_VERIFY=1` exists. `__structuredAttrs` envs, non-git flakes and anything the key
  cannot hash are never cached either. A cached env whose store paths are no longer in the store is a
  miss.
- **Same semantics as `nix develop -c`:** the generated script is sourced, then the command is
  `exec`ed unconditionally with its argv untouched (a `shellHook` that ends with a failing command does
  not skip the command; exit codes pass through). `DURIAN_SHELL_VERIFY=1` additionally evaluates fresh on
  a hit and fails if the two differ; `DURIAN_SHELL_CACHE=0` bypasses.
- **One file, no action paths:** `bin/durian-shell` reads only its arguments, the
  `DURIAN_SHELL_*` variables and the flake (it needs bash, nix, GNU coreutils/findutils/sed/grep and
  git), so it can be used outside this action, e.g. `nix develop` replaced by `durian-shell` in a
  Taskfile.

#### Renamed from `atomi-develop` (v3.7.0)

| v3.7.0 | now |
| --- | --- |
| `atomi-develop` | `durian-shell` |
| `ATOMI_DEVENV_CACHE` / `_DIR` / `_PATHS` / `_VERIFY` / `_KEEP` | `DURIAN_SHELL_CACHE` / `_DIR` / `_PATHS` / `_VERIFY` / `_KEEP` |
| cache dir `/nix/atomi-devenv` | `/nix/durian-shell` |
| log prefix `[atomi-develop]` | `[durian-shell]` |

`atomi-develop` still works: it is a deprecated shim that copies every set `ATOMI_DEVENV_*` variable to
its `DURIAN_SHELL_*` name (an explicitly set old name wins), prints one deprecation line on stderr and
execs `durian-shell`. Commands run through it also see those `DURIAN_SHELL_*` copies. It will be
removed in v4. The old `/nix/atomi-devenv` directory is not read or migrated: after the upgrade each
shell is evaluated once more and stored under `/nix/durian-shell`; the old directory stays on the volume
until the volume is reset.

### `devshell-prewarm`: keep every shell cached across parallel jobs

Parallel jobs fork the cache volume and Namespace keeps the last successful job's copy
(last-writer-wins). With plain `devshell-cache`, each job stores only the shell it runs, so a shell
used by few jobs (say `.#cd` for Docker and Helm next to four `.#ci` jobs) is regularly dropped and
re-evaluated. List every shell the workflow uses, written exactly as the jobs pass it to
`durian-shell`:

```yaml
- uses: AtomiCloud/actions.setup-nix@v3
  with:
    devshell-cache: 'true'
    devshell-prewarm: '.#ci .#cd'
- run: durian-shell .#cd -c ./scripts/ci/docker.sh
```

Every job then runs `durian-shell --warm .#ci .#cd` right after setup: a cached shell costs one key
check (~0.2 s), a missing one is evaluated and stored (its closure is realised too), so whichever
job's volume wins holds all listed shells. Nothing runs inside the shells, a shell that cannot be
cached is skipped, and the step never fails the job. The pass keeps at least one cached env per
listed shell, raising `DURIAN_SHELL_KEEP` (default 8) for itself when the list is longer. Without
`devshell-cache` (and off Namespace Linux) the step does not run.

### `flakehub-login: 'false'`

When a job has `id-token: write`, the Determinate installer action and the warm bootstrap both run
`determinate-nixd login github-action`, which exchanges the job's GitHub OIDC token for a FlakeHub
token. For a repository whose organisation has no FlakeHub access, FlakeHub answers 401 and the login
retries for ~10-30 s before giving up (the job continues). Set `flakehub-login: 'false'` to skip it on
the warm-bootstrap path. The installer action has no such switch and still logs in whenever the job
has OIDC (GitHub injects the token variables into every JavaScript action step, so they cannot be
blanked from here): the real fix is to grant `id-token: write` only to jobs that use it.
