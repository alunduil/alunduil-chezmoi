# Technical writing

Register for documentation prose: ADRs, how-tos, READMEs, Diátaxis
docs. Blog posts are out of scope — they keep their own register.

Vale enforces mechanics: passive voice, sentence length, wordiness,
clichés. It cannot see register. Anything unstated here defers to
Google's [developer documentation style
guide](https://developers.google.com/style).

## Cut packaging

Delete:

- Rhetorical contrast — "the question is not X but Y", "less about A
  than B". State the claim.
- Metaphor carrying no information — "pointing home, not the home
  itself". If the literal sentence loses nothing, it was decoration.
- Inflated diction — "a reach concession", "a considered position".
  Say what happened in the plainest available words.
- Sentences present for rhythm: the third clause balancing the first
  two, the closing restatement.

## Sentences and paragraphs

- One idea per sentence. An `or` inside a long sentence usually marks
  a hidden bulleted list; a sequence of steps marks a numbered one.
- The opening sentence carries the paragraph's point. Readers skim
  openers and skip the rest, so it cannot mislead about what follows.
- One topic per paragraph. Relocate or delete a sentence serving a
  past or future topic.
- Important information first. Actions before the reasoning behind
  them.

## Documents

- Name the reader before writing: role, goal, and what they already
  know. Spend words on what is specific to this project, not on
  general programming.
- The introduction states scope, assumed knowledge, and what the
  document does not cover.
- Headings name the reader's task ("Create the site"), not internal
  machinery ("Initialise the template engine").
- Explain why a step exists before asking for it.
- Don't manufacture hierarchy. A lone child topic belongs in its
  parent.
- Document what has a consequence for the reader. Implementation
  detail they cannot act on is noise.
