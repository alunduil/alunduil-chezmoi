# 11. Restrict host mise to its global config

## Status

Accepted

Supersedes [0009](0009-install-pinned-tools-through-mise.md).

## Context

mise shims let a checkout change which tool the host runs. mise is a
per-project version manager, and
[ADR 0009](0009-install-pinned-tools-through-mise.md) made it the host's
installer. Its shims read the current directory's config on every call,
so a checkout that pins a tool takes it over from the host's copy. An
untrusted checkout stops the shim with a trust prompt instead. A
checkout's tool config should apply only inside a devcontainer or when
asked for explicitly.

The installer has to carry more than single binaries. The host runs
Erlang for a repository with no devcontainer, and Terraform,
`ansible-core`, Node, Rust, and Haskell for host-side runs, alongside the
`github:` and `npm:` tools in `dot_config/mise/config.toml`.

The installer has to meet these criteria:

- A checkout's files can't change the tool the host runs.
- Each tool carries its own pinned version and checksum, as `mise.lock`
  does.
- Renovate bumps every pin.
- One installer covers every host tool, runtimes and npm libraries
  included.
- It runs on the legacy Crostini container and on Baguette.
- Few prerequisites, little root access, CI testing, and little code to
  own.

Homebrew, apt, and aqua each fall short where another option doesn't:

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

home-manager, chezmoi externals pinned by sha256, and restricted mise
meet most criteria:

- **home-manager on Nix.** The profile holds fixed store paths, so a
  checkout can't change the host's tools. A spike on penguin on
  2026-11-15 found no sandbox blocker. Nix 2.35.6 from the official
  multi-user installer built sandboxed under `lxcfs` with no setting
  changed. A standalone home-manager generation switched. Versions
  follow one nixpkgs revision rather than a pin per tool. At
  nixos-unstable `d5cc683`, nixpkgs lacked `truenas-mcp`. Its
  `fourmolu`, `ormolu` and `cabal-gild` trailed their pins because
  nixpkgs follows Stackage's long-term-support snapshots. Renovate's
  [`nix` manager](https://docs.renovatebot.com/modules/manager/nix/) is
  beta, off by default, and moves an unpinned input only through lock
  file maintenance. Nix needs root, `/nix`, a daemon, and build users.
- **chezmoi externals pinned by sha256.** chezmoi reads nothing from the
  current directory, and `chezmoi apply` fails on a checksum mismatch.
  Renovate's `github-release-attachments` datasource updates the hash
  with the version, as the hosted app did for four digests in
  [monetr/monetr#3517](https://github.com/monetr/monetr/pull/3517).
  Every binary tool publishes a linux-x64 asset. Runtimes and the bats
  libraries don't fit, so a second installer would carry them.
- **mise, restricted to its global config.** Environment variables can
  switch off each way mise finds project config: config filenames,
  `.tool-versions`, mise environments, and `auto_env`. A checkout's
  `.miserc.toml` wins over the global `miserc.toml` for these settings,
  and environment variables win over both. mise has no global-only mode. A
  context without the variables lets a checkout take over a host tool
  again, and so does a new discovery mechanism upstream. `auto_env` turns
  on by default in mise 2027.6.0. A test on 2026-11-15 used a checkout
  carrying `mise.toml` with `[env]`, `.tool-versions`, `.miserc.toml`,
  and `mise.linux.toml`. With all four switched off, mise 2026.10.8
  ignored it and ran the host's `just`.

A probe tests mise's gap. No probe removes the costs of the other two:
home-manager trades per-tool pins and supported Renovate bumps for
isolation, and externals split the installer in two.

## Decision

Keep mise as the host-tool installer and restrict it to its global
config.

- Login shells and the systemd user manager set environment variables
  that switch off every project discovery path.
- Host shims never install a missing version.
- A hostile-checkout probe runs a shim from a checkout carrying every
  config file mise discovers. It fails unless only the global config
  loads and the host's version runs. `host-status` runs it on the host,
  and CI runs it on every change.
- A pinned, verified download installs mise itself, and Renovate bumps
  it, so an upstream change to discovery reaches the host only after the
  probe passes in CI.
- A checkout's config applies inside its devcontainer, in CI, or for one
  command with the variables unset.

ADR 0009's other decisions stand: every version-pinned user tool,
runtimes and their CLIs included, installs through mise from a committed
`mise.lock`.

Revisit and prefer home-manager when Renovate's `nix` manager leaves beta
and bumps each package.
[ADR 0010](0010-configure-the-system-layer-with-ansible.md) sets the same
condition for NixOS.

## Consequences

- A checkout's config no longer changes or stops a host tool. A project
  that needs its own pin on the host asks for it explicitly.
- The restriction can fail open. The hostile-checkout probe turns that
  failure into a failing check rather than a silent takeover.
- mise's apt repository leaves the bootstrap, and each mise release waits
  for a Renovate pull request.
- A shim for a missing version fails instead of downloading it.
