# Adding an encrypted secret

For credentials that should replay across machines (API tokens, etc.), encrypt with chezmoi/age rather than leaving them out of source. Run from this checkout's root so `--source` lands the file here; without it `chezmoi add` writes to the apply clone (`~/.local/share/chezmoi`), which is read-only by convention.

```bash
mkdir -p ~/.config/<service>
umask 077
$EDITOR ~/.config/<service>/token          # paste secret, no trailing newline
chezmoi add --encrypt --source "$PWD" ~/.config/<service>/token
```

Stored as `dot_config/<service>/encrypted_private_token.age` and restored (mode 600) on `chezmoi apply`. The `private_` on the file makes the token 600; the service directory stays the conventional 755. See `dot_config/codecov/` for an existing example.
