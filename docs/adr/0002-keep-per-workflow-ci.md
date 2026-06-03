# 2. Keep one CI workflow per sensor

## Status

Accepted

## Context

CI runs one workflow per sensor (`bats`, `python`, `zellij`, `chezmoi`,
`pre-commit`, `lychee`, `observability`), and each repeats the same
`on`/`permissions`/`concurrency` boilerplate. The justfile defines most
of the same checks as recipes (`check-bats`, `check-observability`, …),
so the two can drift. #274 asks whether to collapse the workflows into a
single `ci.yml` with one job per check calling `just <check>`, making the
justfile the single source of truth CI reads from.

Two pressures motivate the question:

- **Drift.** Workflow and justfile encode the same check twice; a recipe
  rename or new sensor has to be made in both places.
- **An actual gap.** `observability.yml` is path-gated to stack-file
  changes, so the cheap `script/checks/observability-config` never runs
  on an unrelated PR, and observability coverage looks absent on most PRs.

Consolidation is weaker than it first appears:

- The only genuinely duplicated boilerplate is the
  `on`/`permissions`/`concurrency` blocks (~10 lines each). The bulk,
  per-job setup, stays distinct regardless: age for `check-chezmoi`,
  Zellij for `check-zellij`, the stack binaries for observability, Python
  for `check-python`.
- Three of the seven don't map to `just <check>`. `bats`, `pre-commit`,
  and `lychee` drive both install and run through marketplace actions
  (`bats-core/bats-action`, `pre-commit/action`,
  `lycheeverse/lychee-action` with its own cache), and `lychee` isn't a
  justfile recipe at all (it's CI-only).
- GitHub supports `paths:` only at the workflow trigger, not per job. A
  single `ci.yml` would need `dorny/paths-filter` or per-job `if` to keep
  the observability smoke gated, more machinery than the per-workflow
  `paths:` it replaces.

The drift risk is already bounded: the justfile header notes each sensor
also runs in its own workflow, so a stale recipe list causes a local
false-pass that CI then catches, never a bad merge. CI is authoritative.

## Decision

We will keep one CI workflow per sensor. New checks land as new
workflows, not as jobs in a shared `ci.yml`. The
consolidation in #274 is rejected, not deferred.

The observability gap is fixed within this structure by splitting the one
workflow in two:

- `observability-config.yml`: static config validation, no path gate,
  runs on every PR. It installs the binaries those checks need (cached on
  their pinned versions to keep the always-on cost low).
- `observability.yml`: the heavy live-metrics smoke, still path-gated to
  the metrics path it exercises.

Issue #241 (`systemd-analyze verify` on the user units) lands as its own
`script/checks/*` + `just` recipe + workflow, consistent with this
structure.

We will revisit when any of these triggers fire:

- A new check is genuinely a `just <check>` one-liner with no bespoke
  setup, and three or more such checks accumulate; at that point a
  shared `ci.yml` job matrix stops duplicating boilerplate without the
  per-job-gating tax.
- Workflow/justfile drift causes a real miss (a check silently stops
  running in CI), not just a theoretical one.

## Consequences

- `observability-config` runs on every PR; a broken service config fails
  the build regardless of which files changed. The always-on binary
  install is the cost, mitigated by version-keyed caching.
- Each sensor keeps an independent status check and a native `paths:`
  filter. No `dorny/paths-filter`, no per-job `if`.
- The per-workflow boilerplate (`on`/`permissions`/`concurrency`) stays
  duplicated across files. A new sensor means a new file copied from an
  existing one.
- justfile recipes and workflows continue to encode checks twice; they
  can drift, caught by CI rather than prevented structurally.
- The smoke workflow installs only the binaries it uses (Prometheus,
  Alloy); Loki/Tempo/Grafana config validation moved to the always-on
  config workflow.
