# 4. Name workflows for their trigger, consolidating CI into one file

## Status

Accepted

Supersedes [0002](0002-keep-per-workflow-ci.md).

## Context

ADR 0002 kept one workflow per sensor and rejected consolidation into a
shared `ci.yml` outright. Nothing it predicted turned out wrong; what
changed is a constraint it never weighed.

Workflow files across these repos are named for the *trigger or cadence*
that fires them, with the descriptive names carried by the jobs inside.
`alunduil/woodland-generators` is the reference: `ci.yml`, `weekly.yml`,
`bench.yml`. This repo already followed the scheme on the scheduled half,
where `weekly.yml` holds the link check as job `external-links`, but not
on the push/pull-request half, where files name the checking tool
(`bats.yml`, `vale.yml`, `pre-commit.yml`) or the subject under test
(`zellij.yml`, `systemd.yml`, `chezmoi.yml`). Neither tells a reader when
the file runs, which is the one thing a workflow filename determines.

The naming convention and the file layout aren't separable. A trigger
named file *is* the consolidation: everything firing on push-to-main and
pull-request belongs in the file named for that trigger.

ADR 0002's three arguments survive this reversal unevenly:

- **Independent status check per sensor.** Retained in full. GitHub
  emits a check run per job, so each sensor still reports separately as
  `CI / <job>`; only the prefix changed.
- **Native per-workflow `paths:` filters.** Genuinely lost. GitHub gates
  paths per workflow, not per job, so the two jobs with expensive setup
  (`systemd-units`, `observability-smoke`) now resolve their filters in a
  `changes` job and gate on its outputs. This is the in-job conditional
  machinery 0002 named as the cost of consolidating, and it's now paid.
- **Consolidation removes only ~10 lines of boilerplate per file.** Still
  true, and still not a reason to consolidate. Boilerplate reduction is a
  side effect here, not the motivation.

## Decision

Name each workflow file for the trigger that fires it. `ci.yml` holds
everything on push-to-main and pull-request; `weekly.yml` holds scheduled
work. Jobs carry the descriptive names.

New checks land as jobs in the file matching their trigger, not as new
files. A new file is warranted only by a new trigger.

Expensive jobs stay path-gated, per 0002's still-standing rule that
gating is for costly setup and never for cheap validation. Gating moves
into the `changes` job, which resolves filters with `dorny/paths-filter`
and exposes one output per gated job.

Revisit if the `changes` job's filters drift out of sync with what the
jobs they gate actually depend on, since that failure is silent in a way
the native `paths:` filter wasn't.

## Consequences

- A reader can tell when a workflow runs from its filename, and the
  convention matches the other repos.
- Path gating is now a hand-maintained filter list in one job rather than
  a native filter next to the job it guards. A change to `ci.yml` itself
  re-runs both gated jobs, since the filter can no longer tell which one
  changed.
- Every run spins up one extra short-lived runner for `changes`, and the
  two gated jobs wait on it before starting.
- `dorny/paths-filter` is a new third-party action in the supply chain,
  SHA-pinned and Renovate-tracked like the rest.
- Renovate's custom managers that scraped versions out of `bats.yml` and
  `chezmoi.yml` now point at `ci.yml`; a future split would have to move
  them again.
