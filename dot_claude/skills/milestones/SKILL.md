---
name: milestones
description: Create, scope, assign, score, and close GitHub milestones as monthly OKRs written to Google's OKR playbook — one committed or aspirational objective per milestone, ranked by month, key results as an "As measured by" checklist scored 0.0–1.0. Use when adding a milestone, writing or reviewing its objective and key results, deciding whether work or a blocker belongs in one, planning the next ranking, or reviewing one at month end. Never as labels.
---

# Milestones

A milestone is one objective. Its issues are the work; its key
results say whether the objective landed. Write and score them to
[Google's OKR
playbook](https://www.whatmatters.com/resources/google-okr-playbook).

The month prefix ranks objectives by priority: an earlier month ranks
higher. Work goes to the highest-ranked objective with an open,
unblocked issue. The ranked month's last day is the objective's
review: it's scored and closed then, whatever work landed.

## Shape

- **Title:** `YYYY-MM: <objective>` — e.g. `2026-11: Secrets resolve
  from 1Password on every host`. The month prefix ranks and filters;
  the objective reads in issue sidebars.
- **Due date:** last day of the ranked month, the review date.
- **Description:**

  ```markdown
  <One or two present-tense sentences expanding the title's objective.>

  Type: committed | aspirational

  As measured by:

  - [ ] <key result> — deliverable
  - [ ] <key result> — observation

  Non-goals: <optional, one line bounding scope>

  Exceptions: <optional, one line per blocker outside the milestones>
  ```

## Objectives across repositories

A milestone is per repository, so an objective with work in several
repositories has one canonical milestone and a supporting milestone
in each other repository.

- **Canonical:** in the repository holding most of the work. It
  carries the full description and is the one scored and counted.
- **Supporting:** same title and due date. Its description names the
  canonical milestone and repeats, word for word, the key results its
  repository's issues move:

  ```markdown
  Supports: <canonical milestone URL>

  As measured by:

  - [ ] <key result copied from the canonical milestone>
  ```

Edit the canonical milestone first, then bring each supporting one
into line. The drift check in *Operations* lists every supporting
milestone whose title or key results differ from its canonical one.

## Writing the objective

The objective states the outcome at review.

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
- A grader scores it 0.0–1.0 at review without asking the author.
  Say how partial credit is counted when it isn't obvious: for
  example, 9 of 12 repositories scores 0.75.
- Together they are sufficient: 1.0 on all of them means the
  objective landed. Add or rework key results until that holds.
- Two to four per objective.
- Mark each one's kind. `deliverable`: closing issues finishes it.
  `observation`: it waits on a window or an event, such as every
  merge in a month, a certificate renewing, or an upstream release
  opening a PR.
- Rank an objective with an observation key result in the month its
  window or event ends; issue throughput can't pull it earlier.
- Date a key result that lands before the review (`by 2026-11-14`).
  Every key result due on the last day means the plan isn't real
  yet.

## Committed or aspirational

Set the type at creation and keep it.

- **Committed:** the ranked month will deliver it; other work moves
  to make room. Expected score 1.0. A lower score carries a one-line
  reason.
- **Aspirational:** the end state worth reaching, even without a
  clear path yet. Expected average around 0.7, with high variance.
  Test: does it meet or exceed what its users would ask for?
  Key results short of 1.0 can carry into a later milestone.

An objective qualifies as committed when every key result has at
least one assigned issue driving it, and no assigned issue has an
open blocker outside the Inbox repositories. Make it aspirational
otherwise.

Treat a milestone with no `Type:` line as committed.

## Blockers

An issue's open blockers sit in its objective's milestones, canonical
or supporting, or in a milestone ranked earlier. A blocker ranked
later, or in no milestone, hides the ranked work from the board.

- **Filing a blocked-by edge** on an issue in a milestone: assign a
  blocker with no milestone to the objective's milestone in the
  blocker's repository.
- **Blocker in a repository without the objective:** create a
  supporting milestone there with the key result the blocker moves.
  When that isn't worth a milestone, add an `Exceptions:` line to the
  canonical description: `Exceptions: <owner/repo#N>: <reason>`.
- **Blocker ranked later under another objective:** move the blocker
  into this objective's milestones, or rank its objective earlier.
- **Blocker outside the Inbox repositories:** record it in
  `Exceptions:`. The objective is aspirational.

## Velocity

The limit counts distinct objectives across every repository on the
Inbox project board, since they share one person's capacity. A
supporting milestone counts toward its canonical one.

- Start at one committed objective per ranked month in total.
- Committed objectives use most of the month's capacity, not all of
  it. Aspirational objectives take the rest.
- Size the next ranking from the closed history: each objective's
  type, score, and key-result kinds. Deliverable scores measure issue
  throughput; observation scores measure what the month allowed.
- Add an objective only after a ranked month where every committed
  objective scored 1.0 and aspirational ones averaged 0.7 or more.
- Aspirational objectives that keep scoring 1.0 are aimed too low;
  aim the next one further out.
- A repository with no ranked objective has no milestone.

## Assigning issues

An issue belongs in a milestone when closing it moves at least one
key result, or unblocks an issue that does. Leave it unassigned
otherwise.

Other groupings use other tools:

- Categorical tag (area, type, priority) → label.
- Ongoing planning across many issues → the Inbox project board.
- "See also" between two issues → `#N` mention or the `issue-links`
  skill.

## Reviewing at month end

1. Draft the canonical milestone's scored description. Score each
   key result 0.0–1.0 against its check and append the score after
   its kind: `- [ ] <key result> — deliverable, 0.5`. Tick the ones
   scoring 1.0.
2. Append the objective's score, the mean of its key results to one
   decimal: `Scored 0.8.` A committed objective below 1.0 adds its
   reason: `Scored 0.8: <reason>.`
3. Pick a destination for each open issue in the canonical and
   supporting milestones: a later-ranked milestone or unset.
4. Show the user the title, the draft description, and each open
   issue with its destination. Wait for a yes before any write.
   Closing can't be undone.
5. Apply, in order: update the description, move or unset the open
   issues, close the supporting milestones, close the canonical one.

The score is velocity data. Record it as measured and close on the
review date whatever it says. When the objective still matters, carry
it into a later-ranked milestone, restating the key results short of
1.0.

## Operations

A PATCH replaces the whole description. Before one, `diff -u` the
live description against the one Claude last wrote this session, or
the new description when there is none. If they differ, show the
diff and ask: merge the edits in, overwrite, or stop.

`inbox_milestones` prints title, URL, canonical URL (`-` on a
canonical milestone), type, and score. The velocity check counts the
rows with `-` in the third column.

```bash
inbox_repos() {
  for o in alunduil dungeon-studio qua-world; do
    gh api --paginate "users/$o/repos?per_page=100&type=owner" \
      --jq '.[] | select(.archived|not) | select(.has_issues) | .full_name'
  done
}

inbox_milestones() {
  inbox_repos | while read -r r; do
    gh api --paginate "repos/$r/milestones?state=$1&per_page=100" | jq -r '
      .[] | (.description // "") as $d
      | [.title, .html_url,
         (($d | capture("^Supports: (?<u>\\S+)").u) // "-"),
         (($d | capture("Type: (?<t>[a-z]+)").t) // "committed"),
         (($d | capture("Scored (?<s>[0-9]+(\\.[0-9]+)?)").s) // "-")]
      | @tsv'
  done | sort
}

key_results() {
  tr -d '\r' | sed -nE 's/^- \[[ x]\] //; T; s/, [0-9]+(\.[0-9]+)?$//; p' | sort
}

milestone_get() {
  gh api "$(sed -E 's#^https://github\.com/([^/]+/[^/]+)/milestone/([0-9]+)$#repos/\1/milestones/\2#' <<<"$1")"
}

milestone_drift() {
  inbox_milestones open | awk -F'\t' '$3 != "-"' |
    while IFS=$'\t' read -r title url canon _; do
      c=$(milestone_get "$canon")
      s=$(milestone_get "$url")
      [[ $title == "$(jq -r .title <<<"$c")" ]] || echo "$url: title differs from $canon"
      comm -23 <(jq -r '.description // ""' <<<"$s" | key_results) \
        <(jq -r '.description // ""' <<<"$c" | key_results) |
        sed "s#^#$url: key result not in canonical: #"
    done
}

inbox_milestones open    # velocity check
inbox_milestones closed  # past scores
milestone_drift          # supporting milestones out of line

gh api repos/:owner/:repo/milestones \
  -f title='2026-11: <objective>' \
  -f due_on='2026-11-30T23:59:59Z' \
  -f description="$(cat description.md)"

# Tick or score
diff -u <(gh api repos/:owner/:repo/milestones/<num> --jq '.description') \
  last-written.md
gh api -X PATCH repos/:owner/:repo/milestones/<num> \
  -f description="$(cat description.md)"

gh api -X PATCH repos/:owner/:repo/milestones/<num> -f state=closed
```

Assign with `mcp__github__issue_write` (`method: create` or `update`).
Its `milestone` param takes the milestone *number*, not the title.

## Procedure

1. Run the velocity check. If the ranked month already holds the
   velocity limit, surface that before creating another.
2. Draft title, objective, type, key results with their kinds, and
   due date. Revise until they pass every test in *Writing the
   objective*, *Writing key results*, and *Committed or
   aspirational*, then confirm with the user before creating.
3. Assign issues that move a key result. Place their open blockers
   per *Blockers*, creating supporting milestones where needed.
4. During the month, tick a key result as soon as its check passes,
   independent of issue state. Run the drift check after editing a
   canonical milestone.
5. At month end, follow *Reviewing at month end*.
