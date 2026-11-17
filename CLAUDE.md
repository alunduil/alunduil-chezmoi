Claude Code reads this file and not `AGENTS.md`, so the import below pulls
the repo's agent rules in. Add a rule here only when it's false for every
other agent.

@AGENTS.md

The `pr-create` skill composes Summary/Gotchas/Verification headings,
which the pull request description rule in `AGENTS.md` forbids; #778
tracks the divergence. `AGENTS.md` wins here.
