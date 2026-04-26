# alunduil-chezmoi

[![CI](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/ci.yml/badge.svg)](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/ci.yml)

Personal dotfiles for [@alunduil](https://github.com/alunduil), managed by [chezmoi](https://chezmoi.io). Bootstraps a Claude Code + [Claustre](https://github.com/pmbrull/claustre) + [Zellij](https://zellij.dev) workflow on a fresh Debian/Crostini host. Source: <https://github.com/alunduil/alunduil-chezmoi>.

Personal config — no warranty, no support. [0BSD licensed](LICENSE).

## Bootstrap

Requires a Debian/Crostini host and the age key from a password manager.

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

mkdir -p ~/.config/chezmoi
$EDITOR ~/.config/chezmoi/key.txt          # paste age key contents
chmod 600 ~/.config/chezmoi/key.txt

~/.local/bin/chezmoi init --apply git@github.com:alunduil/alunduil-chezmoi.git

# Interactive logins (per-machine, never managed):
gh auth login                              # ~/.config/gh/
claude                                     # ~/.claude/.credentials.json
sudo tailscale up                          # tailnet auth
claustre configure                         # wires up Claude Code permissions
```

If SSH to GitHub isn't set up yet, clone over HTTPS first and swap remotes once keys are in place.

## Companion repo

`alunduil-claustre-state` (planned, private) holds Claustre's cross-machine task/project state:

```bash
claustre sync init git@github.com:alunduil/alunduil-claustre-state.git
claustre sync pull
```

Only projects, tasks, and subtasks sync; sessions, worktrees, PIDs, and rate-limit state stay local.

## Layout

- `dot_bashrc`, `dot_profile`, `dot_bash_profile`, `dot_gitconfig` — shell + git config.
- `dot_claude/` — user-level Claude Code harness: `CLAUDE.md` rules, `settings.json` hook wiring, `hooks/pr-draft-guard.sh` blocking non-draft PRs over the GitHub MCP tools. Per-project sensors (tests/linters/types) stay with the project.
- `dot_claustre/config.toml` — Claustre user config (`sync.auto_push = true`).
- `dot_config/zellij/config.kdl` — Zellij config: plugin aliases (zellaude, zjstatus, ghost, notepad — all pinned to release tags), status bars, and `Alt+p`/`Alt+g`/`Alt+m` keybinds.
- `dot_config/zellij/layouts/pair.kdl` — deep-pairing layout: Claude Code (40%) alongside lazygit (60%). VS Code handles editing in its own window; ghost (`Alt+g`) handles on-demand shells.
- `dot_local/bin/gh` — wrapper that shadows `/usr/bin/gh` to require `--draft` on `gh pr create`. Bypass with `GH_DRAFT_GUARD=off`.
- `dot_local/bin/pair-start` — floating fzf picker bound to `Alt+p`. Unifies `~/pair/*` clones, `gh repo list`, and a "create new" fallback (typed name, or `owner/repo` to clone), then opens the pair layout in a new tab with the chosen cwd.
- `run_once_before_install-packages.sh.tmpl` — idempotent bootstrap (apt packages, Tailscale, Zellij, lazygit, nvm/Node, `@anthropic-ai/claude-code`, rustup/Claustre).

## Never in the repo

Credentials of any kind, runtime state (`.credentials.json`, session history, `~/.claustre/db/`), the age private key, SSH private keys, and toolchain binaries (chezmoi/Node/Rust install via canonical installers).
