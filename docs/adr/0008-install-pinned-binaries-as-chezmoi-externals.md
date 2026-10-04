# 8. Install pinned binaries as chezmoi externals

## Status

Accepted

Supersedes [0003](0003-keep-bash-installers-over-chezmoi-externals.md).

## Context

ADR 0003 kept `script/install/*` over `.chezmoiexternal` on two forces,
CI reuse and checksum pinning, and listed six tools that couldn't move
regardless. A spike during #506 and the re-decision in #516 showed
that the first force and most of the list were wrong.

**CI reuse is false.** ADR 0003 said externals need a whole-tree
`chezmoi apply` with dest-dir and age-secret setup. An apply narrowed
with `--include=externals` doesn't: under `env -i`, with an empty
`HOME`, no chezmoi config and no age key, it installed `yq` and created
only a state database. That's ADR 0003's own third trigger, routing CI
binary installs through one `chezmoi apply`, with a working mechanism.

**Few tools can't move.** `type = "file"` handles a raw binary such as
`yq`. An unusual checksum table only complicates resolving a hash, not
pinning a download. `bats-libs` is two archive externals. Three
installers do work an external can't express:

- `signal-cli` verifies a GPG signature against a pinned key
  fingerprint. Externals verify hashes, not signatures.
- `zellij` falls back to a source build.
- `kcov` builds from a source tarball.

**Checksum pinning is the deciding force.** chezmoi accepts only an
inline `checksum.sha256`, and Renovate can't bump one without touching
the PR. A pinned hash plus automated bumps needs either a human edit
per bump or a job that mutates Renovate pull requests. This repo rules
out both. Deriving the hash from `checksums.txt` at template render
time was spiked in #516 and rejected: it slowed every `apply`, `diff`
and `status`, and a failed fetch installed the asset unverified.

The installers' verification is weaker than it looks. They fetch
`checksums.txt` from the same release, same host and same TLS session
as the asset. That catches a corrupt or mismatched upload. It doesn't
catch a compromised release, because an attacker who can replace the
asset can replace the checksum file beside it. TLS already covers
transit.

Upload integrity depends on the upstream repository. GitHub's immutable
releases setting is opt-in per repository. With it on, a tag's assets
can't change after publication. Without it, a maintainer can replace an
asset under the same tag. Of the tools that would migrate, `yq`,
`alloy`, `uv`, `vale` and `trivy` publish immutable releases. `lazygit`,
`lychee`, `just`, `act`, `gcx` and `truenas-mcp` don't.

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
builds. Steps after the download that aren't downloads themselves, such
as `gcx agent skills install` and the `uv tool install` set, stay
bootstrap passes.

Revisit when any trigger fires:

- chezmoi gains remote checksum or signature verification, so an
  external can check the upstream `checksums.txt` or a detached
  signature without a stored hash.
- Renovate gains a chezmoi-external manager or a release-asset hash
  datasource that bumps an inline hash inside its own PR.
- A migrated tool's upstream moves its releases off GitHub or stops
  resolving at a pinned address. #590 tracks this for `truenas-mcp`.

## Consequences

- Externals are chezmoi targets, so they converge natively. Deleting a
  binary restores it on the next apply, with no shell guard or
  `installed_version_matches` check.
- Adding a tool costs a few lines of TOML and an entry the existing
  Renovate regex manager matches, not a script.
- Corruption detection is lost for tools without immutable releases.
  A corrupt or replaced upload installs without complaint.
- Two install models exist: externals for most tools, and scripts plus
  `lib.sh` for `signal-cli`, `zellij` and `kcov`. ADR 0003 called that
  split a cost. It's accepted here because the scripted set is three
  tools with reasons an external can't absorb.
