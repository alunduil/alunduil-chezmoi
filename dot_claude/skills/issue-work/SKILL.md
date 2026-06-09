---
name: issue-work
description: Pick up an existing GitHub issue in the checked-out repo — implement from scratch or take over an in-flight PR. Use when asked to work, take, implement, fix, or close issue #N. Confirms relevance before coding (comments, recent commits, linked PRs/branches), surfaces a go/no-go on staleness, then commits incrementally.
---

# Issue work

## Inspect

```bash
gh issue view <N> --comments                                # body + comments + cross-refs
gh issue develop <N> --list                                 # branches linked to this issue
gh pr list --state all --limit 20 \
  --search "(<N> in:body) OR (<keywords> in:title,body)" \
  --json number,title,state,url
# state=OPEN → in-flight PR (takeover candidate); state=MERGED → scope already covered, even if unlinked

# Milestone gate: issue's milestone vs the current (earliest-due open) milestone
gh issue view <N> --json milestone --jq '.milestone.title // "none"'
gh api repos/:owner/:repo/milestones --jq 'sort_by(.due_on // "9999")[0].title'
# none or current → fine to work; a different (later) milestone → no-go
```

For recent commits in the area:

- Path-scoped: `git log --oneline -- <path>` over files the issue names.
- Otherwise: `git log --oneline --since=<issue createdAt>` over the likely subsystem.

## Reproduce (bug-typed issues)

Attempt repro on the default branch before writing the fix:

- A confirmed repro becomes the failing test the fix has to flip.
- A failed repro is itself a staleness signal — issue may be obsolete.
- If repro is hard because the harness for this code path doesn't exist, surface it. Tiny harness lifts can land inline; anything bigger files separately and waits for direction.

## Staleness signals

Any one fires a go/no-go before writing code:

- A commit since the issue was filed already implements or supersedes the change.
- A linked PR is already merged — the issue should close, not be re-implemented.
- An *unlinked* merged PR covers the same scope (keyword/path search). Filers don't always cross-reference; check before duplicating work.
- The issue assumes tooling/files that have since been replaced or removed.
- The motivating dependency resolved differently (e.g. "waiting on upstream X" — X shipped via a different mechanism).
- A maintainer comment narrows or vetoes the original scope and the body wasn't updated.
- The issue is parked on a *later* milestone (not the current, earliest-due open one). Deferred work — don't pull it forward. No milestone or the current milestone is fine to work.
- Repro fails on the default branch.
- The issue lacks enough detail to start without guessing.

## Go/no-go format

Name (1) the signal, (2) where you saw it (file:line, SHA, comment URL), (3) the proposed call: proceed as written / proceed with adjusted scope / close as obsolete / ask the filer.

Raise in chat by default. Escalate to an issue comment when durability matters: the filer isn't the user, work will pause waiting on an answer, or the resolution is structural enough that future readers need the context.

## Working branch

Prefer existing context over creating new:

- Already on a petname worktree branch (HEAD matches `*/worktree/*` or CWD under `~/.local/share/git-worktrees/`): use it; don't create a new branch.
- Open PR taking the issue forward → takeover: `gh pr checkout <PR#>`.
- Linked branch but no PR yet: `gh issue develop --checkout <N>` checks it out.
- Nothing linked: `gh issue develop --checkout <N>` creates and links a branch.

## Procedure

1. Inspect the issue, its comments, and linked branches/PRs.
2. For bug-typed issues, attempt repro.
3. Scan recent commits in the named area.
4. If any staleness signal fires, surface go/no-go and stop.
5. Otherwise state intent, pick the working branch, and proceed. Commit incrementally for multi-step work. Open a draft PR with `Closes #<N>` (skip if takeover — push to the existing PR's branch).
