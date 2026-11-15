# 11. Restrict host mise to its global config

## Status

Accepted

Supersedes [0009](0009-install-pinned-tools-through-mise.md).

## Context

[ADR 0009](0009-install-pinned-tools-through-mise.md) installs penguin's
pinned tools through mise. mise is a per-project version manager. Its
shims read the current directory's config on every call, so a checkout
that pins a tool takes it over from the host's copy. An untrusted
checkout stops the shim with a trust prompt instead. #1133 and #1138
are that one cause. A checkout's tool config should apply only inside a
devcontainer or when asked for explicitly.

The installer has to carry more than single binaries. The host runs
Erlang for a repository with no devcontainer, and Terraform,
`ansible-core`, Node, Rust, and Haskell for host-side runs, alongside the
`github:` and `npm:` tools in `dot_config/mise/config.toml`.

Six options compete on these criteria:

- A checkout's files can't change the tool the host runs.
- Each tool carries its own pinned version and checksum, as `mise.lock`
  does.
- Renovate bumps every pin.
- One installer covers every host tool, runtimes and npm libraries
  included.
- It runs on the legacy Crostini container and on Baguette.
- Few prerequisites, little root access, CI testing, and little code to
  own.

Three options drop out:

- **Homebrew on Linux** has no version pins. homebrew-bundle removed
  `Brewfile.lock.json` in
  [#1509](https://github.com/Homebrew/homebrew-bundle/pull/1509), and
  Homebrew [rejects](https://docs.brew.sh/Versions) versioned formulae as
  personal pins. Renovate's `homebrew` manager reads formula files only.
- **apt, with release binaries for what Debian lacks.** Debian carries
  few of these tools at the pinned version, and its suites hold one
  version each. The `trivy` and `gh` repositories keep only the latest
  release, so an exact pin breaks on each release. Everything else
  becomes a release binary.
- **aqua** reads `aqua.yaml` from the current directory and every parent.
  `AQUA_CONFIG` puts the host's file first, but a checkout can still add
  commands. Checksums are off by default and recorded on first use.
  Renovate can't update `aqua-checksums.json` without a separate
  workflow. The registry lacks six of the tools and npm.

Three options qualify:

- **home-manager on Nix.** The profile holds fixed store paths, so a
  checkout can't change the host's tools. A spike on penguin on
  2026-11-15 found no sandbox blocker. Nix 2.35.6 from the official
  multi-user installer built under `lxcfs` over `/proc` with
  `sandbox-fallback = false` and no other setting. A standalone
  home-manager generation switched. Versions follow one nixpkgs revision
  rather than a pin per tool. At nixos-unstable `d5cc683`, nixpkgs had
  21 of 22 tools and lacked `truenas-mcp`. `fourmolu`, `ormolu` and
  `cabal-gild` trailed their pins because nixpkgs follows Stackage's
  long-term-support snapshots.
  Renovate's [`nix` manager](https://docs.renovatebot.com/modules/manager/nix/)
  is beta and off by default, and moves an unpinned input only through
  lock file maintenance. It needs root, `/nix`, a daemon, and build
  users.
- **chezmoi externals pinned by sha256.** chezmoi reads nothing from the
  current directory, and `chezmoi apply` fails on a checksum mismatch.
  ADR 0009 rejected pinned hashes because each bump needed a hand edit.
  That no longer holds. Renovate's `github-release-attachments`
  datasource hashes the same-named asset in the new release. The
  hosted app bumped a version and four digests in one pull request in
  [monetr/monetr#3517](https://github.com/monetr/monetr/pull/3517). Every
  binary tool publishes a linux-x64 asset. Runtimes and the bats
  libraries don't fit, so a second installer would carry them.
- **mise, restricted to its global config.** Four environment variables
  confine discovery to `~/.config/mise/config.toml`:

  ```sh
  MISE_OVERRIDE_CONFIG_FILENAMES=none
  MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=none
  MISE_ENV=
  MISE_AUTO_ENV=false
  ```

  A checkout's `.miserc.toml` overrides these settings in the global
  `miserc.toml`, so they must be environment variables. Once only the
  global config loads, `auto_install = false` and
  `not_found_auto_install = false` there stop a shim downloading a
  missing version. mise has no global-only mode, so the restriction
  holds by configuration. A context without the variables reopens the
  gap, and so does a new discovery mechanism upstream. `auto_env` turns
  on by default in mise 2027.6.0.

  Tests on 2026-11-15 ran the host's `just` shim with mise 2026.10.8 from
  checkouts carrying `mise.toml` with `[env]`, `.tool-versions`,
  `.miserc.toml`, and `mise.linux.toml`. With no variables, the shim
  stopped on a trust error. With only `MISE_OVERRIDE_CONFIG_FILENAMES`,
  `.tool-versions` and an environment that `.miserc.toml` selected each
  still loaded and broke the shim. With all four, mise loaded only the
  global config and ran the host's `just`.

A probe can test the restriction, while no setting makes mise isolated
by design. The costs of the other two are structural: home-manager
trades per-tool pins and supported Renovate bumps for isolation, and
externals split the installer in two.

## Decision

Keep mise as the host-tool installer and restrict it to its global
config.

- Login shells and the systemd user manager set the four variables
  above, covering every context a shim runs in.
- A probe runs a shim from a checkout carrying every config file mise
  discovers, and fails unless only the global config loads and the
  host's version runs. host-status runs it on the host, and CI runs it
  on every change.
- A pinned, verified download installs mise itself, and Renovate bumps
  it, so an upstream change to discovery reaches the host only after the
  probe passes in CI.
- A checkout's config applies inside its devcontainer, in CI, or for one
  command with the variables unset.

ADR 0009's other decisions stand: every version-pinned user tool,
runtimes and their CLIs included, installs through mise from a committed
`mise.lock`.

Revisit and prefer home-manager when Renovate's `nix` manager leaves beta
and bumps each package, as [ADR 0010](0010-configure-the-system-layer-with-ansible.md)
also requires.

## Consequences

- A checkout's `mise.toml` no longer changes or stops a host tool. A
  project that needs its own pin on the host asks for it explicitly.
- The restriction can fail open. The probe turns that failure into a
  failing check rather than a silent takeover.
- mise leaves its apt repository for a pinned, verified install, and
  each mise release waits for a Renovate pull request.
- `auto_install` and `not_found_auto_install` stay off on the host, so a
  shim for a missing version fails instead of downloading it.
