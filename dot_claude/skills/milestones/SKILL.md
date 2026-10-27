---
name: milestones
description: Create, scope, assign, score, and close GitHub milestones as monthly OKRs written to Google's OKR playbook — one committed or aspirational objective per milestone, key results as an "As measured by" checklist scored 0.0–1.0. Use when adding a milestone, writing or reviewing its objective and key results, deciding whether work belongs in one, planning next month, or closing one at month end. Never as labels.
---

# Milestones

A milestone is one objective for one calendar month. Its issues are
the work; its key results say whether the objective landed. Write and
score them to [Google's OKR
playbook](https://www.whatmatters.com/resources/google-okr-playbook).

## Shape

- **Title:** `YYYY-MM: <objective>` — e.g. `2026-11: Secrets resolve
  from 1Password on every host`. The month prefix sorts and filters;
  the objective reads in issue sidebars.
- **Due date:** last day of the month.
- **Description:**

  ```markdown
  <One or two present-tense sentences expanding the title's objective.>

  Type: committed | aspirational

  As measured by:

  - [ ] <key result>
  - [ ] <key result>

  Non-goals: <optional, one line bounding scope>
  ```

## Writing the objective

The objective states the outcome at month end.

- Fits in the title, and a rational observer can tell whether it
  landed.
- Names a benefit to someone outside the work: the user at a host, a
  reader, a contributor. Test: could every key result score 1.0 with
  nobody better off? Then reword it around the benefit.
- Starts from what that person needs. Maintenance of what the repo
  already does stays out of milestones.

## Writing key results

Key results are measurable outcomes that prove the objective.

- Each states an outcome with its evidence: a command that passes, a
  count that hits a number, an observable state. A verb like
  consult, help, analyse, or participate marks an activity; restate
  it as what the activity produces.
- Name the effect a user sees. A release, merge, or launch counts
  only as evidence of that effect.
- A grader scores it 0.0–1.0 at month end without asking the author.
  Say how partial credit is counted when it isn't obvious: for
  example, 9 of 12 repositories scores 0.75.
- Together they are sufficient: 1.0 on all of them means the
  objective landed. Add or rework key results until that holds.
- Two to four per objective.
- Date a key result that lands before month end (`by 2026-11-14`).
  Every key result due on the last day means the plan isn't real
  yet.

## Committed or aspirational

Set the type at creation and keep it.

- **Committed:** the month will deliver it; other work moves to make
  room. Expected score 1.0. A lower score carries a one-line reason.
- **Aspirational:** the end state worth reaching, even without a
  clear path yet. Expected average around 0.7, with high variance.
  Test: does it meet or exceed what its users would ask for?
  Key results short of 1.0 can carry into a later milestone.

Treat a milestone with no `Type:` line as committed.

## Velocity

The monthly limit counts objectives across every repository on the
Inbox project board, since they share one person's capacity.

- Start at one committed objective per month in total.
- Committed objectives use most of the month's capacity, not all of
  it. Aspirational objectives take the rest.
- Size each month from the last few months' scores. Add an objective
  only after a month where every committed objective scored 1.0 and
  aspirational ones averaged 0.7 or more.
- Aspirational objectives that keep scoring 1.0 are aimed too low;
  aim the next one further out.
- A repository with no objective this month has no milestone.

## Assigning issues

An issue belongs in a milestone when closing it moves at least one
key result. Leave it unassigned otherwise.

Other groupings use other tools:

- Categorical tag (area, type, priority) → label.
- Ongoing planning across many issues → the Inbox project board.
- "See also" between two issues → `#N` mention or the `issue-links`
  skill.

## Closing at month end

1. Score each key result 0.0–1.0 against its check and append the
   score to its line: `- [ ] <key result> — 0.5`. Tick the ones
   scoring 1.0.
2. Append the objective's score, the mean of its key results to one
   decimal: `Scored 0.8.` A committed objective below 1.0 adds its
   reason: `Scored 0.8: <reason>.`
3. Pick a destination for each open issue: next month's milestone or
   unset.
4. Show the user the milestone's title, the scored description, and
   each open issue with its destination. Wait for a yes before any
   write; closing can't be undone.
5. PATCH the scored description and move or unset the open issues.
6. Close the milestone.

The score is velocity data. Record it as measured and close on
schedule whatever it says. When the objective still matters, carry it
into a new milestone for next month. Closed milestones stay closed.

## Operations

```bash
inbox_repos() {
  for o in alunduil dungeon-studio qua-world; do
    gh api --paginate "users/$o/repos?per_page=100&type=owner" \
      --jq '.[] | select(.archived|not) | select(.has_issues) | .full_name'
  done
}

inbox_milestones() {
  inbox_repos | while read -r r; do
    gh api "repos/$r/milestones?state=$1" | jq -r --arg r "$r" '
      .[] | (.description // "") as $d
      | [.title, $r, .number,
         (($d | capture("Type: (?<t>[a-z]+)").t) // "committed"),
         (($d | capture("Scored (?<s>[0-9]+(\\.[0-9]+)?)").s) // "-")]
      | @tsv'
  done | sort
}

inbox_milestones open    # velocity check
inbox_milestones closed  # past scores

gh api repos/:owner/:repo/milestones \
  -f title='2026-11: <objective>' \
  -f due_on='2026-11-30T23:59:59Z' \
  -f description="$(cat description.md)"

# Tick or score
gh api -X PATCH repos/:owner/:repo/milestones/<num> \
  -f description="$(cat description.md)"

gh api -X PATCH repos/:owner/:repo/milestones/<num> -f state=closed
```

Assign with `mcp__github__issue_write` (`method: create` or `update`).
Its `milestone` param takes the milestone *number*, not the title.

## Procedure

1. Run the velocity check. If this month already holds the
   velocity limit, surface that before creating another.
2. Draft title, objective, type, key results, and due date. Revise
   until they pass every test in *Writing the objective* and
   *Writing key results*, then confirm with the user before
   creating.
3. Assign issues that move a key result.
4. During the month, tick a key result as soon as its check passes,
   independent of issue state.
5. At month end, follow *Closing at month end*.
