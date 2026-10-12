# 9. Install pinned tools through mise

## Status

Accepted

Supersedes [0008](0008-install-pinned-binaries-as-chezmoi-externals.md).

## Context

ADR 0008 moved release binaries to `.chezmoiexternal.toml` and gave up
asset checksums. chezmoi accepts only an inline `sha256`, and Renovate
can't bump one without an edit to its own pull request. Both 0003 and
0008 turned on that force: checksums and automated bumps couldn't
coexist.

[mise](https://mise.jdx.dev) records a checksum per tool and platform in
`mise.lock` and fails the install on a mismatch. Renovate's mise manager
updates that lockfile in the version-bump pull request by running
`mise lock <tool>` itself, the same lockfile step it runs for npm or uv.
A spike in containers and a scratch repository confirmed the parts this
decision rests on:

- **Renovate finds the config at its chezmoi source path.** The default
  pattern `**/{,.}mise/config{,.*}.toml` matches
  `dot_config/mise/config.toml`, and Renovate pairs it with
  `dot_config/mise/mise.lock` and reads the locked versions. The
  config needs no `managerFilePatterns` entry.
- **The lockfile step works from that path.** Renovate runs
  `mise trust config.toml` and `mise lock <tool>` from the config's
  directory. Replaying that after a version edit rewrote the version and
  every platform checksum in the source tree's `mise.lock`.
- **The global config reads its lockfile.** With `config.toml` and
  `mise.lock` deployed to `~/.config/mise/`, `mise install --locked`
  installs from the lock and leaves the file unchanged, so chezmoi sees
  no drift. A wrong checksum fails the install with exit status 1.
- **CI has an action that pins cleanly.** `jdx/mise-action` runs on
  `node24` with no `uses:` steps, so pinning its own commit pins
  everything it runs.

The spike ran Renovate locally, which stops before opening a pull
request. The hosted Renovate app running `mise lock` in a real pull
request, with CI green, is unproven until the first migrated tool gets a
bump.

The three installers 0008 kept fare differently under mise:

- `zellij` moves. 0008 described a source-build fallback that no longer
  exists. Its installer downloads a release binary, which mise installs
  through the aqua registry with a locked checksum.
- `kcov` publishes no release binaries and builds from a source
  tarball. mise has no way to install it.
- `signal-cli` verifies a GPG signature against a pinned key
  fingerprint. mise verifies OpenPGP signatures only against keyrings it
  bundles for its core tools, such as Node and Swift. It offers no way to
  pin a key for a `github:` tool, and the aqua registry has no
  `signal-cli` entry.

mise also manages language runtimes and the CLIs installed through
them, which externals can't. Today nvm, rustup and ghcup each bring
their own pinning and Renovate wiring.

The `ha-terminal` role ignores `.config/**`, `.local/bin/**` and every
bootstrap pass, so it installs no pinned tools today. mise publishes musl
builds that run on its Alpine base, but the role has nothing for them to
install.

## Decision

Install version-pinned user tools through mise. chezmoi deploys a
global config and a committed lockfile to `~/.config/mise/`, from
`dot_config/mise/config.toml` and `dot_config/mise/mise.lock`. A
bootstrap pass runs `mise install --locked`. Renovate's mise manager
bumps the version and the lockfile in one pull request. CI installs the
same tools through `jdx/mise-action`, replacing
`chezmoi apply --include=externals`.

This covers the release binaries 0008 made externals, plus `zellij`.
Language runtimes and their CLIs move too, unless an ecosystem's own
manager is the stronger fit. Each migration records that call.

Keep a script only where mise can't do the job: `signal-cli` for its
pinned-key signature check, and `kcov` for its source build. The
`ha-terminal` role stays mise-free.

Revisit when any trigger fires:

- The hosted Renovate app can't update `mise.lock` in its own pull
  request.
- mise gains pinned-key OpenPGP verification for `github:` or aqua
  tools, so `signal-cli` can move.
- `ha-terminal` starts installing pinned tools.

## Consequences

- Every migrated tool regains corruption detection: a replaced or
  corrupt upload fails the install, whether its upstream enables
  immutable releases.
- Renovate bumps stay hands-off, now with a lockfile diff a reviewer can
  read.
- One installer serves release binaries, runtimes and their CLIs, in
  place of externals plus nvm, rustup and per-tool wiring.
- mise becomes a bootstrap dependency. It can't install itself, so its
  own install needs a pinned, verified download.
- Tools live under `~/.local/share/mise/installs/`, not `~/.local/bin/`,
  so shells and services reach them through mise activation or shims.
- Two install models remain: mise for most tools, and scripts plus
  `lib.sh` for `signal-cli` and `kcov`.
