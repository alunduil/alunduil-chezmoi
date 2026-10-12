# 9. Install pinned tools through mise

## Status

Accepted

Supersedes [0008](0008-install-pinned-binaries-as-chezmoi-externals.md).

## Context

Pinned tools need a verified download and automated version bumps.
chezmoi externals verify only an inline hash, which Renovate can't
update without an edit to its own pull request, and this repository
doesn't edit Renovate's pull requests. ADR 0008 kept the bumps and
dropped the checksums, so a corrupt or replaced upload installs without
complaint unless its upstream enables immutable releases.

Language runtimes and the CLIs installed through them sit outside
externals entirely. nvm, rustup and ghcup each pin and update their own
tools.

The options:

- **Externals without checksums**, as 0008 does. Bumps stay automatic,
  but nothing detects a bad upload.
- **Externals with pinned hashes.** Every bump needs a hash edit in
  Renovate's pull request, which this repository rules out.
- **A script per tool** that checks the release's checksum file, as ADR
  0003 did. Bumps stay automatic, but the checksum file ships beside the
  asset, so a replaced release passes. Each tool costs a script, and
  runtimes keep their own managers.
- **mise.** It records a checksum per tool and platform in `mise.lock`
  and fails the install on a mismatch. Renovate's mise manager rewrites
  the lockfile in its own bump, as it does for npm or uv, so bumps stay
  automatic. The lock pins the hash seen at bump time, so a later
  replacement fails. mise also manages runtimes and their CLIs.

Only mise gives both verified downloads and automated bumps, and it
covers runtimes too.

A spike checked mise against this repository's layout:

- Renovate's default mise file patterns match
  `dot_config/mise/config.toml` and pair it with the `mise.lock` beside
  it, with no change to Renovate's configuration.
- Renovate's lockfile commands, run at that path after a version edit,
  rewrite the version and every platform checksum.
- Deployed to `~/.config/mise/`, `mise install --locked` installs from
  the lockfile without rewriting it, so chezmoi sees no drift. A wrong
  checksum fails the install.
- The hosted Renovate app hasn't yet run the lockfile update in a real
  pull request.

## Decision

Install every version-pinned user tool through mise, language runtimes
and their CLIs included. chezmoi deploys mise's global config and a
committed `mise.lock`, and CI installs the same tools through mise.

A tool mise can't install yet keeps its current installer until the
migration finds it a path into mise.

Revisit if the hosted Renovate app can't update `mise.lock` in its own
pull request.

## Consequences

- A replaced or corrupt upload fails the install, even when upstream
  doesn't enable immutable releases.
- mise replaces externals, nvm, rustup and ghcup as installers.
- mise becomes a bootstrap dependency. It can't install itself, so its
  own install needs a pinned, verified download.
- Tools install under `~/.local/share/mise/`, so shells and services
  need mise activation or shims on `PATH`.
- Some tools need work before they fit. `kcov` has published no release
  binaries since v43. `signal-cli` verifies a GPG signature against a
  pinned key, and mise checks GPG signatures only for its own Node and
  Swift installs.
