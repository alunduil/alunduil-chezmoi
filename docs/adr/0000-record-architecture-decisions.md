# 0. Record architecture decisions

## Status

Accepted

## Context

Architecturally significant choices (picking between non-trivial
alternatives, locking in a dependency, accepting a one-way door) need a
durable home. Commit messages cover *what* changed; PR bodies cover the
merge state. Neither survives well as the rationale a future reader
needs when challenging or revisiting the decision. `CLAUDE.md` files
hold rules-for-AI, not project decisions.

## Decision

We will record architecturally significant decisions as Architecture
Decision Records under `docs/adr/`, using the Nygard format (Title,
Status, Context, Decision, Consequences). Files are named
`NNNN-kebab-title.md`, numbered sequentially starting at `0000`.

New ADRs land with `Status: Accepted` — the PR review that merges them
is the acceptance step. Later transitions to `Superseded by NNNN` or
`Deprecated` happen by edit. `Proposed` is reserved for the rare case
where an ADR is published as a discussion artifact ahead of any
implementing PR.

We will not file ADRs for tactical implementation choices, framework
defaults, or anything a commit message carries adequately. Sprawl makes
the collection worth less.

## Consequences

- Future readers can challenge a decision against the forces that were
  in play when it was made, instead of inferring intent from diffs.
- Adding an ADR is a small discipline cost on the proposer; reading the
  set is a small load on anyone touching an area with prior decisions.
- Deferred decisions (e.g. "stay bash for now, revisit when X fires")
  have a place to record the trigger condition, so re-litigation starts
  from the recorded state rather than from scratch.
- Risk of sprawl if used for tactical choices. The warranted/not check
  in the `adr` skill is the gate.
