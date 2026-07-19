# alunduil-chezmoi

Chezmoi source directory. Files deploy to `$HOME` via `chezmoi apply`;
names follow chezmoi rules (`dot_` → `.`, `executable_` → +x, `.tmpl` →
Go template, `.chezmoiscripts/run_*_before_NN-…` → ordered idempotent bootstrap).
`docs/tutorials/bootstrap.md` has the bootstrap walkthrough; `docs/explanation/architecture.md` has the human-facing rationale.

## Source vs. apply path

`chezmoi diff`/`apply` read the *applied* clone at
`~/.local/share/chezmoi`, not this working tree. Edits here don't take
effect on `apply` until committed and pulled into the apply clone. Use
`chezmoi diff --source-path .` to preview from this checkout.

## Invariants

- Bootstrap scripts live in `.chezmoiscripts/` and are idempotent;
  re-running is safe. `run_*_before_NN-*` install/config passes carry a
  numeric prefix that orders them (dependencies); `run_onchange_after_*`
  passes are order-independent and named by concept, not numbered. Passes
  that must re-fire when their inputs change (`run_onchange_before_02`,
  `_04`) are `run_onchange` and embed those inputs' hashes.
- Tool versions live in `script/install/*` (one script per tool, each
  pinning its own `*_VERSION`) and are reused by both bootstrap and CI.
  Bump in one place. Zellij *plugins*
  (`zellaude`, `zjstatus`) are pinned separately as alias tags in
  `dot_config/zellij/config.kdl`.
- `gh` extensions install in script 05 alongside other bespoke
  installers, not script 02 — they're managed by `gh extension`, not
  the `script/install/` download-and-verify pattern. Version pin lives
  inline in the script (e.g. `GH_POI_VERSION`).
- `dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft`
  on `gh pr create`. PRs Claude opens go through this wrapper.

## Sensors

CI is authoritative. Run all sensors locally before claiming done:

```bash
just check                     # runs every sensor below, reports all failures
```

Each runs in its own CI workflow and can be invoked alone:

```bash
pre-commit run --all-files     # shellcheck, shfmt, check-json
bats --recursive dot_local dot_claude script  # unit tests
script/checks/zellij-config    # zellij KDL validation (needs zellij)
script/checks/chezmoi-apply    # apply round-trip (needs chezmoi + age)
```

## Two CLAUDE.md files

- This file: rules for AI editing the chezmoi *source*.
- `dot_claude/CLAUDE.md` → deploys to `~/.claude/CLAUDE.md`. Edits there
  change Claude's host-wide behaviour on next `chezmoi apply`.
