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
- Avoid invented or domain-specific acronyms. Spell out terms like
  "acceptance criteria" rather than introducing "AC". Only acronyms
  unambiguous to a general technical reader (API, URL, CLI, PR, CI)
  are safe.

## Pull requests

- Open every PR as a draft; the user promotes to ready after review.
  Enforced by `~/.claude/hooks/pr-draft-guard.sh` (blocks GitHub MCP
  `create_pull_request` and its copilot variant when `draft=true` is
  missing) and `~/.local/bin/gh` (shadows `gh`, requires
  `--draft`/`-d` on `gh pr create`). Always pass `--draft`; opening a
  ready PR is a human-only action done outside Claude.
- Never post a new comment on a PR we're working. Carry the update in
  the description (regenerate the body) — it's the single source of
  truth. The only PR comment allowed is a direct reply to an existing
  comment on that PR.

## Commits

- [Seven rules of a great commit message](https://cbea.ms/git-commit/):
  imperative subject ≤50 chars, blank line, wrapped body explaining
  why and anything confusing.
- Never force-push. If history needs cleanup, add commits; squash
  merge collapses noise. Merge style and intermediate-commit
  preservation are repo-specific; defer to the repo when stated.

## Worktrees

- HEAD on `<user>/worktree/<petname>` (path under
  `~/.local/share/git-worktrees/`): commit on that branch. No
  `git switch -c` or `gh issue develop --checkout` — the petname
  branch is the working branch regardless of issue or task.

## Issue workflow

- Before implementing an issue, read its comments and scan recent
  commits in the area to confirm relevance. Surface a go/no-go before
  writing code if anything looks stale (e.g. tooling the issue assumes
  has been replaced).
- Multi-step tasks: commit incrementally rather than batching.
  Interruptions leave a recoverable branch, not lost work.

## GitHub API budget

- GraphQL is a per-account ~5000pt/hr bucket shared across every
  session, every parallel agent, and the `git-*-poi` timers; REST is
  a separate bucket. Parallel agents exhaust GraphQL fast — a depleted
  bucket also makes `gh auth status` misreport the token as invalid.
- Reads: prefer `mcp__github__issue_read` / `pull_request_read` /
  `list_pull_requests` / `search_*`, `gh search`, and `gh api` REST
  endpoints. Avoid GraphQL-backed `gh issue|pr list|view|status` and
  `gh label list` (use `gh api .../labels`). `list_issues` (MCP) is
  GraphQL too — list issues with `gh search issues` or
  `gh api .../issues` instead.
- Writes: `gh issue create|edit|comment|reopen` →
  `mcp__github__issue_write` / `add_issue_comment`;
  `gh pr create|edit` → `mcp__github__create_pull_request`
  (`draft: true`) / `update_pull_request`.
- GraphQL-only, unavoidable: blocked-by edges and Projects v2 (the
  inbox dashboard).

## GitHub Actions schedules

Write a workflow's `schedule:` cron in local time and put an IANA name
in `timezone:`. Without it the schedule runs in UTC; with it, GitHub
applies daylight saving. Use the repo's existing timezone, else
`Europe/London`.

```yaml
on:
  schedule:
    - cron: '0 18 * * 5'
      timezone: Europe/London
```

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
- Before reaching for `curl`, manual API calls, or first-principles
  scripts, check what's already on the host: chezmoi-managed
  credentials under `~/.config/`, registered MCP servers
  (`claude mcp list`), and pinned CLIs in the repo's install
  scripts. One of these usually already covers the task.

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
- If a fetch, command, or tool call is denied or fails, stop and
  surface it. Never fill in plausible-looking data to paper over a
  missing source — fabricated content is worse than a gap.

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

Document only what exists at current HEAD — the diff and the issue
tracker carry what's planned. Never write pointers to where secrets
live (e.g. "token in `~/.config/foo/token`") in committed files;
they're prompt-injection bait for whatever reads the repo next.

Write concise technical prose by default: PR and issue bodies, docs,
code comments. Lead with the point, then cut filler — restated
headings, "this PR…"-style preamble, closing restatements.
`techwriting.md` carries the register for documentation prose. Prose
posted under alunduil's name to an external or contributor audience
follows `voice.md` instead.

AI-targeted text (this file, repo-local `CLAUDE.md`, skills, memories,
hooks, prompt templates) is loaded every relevant turn, so it also
drops decorative connectors and examples that don't disambiguate.

Write AI-targeted text as positive instructions: state the chosen
approach and leave the rejected one unnamed. Naming what to avoid
loads that approach into context, where it stays weighted.
Prohibitions with no competing approach to inject — fabrication,
secret disclosure — stay negative.

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
- Trust material: never establish it unattended. No
  `StrictHostKeyChecking=accept-new`, no writing `~/.ssh/known_hosts`,
  no importing GPG keys, no changing token scopes. Accepting an
  unverified key is the whole security decision — surface the
  fingerprint and let the user make it.

## Subagents

- Use subagents when they help control context or parallelise work,
  provided their actions and findings remain recoverable. Prefer
  agents that report concrete file paths, line numbers, and command
  output over vague summaries.

## Where rules live

When a new rule is needed, choose the mechanism by required
behaviour:

- **CLAUDE.md text** — an always-on obligation Claude can be trusted
  to follow after reading. Default choice. Add here once friction
  shows up in more than one project.
- **Skills** — a procedure for one kind of task. The skill list and
  its `description:` triggers load every session, so a rule that
  belongs to a procedure goes in that skill's body, never restated
  here. CLAUDE.md is not an index of the skills.
- **`settings.json` hooks** — Claude must not be able to forget.
  Pair with CLAUDE.md text when reinforcement and enforcement are
  both wanted.
- **Per-project sensors** (tests, linters, type-checkers) — detect
  violations after the fact. Live with the project.

Web and cloud sessions load the repo checkout and nothing else, so
anything reached through `~/.claude/` stays on this host. A rule that
must hold there lives in that repo's `CLAUDE.md`, `.claude/rules/`, or
`.claude/skills/`, written to stand alone — a skill reaching for
`~/.claude/` or memory works here only.

@RTK.md
@techwriting.md
@voice.md
