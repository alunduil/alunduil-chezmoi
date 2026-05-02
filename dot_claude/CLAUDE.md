# Claude Code -- user-level guide

Cross-machine defaults for every Claude Code session on this host.
A per-repo `CLAUDE.md` overrides anything here.

## Communication

- Ambiguous request: ask clarifying questions AND propose options
  with trade-offs and a single recommendation. Don't silently pick.
- Unambiguous request: state intent in a sentence and proceed.
- Surface disagreement early. If your model of the problem differs
  from the user's, settle it before investing in a solution that may
  not match.
- Mark uncertainty plainly ("I think", "haven't checked, but..."). When
  confident and pushed back on, cite proof — file path, command
  output, source.
- Don't fuse exposition with edits. When a change embeds a non-obvious
  decision (architecture, naming, tradeoff, scope), present the option
  and pause — don't narrate context and immediately write files.
- End multi-step work with a 1-2 line summary naming any non-obvious
  choices made. "Revisit if you don't like it" doesn't substitute for
  surfacing the choice.

## Pull requests

- Open every PR as a draft; the user promotes to ready after review.
  Enforced by `~/.claude/hooks/pr-draft-guard.sh` (blocks GitHub MCP
  `create_pull_request` and its copilot variant when `draft=true` is
  missing) and `~/.local/bin/gh` (shadows `gh`, requires
  `--draft`/`-d` on `gh pr create`). Override with
  `GH_DRAFT_GUARD=off gh pr create ...`.
- Use the repo's PR template when one exists. Otherwise, structure
  the body (squash-merged, so this becomes the commit context):
  - **Summary** — 1-2 sentences. Lead with the user-visible
    outcome ("X now works"), not the diff line ("set Y to Z in
    foo.kdl"). The diff shows what changed; the Summary explains
    what now works. Surface mechanism only when the choice isn't
    obvious from the diff. Link the issue; don't re-explain.

    Bad: "Set `format_space \"#[bg=16]\"` in pair.kdl."
    Good: "Bar paints uniformly black across the format gap,
    closing the lighter strip from #68."
  - **Gotchas** — direct the reviewer: "focus on X because Y." Where
    to spend time, not just what's risky. Omit when nothing to flag.
  - **Verification** — material checks beyond CI in past tense ("ran
    X, confirmed Y"). Skip trivial steps (file reads, listings) unless
    load-bearing. Omit the section when CI covers everything.
    Unverified items belong in Gotchas, not here.
- When adding commits to an open PR, regenerate the body from scratch.
  The body describes the merge state, not the commit log; appending
  each round drifts toward changelog narration.

## Commits

- [Seven rules of a great commit message](https://cbea.ms/git-commit/):
  imperative subject ≤50 chars, blank line, wrapped body explaining
  why and anything confusing.
- Never force-push. If history needs cleanup, add commits; squash
  merge collapses noise. Merge style and intermediate-commit
  preservation are repo-specific; defer to the repo when stated.

## Issues

- Use the repo's issue template when one exists. Otherwise:
  - **Title** — statement true when done. Active voice, outcome
    ("Profile writes persist across API restarts in Firestore",
    not "Fix profile persistence").
  - **Summary** — 1-2 sentences on what this delivers.
  - **Motivation** — what problem, dependency, or opportunity drives
    this.
  - **Scope** — concrete changes required, specific enough to start
    without ambiguity.
  - **Acceptance criteria** — measurable conditions true when done.
    Task-list syntax (`- [ ]`).
  - **Additional context** — links, screenshots, related issues, when
    they help.
- Before filing, check milestones and labels. Assign to the most
  relevant milestone (unset if none fits) and apply matching labels.

## Issue workflow

- Before implementing an issue, read its comments and scan recent
  commits in the area to confirm relevance. Surface a go/no-go before
  writing code if anything looks stale (e.g. tooling the issue assumes
  has been replaced).
- Multi-step tasks: commit incrementally rather than batching.
  Interruptions leave a recoverable branch, not lost work.

## Feedback preference

- Run the project's computational sensors (tests, linters, type
  checker, formatter) before claiming done. Use inferential review
  (another LLM reading the diff) to catch what they miss, not as a
  substitute.

## Approach

- Prefer the simplest solution that meets the requirement. Check for
  a standard mechanism (env var, official package, existing repo
  pattern) before writing custom scripts, guards, or wrappers. When
  the change exceeds repo precedent, justify the divergence in one
  sentence or pick the precedent.
- Minimal fix first. Add complexity only when the minimal version
  proves insufficient, not pre-emptively.
- Rule of three before extracting an abstraction. Exception: when a
  clean semantic concept is obvious upfront, name it early — shared
  vocabulary beats loose duplicates that resist extraction.

## Scope

- Fix only what was asked. Don't refactor, rename, or tidy adjacent
  code in the same change unless explicitly requested.
- Unrelated issues found mid-task: file separately by default.
  Piggyback only when the inclusion is small, defensible, and called
  out in the PR body.

## Verify before claiming

- Don't assert behaviour you haven't checked. Claims about bundled
  contents, schema fields, environment capability, or issue staleness
  need a quick `grep`/`find`/`unzip -l`/WebFetch/devcontainer-exec
  first. When verifying is too expensive, say "I haven't checked, but
  I think..." rather than picking a side.

## Comments

- Default to no comment. Earn each one with: "would this be true and
  useful 18 months from now to a stranger?" Drop procedural
  restatements, parentheticals describing standard tools,
  commit-message framing ("we used to test X but stopped"), and
  versions/dates that rot. Keep timeless WHY, non-obvious patterns,
  and protocol details not in code. Match the surrounding file's
  precedent.

## Documentation

Choose the cheapest layer that adds value; escalate only when the
audience needs more:

- Inline comment for non-obvious why.
- Docstring on functions, modules, packages — interfaces future
  readers land on.
- Project documentation organised by [Diátaxis](https://diataxis.fr)
  (tutorials / how-to / reference / explanation) for knowledge
  shared across the project.
- Repo-local `CLAUDE.md` when the audience is Claude, not a human.
- Promote to `~/.claude/CLAUDE.md` when the same friction shows up
  in more than one project.

Human-read docs should be skimmable and earn their place.
AI-targeted text (this file, repo-local `CLAUDE.md`, hooks, prompt
templates) is loaded every relevant turn. Optimise for tokens, not
readability: cut filler, decorative connectors, restated headings,
and examples that don't disambiguate.

## READMEs and CONTRIBUTING

- README work (audit, write, revise, badges): `readme` skill.
- CONTRIBUTING work, including the warranted/not decision:
  `contributing` skill.

## Renovate

- `renovate.json` work (audit, write, troubleshoot dashboard, regex
  managers): `renovate` skill. Default preset is
  `config:best-practices` with the pre-commit manager enabled
  unconditionally.

## Tests

- Don't test upstream. If a behaviour belongs to the language,
  library, or tool, don't test it — upstream's tests cover that
  better. Project tests cover project-specific logic only: your
  code's invariants, your config's cross-references, your wrappers'
  added behaviour.
- Avoid test theatre. If a test would still pass after deleting the
  code it claims to verify, it's decoration — delete or rewrite.
  Assertions must exercise the claimed logic or requirement.

## Before acting on shared or external state

Local, reversible work (file edits, tests, builds) needs no
confirmation — narrate, proceed. Pause and ask before anything hard
to undo or touching state outside this checkout.

- Hard-to-undo: force-pushing, modifying remote history, deleting
  branches, deployments, dropping data, edits to host-wide config
  that takes effect on next apply (e.g. `alunduil-chezmoi` source,
  `~/.claude/settings.json`).
- Installing tools: ask first. Prefer isolation (devcontainer, then
  language-native venv). When a new tool earns its place, decide
  whether it lives in the repo (isolated) or in `alunduil-chezmoi`
  (host-wide) — surface the choice, don't pick silently.
- Permission allowlists in `settings.json`: read-only fine to
  propose; mutating local needs review; remote/external stays manual.

## Subagents

- Use subagents when they help control context or parallelise work,
  provided their actions and findings remain recoverable. Prefer
  agents that report concrete file paths, line numbers, and command
  output over vague summaries.

## Where rules live

When a new rule is needed, choose the mechanism by required
behaviour:

- **CLAUDE.md text** — Claude can be trusted to follow it after
  reading. Default choice. Add here once friction shows up in more
  than one project.
- **`settings.json` hooks** — Claude must not be able to forget.
  Pair with CLAUDE.md text when reinforcement and enforcement are
  both wanted.
- **Per-project sensors** (tests, linters, type-checkers) — detect
  violations after the fact. Live with the project.
