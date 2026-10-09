# Adding a secret

A secret deploys from an item in the `chezmoi` 1Password vault. The repo
holds only a template that names the item.

## Store the secret in 1Password

Create an **API Credential** item in the `chezmoi` vault and paste the
secret into its **credential** field. Then look up the item's ID:

```bash
op item list --vault chezmoi
```

Templates use the ID because `op://` references reject some characters
that titles allow, such as `:`, and because an ID survives a rename.

## Add the template

Name the file so chezmoi writes it with mode 600, for example
`dot_config/<service>/private_token.tmpl`:

```text
{{- if not (env "CHEZMOI_NO_1PASSWORD") -}}
{{ onepasswordRead "op://chezmoi/<item-id>/credential" }}
{{ end -}}
```

The checks set `CHEZMOI_NO_1PASSWORD`, which renders the file empty
instead of reading 1Password. See `dot_config/codecov/` for an existing
example.

## Rerun what consumes it on rotation

When a script hands the secret to something long-running, key the
script on the secret's value so a rotation reruns it. Make it a
`run_onchange_after_` script with a hash line:

```text
# token-hash: {{ if not (env "CHEZMOI_NO_1PASSWORD") }}{{ onepasswordRead "op://chezmoi/<item-id>/credential" | sha256sum }}{{ end }}
```

`.chezmoiscripts/run_onchange_after_register-uptimerobot-mcp.sh.tmpl`
is an example.

## Rotate a secret

Replace the value in the 1Password item, then run `chezmoi apply`.
