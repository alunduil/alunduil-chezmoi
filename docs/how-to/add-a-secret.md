# Adding a secret

A secret deploys from an item in the `chezmoi` 1Password vault. The repo
holds only the item's ID.

## Store the secret in 1Password

Create an **API Credential** item in the `chezmoi` vault and paste the
secret into its **credential** field. Then look up the item's ID:

```bash
op item list --vault chezmoi
```

Add the reference under `onepassword` in `.chezmoidata/onepassword.yaml`:

```yaml
  <service>: op://chezmoi/<item-id>/credential
```

## Add the template

Name the file so chezmoi writes it with mode 600, for example
`dot_config/<service>/private_token.tmpl`:

```text
{{ includeTemplate "onepassword-read" .onepassword.<service> -}}
```

See `dot_config/codecov/` for an existing example.

## Rerun what consumes it on rotation

When a script hands the secret to something long-running, key the
script on the secret's value so a rotation reruns it. Make it a
`run_onchange_after_` script with a hash line:

```text
# token-hash: {{ includeTemplate "onepassword-read" .onepassword.<service> | sha256sum }}
```

`.chezmoiscripts/run_onchange_after_register-uptimerobot-mcp.sh.tmpl`
is an example.

## Rotate a secret

Replace the value in the 1Password item, then run `chezmoi apply`.
