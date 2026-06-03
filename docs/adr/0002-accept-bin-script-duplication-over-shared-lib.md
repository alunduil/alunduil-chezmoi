# 2. Accept duplication in dot_local/bin/ over a shared sourced library

## Status

Accepted

## Context

`dot_local/bin/executable_git-repo-picker` and
`dot_local/bin/executable_git-worktree-poi` independently carry the same
building blocks (#206). An internal-consistency audit (#207) did the
within-file cleanup but deferred the cross-file question, because unifying
the shared pieces means standing up a sourcing mechanism the deployed
`bin/` scripts don't use today.

The genuinely duplicated pieces, and what unifying each would cost:

- `WORKTREE_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/git-worktrees"`,
  an identical literal in each file.
- `die()`—one line each, but *different*: each prints its own
  script-name prefix (`git-repo-picker:` vs `git-worktree-poi:`).
  Unifying it trades the duplicated line for a prefix parameter at every
  call site, or a per-script global the lib reads.
- The depth-3 worktree walk (`find "$WORKTREE_ROOT" -mindepth 3
  -maxdepth 3 -type d | sort` plus a `.git` filter, encoding the
  `<org>/<repo>/<petname>` layout), present as a `walk_worktrees()`
  helper in poi and inline twice in the picker.
- worktree-path decomposition into org/repo/petname—`split_petdir()` in
  the picker; poi strips the prefix inline.

`script/install/lib.sh` is the repo's one sourced-library precedent, but
it serves eight installers that all run from a known checkout dir and
source a guaranteed sibling. The deployed `bin/` scripts run from
`~/.local/bin/` with no such guarantee. A shared lib is *technically*
reachable—a non-executable `dot_local/bin/worktree-lib.sh` deploys as
a sibling in both the source tree and `~/.local/bin/`, sourced
self-relative so the `bats` suite (which sources the scripts by path)
resolves it—but it's a new pattern with a real cost: a deploy
artifact, sourcing boilerplate in each script, and a runtime failure
mode if the lib is missing or out of step at apply time.

## Decision

We will accept the cross-file duplication and not introduce a shared
sourced library for `dot_local/bin/` scripts.

Two consumers with thin bodies don't clear this repo's bar for an
abstraction: the shared surface is roughly seven lines, `die()` isn't
even true duplication once the per-script prefix is accounted for, and
the cost of the sourcing mechanism outweighs the saving. The strongest
case for extraction is `walk_worktrees()` naming the depth-3 layout
invariant in one place, but that layout is the bedrock of the whole
pair-tab workflow—about as stable as anything in the repo—so the
"change it in three sites" risk it guards against is remote.

We will revisit if a third consumer of these building blocks appears
under `dot_local/bin/`, or if the worktree-layout invariant itself
starts changing. At either trigger the rule of three is genuinely met
and the lib pays for itself.

## Consequences

- No new deploy artifact, no per-script sourcing boilerplate, no
  lib-missing failure mode at apply time. The `bin/` scripts stay
  self-contained.
- `WORKTREE_ROOT`, the depth-3 walk, and the org/repo/petname decode
  remain defined in both files. A change to the worktree layout touches
  both scripts (and both walk sites in the picker).
- This ADR is the durable record that the duplication is deliberate, so
  a future audit reads it as a decision rather than a missed cleanup and
  doesn't re-litigate #206.
