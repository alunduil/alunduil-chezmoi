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

2. Follow [Rotate a secret](add-a-secret.md#rotate-a-secret) with the
   new token, and update the item's **expires** date.
