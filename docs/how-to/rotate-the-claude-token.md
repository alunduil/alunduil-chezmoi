# Rotating the Claude token

The pair launcher signs Claude in inside a devcontainer with a
long-lived token. `chezmoi apply` writes it to
`~/.config/claude-pair/token` from the 1Password item that
`.chezmoidata/onepassword.yaml` names under `claude`. Rotate it when it
expires or leaks.

1. Generate a token:

   ```bash
   claude setup-token
   ```

2. Paste the token into that item's **credential** field, replacing the
   old value, and update its **expires** date.

3. Deploy it:

   ```bash
   chezmoi apply ~/.config/claude-pair/token
   ```

`docs/how-to/add-a-secret.md` covers creating the item the first time.
