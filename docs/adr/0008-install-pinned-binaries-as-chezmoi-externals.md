# 8. Install pinned binaries as chezmoi externals

## Status

Accepted

Supersedes [0003](0003-keep-bash-installers-over-chezmoi-externals.md).

## Context

ADR 0003 kept `script/install/*` over `.chezmoiexternal` on two forces,
CI reuse and checksum pinning, and listed six tools that couldn't move
regardless. The first force and most of the list were wrong.

**CI reuse is false.** ADR 0003 said externals need a whole-tree
`chezmoi apply` with dest-dir and age-secret setup.
`chezmoi apply --include=externals` needs neither: it runs with an
empty `HOME`, no chezmoi config and no age key. That fires ADR 0003's
third revisit trigger.

**Few tools can't move.** Externals handle a raw binary such as `yq`
and several archives such as `bats-libs`. Three installers do work an
external can't express:

- `signal-cli` verifies a GPG signature against a pinned key
  fingerprint. Externals verify hashes, not signatures.
- `zellij` falls back to a source build.
- `kcov` builds from a source tarball.

**Checksum pinning is the deciding force.** chezmoi accepts only an
inline `checksum.sha256`, and Renovate can't bump one without touching
the PR. A pinned hash plus automated bumps needs either a human edit
per bump or a job that mutates Renovate pull requests. This repo rules
out both. Deriving the hash from `checksums.txt` at template render
time slows every `apply`, `diff` and `status`, and a failed fetch
installs the asset unverified.

The installers' checksum check catches a corrupt upload but not a
compromised release. They fetch `checksums.txt` from the same release
as the asset, so an attacker who can replace the asset can replace the
checksum file beside it. TLS already covers transit.

Upload integrity depends on the upstream repository. GitHub's immutable
releases setting is opt-in per repository. With it on, a tag's assets
can't change after publication. Without it, a maintainer can replace an
asset under the same tag. Some tools that would migrate enable it and
some don't.

## Decision

Install version-pinned release binaries as `.chezmoiexternal` entries,
with the version in the download address and no asset checksum.
Renovate bumps the version through a regex manager over that address,
the same pattern as the Zellij plugins in
`dot_config/zellij/config.kdl`, so no Renovate PR needs an edit. CI
obtains these binaries from one `chezmoi apply --include=externals`
instead of calling installers directly.

Keep a script only where an external can't do the job: `signal-cli`
for its signature check, and `zellij` and `kcov` for their source
builds. Post-install steps such as `gcx agent skills install` and the
`uv tool install` set stay bootstrap passes.

Revisit when any trigger fires:

- chezmoi gains remote checksum or signature verification, so an
  external can check the upstream `checksums.txt` or a detached
  signature without a stored hash.
- Renovate gains a chezmoi-external manager or a release-asset hash
  datasource that bumps an inline hash inside its own PR.
- A migrated tool's upstream moves its releases off GitHub or stops
  resolving at a pinned address.

## Consequences

- Externals are chezmoi targets, so they converge natively. Deleting a
  binary restores it on the next apply, with no shell guard.
- Adding a tool costs a few lines of TOML, not a script.
- Tools without immutable releases lose corruption detection. A corrupt
  or replaced upload installs without complaint.
- Two install models exist: externals for most tools, and scripts plus
  `lib.sh` for `signal-cli`, `zellij` and `kcov`. ADR 0003 counted
  that split as a cost. Three tools an external can't serve make it an
  acceptable one.
