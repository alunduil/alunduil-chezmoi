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

## PGP commit signing

The age-encrypted secret key in `private_dot_gnupg/` deploys to `~/.gnupg/secret-keys.asc` on apply, and `run_once_before_08-import-pgp-from-chezmoi.sh.tmpl` imports it into the local keyring. New machine: `chezmoi apply` is the only step. The trust chain is age key (in `~/.config/chezmoi/key.txt`) + GPG passphrase.

Upload the public key to GitHub once per account so signed commits show "Verified":

```bash
gh api user/gpg_keys -f armored_public_key="$(gpg --armor --export 8F491CBC32D144341679826AE7E6572EF50D1BC5)"
```

### Offline backup (paper key)

Independent of any cloud or repo. Print, store physically, shred the digital copy:

```bash
sudo apt-get install paperkey
gpg --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5 \
  | paperkey --output paperkey.txt
# print, file in safe, then:
shred -u paperkey.txt
```

Recovery from paper requires the public key (Keybase / GitHub / this repo) plus the paperkey output, fed back through `paperkey --pubring … --secrets paperkey.txt | gpg --import`.

### Refreshing the chezmoi blob after key rotation

```bash
gpg --armor --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5 > ~/.gnupg/secret-keys.asc
chezmoi add --encrypt --source "$PWD" ~/.gnupg/secret-keys.asc
```

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
