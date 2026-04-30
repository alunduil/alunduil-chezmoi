# Claude Code -- user-level guide

Cross-machine defaults for every Claude Code session on this host.
A per-repo `CLAUDE.md` overrides anything here.

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

## Comments

- Default to no comment. Earn each one by asking "would this be true
  and useful 18 months from now to a stranger?" Drop procedural
  restatements, parentheticals describing what standard tools do,
  commit-message framing ("we used to test X but stopped"), and
  versions/dates that rot. Keep timeless WHY, non-obvious patterns,
  and protocol details not visible in code. Match the precedent in
  the surrounding file.

## Don't test upstream

- If the language, library, or tool is responsible for a behaviour,
  don't add a check for it — upstream's tests cover that better than
  yours can. Project tests cover project-specific logic only: your
  code's invariants, your config's cross-references, your wrappers'
  added behaviour.

## Where rules live

When a new rule is needed, choose the mechanism by how it must
behave:

- **CLAUDE.md text** — for behaviour Claude can be trusted to follow
  consistently after reading. Default choice. Add here once friction
  shows up in more than one project.
- **`settings.json` hooks** — for behaviour Claude must not be able
  to forget. Pair with text in CLAUDE.md when both reinforcement and
  enforcement are wanted.
- **Per-project sensors** (tests, linters, type-checkers) — for
  detecting violations after the fact. Live with the project, not
  here.
