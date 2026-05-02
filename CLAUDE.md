# alunduil-chezmoi

Chezmoi source directory. Files deploy to `$HOME` via `chezmoi apply`;
names follow chezmoi rules (`dot_` → `.`, `executable_` → +x, `.tmpl` →
Go template, `run_once_before_NN-…` → ordered idempotent bootstrap).
README.md has the bootstrap walkthrough.

## Source vs. apply path

`chezmoi diff`/`apply` read the *applied* clone at
`~/.local/share/chezmoi`, not this working tree. Edits here don't take
effect on `apply` until committed and pulled into the apply clone. Use
`chezmoi diff --source-path .` to preview from this checkout.

## Invariants

- Bootstrap scripts (`run_once_before_NN-*.sh.tmpl`) are idempotent;
  re-running is safe. Numeric prefix orders them.
- Tool versions live in `script/install/{zellij,lazygit,act,gcx}` and are
  reused by both bootstrap and CI. Bump in one place. Zellij *plugins*
  (`zellaude`, `zjstatus`) are pinned separately as alias tags in
  `dot_config/zellij/config.kdl`.
- `dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft`
  on `gh pr create`. PRs Claude opens go through this wrapper.

## Sensors

CI is authoritative. Run locally before claiming done:

```bash
pre-commit run --all-files     # shellcheck, shfmt, check-json
bats test/                     # unit tests
script/checks/zellij-config    # zellij KDL validation (needs zellij)
script/checks/chezmoi-apply    # apply round-trip (needs chezmoi + age)
```

## Two CLAUDE.md files

- This file: rules for AI editing the chezmoi *source*.
- `dot_claude/CLAUDE.md` → deploys to `~/.claude/CLAUDE.md`. Edits there
  change Claude's host-wide behaviour on next `chezmoi apply`.
