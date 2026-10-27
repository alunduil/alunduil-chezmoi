# Bootstrap

Zero to a fully configured host. Requires a Debian/Crostini host, a 1Password account with access to the `chezmoi` vault, and the age key from a password manager.

mise installs every pinned tool, chezmoi included, at the versions and checksums in the repo's `mise.lock`, so it comes first. Debian's `extrepo` package carries the key that signs mise's apt repository.

Apply runs twice. Secrets come from the 1Password desktop app, which the first apply installs, so the first apply skips them.

```bash
sudo apt-get install -y extrepo git
sudo extrepo enable mise
sudo apt-get update
sudo apt-get install -y mise

# Decrypts the Cloudflare token, the one age-encrypted secret.
mkdir -p ~/.config/chezmoi
$EDITOR ~/.config/chezmoi/key.txt          # paste age key contents
chmod 600 ~/.config/chezmoi/key.txt

# First apply: installs everything, including 1Password; skips secrets.
# Runs the chezmoi pinned in the clone's mise.lock.
git clone https://github.com/alunduil/alunduil-chezmoi.git ~/.local/share/chezmoi
CHEZMOI_NO_1PASSWORD=1 \
  MISE_GLOBAL_CONFIG_FILE=~/.local/share/chezmoi/dot_config/mise/config.toml \
  mise exec chezmoi -- chezmoi init --apply
```

Open 1Password from the launcher and sign in. In **Settings → Developer**, turn on **Integrate with 1Password CLI**. Open a new terminal, whose login shell puts mise's shims on `PATH`. Then apply again and approve the 1Password prompt:

```bash
# Second apply: writes the secrets and starts what needs them.
chezmoi apply

# Lists the logins, units, and tools still outstanding, each with its fix.
host-status
```

Run each fix `host-status` prints, then run it again. It prints nothing once the host is fully set up.

SSH to GitHub works once you sign in to 1Password. The bootstrap clones over HTTPS to bridge the gap before then. Swap the apply clone's remote back to SSH if preferred: `git -C ~/.local/share/chezmoi remote set-url origin git@github.com:alunduil/alunduil-chezmoi.git`.
