# Commit signing

The armored secret key lives in the `chezmoi` 1Password vault (`op://chezmoi/gpg/secret_key`), renders to `~/.gnupg/secret-keys.asc` on apply, and `run_once_before_08-import-pgp-from-chezmoi.sh.tmpl` imports it into the local keyring. New machine: `chezmoi apply` with the token placed is the only step. The trust chain is vault token + GPG passphrase.

Upload the public key to GitHub once per account so signed commits show "Verified":

```bash
gh api user/gpg_keys -f armored_public_key="$(gpg --armor --export 8F491CBC32D144341679826AE7E6572EF50D1BC5)"
```

## Offline backup (paper key)

Independent of any cloud or repo. Print, store physically, shred the digital copy:

```bash
sudo apt-get install paperkey
gpg --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5 \
  | paperkey --output paperkey.txt
# print, file in safe, then:
shred -u paperkey.txt
```

Recovery from paper requires the public key (Keybase / GitHub / this repo) plus the paperkey output, fed back through `paperkey --pubring … --secrets paperkey.txt | gpg --import`.

## Refreshing the vault field after key rotation

```bash
op item edit gpg --vault chezmoi \
  "secret_key=$(gpg --armor --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5)"
```

The next `chezmoi apply` on each host renders the new key to `~/.gnupg/secret-keys.asc`.
