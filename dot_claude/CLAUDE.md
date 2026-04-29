# Claude Code -- user-level guide

Cross-machine defaults for every Claude Code session on this host. A per-repo
`CLAUDE.md` overrides anything here.

Framed on Martin Fowler's harness-engineering model: this file is a *guide*
(feedforward -- steers behaviour before an action). Deterministic *sensors*
(tests, linters, type-checkers) live per-project, not here. Hooks in
`settings.json` enforce the rules below for the cases where text alone is not
reliable enough.

## Pull requests

- Open every PR as a draft. The user promotes to ready after reviewing.
  Two deterministic enforcers cover the paths the model can take:
  `~/.claude/hooks/pr-draft-guard.sh` blocks the GitHub MCP tools
  (`mcp__github__create_pull_request` and its copilot variant) when
  `draft=true` is missing, and `~/.local/bin/gh` shadows the apt `gh`
  binary to require `--draft`/`-d` on `gh pr create`. Override
  intentionally with `GH_DRAFT_GUARD=off gh pr create ...`.
- PR body structure (assumes the PR will be squash-merged, so the body
  is the surviving commit context):
  - **Context** — one or two sentences on why this change exists. If an
    issue exists, link it and state the PR's approach to it; do not
    re-explain the issue.
  - **Gotchas** — direct the reviewer: "focus on X because Y." Tell
    them where to spend time, not just what is risky. Omit the heading
    when there is nothing to flag.
  - **Verification** — what was checked beyond CI (which is already
    visible in the PR). Describe manual or exploratory testing that was
    performed, using past tense ("ran X, confirmed Y"). Do not
    re-list automated checks that CI covers.

## Issues

- When a repo provides issue templates, use the matching template.
  When no template exists, structure the issue body as follows:
  - **Why** — the motivation: what problem exists, what opportunity is
    being missed, or what user need is unmet. Lead with outcomes, not
    implementation.
  - **Done when** — one or two concrete acceptance criteria that define
    the exit condition. State the desired end state without prescribing
    the implementation path.
- Before filing, check the repo's milestones and labels. Assign the
  issue to the most relevant milestone (or leave it unset if none fits)
  and apply labels that match the issue's type and area.

## Issue workflow

- Before implementing a GitHub issue, read its comments and scan recent
  commits in the relevant area to confirm the work is still relevant
  given the current state of the repo. Surface a go/no-go before
  writing code if anything looks stale (e.g., the tooling the issue
  assumes has since been replaced).
- For multi-step tasks, commit incrementally rather than batching all
  changes for the end. Usage limits or interruptions then leave a
  recoverable branch instead of lost work.

## Feedback preference

- Run the project's computational sensors (tests, linters, type checker,
  formatter) before claiming a task is done. Use inferential review
  (another LLM reading the diff) to catch what those miss, not as a
  substitute for them.

## Approach

- Prefer the simplest solution that meets the requirement. Before
  writing custom scripts, guards, or wrappers, check whether a standard
  mechanism (env var, official package repo, existing repo pattern)
  already covers it. When the proposed change is more complex than
  precedent in the repo, justify the divergence in one sentence or
  pick the precedent.
- Propose the minimal fix first. Add complexity only when the minimal
  version is shown to be insufficient -- not pre-emptively.

## Scope

- Fix the task that was asked. Don't refactor, rename, or tidy adjacent
  code in the same change unless explicitly requested.

## Verify before claiming

- Don't assert behaviour you haven't checked. Claims like "this script
  isn't bundled in the WASM", "the schema doesn't include this field",
  "tests can't run in this environment", or "the issue is obsolete" need
  a quick `grep`/`find`/`unzip -l`/WebFetch/devcontainer-exec first. When
  verifying is too expensive, say "I haven't checked, but I think..."
  rather than picking a side. A confident wrong answer costs more than
  one round of "let me confirm".

## Growing this file

Add a rule here once the same friction shows up in more than one project.
If a rule needs to be deterministic (Claude must not be able to forget it),
pair it with a hook in `settings.json` instead of -- or in addition to --
a bullet here.
