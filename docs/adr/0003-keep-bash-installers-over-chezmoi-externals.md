# 3. Keep bash installers over chezmoi externals

## Status

Accepted

## Context

`script/install/*` plus `lib.sh` reimplement a download, verify, extract,
install pipeline. chezmoi ships that pipeline natively as `.chezmoiexternal`
externals, with built-in caching, `refreshPeriod`, and `sha256` checks. For
the tools that are a single binary in a public release tarball, one external
stanza would replace a whole installer. #309 asked whether to migrate,
and #295 is poised to add yet another script on the current pattern.
So the question is worth a recorded answer, not a per-tool reflex.

Twelve tools fit an external on the surface: `act`, `alloy`, `gcx`, `just`,
`lazygit`, `loki`, `lychee`, `tempo`, `trivy`, `truenas-mcp`, `uv`, `vale`. Six
can't move regardless: `signal-cli` (GPG-pinned), `grafana` (multi-file tree
plus a symlink), `prometheus` (two binaries), `yq` (raw binary, odd checksum
format), `zellij` (source-build fallback), and `bats-libs` (two linked
libraries). Those keep `lib.sh` alive no matter what.

Three forces decide the rest:

- **CI reuse.** Five workflows call `script/install/<tool> --bin-dir` to drop
  one binary on a runner. Externals only appear on `chezmoi apply`, which needs
  the full dest-dir and age-secret setup. Migrating forces CI to run a full
  apply or to keep the scripts anyway. Keeping both is strictly worse.

- **Checksum pinning.** The script tools fetch upstream `checksums.txt` at
  install and verify the match, so Renovate bumps only the version string.
  Externals take only an inline `sha256`; there is no remote lookup. Renovate
  has no chezmoi-external manager and no datasource that yields a release
  asset hash, so each bump becomes a manual hash chore or drops verification.

- **Prototype.** lazygit as an `archive-file` external applied in under a second
  with an inline `sha256`. It works, but getting the pin meant fetching
  `checksums.txt` by hand, which is the manual step Renovate can't automate.

## Decision

We keep the bash installers and reject the move to `.chezmoiexternal`. New
tools land as a `script/install/*` script on the shared `lib.sh` pattern.

The win was never whole: six tools stay scripts, so `lib.sh` stays too.
Migrating the other twelve would split the install model in two, drop dynamic
verification or add manual hash work per bump, and still not replace the
scripts CI depends on.

We revisit when any trigger fires:

- chezmoi gains remote checksum verification, so a pin can match a
  `checksums.txt` entry instead of a hand-copied hash.
- Renovate gains a chezmoi-external manager or a release-asset hash
  datasource that updates the inline `sha256` on a bump.
- CI stops needing standalone binary installs, for example by routing every
  binary check through one cached `chezmoi apply`.

## Consequences

- The single `lib.sh` plus per-tool pin plus Renovate regex manager stays the
  one install model. Bumps stay automated and verification stays dynamic.
- CI keeps calling the scripts directly, with no apply or secret setup on a
  runner that only needs one binary.
- New tools keep paying the small cost of a new script rather than a one-line
  external. That cost is the price of staying on a single, CI-reusable model.
- The triggers are the load-bearing part: without them this reads as "stay
  bash forever," which isn't the decision being made.
