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
readwise login                             # ~/.readwise-cli.json
sudo tailscale up                          # tailnet auth
claustre configure                         # wires up Claude Code permissions
keybase login                              # ~/.config/keybase/ (devices, KBFS)
signal-desktop                             # link to phone via QR scan
signal-cli -a +<phone> register            # SMS-verified, ~/.local/share/signal-cli/

# PATH check for chezmoi-installed binaries:
zellij --version && lazygit --version && act --version && rtk --version
lychee --version                           # markdown link checker (mirrors CI)
ghc --version && cabal --version           # ghcup-managed Haskell toolchain
golang-petname                             # repo-picker worktree namer
gh extension list                          # confirms gh-poi (squash-merge pruner)
claude mcp list                            # confirms cloudflare-* MCP servers
```

If SSH to GitHub isn't set up yet, clone over HTTPS first and swap remotes once keys are in place.

## Adding an encrypted secret

For credentials that should replay across machines (API tokens, etc.), encrypt with chezmoi/age rather than leaving them out of source. Run from this checkout's root so `--source` lands the file here; without it `chezmoi add` writes to the apply clone (`~/.local/share/chezmoi`), which is read-only by convention.

```bash
mkdir -p ~/.config/<service>
umask 077
$EDITOR ~/.config/<service>/token          # paste secret, no trailing newline
chezmoi add --encrypt --source "$PWD" ~/.config/<service>/token
```

Stored as `dot_config/<service>/encrypted_private_token.age` and restored (mode 600) on `chezmoi apply`. See `dot_config/codecov/` for an existing example.

## Contributing

Personal configuration — not accepting contributions. Fork freely under [0BSD](LICENSE).
