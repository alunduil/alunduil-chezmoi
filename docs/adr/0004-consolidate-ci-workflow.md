# 4. Name workflows for when they run

## Status

Accepted

Supersedes [0002](0002-keep-per-workflow-ci.md).

## Context

ADR 0002 kept one workflow per sensor and rejected consolidation into a
shared `ci.yml`. Its reasoning was sound on the axis it considered, which
was whether to collapse *everything*. It never weighed the naming
question as its own axis.

A workflow filename should answer one question: when does this run. The
per-sensor layout answered a different one. Files named the checking tool
(`bats.yml`, `vale.yml`, `pre-commit.yml`), the language (`python.yml`),
or the subject under test (`chezmoi.yml`, `zellij.yml`). None of those say
when, and the tool-named ones proliferate one file per tool per trigger.
The scheduled half of the repo already got this right: `weekly.yml` is
named for its cadence and holds the link check as job `external-links`.

The distinction that ADR 0002 missed, and that resolves it, is that "when"
comes at more than one granularity. Most sensors run on every integration
event: a push to main or a pull request. Others run on a narrower condition,
only when specific paths change, because their setup is expensive
(`systemd-analyze verify` needs a ~400 MB install; the metrics smoke binds
real ports). Those are different whens, so they're different files.

Consolidating the always-on set and keeping the path-gated set split is
therefore not a compromise between 0002 and its alternative. Both fall
out of the same rule.

ADR 0002's three arguments resolve as follows:

- **Independent status check per sensor.** Retained. GitHub emits a check
  run per job, so each sensor still reports on its own; the consolidated
  ones are now prefixed `CI /`.
- **Native per-workflow `paths:` filters.** Retained, because the
  path-gated workflows keep their own files. Folding them into `ci.yml`
  would have meant re-implementing gating with a `changes` job and a
  filter-matching action—a duplicated filter list, an extra runner per
  run, and a drift failure that's silent where the native filter's isn't.
- **Consolidation removes only ~10 lines of boilerplate per file.** True,
  and not a reason to consolidate. Boilerplate reduction is a side effect.

## Decision

Name each workflow file for when it runs, at the granularity that
actually distinguishes it. Jobs carry the descriptive names.

- `ci.yml`: every sensor that runs unconditionally on an integration
  event (push to main, pull request).
- `weekly.yml`: the schedule.
- `systemd.yml`, `observability-smoke.yml`: path-gated, one file each,
  keeping the native `paths:` filter. For these the subject *is* the
  when: "runs when the systemd units change."

A new check lands as a job in the file matching its when. A new file is
warranted only by a genuinely different when, which in practice means a
new trigger, a new cadence, or a path gate.

Gating remains reserved for expensive setup, per 0002's still-standing
rule. A check whose only cost is fast validation runs unconditionally, so
missing coverage never goes unnoticed.

Revisit if another path-gated check appears whose filter overlaps an
existing one, since duplicated `paths:` lists across files would then be
their own drift risk.

## Consequences

- A reader can tell when a workflow runs from its filename.
- The always-on sensors share one set of trigger, permissions, and
  concurrency boilerplate rather than one copy each.
- `prose` needs `if: github.event_name == 'pull_request'`, because
  `reviewdog` has no diff to filter against otherwise. A job `if:` covers
  conditions GitHub evaluates at job level, which is why it suits the event
  name and not `paths:`.
- The path-gated workflows keep their `paths:` filter next to the job it
  guards, and no filter-matching action enters the supply chain.
- Moving a job between workflow files costs no Renovate config change: each
  pin carries a `# renovate:` annotation that travels with it, and
  `script/checks/renovate-pins` fails the build on an unannotated pin.
