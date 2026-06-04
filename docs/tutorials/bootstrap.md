# Bootstrap

Zero to a fully configured host. Requires a Debian/Crostini host and the age key from a password manager.

```bash
CHEZMOI_VERSION="v2.70.5"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" -t "$CHEZMOI_VERSION"

mkdir -p ~/.config/chezmoi
$EDITOR ~/.config/chezmoi/key.txt          # paste age key contents
chmod 600 ~/.config/chezmoi/key.txt

~/.local/bin/chezmoi init --apply https://github.com/alunduil/alunduil-chezmoi.git

# Interactive logins (per-machine, never managed):
gh auth login                              # ~/.config/gh/
claude                                     # ~/.claude/.credentials.json
gcx login                                  # ~/.config/gcx/
readwise login                             # ~/.readwise-cli.json
sudo tailscale up                          # tailnet auth
keybase login                              # ~/.config/keybase/ (devices, KBFS)
signal-desktop                             # link to phone via QR scan
signal-cli -a +<phone> register            # SMS-verified, ~/.local/share/signal-cli/

# PATH check for chezmoi-installed binaries:
zellij --version && lazygit --version && act --version && rtk --version
lychee --version                           # markdown link checker (mirrors CI)
yq --version                               # YAML processor (mikefarah/yq)
vale --version                             # prose linter (vale-cli/vale)
just --version                             # command runner (justfiles)
uv --version                               # Python-CLI installer (astral-sh/uv)
pre-commit --version                       # git hook runner (uv tool install)
ghc --version && cabal --version           # ghcup-managed Haskell toolchain
pnpm --version                             # pnpm package manager (npm global)
command -v cargo-cache                     # cargo registry GC helper (needs cargo)
golang-petname                             # repo-picker worktree namer
command -v nethack                         # roguelike (nethack-console)
command -v calibre                         # ebook library manager
command -v code                            # VS Code (upstream .deb)
docker --version                           # container engine (docker-ce, auto-updated)
command -v truenas-mcp                     # TrueNAS MCP server binary
trivy --version                            # vulnerability scanner (aquasecurity/trivy)
gh extension list                          # confirms gh-poi (squash-merge pruner)
claude mcp list                            # confirms registered MCP servers
```

SSH keys deploy from age-encrypted chezmoi source on apply, so `~/.ssh/{id_rsa,config}` land alongside the age-key paste step, so SSH to GitHub works as soon as `chezmoi init --apply` finishes. The bootstrap clones over HTTPS to bridge the gap before keys exist; swap the apply clone's remote back to SSH if preferred: `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:alunduil/alunduil-chezmoi.git`.
