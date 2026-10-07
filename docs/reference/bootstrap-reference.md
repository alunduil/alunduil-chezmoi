# Bootstrap reference

The rules `chezmoi apply` follows on this repo: when each bootstrap pass
runs, where each tool installs from, what each host role receives, and
what unlocks each secret. The files named in each section are the only
copies of the values. For why the system has this shape, see
[../explanation/architecture.md](../explanation/architecture.md).

## Script prefixes

Bootstrap passes live in `.chezmoiscripts/`. The prefix sets when a pass
runs:

| Prefix | Runs | Used for |
| ------ | ---- | -------- |
| `run_` | every apply | every pass that converges on host state |
| `run_onchange_` | when the script's rendered content changes | `_07` and `register-*-mcp`, whose trigger is content |
| `run_once_` | never used | `script/checks/bootstrap-convergence` fails the build on one |

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
- What an `after` pass consumes: a user unit from
  `dot_config/systemd/user/` (`enable-*`), a decrypted token
  (`register-*-mcp`), or an external binary (`install-via-externals`).
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
| apt packages | `.chezmoidata/packages.yaml` | pass `01`, one transaction | the apt repository |
| Release binaries | `.chezmoiexternal.toml` | `chezmoi apply` | the version in the download address |
| Binaries an external can't express | `script/install/*` | pass `02` | `*_VERSION` in the script |
| Python tools | `run_after_install-via-externals` | `uv tool install` | `*_VERSION` in the pass |
| `gh` extensions | pass `05` | `gh extension install` | `gh extension` |
| Node, Haskell, Rust | passes `03`, `06`, `09` | each ecosystem's own manager | `*_VERSION` in the pass |
| Zellij plugins | `plugins` block of `dot_config/zellij/config.kdl` | Zellij at load | the version in the download address |

[ADR 0008](../adr/0008-install-pinned-binaries-as-chezmoi-externals.md)
names the binaries that stay in `script/install/*`.

## Host roles

`chezmoi init` reads `role` from `CHEZMOI_ROLE`, defaulting to
`workstation`. `.chezmoiignore` applies it.

| Role | Host | Ignored targets |
| ---- | ---- | --------------- |
| `workstation` | Debian/Crostini | none |
| `ha-terminal` | Home Assistant SSH add-on (Alpine/musl, ephemeral `/root`) | `.chezmoiscripts/**`, `.config/**`, `.local/bin/**`, `.local/lib/bats/**`, `.gnupg/**`, `.ssh/**`, `.bashrc`, `.bash_profile`, `.profile`, `.gitconfig` |

Each role lists the targets it drops. To keep one target a pattern
drops, re-include that file with `!`.

## Secrets

Every secret below is an age-encrypted `encrypted_*.age` source,
decrypted on apply with the age key. The age key itself comes from a
password manager during bootstrap.

| Secret | Target | Unlocks with | `ha-terminal` |
| ------ | ------ | ------------ | ------------- |
| GPG signing key | `~/.gnupg/secret-keys.asc`, imported by pass `08` | age key + GPG passphrase | ignored |
| SSH key and config | `~/.ssh/{id_rsa,config}` | age key | ignored |
| Service tokens | `~/.config/{cloudflare,codecov,github,grafana-cloud,truenas,uptimerobot}/` | age key | ignored |

The paper-key backup in
[../how-to/pgp-signing.md](../how-to/pgp-signing.md) recovers the GPG
key without the age key.
