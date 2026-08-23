---
name: pr-review
description: Review a pull request's diff against the cross-repo judgment bar — correctness, secrets, inline suppressions, matching the repo's conventions, docs, commits, and the test plan. Use when asked to review a PR or a branch diff for what the repo's linters, type checkers, and scanners can't assert. Assumes the sensors are green and reviews only the residue.
---

# PR review

The repo's sensors already assert what a machine can. This review is
the residue: whether the change is *right*, not whether it is clean.
Read the diff — the tree is context, not the subject.

`/code-review` hunts bugs and cleanups in the same diff. This is the
judgment pass beside it.

## Input

```bash
# REST reads — see ~/.claude/CLAUDE.md "GitHub API budget".
gh api repos/:owner/:repo/pulls/<N> \
  --jq '{title, draft, body, base: .base.ref, user: .user.login}'
gh pr diff <N>                                              # the subject
gh api repos/:owner/:repo/pulls/<N>/commits --jq '.[].commit.message'
```

No PR open yet → `git log --patch main..HEAD` reviews the same change.

## Precondition: sensors green

Find what the repo already enforces before reading a line of the diff.

```bash
ls .pre-commit-config.yaml .vale.ini Justfile justfile Makefile 2>/dev/null
ls .github/workflows/
cat CLAUDE.md CONTRIBUTING.md 2>/dev/null   # the repo's stated conventions
gh api repos/:owner/:repo/commits/<head-sha>/check-runs \
  --jq '.check_runs[] | select(.conclusion != "success") | {name, conclusion}'
```

- Red CI is the finding. Report it and stop — restating a sensor's
  output as review prose tells the author nothing new.
- Every item a discovered sensor asserts drops out of the sections
  below. `shellcheck` owns quoting, the type checker owns annotations,
  `detect-private-key` owns anything key-shaped.
- The reverse also holds: a check the repo *lacks* moves into scope.
  An unformatted repo needs a human to notice the formatting.

## Sections

Each names the sensor's half, then yours.

**Correctness** — Sensors run the tests; they can't say these are the
right tests. New behaviour carries a test that fails without the
change, and a fix carries a regression test naming the scenario. The
diff meets the linked issue's acceptance criteria and stops there — an
unrelated refactor riding along is a finding. Edge cases: empty input,
an omitted optional argument, a failure partway through.

**Secrets** — The scanner catches what looks like a key. Catch what
doesn't: a token, endpoint, or hostname reading as ordinary config; a
file that should be `private_` or age-encrypted and isn't; a committed
pointer to where a secret lives (`token in ~/.config/foo/token`), bait
for whatever reads the repo next.

**Inline suppressions** — The hooks already force a scoped code and
reject a blanket ignore. Each new `# type: ignore[code]`, `# nosec`,
`# noqa`, or `pylint: disable` says *why* the suppression can't be
avoided, in a form still true to a stranger in 18 months.

**Match the repo, don't impose** — Typing, logging, subprocess, and
error handling follow the module the change lands in and whatever the
repo's `CLAUDE.md` or `CONTRIBUTING.md` state. Read a neighbouring file
before calling a pattern wrong. A finding names the existing pattern
the change departs from; "the repo hasn't adopted X" is a separate
issue to file, not a demand on this PR.

**Docs** — A user-visible change updates the README, the `--help` or
usage text, and whatever under `docs/` a reader lands on. Rationale a
reader can't infer from the code belongs in the repo, not only in the
PR body. New prose under `docs/` sits in one Diátaxis mode — the
`diataxis` skill owns that call.

**Commits and PR** — Subjects follow the repo's convention:
Conventional Commits where `git log` shows them, its house format
otherwise. The body says why, not what. A PR we opened is still a
draft — promoting it is the user's act, not the author's.

**Test plan** — The PR states how the change was verified, past tense
and concrete enough that the reviewer can run it and see the claimed
result. "Tested manually" is not one. An unverified item belongs in
Gotchas instead.

## Findings

- **A repo the user owns → chat.** Per `~/.claude/CLAUDE.md` a new
  comment on a PR we're working is off the table; the author carries
  fixes into the branch and regenerates the description.
- **Someone else's PR → propose a GitHub review.**
  `mcp__github__pull_request_review_write` with inline comments — a
  review, not a new comment — written in the `~/.claude/voice.md`
  register. Show the text and post only once the user approves; a
  review is shared state.
- Findings only. Sections that come out clean get one line naming
  them. Each finding carries the file and line, what's wrong, and what
  would fix it. Uncertain → say so and ask, rather than assert.

## Procedure

1. Read the PR's metadata, commits, and diff.
2. Discover the repo's sensors and stated conventions, and check CI.
   Red → report that and stop.
3. Walk the sections against the diff, dropping every item a
   discovered sensor already asserts.
4. Report per *Findings*.
