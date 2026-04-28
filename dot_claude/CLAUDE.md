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
  - **Context** — why this change exists. Link the motivating issue or
    describe the problem. The diff already shows *what* changed; the body
    explains *why*.
  - **Gotchas** — anything a reviewer should watch for: non-obvious side
    effects, temporary trade-offs, migrations, breaking changes, or
    areas that need extra scrutiny. Omit the heading when there is
    nothing to flag.
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
  - **Suggested approach** — a lightweight sketch of how to address it.
    Focus on the desired end state and key constraints rather than
    step-by-step instructions. Include enough detail to reduce ambiguity
    without over-prescribing the solution.
- Before filing, check the repo's milestones and labels. Assign the
  issue to the most relevant milestone (or leave it unset if none fits)
  and apply labels that match the issue's type and area.

## Feedback preference

- Run the project's computational sensors (tests, linters, type checker,
  formatter) before claiming a task is done. Use inferential review
  (another LLM reading the diff) to catch what those miss, not as a
  substitute for them.

## Scope

- Fix the task that was asked. Don't refactor, rename, or tidy adjacent
  code in the same change unless explicitly requested.

## Growing this file

Add a rule here once the same friction shows up in more than one project.
If a rule needs to be deterministic (Claude must not be able to forget it),
pair it with a hook in `settings.json` instead of -- or in addition to --
a bullet here.
