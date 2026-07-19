# Recovering secret access

The single out-of-band secret is the 1Password service-account token at `~/.config/op/token`. Recovery depends on what's lost.

## Lost the token, account access intact

Generate a fresh service-account token scoped to the `chezmoi` vault, place it, and re-apply:

```bash
$EDITOR ~/.config/op/token       # paste the new token
chmod 600 ~/.config/op/token
export OP_SERVICE_ACCOUNT_TOKEN="$(<~/.config/op/token)"
chezmoi apply
```

Revoke the old service account in 1Password so the lost token is dead.

## Lost 1Password account access

Regain the account with the 1Password Emergency Kit—the printed Secret Key plus account password—then generate a new service-account token as above. The Emergency Kit is the account-level analogue of the PGP paper key: store it physically, independent of any host.

## Lost the signing key

The GPG secret key has a fallback that doesn't depend on 1Password: the paper-key backup (see [pgp-signing.md](pgp-signing.md)). Recover from paper, re-import, and refresh the vault field.
