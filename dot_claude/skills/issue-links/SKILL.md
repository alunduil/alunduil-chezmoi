---
name: issue-links
description: Relate GitHub issues and PRs — pick the right edge type (blocked-by via GraphQL, parent/sub-issue, Closes/Fixes in PR body, plain mention) and apply it. Use when asked to link, block, depend on, make a subtask of, or close-on-merge.
---

# Issue links

Pick the *strongest accurate* relationship — but no stronger.

## Decision tree

- **Closes / Fixes / Resolves #N in PR body** — auto-closes on merge.
  Default when a PR ends an issue.
- **blocked-by / blocks** — A can't proceed or ship until B lands.
  Both are peer-sized; B is *not* a piece of A. Surfaces in the
  dependency graph and gates closing.
- **parent / sub-issue** — A is decomposition of parent B's work.
  Sub wouldn't exist on its own; parent isn't done until subs are.
  Subs roll up into parent's progress.
- **plain `#N` mention** — context only, no causal edge. Discussion,
  prior art, "see also". Default when nothing stronger fits.

The trap: reaching for parent/sub-issue when blocked-by is what's
meant, because sub-issues were the only hierarchy GitHub had for
years. Size test — peer-sized → blocked-by; smaller-than-parent →
sub-issue.

## How to apply each

### Closes / Fixes / Resolves

In the PR body or commit message:

```
Closes #123
```

Same-repo number, or `owner/repo#123` cross-repo. Recognized verbs:
close, fix, resolve (any tense).

### blocked-by (GraphQL only — no `gh issue` flag, no REST)

```bash
A=$(gh issue view <A> --json id --jq .id)   # blocked issue
B=$(gh issue view <B> --json id --jq .id)   # blocker
gh api graphql -f query='
  mutation($a: ID!, $b: ID!) {
    addBlockedBy(input: { issueId: $a, blockingIssueId: $b }) {
      issue { number }
      blockingIssue { number }
    }
  }' -f a="$A" -f b="$B"
```

Removal: `removeBlockedBy(input: { issueId, blockingIssueId })`.
Read: `Issue.blockedBy`, `Issue.blocking`, `Issue.issueDependenciesSummary`.
Use `-f` (not `-F`) for `ID!` variables — `-F` coerces to Int/Bool.

### Parent / sub-issue

```bash
P=$(gh issue view <parent> --json id --jq .id)
S=$(gh issue view <sub>    --json id --jq .id)
gh api graphql -f query='
  mutation($p: ID!, $s: ID!) {
    addSubIssue(input: { issueId: $p, subIssueId: $s }) {
      issue { number }
    }
  }' -f p="$P" -f s="$S"
```

Removal: `removeSubIssue`. Reorder: `reprioritizeSubIssue`. Reparent
an existing sub: `addSubIssue` with `replaceParent: true`. Read:
`Issue.parent`, `Issue.subIssues`, `Issue.subIssuesSummary`.

### Plain mention

Just `#123` in the body. No tooling.

## Procedure

1. Read both issues — what each is *for*. Don't link from the user's
   framing alone.
2. Apply the strongest accurate edge using the size test: peer-sized
   → blocked-by; smaller-than-parent → sub-issue; resolved-by-merge →
   Closes; otherwise → plain mention. If torn between two, surface;
   don't silently pick.
3. Verify it reads back: `Issue.blockedBy` / `Issue.subIssues` for
   graph edges, the PR body for Closes.
