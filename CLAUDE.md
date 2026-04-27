# alunduil-chezmoi

Chezmoi-managed dotfiles. Source files in this repo deploy to `$HOME` via
`chezmoi apply`. This is the *chezmoi source directory*, not a conventional
software project — naming conventions and file structure follow chezmoi rules.

## Chezmoi naming conventions

- `dot_` prefix → deployed as `.` (e.g. `dot_bashrc` → `~/.bashrc`)
- `executable_` prefix → deployed with mode +x
- `.tmpl` suffix → expanded as a Go template before deployment
- `run_once_before_` prefix → script executed once on `chezmoi apply`; re-runs
  only when the file's content hash changes
- `.chezmoiignore` → lists source files excluded from deployment (README.md,
  LICENSE)

## Layout

- `dot_bashrc`, `dot_profile`, `dot_bash_profile`, `dot_gitconfig` — shell and
  git config
- `dot_claude/` — user-level Claude Code harness deployed to `~/.claude/`:
  `CLAUDE.md` (guide), `settings.json` (hook wiring), `hooks/` (pr-draft-guard)
- `dot_claustre/config.toml` — Claustre user config
- `dot_config/zellij/` — Zellij config and layouts (pair.kdl for deep-pairing)
- `dot_local/bin/executable_gh` — wrapper shadowing system `gh` to enforce
  `--draft` on PR creation
- `run_once_before_install-packages.sh.tmpl` — idempotent bootstrap script
  (apt packages, Tailscale, Zellij, lazygit, nvm/Node, Claude Code, Readwise
  CLI, rtk, rustup/Claustre)

## Previewing and testing changes

```bash
chezmoi diff          # show what chezmoi apply would change on the host
chezmoi apply -n      # dry-run: same as diff but in apply format
chezmoi apply -v      # apply with verbose output
```

No test suite or linter — verification is `chezmoi diff` and manual review.
The bootstrap script is idempotent; re-running it is safe.

## Never commit

Credentials, private keys (`key.txt`, `.credentials.json`), runtime state
(`~/.claustre/db/`), SSH private keys, or toolchain binaries. See README
"Never in the repo" for the full list.

## Two CLAUDE.md files

- **This file** (`CLAUDE.md` at repo root): instructions for AI tools working
  on the chezmoi source — naming conventions, layout, testing.
- **`dot_claude/CLAUDE.md`**: the deployed user-level Claude Code guide
  (`~/.claude/CLAUDE.md`). It governs Claude Code behaviour on the host, not
  contributions to this repo.
