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
  Enforced by `~/.claude/hooks/pr-draft-guard.sh`; this bullet is the
  backup for code paths the hook does not cover (e.g. `gh pr create`
  invoked through Bash).

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
