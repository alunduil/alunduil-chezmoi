# alunduil-chezmoi

Dotfiles for Alex Brandt's Crostini / Chromebook workstation, managed by [chezmoi](https://chezmoi.io). Bootstraps a Claude Code + [Claustre](https://github.com/pmbrull/claustre) + [Zellij](https://zellij.dev) workflow on a fresh Debian/Crostini host — Claustre multiplexes day-to-day Claude Code sessions; Zellij (with a `pair` layout and zellaude/zjstatus/ghost/notepad plugins) is reserved for deep pairing sessions.

## Disaster recovery — fresh machine bootstrap

The whole setup must rebuild from this repo plus the age key stored in a password manager. On a fresh Crostini container:

```bash
# 1. Install chezmoi itself (no apt package — canonical installer to ~/.local/bin)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"

# 2. Restore the age key from the password manager
mkdir -p ~/.config/chezmoi
$EDITOR ~/.config/chezmoi/key.txt     # paste key contents
chmod 600 ~/.config/chezmoi/key.txt

# 3. Initialize + apply. Clones the source, runs the install script, writes
#    managed files. The install script needs sudo for apt.
~/.local/bin/chezmoi init --apply git@github.com:alunduil/alunduil-chezmoi.git

# 4. Log in to remote services (interactive — not managed by chezmoi)
gh auth login
claude                 # first launch prompts for the Anthropic login
sudo tailscale up      # opens a browser to join the tailnet
claustre configure     # checks prereqs, wires up Claude Code permissions
```

If SSH auth to GitHub isn't set up yet, clone over HTTPS first (`https://github.com/alunduil/alunduil-chezmoi.git`) and swap the remote once keys are in place.

## Manual steps (not automated by this repo)

By design — none of these should ever enter the repo:

- **Anthropic / Claude Code login** — lives in `~/.claude/.credentials.json`
- **GitHub CLI login** — `gh auth login`, stored under `~/.config/gh/`
- **age key** — `~/.config/chezmoi/key.txt`, restored from password manager. The key that decrypts this repo cannot live inside it.
- **SSH keys** — generated per machine, public half uploaded to GitHub
- **Tailscale auth** — `sudo tailscale up` opens a browser for tailnet auth. Per-machine, not syncable (auth keys are bound to the node identity).

## Companion repo

`alunduil-claustre-state` (planned, private): holds Claustre's cross-machine task/project state. Claustre syncs into `~/.claustre/sync/`. Bootstrap on a new machine with:

```bash
claustre sync init git@github.com:alunduil/alunduil-claustre-state.git
claustre sync pull
```

Only projects, tasks, and subtasks are synced — sessions, worktrees, PIDs, and rate-limit state stay local.

## Intentionally NOT in this repo

- Plaintext API keys, session tokens, or credentials of any kind
- `~/.claude/.credentials.json`, Claude Code session history, or any runtime state
- `~/.claustre/db/` or other Claustre runtime state
- The age private key (password manager only)
- Node, Rust, or chezmoi binaries (install script uses canonical installers)
- `~/.claude/` configs (deferred — will be added once real usage informs what's worth syncing)
- `~/.claustre/` runtime state (`claustre.db`, `sockets/`, `pids/`, `worktrees/`, `tmp/`, `hooks/`, `sync/`) — machine-local by design; only `config.toml` is managed

## Layout

- `dot_bashrc`, `dot_profile`, `dot_bash_profile`, `dot_gitconfig` — managed shell + git config.
- `dot_claustre/config.toml` — Claustre's user config. Currently sets `sync.auto_push = true` so task/project state pushes to the companion `alunduil-claustre-state` repo automatically. Runtime state (DB, sockets, worktrees) stays machine-local.
- `dot_config/zellij/config.kdl` — Zellij config for deep-pairing sessions (Claustre handles the multi-session axis). Pins four plugins by release tag and loads them by URL (Zellij caches under `~/.cache/zellij/`): **zellaude** (per-tab Claude Code activity, top bar), **zjstatus** (mode/session/tabs/clock, bottom bar), **ghost** (floating ad-hoc terminal, `Alt+g`), **zellij-notepad** (floating timestamped `$EDITOR` notepad, `Alt+m`). `Alt+p` opens the pair layout in a new tab.
- `dot_config/zellij/layouts/pair.kdl` — two-pane pairing layout: Claude Code (40%) alongside lazygit (60%). The editing surface is VS Code in its own window; this layout is for "watch the changes, drive Claude". On-demand shells come from ghost (`Alt+g`). Invoke with `zellij --layout pair` for a fresh session or `Alt+p` / `zellij action new-tab --layout pair` from inside a running session.
- `run_once_before_install-packages.sh.tmpl` — idempotent bootstrap: apt packages (`gh zsh ripgrep fd-find jq unzip age`), Tailscale via its official installer (system daemon, enables `tailscaled.service`), zellij and lazygit from upstream GitHub releases (pinned, sha256-verified; Debian bookworm either doesn't package zellij or ships lazygit only in backports), nvm + Node LTS, `@anthropic-ai/claude-code`, rustup + `claustre` from git, and the `~/.config/zellij/plugins/` dir for any locally-staged WASM. Re-runs whenever its content hash changes.
