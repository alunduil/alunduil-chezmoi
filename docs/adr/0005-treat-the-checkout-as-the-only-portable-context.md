# 5. Treat the checkout as the only portable context

## Status

Accepted

## Context

Claude Code runs on this host and on Anthropic-managed cloud VMs, and the
two see different configuration. A cloud session—the web app, `claude
--cloud`, a routine—starts from a fresh clone of one repository. This repo
deploys the host side: `dot_claude/CLAUDE.md` becomes `~/.claude/CLAUDE.md`,
`dot_claude/skills/` becomes `~/.claude/skills/`, and `dot_claude/hooks/`
backs the guards wired up in `~/.claude/settings.json`. None of it lives in
a checkout, so a cloud session never sees it. Global conventions and
accumulated memory are silently absent there rather than absent with a
warning, which is what makes the split worth recording.

What a cloud session does load is fixed by the product, not by us:

- From the clone: the repo's `CLAUDE.md`, `.claude/rules/`,
  `.claude/skills/`, `.claude/agents/`, `.claude/commands/`, the hooks in
  `.claude/settings.json`, and `.mcp.json`.
- Declared in the clone: plugins named in `.claude/settings.json`, fetched
  from their marketplace at session start.
- From the account: skills enabled on claude.ai, synced at session start.

Everything else stays here. The documentation is explicit that
`~/.claude/CLAUDE.md` doesn't travel because it "lives on your machine, not
in the repo," and that auto memory under `~/.claude/projects/*/memory/` is
machine-local and "not shared across machines or cloud environments."

Three ways to close the gap were weighed.

**Bootstrap chezmoi from a cloud-environment setup script.** This is the
only mechanism that can place a file at `~/.claude/CLAUDE.md` in a cloud
VM, and it would carry the skills and hooks along with it. A `cloud` value
for the existing `role` axis plus a `.chezmoiignore` block would scope the
apply to `dot_claude/`, which needs no age key because every encrypted
source sits outside that tree. It loses on where the trigger lives: the
setup script is a text field in the claude.ai environment dialog, not a
file in this repo. Nothing here can version it, no sensor can check it, and
Renovate can't see it—the repo would hold a `cloud` role whose only caller
is invisible to the repo. The delivered content would also lag. Anthropic
snapshots the filesystem after the first run and reuses it for about seven
days, so an edit to `dot_claude/CLAUDE.md` reaches cloud sessions whenever
the cache happens to expire. Rules that are quietly a week stale are worse
than rules known to be absent. The approach further assumes the session's
Claude Code runs as root with `HOME=/root`, which the documentation doesn't
state; setup scripts run as root, but that says nothing about the session.
Finally, much of `~/.claude/CLAUDE.md` is about this host—the RTK proxy
hook, the `gh` shim at `~/.local/bin/gh`, worktree paths, the
source-versus-apply clone split. In a cloud VM those rules describe
machinery that isn't there.

**Publish the skills and hooks as a marketplace plugin.** A plugin is
versioned, testable in CI, and reaches both local and cloud sessions from
one source, and a repo opts in with one line of `.claude/settings.json`. It
doesn't solve the problem this issue is about. A plugin's components are
`skills/`, `commands/`, `agents/`, `hooks/`, `.mcp.json`, `.lsp.json`,
`monitors/`, `bin/`, and `settings.json`; there's no slot for a `CLAUDE.md`
or a `rules/` directory, so the always-on rules still wouldn't travel. It
also needs a new repository, which is its own decision.

**Accept the split.** Nothing is built, so nothing can drift or go stale,
and the boundary becomes something to design against rather than to
discover. The cost is that a convention needed in several repos is written
in each of them.

Memory carries no real choice. No mechanism moves auto memory in any
direction, on purpose: it's per-machine session state.

## Decision

We will treat the repository checkout as the only context that travels.

A rule that must hold in a web or cloud session lives in that repo's
`CLAUDE.md`, `.claude/rules/`, or `.claude/skills/`, and is written to
stand on its own. Skills in particular assume no host: one that reaches for
`~/.claude/` or for memory works here and nowhere else.

`~/.claude/CLAUDE.md`, `~/.claude/skills/`, the `~/.claude/settings.json`
hooks, and auto memory stay host-local. They keep describing this host,
including the parts that only make sense here, and they aren't trimmed
toward portability.

Auto memory stays local-only and isn't promoted wholesale. A memory that
turns out to be durable project knowledge rather than a working note
graduates into the repo's `CLAUDE.md` as a rule, which is the same bar that
governed it before.

Revisit if Anthropic ships a first-party path for user-scope
instructions—an account-level `CLAUDE.md` equivalent to the account-level
skill sync—since that removes the objection that killed the setup-script
option.

## Consequences

- A web session honours the repo it cloned and nothing else. That's now a
  stated boundary, so a skill or rule can be written against it.
- The deployed `~/.claude/CLAUDE.md` is free to stay host-specific. Rules
  about the `gh` shim, RTK, and worktrees don't have to be softened for an
  audience that will never load them.
- A convention wanted in several repos is written in each of them. The
  duplication is visible in review rather than papered over by a mechanism
  that might not have run.
- The skills under `dot_claude/skills/` remain host-only. Making one
  available on the web means committing it to a repo, enabling it for the
  claude.ai account, or shipping it in a plugin—each a separate decision,
  none forced by this one.
- No cloud-environment setup script, so the claude.ai environment dialog
  holds no configuration this repo depends on.
- The `role` axis keeps its two values. A `cloud` role would have been the
  first whose caller lived outside the repo.
