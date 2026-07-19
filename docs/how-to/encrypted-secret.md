# Adding an encrypted secret

For credentials that should replay across machines (API tokens, etc.), encrypt with chezmoi/age rather than leaving them out of source. Run from this checkout's root so `--source` lands the file here; without it `chezmoi add` writes to the apply clone (`~/.local/share/chezmoi`), which is read-only by convention.

```bash
mkdir -p ~/.config/<service>
umask 077
$EDITOR ~/.config/<service>/token          # paste secret, no trailing newline
chezmoi add --encrypt --source "$PWD" ~/.config/<service>/token
chezmoi chattr --source "$PWD" +private ~/.config/<service>   # 700 dir, matching siblings
```

Stored as `dot_config/private_<service>/encrypted_private_token.age` and restored (mode 600) on `chezmoi apply`. The `chattr +private` renames the source dir to `private_<service>`, so the deployed `~/.config/<service>/` is 700 like the other secret directories. See `dot_config/private_codecov/` for an existing example.
