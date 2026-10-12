# 9. Install pinned tools through mise

## Status

Accepted

Supersedes [0008](0008-install-pinned-binaries-as-chezmoi-externals.md).

## Context

Pinned tools need a verified download and automated version bumps.
This repository doesn't edit Renovate's pull requests, so a bump can't
carry a hand edit.

Language runtimes and the CLIs installed through them sit outside
externals entirely. nvm, rustup and ghcup each pin and update their own
tools.

Four installers could serve this repository:

- **Externals without checksums**, as 0008 does. Bumps stay automatic,
  but a corrupt or replaced upload installs without complaint unless its
  upstream enables immutable releases.
- **Externals with pinned hashes.** chezmoi verifies only an inline
  hash, so every bump needs a hash edit in Renovate's pull request.
- **A script per tool** that checks the release's checksum file, from
  ADR 0003. Bumps stay automatic, but the checksum file ships beside the
  asset, so a replaced release passes. Each tool costs a script, and
  runtimes keep their own managers.
- **mise.** It records a checksum per tool and platform in `mise.lock`
  at bump time, and a later replacement fails the install. Renovate's
  mise manager rewrites the lockfile in its own bump, as it does for npm
  or uv, so bumps stay automatic. mise also manages runtimes and their
  CLIs.

Only mise gives both verified downloads and automated bumps, and it
covers runtimes too.

mise fits chezmoi's source layout:

- Renovate's default mise file patterns match
  `dot_config/mise/config.toml` and pair it with the `mise.lock` beside
  it, with no change to Renovate's configuration.
- Renovate's lockfile update at that path rewrites the version and every
  platform checksum.
- Deployed to `~/.config/mise/`, mise installs from the lockfile without
  rewriting it, so chezmoi sees no drift. A wrong checksum fails the
  install.

The hosted Renovate app hasn't yet run the lockfile update in a real
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
- Some tools need work before they fit. `kcov` publishes no release
  binaries. `signal-cli` verifies a GPG signature against a
  pinned key, and mise checks GPG signatures only for its own Node and
  Swift installs.
