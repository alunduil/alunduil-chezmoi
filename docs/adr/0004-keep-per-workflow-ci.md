# 4. Keep one workflow per sensor

## Status

Accepted

## Context

Each CI sensor runs in its own workflow, duplicating the
`on`/`permissions`/`concurrency` boilerplate, and most are also justfile
recipes, so the two can drift. The recurring temptation (#274) is to
collapse them into a single `ci.yml` whose jobs each call `just <check>`,
making the justfile the one source of truth.

The temptation is weaker than it looks. Consolidation removes only the
trigger boilerplate (~10 lines per file); the bulk of each workflow is
per-job setup (tool installs, language toolchains, secret material) that
stays distinct wherever the jobs live. Not every check is a
`just <check>` one-liner: some install and run through marketplace
actions, and link-checking isn't a recipe at all. And GitHub gates paths
only per workflow, not per job, so a single `ci.yml` would reintroduce
path filtering as in-job conditionals, machinery the per-workflow layout
gets for free along with an independent status check per sensor.

A related question is when a workflow should be path-gated. Gating hides
a check on unrelated PRs; gating a check whose only cost is fast
validation drops coverage unnoticed, which is how the observability config
validation came to never run on most PRs.

## Decision

Keep one workflow per sensor. New checks land as new workflows, not as
jobs in a shared `ci.yml`. Consolidation is rejected, not deferred.

A workflow is path-gated only when its setup is expensive, such as a
heavy install or binding real ports. A check whose only cost is fast
validation runs unconditionally, so missing coverage never goes unnoticed.

Revisit if enough checks become genuine `just <check>` one-liners with
no bespoke setup that a shared job matrix would remove real duplication,
or if workflow/justfile drift ever causes a check to stop running in CI
unnoticed.

## Consequences

- Each sensor keeps an independent status check and a native `paths:`
  filter, with no per-job path conditionals.
- The trigger boilerplate stays duplicated across files: a new sensor is
  a new file copied from an existing one, and recipe/workflow drift is
  caught by CI rather than prevented structurally.
- Cheap checks pay a small cost on every PR in exchange for never losing
  coverage unnoticed; only expensive setup is gated.
