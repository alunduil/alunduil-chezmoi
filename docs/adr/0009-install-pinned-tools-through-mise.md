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

- Keep externals without checksums, as 0008 does.
- Pin hashes in externals and update them by hand on every bump.
- Return to a script per tool that checks the upstream checksum file, as
  ADR 0003 did. Each tool costs a script, and runtimes stay with their
  own managers.
- Install through mise, which records a checksum per tool and platform
  in `mise.lock` and fails the install on a mismatch. Renovate's mise
  manager updates the lockfile inside its own bump, as it does for npm
  or uv. mise also manages runtimes and their CLIs. A local Renovate run
  confirmed the lockfile update at chezmoi's source path. The hosted
  Renovate app hasn't yet run it in a real pull request.

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
  binaries, and `signal-cli` verifies a GPG signature against a pinned
  key, which mise can't express.
