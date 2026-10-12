# Credentials

Every credential on a `workstation` host: where it comes from, which
[data flow](data-flow.md#level-0) store holds it, which process reads it,
and what it reaches. Process and store numbers are the Level 0 ones.

| Credential | Source | Held in | Read by | Reaches |
| --- | --- | --- | --- | --- |
| 1Password account password and Secret Key | The user | Not stored | `2.0` | 1Password |
| age identity | The user, at bootstrap | D2 | `1.0` | None |
| SSH key | 1Password | D4 | `2.0`, signing for `4.0` | GitHub, Home Assistant |
| GitHub token | 1Password | D3, D5 | `1.0`, `3.0` | GitHub |
| TrueNAS API key | 1Password | D3, D5 | `1.0`, `3.0` | TrueNAS appliance |
| Uptime Robot token | 1Password | D3, D5 | `1.0`, `3.0`, `4.0` | Uptime Robot |
| Codecov token | 1Password | D3 | `4.0` | Codecov |
| Grafana Cloud token | 1Password | D3 | `5.0` | Grafana Cloud |
| Cloudflare token | age-encrypted in D1 | D3 | `4.0` | None drawn |
| Claude Code session | `claude` login | D9 | `3.0` | Anthropic |
| `gh` OAuth token | `gh auth login` | D9 | `4.0`, `7.0` | GitHub |
| Tailscale node key | `tailscale up` | D9 | `8.0` | Peers on the tailnet |
| Grafana Cloud login | `gcx login` | D9 | `gcx` | Grafana Cloud |
| Readwise token | `readwise login` | D9 | `readwise` | Readwise |
| Keybase device keys | `keybase login` | D9 | `keybase` | Keybase |
| Signal registration | `signal-cli register`, Signal Desktop link | D9 | `signal-cli`, Signal Desktop | Signal |

## Servers a session calls

| Server | Credential | Held in |
| --- | --- | --- |
| Notion and Readwise, through claude.ai connectors | OAuth grant on the Anthropic account | Anthropic |
| Cloudflare `graphql`, `docs`, `dns-analytics` | OAuth grant from a browser sign-in | Claude Code, outside the chezmoi source |
| GitHub, Uptime Robot | Bearer token | D5 |
| TrueNAS | API key as an environment variable | D5 |
| Context7 | None | Not applicable |

TrueNAS runs with certificate verification off.

## Shell environment

`dot_bashrc` exports the Codecov, Uptime Robot, and Cloudflare tokens
from D3, so every process `4.0` starts inherits all three. Nothing this
repository manages reads the Cloudflare token.

## Login credentials

Apply never writes D9. A new host repeats each login by hand. `7.0`
spends the `gh` OAuth token with no person present.
