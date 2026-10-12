---
name: milestones
description: Create, scope, assign, score, and close GitHub milestones as monthly OKRs — one objective per milestone, key results as an "As measured by" checklist in the description. Use when adding a milestone, deciding whether work belongs in one, planning next month, or closing one at month end. Never as labels.
---

# Milestones

A milestone is one objective for one calendar month. Its issues are
the work; its key results say whether the objective landed.

## Shape

- **Title:** `YYYY-MM: <objective>` — e.g. `2026-11: Secrets resolve
  from 1Password on every host`. The month prefix sorts and filters;
  the objective reads in issue sidebars.
- **Due date:** last day of the month.
- **Description:**

  ```markdown
  <Objective: one or two present-tense sentences stating the outcome.>

  As measured by:

  - [ ] <key result>
  - [ ] <key result>

  Non-goals: <optional, one line bounding scope>
  ```

Each key result is a check anyone can run at month end: a command
that passes, a count that hits a number, an observable state. A key
result names an end state; the issues carry the tasks. Two or three
per objective.

## Velocity

Capacity is shared across every repository under `alunduil`,
`dungeon-studio`, and `qua-world`; the Inbox project board tracks them
together. The monthly limit counts objectives across all of them.

- Start at one objective per month in total.
- Size each month from the last few months' scores. Add an objective
  only after a month whose key results all landed.
- A repository with no objective this month has no milestone.

## Assigning issues

An issue belongs in a milestone when closing it moves at least one
key result. Leave it unassigned otherwise.

## Ticking key results

Tick a key result by editing the description when its check passes,
independent of issue state. The milestone page renders the checklist
read-only.

## Closing at month end

1. Tick every key result whose check passes now.
2. Append a score line to the description: `Scored N/M key results.`
3. Move open issues to next month's milestone or unset them.
4. Close the milestone.

The score is velocity data. Record it as measured and close on
schedule whatever it says. When the objective still matters, carry it
into a new milestone for next month. Closed milestones stay closed.

## Operations

```bash
# Open milestones across every repository: the velocity check
for o in alunduil dungeon-studio qua-world; do
  gh api --paginate "users/$o/repos?per_page=100&type=owner" \
    --jq '.[] | select(.archived|not) | select(.has_issues) | .full_name'
done | while read -r r; do
  gh api "repos/$r/milestones?state=open" \
    --jq ".[] | \"$r\t\(.number)\t\(.title)\""
done

# Past scores for planning
gh api 'repos/:owner/:repo/milestones?state=closed' \
  --jq '.[] | "\(.title)\t\((.description // "") | capture("Scored (?<s>[0-9]+/[0-9]+)").s // "-")"'

# Create
gh api repos/:owner/:repo/milestones \
  -f title='2026-11: <objective>' \
  -f due_on='2026-11-30T23:59:59Z' \
  -f description="$(cat description.md)"

# Tick, score: rewrite the description
gh api -X PATCH repos/:owner/:repo/milestones/<num> \
  -f description="$(cat description.md)"

# Close
gh api -X PATCH repos/:owner/:repo/milestones/<num> -f state=closed
```

Assign with `mcp__github__issue_write` (`method: create` or `update`).
Its `milestone` param takes the milestone *number*, not the title.

## Procedure

1. Run the cross-repository listing. If this month already holds the
   velocity limit, surface that before creating another.
2. Draft title, objective, key results, and due date; confirm with
   the user before creating.
3. Assign issues that move a key result.
4. At month end: tick, score, move spillover, close.
