---
name: ai-docs
description: Technical-writing pass on AI-targeted documentation — CLAUDE.md (user + repo-local), RTK.md, voice.md, skill SKILL.md bodies, hook/prompt-template comments, anything under .claude/ or dot_claude/. Use when AI-instruction text has accreted filler, restated headings, rotted dates/versions, or wordy phrasing. The inverse of prose linting: optimise for tokens, not readability. The LLM counterpart to Vale's deliberate AI-doc exclusion — does the "does this earn its tokens?" judgment Vale structurally can't, plus the aligned subset of mechanical fixes.
---

# AI docs

AI-targeted text is loaded every relevant turn and read by a model, not skimmed by a human. The goal inverts ordinary technical writing: **optimise for tokens, not readability.** Terse imperative, sentence fragments, dropped articles, no connective tissue — all fine, all preferred. There is no human reader to please; there is a context window to spend wisely and a directive to convey precisely.

Vale (the `vale` skill) deliberately excludes these files (`.pre-commit-config.yaml` excludes `CLAUDE.md`, `dot_claude/`, `.claude/`). This skill is the substitute. Vale enforces deterministic prose rules tuned for human readability — the wrong target and mostly the wrong direction here. The core of an AI-doc pass ("does this sentence earn its tokens? is this heading restated? does this example disambiguate or decorate?") is judgment no Vale rule can express.

## Scope

**In** — files a model loads as instruction:

- `CLAUDE.md` (user-level `dot_claude/CLAUDE.md`, repo-local `CLAUDE.md`), and `@`-included companions (`RTK.md`, `voice.md`).
- `dot_claude/skills/*/SKILL.md` bodies.
- Hook and prompt-template comments; anything else under `.claude/` or `dot_claude/` read by the model rather than executed by a human.

**Out** — route elsewhere, don't terse-ify:

- READMEs, CONTRIBUTING → `readme` / `contributing`. Tutorials/how-to/reference/explanation → `diataxis`. Human-facing `.md` under Vale's scope → `vale`. Commit messages, PR/issue bodies → their own conventions. These have human readers; the token inversion does not apply.

## The standard (from CLAUDE.md "Documentation" + "Comments")

**Cut:**

- Filler, decorative connectors ("in order to", "it's worth noting", "as mentioned"), restated headings, intro sentences that re-announce the section title.
- Examples that don't disambiguate — an example earns its tokens only when it resolves an ambiguity prose left open.
- Versions/dates that rot, pre-announcements, forward-looking banners ("planned", "coming soon"). Document HEAD only.
- Procedural restatements and parentheticals describing standard tools.
- Hedging that conveys no information ("basically", "simply", "of course").

**Keep:**

- Timeless WHY, non-obvious patterns, protocol details not visible in code.
- Disambiguating examples and load-bearing qualifiers (see Guardrails — these are directives).
- The precise imperative. Cutting words is good; cutting meaning is a regression.

## Phrasing fixes that align

The subset of ordinary technical-writing fixes that *also* save tokens or sharpen the directive — apply these:

- Wordiness → terse ("at this point in time" → "now"; "make use of" → "use").
- Passive → active imperative (these are instructions; imperative is the correct register and usually shorter).
- Redundant qualifiers, doubled synonyms, weasel words that don't disambiguate → cut.
- Adverbs that don't change meaning → cut.

## Anti-fixes (refuse these)

Standard prose-linter moves that *add* tokens or fight the register — do **not** apply, even though Vale/Microsoft/Google would:

- Don't expand contractions, add transitional/connector words for "flow", or convert fragments to full sentences.
- Don't soften imperative to polite ("please", "you may want to").
- Don't add context/intro sentences for readability, or enforce heading-style/sentence-case for smoothness.
- Don't chase readability-grade scores — nothing here is read linearly by a human.
- Don't invent acronyms to shorten (CLAUDE.md rule); a saved token isn't worth an ambiguous term.

## Guardrails

- **Meaning-preserving only.** These files are instructions Claude executes — on next `chezmoi apply` for `dot_claude/`, host-wide. A dropped qualifier, two rules merged into one, or a reworded directive can silently change behaviour. For each cut ask: *would Claude behave identically after this?* If not, leave it or flag it separately — don't trade correctness for tokens.
- **Examples are payload in voice/sample files.** `voice.md` documents an external prose voice; its example bullets ("I struggled through this...", quoted patterns) ARE the content, not bloat to compress. Tighten only the surrounding meta-instructions, never the samples. Same for any file whose body is quoted exemplars.
- **Don't touch** code blocks, command examples, protocol strings, URLs, or vocab lists — content, not prose.
- **Not a greenfield rewrite.** Target accreted bloat in already-shipped files. A file that's already terse may need zero edits; say so rather than churn it.
- **Surface before applying.** These change host-wide behaviour on apply. Show diffs, get agreement, then edit. Edit only in the chezmoi source checkout (never the apply clone or deployed target).

## Procedure

1. Identify in-scope files (Scope above). Drop anything human-facing — route it to the matching skill rather than terse-ifying it.
2. Per file, three sweeps:
   - **Tokens** — cut against the standard (filler, restated headings, decorative connectors, non-disambiguating examples).
   - **Phrasing** — apply the aligned fixes; refuse the anti-fixes.
   - **Rot** — strip dates/versions that age, pre-announcements, anything not true at HEAD.
3. For each proposed change, confirm it's meaning-preserving (Guardrails). Demote behaviour-changing edits to a flag, not a silent edit.
4. Surface the diffs. Apply after agreement.
