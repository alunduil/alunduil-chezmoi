---
name: changelog
description: Audit, write, or update CHANGELOG.md following Keep a Changelog 1.1.0. Use when creating a CHANGELOG, or reviewing commits to ensure Unreleased reflects user-visible changes. Defers to auto-managed setups (changesets, release-please, git-cliff, semantic-release, towncrier) and applies semver 2.0.0 — or Haskell PVP for Haskell projects.
---

# Changelog

References: <https://keepachangelog.com/en/1.1.0/>, <https://semver.org/>, <https://pvp.haskell.org/>.

This skill maintains a hand-curated KAC. It detects auto-managed setups and steps aside; it never proposes adopting tooling. Cutting a release (tagging, version-file edits) is out of scope — bootstrap and review-against-commits only.

## Defer to auto-tooling

If any are present the changelog is auto-managed — surface the detection and stop unless the user overrides:

- `.changeset/` — changesets
- `.release-please-manifest.json` / `release-please-config.json` — release-please
- `cliff.toml` / `.cliff.toml` — git-cliff
- `package.json` `"release"` / `"semantic-release"`, or `.releaserc*` / `release.config.*` — semantic-release
- `pyproject.toml` `[tool.towncrier]`, or `newsfragments/` — towncrier

Treat any clearly auto-managed CHANGELOG the same way.

## What to include

Entries describe changes visible to consumers of the deliverable — users of the library / CLI / service, not contributors to the repo.

Include: public API changes (additions, removals, renames, signatures), observable behavior changes (output, errors, defaults), user-facing bug fixes, perceptible performance changes, security fixes, breaking deprecations, and supported-platform / runtime / dependency changes users must adapt to.

Skip: typos, comment-only changes, internal refactors, test changes, build/CI tweaks, dependency bumps users don't perceive, doc fixes (unless docs are the deliverable), and fixes for bugs no released version exhibited.

The test: "would a user of this project notice or care?" If no, skip.

## Format invariants

- `## [Unreleased]` at the top; releases below as `## [X.Y.Z] - YYYY-MM-DD`, newest first.
- Section order: Added → Changed → Deprecated → Removed → Fixed → Security. Omit empty sections unless the file already keeps them.
- Comparison links at the bottom (`[X.Y.Z]: https://.../compare/...`).
- Released versions are immutable. If a PR merged after its target tag, move the entry from the released section back to `[Unreleased]` rather than editing the released section.

## Versioning

Default: **semver 2.0.0** — MAJOR breaking, MINOR additions, PATCH fixes.

Haskell (any of `*.cabal`, `cabal.project`, `stack.yaml`, `package.yaml` present): **PVP A.B.C.D**. Both `A` and `B` together form the major version — a bump in *either* means breaking change. `C` is for API additions. `D` is maintainer-defined, typically non-API patches. The leading `A` is the "epoch" — discretionary, used for major directional shifts and documented in the [PVP FAQ](https://pvp.haskell.org/faq/) as a recognized convention.

Bootstrap names the scheme in the seeded header so future review classifications stay consistent. The skill does not perform bumps.

## Evidence

Source entries from the repository, not invention:

- `git status --short`, `git diff`, `git diff --cached` — pending changes.
- `git log --oneline <last-tag>..HEAD` — commits since the last release.
- Existing `CHANGELOG.md` headings and link style.

If a change is real and user-visible but its KAC category isn't clear from the diff, mark `TBD (owner needed)` instead of guessing.

## Modes

**Bootstrap** (no CHANGELOG.md): seed a minimal KAC 1.1.0 skeleton — `## [Unreleased]`, a header link to keepachangelog.com, and a note naming the versioning scheme (semver or PVP). Optionally backfill `## [X.Y.Z]` sections from existing git tags — ask first, never unsolicited. Do not propose adopting tooling.

**Review** (CHANGELOG exists): walk commits since the last release tag (or since the last `[Unreleased]` update), apply the user-impact filter, classify each kept change into one of the six sections, and update `[Unreleased]` so it reflects user-visible work-in-progress. Used both during work as discoveries land and at release-prep time.

## Procedure

1. Detect auto-tooling. If present, surface and stop unless overridden.
2. Determine versioning scheme (PVP if Haskell, else semver).
3. Pick the mode: bootstrap / review.
4. Walk evidence; apply the user-impact filter; drop anything that fails the test.
5. Map kept changes to sections; update `[Unreleased]`.
6. Verify: section order preserved, no released-version mutation, no fabricated entries, no skipped-category items present.
