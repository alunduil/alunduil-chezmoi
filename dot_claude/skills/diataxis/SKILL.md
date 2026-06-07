---
name: diataxis
description: Audit, write, or revise docs under `docs/` (or repo equivalent) when the artifact is a tutorial, how-to, reference, or explanation — anything not already a README, CONTRIBUTING, ADR, or CHANGELOG. Forces a Diátaxis mode pick before writing, then loads mode-specific anti-patterns. Use when creating or editing a tutorial/how-to/reference/explanation doc, or when prose drifts across modes (the canonical case: a how-to growing explanatory paragraphs).
---

# Diátaxis

Reference: <https://diataxis.fr>

The four modes are the meta-framework the artifact skills sit inside.
This skill forces the mode pick the artifact skills assume. Pick one
mode per document *before* writing; a doc that needs two modes is two
documents.

## Cheapest layer first

Doc work escalates up the user-`CLAUDE.md` ladder; reach for a
Diátaxis doc only when the cheaper layer can't carry the knowledge:

inline comment → docstring → **Diátaxis doc** → repo-local `CLAUDE.md`
→ `~/.claude/CLAUDE.md`.

A non-obvious *why* is a comment. An interface contract is a docstring.
Reach a `docs/` artifact only for knowledge shared across the project
that no closer layer holds.

## Defer to the artifact skills

`readme`, `contributing`, `adr`, `changelog` own their specific
artifacts. This skill owns the meta-mode for everything else under
`docs/`. When both could apply, the artifact skill wins — a README is a
README, not a "reference doc."

## Pick the mode

Two axes: **action vs cognition** (do something / understand
something), **acquisition vs application** (studying / working).

| Mode | Axis | Serves | Reader |
| --- | --- | --- | --- |
| Tutorial | action + acquisition | learning by doing | newcomer, no prior context |
| How-to | action + application | a goal at work | practitioner who knows the goal |
| Reference | cognition + application | a fact at work | practitioner who needs to look it up |
| Explanation | cognition + acquisition | understanding | someone studying the why |

Smell test before writing: is the reader *learning*, *doing*,
*looking up*, or *understanding*? One answer. If two, split the doc.

## Tutorial

- **Purpose** — a lesson. The reader ends able to do the thing, having
  done it once under guidance.
- **Audience** — a newcomer with no prior context; assume nothing.
- **Shape** — a single guaranteed-success path, concrete and
  hand-held. Author owns every step; the reader only follows.
- **Anti-patterns**
  - Over-explaining mechanics — *why* belongs in explanation; the
    tutorial just has the reader do it.
  - Assuming the reader will deviate or offering branches — one path,
    no choices.
  - Reference-style completeness — list only what this lesson touches,
    not every option.
  - Leaving a step that can fail on a clean machine — a tutorial that
    doesn't reproduce isn't a lesson.

## How-to

- **Purpose** — a recipe to reach a goal the reader already has.
- **Audience** — a competent practitioner who knows what they want and
  needs the steps, not the background.
- **Shape** — an ordered series of actions. Imperative. Starts at a
  realistic precondition, ends at the goal.
- **Anti-patterns**
  - Narrating wrapper/tool internals — the reader runs the command,
    they don't need its call graph.
  - Restating idempotence or guarantees already in source comments —
    if the code says it, the how-to doesn't.
  - Predicting self-describing prompts or output — don't transcribe
    what the tool already tells the operator on screen.
  - Explanatory prose wrapped around code blocks ("documentation
    poetry") — if a paragraph doesn't change what the reader *types*,
    cut it. (Primary motivating failure.)

## Reference

- **Purpose** — describe the machinery so the reader can look up a
  fact and trust it.
- **Audience** — a practitioner mid-task who needs an authoritative
  answer fast.
- **Shape** — dry, structured, consistent. Mirror the code's own
  structure (one section per command/flag/field). Complete within
  scope.
- **Anti-patterns**
  - Narrative connective tissue — no "now that we've seen X, let's…";
    entries stand alone.
  - Opinionated commentary or recommendations — state what is, not
    what you'd choose; advice belongs in how-to or explanation.
  - Selective coverage — partial reference is a trap; if it's in
    scope, document it or say it's out of scope.

## Explanation

- **Purpose** — illuminate the *why*: context, background, the shape
  of the decision space.
- **Audience** — someone studying the topic away from the keyboard,
  building a mental model.
- **Shape** — discursive prose. Free to discuss alternatives, history,
  trade-offs, opinions (owned as opinions).
- **Anti-patterns**
  - Drifting into runnable commands or step lists — link the how-to,
    don't inline it.
  - Ending with a recipe — if it tells the reader what to *do* next,
    that's a how-to wearing an explanation's clothes.
  - Pretending to be neutral reference — explanation takes positions;
    own them rather than disguising them as fact.

## Procedure

1. Confirm the artifact isn't a README/CONTRIBUTING/ADR/CHANGELOG — if
   it is, hand off to that skill.
2. Run the smell test; name the single mode. If the doc wants two,
   surface the split before writing.
3. Draft against that mode's shape; check the draft against its
   anti-patterns before claiming done.
4. On an *edit*, first classify the existing doc's mode, then flag any
   prose that belongs to a different mode (the drift this skill exists
   to catch).
