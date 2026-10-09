# Bootstrap reference

Rules for what `chezmoi apply` runs, installs, and deploys on each host.
Where a rule names a file, that file holds the values. For why the
system has this shape, see
[../explanation/architecture.md](../explanation/architecture.md).

## Passes

Bootstrap passes live in `.chezmoiscripts/` and source shared helpers
from `script/lib/bootstrap.sh`. Each pass owns one product family: a
tool that needs both `apt` and a download lives in one pass.

| Prefix | Used for |
| ------ | -------- |
| `run_` | every pass with a local guard |
| `run_onchange_` | a pass whose only guard costs a network round-trip or a password prompt, keyed on the content that should re-fire it |
| `run_once_` | nothing: `script/checks/bootstrap-convergence` fails the build on one |

A `run_` pass checks host state before acting and reaches no `sudo` when
the host already matches. Local guards: `dpkg-query` status compared to
`installed`, a pinned `--version`, `cmp` before `sudo install`.

## Phases and order

| Phase | Name | Belongs here when |
| ----- | ---- | ----------------- |
| `before` | `run_*_before_NN-<concern>` | the pass needs nothing `apply` deploys |
| `after` | `run_*_after_<concept>` | the pass reads a user unit, decrypted token, or external binary that `apply` deploys |

- `before` passes run in `NN` order, a sort key where one install
  depends on another. Gaps are fine.
- `after` passes are mutually independent and carry no number.
- Enabling a service its own package shipped, such as `tailscaled`,
  stays in the `before` pass that installed it.

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

To keep one target a role's pattern drops, re-include that file with
`!`.

## Secrets

Every secret but the Cloudflare token lives in the `chezmoi` 1Password
vault. Apply reads each through the 1Password desktop app, except the SSH
key, which the app's agent serves without writing it to disk. Setting
`CHEZMOI_NO_1PASSWORD` renders every 1Password secret empty; the checks
and the first bootstrap pass set it.

| Secret | Source | Unlocks with | `ha-terminal` |
| ------ | ------ | ------------ | ------------- |
| GPG signing key | `private_dot_gnupg/private_secret-keys.asc.tmpl`, imported by `import-pgp-from-chezmoi` | 1Password + GPG passphrase | ignored |
| SSH key | 1Password agent, limited by `dot_config/1Password/ssh/agent.toml` | 1Password | ignored |
| Service tokens | `dot_config/<service>/private_*.tmpl` | 1Password | ignored |
| Cloudflare token | `dot_config/cloudflare/encrypted_private_token.age` | age key | ignored |
