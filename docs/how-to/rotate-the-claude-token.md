# Rotating the Claude token

`~/.config/claude-pair/token` holds a long-lived token that signs
Claude in without a browser. Rotate it when it expires or leaks.

1. Generate a token:

   ```bash
   claude setup-token
   ```

2. Follow [Rotate a secret](add-a-secret.md#rotate-a-secret) for the
   `claude` entry in `.chezmoidata/onepassword.yaml`, then update the
   item's **expires** date.
