# 3. Keep bash installers over chezmoi externals

## Status

Accepted

## Context

`script/install/*` plus `lib.sh` duplicate a download-verify-extract
pipeline that chezmoi ships natively as `.chezmoiexternal` externals.
For a single binary from a public release tarball, one external stanza
would replace a whole installer. #309 asked whether to migrate, and #295
is poised to add another script on the pattern. So the question wants a
recorded answer, not a per-tool reflex.

Of the eighteen installers, six can't move regardless: `signal-cli`
(GPG-pinned), `grafana` (multi-file tree), `prometheus` (two binaries),
`yq` (raw binary, odd checksum), `zellij` (source-build fallback), and
`bats-libs` (two linked libraries). They keep `lib.sh` alive either way.

The other twelve fit an external on the surface, but two forces sink the
move:

- **CI reuse.** Five workflows call `script/install/<tool> --bin-dir` to
  drop one binary on a runner. Externals only appear on `chezmoi apply`,
  which needs the full dest-dir and age-secret setup. Migrating forces a
  heavy apply in CI or keeping the scripts anyway.
- **Checksum pinning.** The scripts fetch upstream `checksums.txt` and
  verify at install, so Renovate bumps only the version. Externals take
  only an inline `sha256`, and Renovate has no datasource to bump that
  hash, so each version bump turns manual or drops verification.

A lazygit prototype confirmed both: the `archive-file` external applied
in under a second, but the `sha256` had to come from `checksums.txt` by
hand, the step Renovate can't automate.

## Decision

We keep the bash installers and reject the move to `.chezmoiexternal`.
New tools land as a `script/install/*` script on the `lib.sh` pattern.
Migrating only splits the install model in two, since six tools stay
scripts regardless, and still can't replace the scripts CI depends on.

We revisit when any trigger fires:

- chezmoi gains remote checksum verification, so a pin can match a
  `checksums.txt` entry instead of a hand-copied hash.
- Renovate gains a chezmoi-external manager or a release-asset hash
  datasource that bumps the inline `sha256`.
- CI stops needing standalone binary installs, for example by routing
  binary checks through one cached `chezmoi apply`.

## Consequences

- One install model stays: `lib.sh` plus per-tool pin plus Renovate
  regex manager, with automated bumps and dynamic verification.
- CI keeps calling the scripts directly, with no apply or secret setup
  on a runner that needs one binary.
- New tools keep paying for a script, not a one-line external. The
  triggers are load-bearing: without them this is "stay bash forever,"
  which isn't the decision.
