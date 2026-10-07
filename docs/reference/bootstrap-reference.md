# Bootstrap reference

The rules `chezmoi apply` follows on this repo: when each bootstrap pass
runs, where each tool installs from, what each host role receives, and
what unlocks each secret. Where a rule names a file, that file holds the
values. For why the system has this shape, see
[../explanation/architecture.md](../explanation/architecture.md).

## Script prefixes

Bootstrap passes live in `.chezmoiscripts/`.

| Prefix | Used for |
| ------ | -------- |
| `run_` | every pass that converges on host state |
| `run_onchange_` | `register-claude-mcp-servers` and `register-*-mcp`, whose trigger is content |
| `run_once_` | nothing: `script/checks/bootstrap-convergence` fails the build on one |

A `run_` pass checks host state before acting and reaches no `sudo` when
the host already matches. Its guard stays local: `dpkg-query` status
compared to `installed`, a pinned `--version`, `cmp` before
`sudo install`. A pass whose only guard costs a network round-trip or a
password prompt uses `run_onchange_`, keyed on the content that should
re-fire it.

[ADR 0009](../adr/0009-converge-bootstrap-passes-on-every-apply.md)
records why.

## Phases and order

| Phase | Runs | Name | Belongs here when |
| ----- | ---- | ---- | ----------------- |
| `before` | before chezmoi writes files | `run_*_before_NN-<concern>` | the pass needs nothing `apply` deploys |
| `after` | after chezmoi writes files | `run_*_after_<concept>` | the pass reads a file `apply` deploys |

- `before` passes run in `NN` order, a sort key where one install
  depends on another. Gaps are fine.
- `after` passes are mutually independent and carry no number.
- An `after` pass consumes a user unit from `dot_config/systemd/user/`,
  a decrypted token, or an external binary.
- Enabling a service its own package shipped, such as `tailscaled`,
  stays in the `before` pass that installed it.
- One pass per product family. A tool that needs both `apt` and a
  download lives in one pass.
- Shared helpers live in `script/lib/bootstrap.sh`, which every pass
  sources.

[ADR 0006](../adr/0006-run-units-at-least-privilege.md) sets which
systemd manager a unit belongs in and what it runs as.

## Install sources

| Kind | Declared in | Installed by | Pinned by |
| ---- | ----------- | ------------ | --------- |
| apt packages | `.chezmoidata/packages.yaml` | `install-system-packages`, one transaction | the apt repository |
| Release binaries | `.chezmoiexternal.toml` | `chezmoi apply` | the version in the download address |
| Binaries an external can't express | `script/install/*` | `install-binary-tools` | `*_VERSION` in the script |
| Python tools | `install-via-externals` | `uv tool install` | `*_VERSION` in the pass |
| `gh` extensions | `install-gh-extensions` | `gh extension install` | `gh extension` |
| Node, Haskell, Rust | `install-{node,haskell,rust}-ecosystem` | each ecosystem's own manager | `*_VERSION` in the pass |
| Zellij plugins | `plugins` block of `dot_config/zellij/config.kdl` | Zellij at load | the version in the download address |

Every apt package goes in the one list. Later passes configure what
`install-system-packages` installed rather than calling apt themselves.

[ADR 0008](../adr/0008-install-pinned-binaries-as-chezmoi-externals.md)
names the binaries that stay in `script/install/*`.

## Host roles

`chezmoi init` reads `role` from `CHEZMOI_ROLE`, defaulting to
`workstation`. `.chezmoiignore` applies it.

| Role | Host | Ignores |
| ---- | ---- | ------- |
| `workstation` | Debian/Crostini | nothing |
| `ha-terminal` | Home Assistant SSH add-on (Alpine/musl, ephemeral `/root`) | the targets in the `ha-terminal` block of `.chezmoiignore` |

Each role lists the targets it drops. To keep one target a pattern
drops, re-include that file with `!`.

## Secrets

Every secret is an age-encrypted `encrypted_*.age` source, decrypted on
apply with the age key. The age key itself comes from a password manager
during bootstrap.

| Secret | Source | Unlocks with | `ha-terminal` |
| ------ | ------ | ------------ | ------------- |
| GPG signing key | `private_dot_gnupg/`, imported by `import-pgp-from-chezmoi` | age key + GPG passphrase | ignored |
| SSH key and config | `private_dot_ssh/` | age key | ignored |
| Service tokens | `dot_config/<service>/encrypted_private_*.age` | age key | ignored |

The paper-key backup in
[../how-to/pgp-signing.md](../how-to/pgp-signing.md) recovers the GPG
key without the age key.
