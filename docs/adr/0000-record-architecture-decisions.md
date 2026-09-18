# 0. Record architecture decisions

## Status

Accepted

## Context

Architecturally significant choices (picking between non-trivial
alternatives, locking in a dependency, accepting a one-way door) need a
durable home. Commit messages cover *what* changed. PR bodies cover the
merge state. Neither survives well as the rationale a future reader
needs when challenging or revisiting the decision. `CLAUDE.md` files
hold rules-for-AI, not project decisions.

## Decision

Record architecturally significant decisions as Architecture
Decision Records under `docs/adr/`, using the Nygard format (Title,
Status, Context, Decision, Consequences). Name files
`NNNN-kebab-title.md`, numbered sequentially from `0000`.

New ADRs land with `Status: Accepted`—the PR review that merges them
is the acceptance step. Later transitions to `Superseded by NNNN` or
`Deprecated` happen by edit. Use `Proposed` only for the rare case of an
ADR published as a discussion artifact ahead of any implementing PR.

Skip ADRs for tactical implementation choices, framework
defaults, or anything a commit message carries adequately. Sprawl makes
the collection worth less.

## Consequences

- Future readers can challenge a decision against the forces in play at
  the time, instead of inferring intent from diffs.
- Adding an ADR is a small discipline cost on the proposer. Reading the
  set is a small load on anyone touching an area with prior decisions.
- Deferred decisions—"stay bash for now, revisit when X fires"—have a
  place to record the trigger condition. Re-litigation then starts from
  the recorded state rather than from scratch.
- Risk of sprawl if used for tactical choices. The warranted/not check
  in the `adr` skill is the gate.
