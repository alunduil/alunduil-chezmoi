# alunduil-chezmoi

Dotfiles for Alex Brandt's Crostini / Chromebook workstation, managed by [chezmoi](https://chezmoi.io). Bootstraps a Claude Code + [Claustre](https://github.com/pmbrull/claustre) + [Zellij](https://zellij.dev) multi-session workflow on a fresh Debian/Crostini host.

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
- `~/.claude/` and `~/.claustre/` configs (deferred — will be added once real usage informs what's worth syncing)

## Layout

- `dot_bashrc`, `dot_profile`, `dot_gitconfig` — managed shell + git config.
- `run_once_before_install-packages.sh.tmpl` — idempotent bootstrap: apt packages (`gh zsh ripgrep fd-find jq unzip age`), Tailscale via its official installer (system daemon, enables `tailscaled.service`), zellij from the upstream GitHub release (pinned, sha256-verified; Debian bookworm doesn't package it), nvm + Node LTS, `@anthropic-ai/claude-code`, rustup + `claustre` from git, and the `~/.config/zellij/plugins/` directory that zellaude auto-populates on first Zellij load. Re-runs whenever its content hash changes.
