# 4. Resolve secrets from 1Password at apply

## Status

Accepted

## Context

Every long-lived secret ships as an age-encrypted blob in the source
tree—four API tokens (`dot_config/{codecov,github,truenas,uptimerobot}`),
the GPG secret key, and the SSH key and config—unlocked by the age key
pasted into `~/.config/chezmoi/key.txt` on a fresh host. Two costs push
against that model:

- **Rotation is a four-step dance.** Paste the new secret, `chezmoi add
  --encrypt`, commit, push—and it must run from a checkout that can
  decrypt. The ciphertext history also lingers in `git log`.
- **Each new secret is bespoke.** #188 and #201 both reached for the
  encrypted-blob pattern, and #201 flagged the HTTP-MCP `Authorization`
  header case as having no clean home. A password-manager lookup at
  render time generalises across env vars, HTTP headers, and on-disk
  credentials without per-shape carve-outs.

chezmoi ships first-class 1Password template functions, so the fetch is
a template rewrite, not new bootstrap machinery. Three options were
weighed:

1. **Stay on age.** Zero new dependency, works offline, but keeps both
   costs above.
2. **1Password account mode** (`op signin`). Full account auth. Ergonomic
   only with the desktop app's local socket or biometric unlock, which
   this Crostini host can't rely on. That leaves account password plus
   secret key re-entered for every scripted `chezmoi apply`.
3. **1Password service-account mode.** A non-human identity, a token
   scoped read-only to one vault. No desktop-app dependency, revocable
   server-side, least privilege.

Service mode carries one constraint: `onepasswordDocument` is
unavailable there, only `onepasswordRead`. Both the GPG key
(`--export-secret-keys --armor`) and the SSH key (OpenSSH PEM) are text,
so each stores as a multiline field and reads via `onepasswordRead`. The
document function isn't needed.

The service-account token is itself a bearer secret that must be present
at every apply, not just bootstrap, and can't come from 1Password
(chicken-and-egg). It's a direct swap for the on-disk age key rather than
a new class of exposure.

## Decision

We resolve secrets with `onepasswordRead "op://chezmoi/<item>/<field>"`
in service mode (`onepassword.mode = "service"`), scoped read-only to a
dedicated `chezmoi` vault. Every secret is an `onepasswordRead` lookup;
keys live as multiline fields, so `onepasswordDocument` is never used.

The token lives at `~/.config/op/token` (0600, out of band, never
chezmoi-managed), exported as `OP_SERVICE_ACCOUNT_TOKEN` from the shell
rc. It replaces `~/.config/chezmoi/key.txt` as the single out-of-band
bootstrap secret.

Every secret template guards on the token
(`{{ if env "OP_SERVICE_ACCOUNT_TOKEN" }}…{{ end }}`) so an apply with no
token—CI, or a host before the token is placed—renders empty instead of
failing the whole run.

## Consequences

- Rotation collapses to one vault edit; the next apply picks it up. No
  ciphertext history, no decrypt-capable checkout required.
- New secrets are a one-line `onepasswordRead`, uniform across tokens,
  headers, and on-disk credentials.
- The trust chain moves from *age key + GPG passphrase* to *1Password
  service-account token*. Blast radius on token leak is one read-only
  vault, and the token revokes server-side without touching the repo.
- Apply now needs a network round-trip to 1Password; a fresh-host
  bootstrap on a flaky connection is more brittle than local age
  decryption was.
- 1Password is a commercial service where age was a public spec. Recovery
  from lost vault access leans on the 1Password Emergency Kit, the
  analogue of the PGP paper key.
- Service accounts bind the CLI to a single 1Password account; a
  multi-account need would force a different mode.
- An apply with no token materialises empty secret files rather than
  failing. That keeps CI green but means a host is only fully provisioned
  once the token is in place.
