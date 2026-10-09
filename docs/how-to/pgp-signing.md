# Commit signing

The secret key is the `GPG Key` document in the `chezmoi` 1Password vault. Apply writes it to `~/.gnupg/secret-keys.asc`, and `.chezmoiscripts/run_before_08-import-pgp-from-chezmoi.sh.tmpl` imports it into the local keyring on the next apply. The trust chain is 1Password + GPG passphrase.

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

## Refreshing the 1Password copy after key rotation

```bash
gpg --armor --export-secret-keys 8F491CBC32D144341679826AE7E6572EF50D1BC5 \
  | op document edit "GPG Key" --vault chezmoi - --file-name secret-keys.asc
```
