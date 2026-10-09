# Bootstrap

Zero to a fully configured host. Requires a Debian/Crostini host, a 1Password account with access to the `chezmoi` vault, and the age key from a password manager.

Apply runs twice. Secrets come from the 1Password desktop app, which the first apply installs, so the first apply skips them.

```bash
CHEZMOI_VERSION="v2.73.0"
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin" -t "$CHEZMOI_VERSION"

# Decrypts the Cloudflare token, the one age-encrypted secret.
mkdir -p ~/.config/chezmoi
$EDITOR ~/.config/chezmoi/key.txt          # paste age key contents
chmod 600 ~/.config/chezmoi/key.txt

# First apply: installs everything, including 1Password; skips secrets.
CHEZMOI_NO_1PASSWORD=1 ~/.local/bin/chezmoi init --apply https://github.com/alunduil/alunduil-chezmoi.git
```

Open 1Password from the launcher and sign in. In **Settings → Developer**, turn on **Use the SSH agent** and **Integrate with 1Password CLI**. Then apply again and approve the 1Password prompt:

```bash
# Second apply: writes the secrets and starts what needs them.
chezmoi apply

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
zellij --version && lazygit --version && act --version
lychee --version                           # markdown link checker (mirrors CI)
yq --version                               # YAML processor (mikefarah/yq)
vale --version                             # prose linter (vale-cli/vale)
just --version                             # command runner (justfiles)
uv --version                               # Python-CLI installer (astral-sh/uv)
pre-commit --version                       # git hook runner (uv tool install)
beet --version                             # music tagger (uv tool install)
ffprobe -version && mediainfo --version    # media inspection (ffmpeg, mediainfo)
exiftool -ver && fpcalc -version           # metadata reader, audio fingerprinter
rsync --version                            # file sync
ghc --version && cabal --version           # ghcup-managed Haskell toolchain
cargo --version && rustc --version         # rustup-managed Rust toolchain
pnpm --version                             # pnpm package manager (npm global)
uptimerobot --version                      # Uptime Robot CLI (npm global)
java --version                             # Temurin 21 JDK (Firebase emulators)
command -v cargo-cache                     # cargo registry GC helper
golang-petname                             # repo-picker worktree namer
command -v nethack                         # roguelike (nethack-console)
command -v calibre                         # ebook library manager
command -v code                            # VS Code (upstream .deb)
docker --version                           # container engine (docker-ce, auto-updated)
command -v truenas-mcp                     # TrueNAS MCP server binary
trivy --version                            # vulnerability scanner (aquasecurity/trivy)
gh extension list                          # confirms gh-poi (squash-merge pruner)
claude mcp list                            # confirms registered MCP servers
kitty --version                            # terminal (apt)
foot --version                             # terminal, pending kitty's replacement (apt)
sar -V && forkstat --version               # host telemetry recorders (apt)
systemctl is-active sysstat-collect.timer  # confirms sar is sampling
systemctl --user is-active alloy.service   # confirms the Grafana Cloud shipper
systemctl --user is-active 1password.service  # confirms the app owns the SSH agent
ssh-add -l                                 # lists the SSH key from 1Password
```

SSH to GitHub works once you sign in to 1Password. The bootstrap clones over HTTPS to bridge the gap before then. Swap the apply clone's remote back to SSH if preferred: `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:alunduil/alunduil-chezmoi.git`.
