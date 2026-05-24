---
name: vale
description: Audit, write, or revise .vale.ini. Use when adding Vale to a repo, troubleshooting silent passes or noisy findings, or evolving an existing config. Applies the two-hook pre-commit pattern (sync + lint), explicit Packages and per-format BasedOnStyles, scoping/ignores for false positives, and a shared accept.txt vocabulary.
---

# Vale

Config keys: <https://vale.sh/docs/keys/>. Current Vale 3.x key set is: `BasedOnStyles, BlockIgnores, CommentDelimiters, IgnoredClasses, IgnoredScopes, MinAlertLevel, Packages, SkippedScopes, StylesPath, TokenIgnores, Transform, Vocab`. Anything else is stale.

## Defaults

```ini
StylesPath = .vale/styles
MinAlertLevel = warning
Packages = Microsoft, proselint, alex
Vocab = <Project>

[*.md]
BasedOnStyles = Vale, Microsoft, proselint, alex
```

- `StylesPath` — relative to `.vale.ini`. `.vale/styles` keeps the tree hidden. Commit `<StylesPath>/config/vocabularies/`; gitignore the auto-downloaded package subdirectories Vale writes under `<StylesPath>/` on `vale sync`. Migration: Vale 2.x put vocabularies under `<StylesPath>/Vocab/`; 3.x moved to `<StylesPath>/config/vocabularies/`.
- `MinAlertLevel` — `suggestion` (Vale default), `warning`, `error`. Gates **display only**; Vale exits nonzero whenever any error-severity finding exists regardless of this setting. Set it to the lowest level you want printed on interactive `vale .` runs; pass `--minAlertLevel=error` to pre-commit to suppress non-error noise from hook output.
- `Packages` — comma-separated. Names from `vale-cli/packages`, URLs to a `.zip`, or local paths. Resolvable bare names today: `Microsoft, Google, write-good, proselint, Joblint, alex, Readability, RedHat, AsciiDoc, OpenShiftAsciiDoc, Elastic, NoAnimalViolence` (style packages), plus `Hugo, MDX` (config packages that teach Vale about non-standard markup, not rule sets). Local files under `<StylesPath>/` override packages; later `Packages` entries override earlier.
- `Vocab` — see Vocabularies below. References `<Project>` so create the directory plus `accept.txt`/`reject.txt` on greenfield.
- `[*.md]` `BasedOnStyles` — **without a per-format section, no rules from `Packages` actually run and Vale silently reports zero findings.** Add per format you lint (`[*.{md,mdx}]`, `[*.rst]`). The built-in `Vale` style must be listed for `Vale.Terms`, `Vale.Avoid`, `Vale.Spelling` to fire. Disable individual rules with `Style.Rule = NO`.

## Choosing Packages

The Defaults set above (`Microsoft, proselint, alex`) suits technical docs, READMEs, and Diátaxis pages. For that case add two disables to suppress known overlap:

```ini
proselint.Cliches = NO    # overlaps Microsoft.Terms
proselint.Spelling = NO   # Vale.Spelling owns this
```

Microsoft beats Google as the default base because `Microsoft.Avoid`+`Microsoft.Terms` is a longer banned-term list than `Google.WordList`, defaults to `error` on bans (matches pre-commit gating), and adds `Adverbs`/`Wordiness` rules Google lacks. Every Google rule worth keeping (Passive, Headings, We, FirstPerson, Acronyms, Contractions) duplicates a Microsoft one — see Overlaps below.

**Long-form prose / blog.** Add `write-good` and `Readability`; disable the duplicate Passive.

```ini
Packages = Microsoft, proselint, write-good, alex, Readability

[*.md]
BasedOnStyles = Vale, Microsoft, proselint, write-good, alex, Readability
Microsoft.Passive = NO    # write-good.Passive at warning is the keeper
Readability.FleschKincaid = YES
```

`Readability` adds doc-level grade scoring (per-file, not per-finding); thresholds set in-file. `write-good` warns on passive (Microsoft's is `suggestion`) and adds unique `ThereIs`/`Weasel` rules. Pair with the en_GB Hunspell pattern (Troubleshooting) for British prose.

**Short marketing copy / landing pages.** Google over Microsoft here — sentence-case headings fire at `warning`, `Slang`/`Will` rules suit the register. Drop proselint (too noisy on brevity-and-punch copy).

```ini
Packages = Google, alex

[*.{md,mdx}]
BasedOnStyles = Vale, Google, alex
```

**Job descriptions (`careers/*.md`).** Joblint adds 14 unique rules (`Bro`, `Meritocracy`, `Visionary`, `Benefits`, …) absent elsewhere.

```ini
Packages = Microsoft, alex, Joblint

[careers/*.md]
BasedOnStyles = Vale, Microsoft, alex, Joblint
Joblint.Gendered = NO    # alex.Gendered substitutes; Joblint just blocks
```

### Known overlaps

Loading two packages that fire on the same span produces duplicate findings under different rule names. Don't load both unless deviating intentionally:

- `Microsoft.Passive` ≈ `Google.Passive` ≈ `write-good.Passive` — same regex; same span fires 2–3×. Pick one (write-good warns; the others suggest).
- `Microsoft.Acronyms` ≡ `Google.Acronyms` — identical regex and exception list.
- `Microsoft.Headings` ≈ `Google.Headings` — same scope/match; Google at `warning` vs Microsoft's `suggestion`.
- `Microsoft.Contractions` and `Google.Contractions` both *prefer* contractions (not opposite stances).
- `Microsoft.Avoid`/`Terms` ⊃ `Google.WordList`; `proselint.Cliches` overlaps both.
- `Microsoft.GenderBias` ≈ `Google.GenderBias` ≈ `proselint.GenderBias` — same direction, overlapping token lists.
- `Microsoft.Foreign` ≡ `Google.Latin` — both replace `e.g.`/`i.e.`.

### Deviation triggers

- Repo has `careers/` or hiring copy → add `Joblint`, scope via `[careers/*.md]`.
- Long-form blog or essays → add `Readability` + `write-good`; disable `Microsoft.Passive`.
- en_GB / en_AU / en_CA prose → see Troubleshooting (vendor Hunspell, disable `Vale.Spelling`).
- Sentence-case headings wanted as blocking, not suggestion → swap `Microsoft` for `Google`, or keep Microsoft and lower the pre-commit threshold to `--minAlertLevel=warning` for that repo.
- External contributors with varied English fluency → relax most `proselint.*` rules (they default to `error`); keep `alex` — its substitution suggestions teach rather than block.
- Inclusive-language gating only, no voice/tone friction → drop Microsoft/Google; load `alex` alone (~11 warnings, all actionable).
- Per-sentence length nags add noise on non-tutorial prose → disable `Microsoft.SentenceLength`, lean on `Readability` for document-level grade.

## Scoping & ignores

Default package rules trip on inline code, tables, and technical strings. Scope them out without disabling rules wholesale:

- `IgnoredScopes` — inline HTML tags Vale skips entirely. Defaults to `code, tt`. Add `kbd, var` if used.
- `SkippedScopes` — block HTML tags Vale skips. Defaults to `script, style, pre`. Add `figure, blockquote` for untrimmed quoted sources.
- `BlockIgnores` / `TokenIgnores` — regex escape hatches for block and inline content with no HTML tag. **Markdown, reStructuredText, AsciiDoc, Org only.** Use for fenced shell prompts, custom MDX directives, file paths.
- `IgnoredClasses` — by HTML class. Useful for rendered output linting.
- `CommentDelimiters` — comment markers Vale honours for `<!-- vale off -->` directives. Default `<!-- -->`; set to `{/* */}` for MDX where HTML comments don't render.

## Vocabularies

`Vocab = <Project>` enables two implicit rules sourced from `<StylesPath>/config/vocabularies/<Project>/`:

- `accept.txt` → `Vale.Terms`. Enforces exact casing; if the file lists `Diátaxis`, then `diataxis` becomes an error.
- `reject.txt` → `Vale.Avoid`. Flags banned terms.

Both files: one regex per line, case-sensitive (prefix `(?i)` for case-insensitive), `#` for comments. The built-in `Vale` style must be in `BasedOnStyles` for these rules to fire.

A starter `accept.txt` ships next to this skill at `~/.claude/skills/vale/accept.txt` with cross-repo terms (project names, host tooling, languages). Copy into `<StylesPath>/config/vocabularies/<Project>/` on greenfield; extend per-project.

## Validation (pre-commit)

Two hooks, both `id: vale`. The first runs `vale sync` to install declared `Packages`; the second lints.

```yaml
- repo: https://github.com/errata-ai/vale
  rev: <latest>
  hooks:
    - id: vale
      args: [sync]
      pass_filenames: false
    - id: vale
      args: [--output=line, --minAlertLevel=error]
```

- `sync` first — without it, packages declared in `.vale.ini` aren't installed in the hook's cached env and the lint produces zero findings (silent pass that looks clean).
- `--minAlertLevel=error` — overrides the file's `warning` default so only errors block commits.
- `errata-ai/*` repos resolve to `vale-cli/*` on GitHub; vale.sh still publishes `errata-ai/vale` in the canonical example. Both work — match the upstream docs rather than chase the rename in every repo.
- Pair with `markdownlint-cli2` for prose-heavy repos. Vale catches voice/usage; markdownlint catches structure (heading hierarchy, link syntax). No overlap; wire as separate hooks.

## Troubleshooting

- `vale ls-config` prints the resolved config (StylesPath, loaded styles, per-format sections). First stop for "zero findings but my file is wrong."
- Zero findings + non-empty `Packages` = forgot `vale sync`, or no `[*.<ext>]` section declares `BasedOnStyles`, or `$XDG_CONFIG_HOME/vale/.vale.ini` is overriding a single-valued key. Global config loads *in addition to* project config; multi-valued keys merge, single-valued get overridden.
- Excessive findings on a fresh add = `MinAlertLevel = suggestion` loading every nit. Raise to `warning` in-file; keep `--minAlertLevel=error` in pre-commit.
- `Packages` name not resolving = wrong casing (`write-good` and `alex` lowercase; `Microsoft`, `Google`, `Joblint`, `Readability`, `RedHat` TitleCase) or it's outside `vale-cli/packages` — switch to a URL.
- `--filter` accepts a CEL expression for "which rules fired" debugging; `--no-wrap` disables output wrapping for grep/CI piping.
- **British English (en_GB).** `Vale.Spelling` is en_US. Working pattern: vendor `wooorm/dictionaries` en_GB Hunspell under `<StylesPath>/Custom/`, declare a `Custom.Spelling` rule extending `spelling` with `dictionaries: [en_GB]`, set `Vale.Spelling = NO` per format. Reference exemplar: `~/blog.alunduil.com/.vale/styles/Custom/Spelling.yml`.

## Procedure

1. Confirm any field you plan to write against `https://vale.sh/docs/keys/<field>/` before editing. Memory and prior commits aren't authoritative — Vale 3.x changed several keys vs 2.x.
2. Read `.vale.ini` if present. Note `StylesPath`, declared `Packages`, per-format `BasedOnStyles` blocks, and any `Vocab` references.
3. **Greenfield** — identify the project type (technical docs, long-form prose, marketing copy, job descriptions) and pick the matching recipe from Choosing Packages. Write `.vale.ini` with that recipe; fill `<Project>`. Copy the starter `accept.txt` from `~/.claude/skills/vale/accept.txt` into `<StylesPath>/config/vocabularies/<Project>/`; add an empty sibling `reject.txt`. Add the two-hook pre-commit entry. Run `vale sync` locally to confirm packages resolve.
4. **Audit existing** — walk the Defaults block and flag drift:
   - `[*]` instead of `[*.<ext>]` (fires on code files without `CommentDelimiters`)
   - Silent passes from missing `BasedOnStyles`
   - Declared `Packages` without `vale sync` in pre-commit
   - `Vocab` referenced from `.vale.ini` but missing on disk
   - Vale 2.x `<StylesPath>/Vocab/` path (migrate to `<StylesPath>/config/vocabularies/`)
   - Disabled rules without an inline comment explaining why
   - `MinAlertLevel = suggestion` driving pre-commit noise
   - Packages loaded with known overlap (Microsoft + Google, Microsoft + write-good, proselint + write-good) without the duplicate-rule disables — see Choosing Packages
5. Surface findings before editing. Apply only after scope is agreed.
