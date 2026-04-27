# alunduil-chezmoi

[![Pre-commit](https://img.shields.io/github/actions/workflow/status/alunduil/alunduil-chezmoi/pre-commit.yml?label=pre-commit)](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/pre-commit.yml)
[![Zellij](https://img.shields.io/github/actions/workflow/status/alunduil/alunduil-chezmoi/zellij.yml?label=zellij)](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/zellij.yml)
[![Chezmoi](https://img.shields.io/github/actions/workflow/status/alunduil/alunduil-chezmoi/chezmoi.yml?label=chezmoi)](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/chezmoi.yml)
[![Bats](https://img.shields.io/github/actions/workflow/status/alunduil/alunduil-chezmoi/bats.yml?label=bats)](https://github.com/alunduil/alunduil-chezmoi/actions/workflows/bats.yml)
[![License: 0BSD](https://img.shields.io/github/license/alunduil/alunduil-chezmoi)](LICENSE)
[![Managed with chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)](https://chezmoi.io)
[![Platform: Debian / Crostini](https://img.shields.io/badge/platform-Debian%20%2F%20Crostini-A81D33?logo=debian&logoColor=white)](https://www.debian.org)

Personal [chezmoi](https://chezmoi.io)-managed dotfiles for [@alunduil](https://github.com/alunduil). Run one command on a fresh Debian/Crostini host to go from bare OS to a fully configured development environment with AI pair programming, terminal multiplexing, and git integration — layouts, keybinds, and guardrails included. Source: <https://github.com/alunduil/alunduil-chezmoi>.

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

### Verify

After bootstrap, confirm the key tools are on PATH:

```bash
claude --version && claustre --version && zellij --version && lazygit --version
```

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
- `run_once_before_*.sh.tmpl` — idempotent bootstrap scripts, split by concern:
  - `01-install-system-packages` — apt packages, HashiCorp repo, Tailscale.
  - `02-install-binary-tools` — Zellij, lazygit (GitHub release binaries).
  - `03-install-node-ecosystem` — nvm, Node LTS, `@anthropic-ai/claude-code`, `@readwise/cli`.
  - `04-install-rust-ecosystem` — rustup, Claustre.
  - `05-install-standalone-tools` — rtk.

## Never in the repo

Credentials of any kind, runtime state (`.credentials.json`, session history, `~/.claustre/db/`), the age private key, SSH private keys, and toolchain binaries (chezmoi/Node/Rust install via canonical installers).

## Contributing

Personal configuration — not accepting contributions. Fork freely under [0BSD](LICENSE).
