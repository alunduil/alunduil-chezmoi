# 9. Install pinned tools through mise

## Status

Accepted

Supersedes [0008](0008-install-pinned-binaries-as-chezmoi-externals.md).

## Context

chezmoi externals verify only an inline `sha256`, which Renovate can't
bump without an edit to its own pull request. Under ADR 0008, release
binaries install without a checksum so that Renovate bumps stay
automatic.

Externals also can't manage language runtimes or the CLIs installed
through them. nvm, rustup and ghcup each pin and update their own tools.

[mise](https://mise.jdx.dev) manages both. It records a checksum per
tool and platform in `mise.lock` and fails the install on a mismatch.
Renovate's mise manager updates `mise.lock` in the version-bump pull
request, as its lockfile step for npm or uv does.

This works at chezmoi's source path:

- Renovate's default file patterns find `dot_config/mise/config.toml`
  and its lockfile, and the lockfile update runs from there.
- Deployed to `~/.config/mise/`, the config installs from the lockfile
  without rewriting it, so chezmoi sees no drift.
- `jdx/mise-action` calls no other actions, so pinning its commit
  satisfies the commit-pinning invariant.

Renovate's lockfile update has run only locally. The hosted Renovate app
hasn't yet run it in a real pull request with CI.

Three tools still install through `script/install/*`:

- `zellij` installs a release binary, which mise covers.
- `kcov` publishes no release binaries and builds from source.
- `signal-cli` verifies a GPG signature against a pinned key. mise
  checks OpenPGP signatures only against keyrings it bundles, such as
  Node's, and can't pin a key for another tool.

The `ha-terminal` role installs no pinned tools. mise publishes musl
builds that run on its Alpine base.

## Decision

Install version-pinned user tools through mise. chezmoi deploys
`dot_config/mise/config.toml` and a committed `mise.lock` to
`~/.config/mise/`, and a bootstrap pass runs `mise install --locked`.
CI installs the same tools through `jdx/mise-action`, replacing
`chezmoi apply --include=externals`.

This covers the release binaries in `.chezmoiexternal.toml` and
`zellij`. Language runtimes and their CLIs move too, unless an
ecosystem's own manager fits better. Each migration records that call.

Keep a script only where mise can't do the job: `signal-cli` and
`kcov`. The `ha-terminal` role stays mise-free.

Revisit when any trigger fires:

- The hosted Renovate app can't update `mise.lock` in its own pull
  request.
- mise can pin an OpenPGP key for any tool, so `signal-cli` can move.
- `ha-terminal` starts installing pinned tools.

## Consequences

- A replaced or corrupt upload fails the install, even when upstream
  doesn't enable immutable releases.
- mise replaces externals, nvm and rustup as installers.
- mise becomes a bootstrap dependency. It can't install itself, so its
  own install needs a pinned, verified download.
- Tools install under `~/.local/share/mise/`, so shells and services
  need mise activation or shims on `PATH`.
