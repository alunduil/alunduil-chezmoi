# PGP commit signing

The age-encrypted secret key in `private_dot_gnupg/` deploys to `~/.gnupg/secret-keys.asc` on apply, and `run_once_before_08-import-pgp-from-chezmoi.sh.tmpl` imports it into the local keyring. New machine: `chezmoi apply` is the only step. The trust chain is age key (in `~/.config/chezmoi/key.txt`) + GPG passphrase.

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

## Refreshing the chezmoi blob after key rotation

```bash
gpg --armor --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5 > ~/.gnupg/secret-keys.asc
chezmoi add --encrypt --source "$PWD" ~/.gnupg/secret-keys.asc
```
