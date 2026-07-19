# Adding a secret

Credentials that replay across machines resolve from the `chezmoi` 1Password vault at apply time; nothing secret lands in the source tree. Two steps: store the value in the vault, then add a template that reads it.

1. Store the secret in the `chezmoi` vault, one field per credential:

   ```bash
   op item create --category "API Credential" --vault chezmoi \
     --title <service> "token=<paste-secret>"
   ```

2. Add a guarded template in this checkout:

   ```bash
   mkdir -p dot_config/<service>
   cat > dot_config/<service>/private_token.tmpl <<'EOF'
   {{- if env "OP_SERVICE_ACCOUNT_TOKEN" -}}
   {{ onepasswordRead "op://chezmoi/<service>/token" }}
   {{- end -}}
   EOF
   ```

Deploys to `~/.config/<service>/token` (mode 600) on the next `chezmoi apply`. The `private_` prefix sets 0600, the `.tmpl` suffix renders the template, and the env guard lets it render without an op session (CI, or a host before the token is placed). See `dot_config/codecov/` for an existing example.

Rotation is a vault edit (`op item edit <service> "token=<new>" --vault chezmoi`); the next apply picks it up.
