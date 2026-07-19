# Bootstrap

Zero to a fully configured host. Requires a Debian/Crostini host and a 1Password service-account token scoped to the `chezmoi` vault.

```bash
CHEZMOI_VERSION="v2.70.5"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" -t "$CHEZMOI_VERSION"

# The 1Password CLI must exist before the first apply: chezmoi renders every
# template (the onepasswordRead secrets included) before run_once_before
# installs anything, so op has to be on PATH up front. run_once_before_01
# reinstalls it idempotently once the host is managed.
curl -fsSL https://downloads.1password.com/linux/keys/1password.asc |
  sudo gpg --dearmor -o /usr/share/keyrings/1password-archive-keyring.gpg
printf 'deb [arch=%s signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/%s stable main\n' \
  "$(dpkg --print-architecture)" "$(dpkg --print-architecture)" |
  sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
sudo apt-get update && sudo apt-get install -y 1password-cli

mkdir -p ~/.config/chezmoi ~/.config/op
printf '[onepassword]\n  mode = "service"\n' > ~/.config/chezmoi/chezmoi.toml
$EDITOR ~/.config/op/token                 # paste 1Password service-account token
chmod 600 ~/.config/op/token
export OP_SERVICE_ACCOUNT_TOKEN="$(<~/.config/op/token)"

# One apply converges: op is installed, the token is set, secrets resolve.
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

SSH keys resolve from 1Password on that apply, so `~/.ssh/{id_ed25519,config}` land and SSH to GitHub works straight away. The bootstrap clones over HTTPS to bridge the gap before keys exist; swap the apply clone's remote back to SSH if preferred: `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:alunduil/alunduil-chezmoi.git`.

For later updates, run `chezmoi-sync` (deployed to `~/.local/bin`) rather than `chezmoi apply`. It validates the service-account token, prompts for a replacement if it's expired or missing, then applies—so a rotated token is a one-command fix, not an out-of-band edit.
