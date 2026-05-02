# alunduil-chezmoi

By [@alunduil](https://github.com/alunduil)

[![License: 0BSD](https://img.shields.io/github/license/alunduil/alunduil-chezmoi)](LICENSE)
[![Managed with chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)](https://chezmoi.io)
[![Platform: Debian / Crostini](https://img.shields.io/badge/platform-Debian%20%2F%20Crostini-A81D33?logo=debian&logoColor=white)](https://www.debian.org)
[![Claude skills: shareable](https://img.shields.io/badge/Claude%20skills-shareable-262625?logo=claude&logoColor=D97757)](dot_claude/skills/)

Personal [chezmoi](https://chezmoi.io)-managed dotfiles. Run one command on a fresh Debian/Crostini host to go from bare OS to a fully configured development environment with AI pair programming, terminal multiplexing, and git integration — layouts, keybinds, and guardrails included. Source: <https://github.com/alunduil/alunduil-chezmoi>.

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
gcx login                                  # ~/.config/gcx/
sudo tailscale up                          # tailnet auth
claustre configure                         # wires up Claude Code permissions

# PATH check for chezmoi-installed binaries:
zellij --version && lazygit --version
```

If SSH to GitHub isn't set up yet, clone over HTTPS first and swap remotes once keys are in place.

## Contributing

Personal configuration — not accepting contributions. Fork freely under [0BSD](LICENSE).
