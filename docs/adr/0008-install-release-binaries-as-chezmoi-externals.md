# 8. Install release binaries as chezmoi externals

## Status

Accepted

Supersedes [0003](0003-keep-bash-installers-over-chezmoi-externals.md).

## Context

ADR 0003 kept the `script/install/*` installers and rejected
`.chezmoiexternal` on two forces: CI reuse and checksum pinning. Re-checking
both in #516 falsified the first and dissolved the second.

**CI reuse.** 0003 held that externals only appear on a full `chezmoi apply`,
which needs the age key and a configured destination. An externals-only
apply needs neither. `chezmoi apply --include=externals` runs under `env -i`
with an empty `HOME`, no chezmoi config and no age key, and writes nothing
but its state database. A CI job gets its binary from one apply of the
targets it names. This is 0003's third revisit trigger, already met.

**The immovable list.** 0003 listed six tools that could never move. Most
can. `yq` is a raw binary, which `type = "file"` installs. `bats-libs` is two
`archive` externals. `grafana` and `prometheus` have since left the repo. The
tools that genuinely stay scripts are:

- `signal-cli`, verified by a detached GPG signature. Externals check hashes,
  not signatures.
- `kcov`, built from source with a patch applied. It's not a download.

**Checksum pinning.** chezmoi still takes only an inline `checksum.sha256`,
and Renovate still can't bump one. Nothing may push to a Renovate PR, so a
stored hash and automated version bumps can't coexist. The question is what
the hash buys. The installers verified each asset against a `checksums.txt`
fetched from the same host, over the same TLS connection. That catches a
corrupted download. It's no independent trust root: anyone able to replace
the asset can replace the checksums file beside it. A GitHub release asset
is immutable, so a download address with the version pinned already fixes
the bytes, and TLS covers transit. Dropping the hash costs corruption
detection and nothing else.

Two other approaches were tried and rejected:

- **Derive the hash at render time.** The externals file is a template, so it
  can fetch the release's checksums table through `output`. It works, but
  every `apply`, `diff`, and `status` pays two fetches per tool, and offline
  commands fail. A failed fetch renders an empty `checksum.sha256`, which
  chezmoi reads as "no checksum" and installs unverified.
- **Pin the version inside each download address.** A Renovate regex over
  the address bumps only the path segment. Five assets repeat the version
  in their filename, such as `vale_3.23.0_Linux_64-bit.tar.gz`, so their
  bumps would break.

## Decision

Install version-pinned release binaries as chezmoi externals, without a
stored checksum.

- `.chezmoiexternal.toml.tmpl` declares each external. Its download address
  comes from a version in `.chezmoidata/versions.yaml`.
- Each version carries the repo's usual `# renovate:` annotation, so the
  existing custom manager and the `renovate-pins` check cover it.
- CI obtains binaries through `chezmoi apply --include=externals`, using the
  `setup-chezmoi` local action.
- A GitHub source-archive tarball (`archive/refs/tags/…`) keeps an inline
  `checksum.sha256`. GitHub generates those on request rather than storing
  them, so the address doesn't fix the bytes. Renovate bumps the version
  and a person refreshes the hash.
- A tool stays a `script/install/*` script only when it needs more than a
  download: a signature check, or a build.

## Consequences

- An external is a target. A deleted or replaced binary shows up as drift
  and comes back on the next apply, with no guard in a script.
- Adding a release binary means adding one version line and one external
  entry instead of a new installer script.
- Migrated tools lose corruption detection. A truncated download that still
  unpacks would install. TLS and archive extraction catch most such
  failures; the rest surface the first time the tool runs.
- The `chezmoi-source` CI job fetches every external during its apply
  round-trip. A release asset that moved or changed name on a version bump
  fails that job before the bump merges.
- `uv` and `gcx` now appear only once apply has written its targets.
  Passes that use them run `after`.
- Two install models remain: externals for downloads, scripts for the tools
  listed above. `lib.sh` keeps only the helpers those scripts use.
