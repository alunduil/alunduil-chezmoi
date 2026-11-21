# Bootstrap reference

Rules for what `chezmoi apply` runs, installs, and deploys on each host.
Where a rule names a file, that file holds the values. For why the
system has this shape, see
[../explanation/architecture.md](../explanation/architecture.md).

## Passes

Bootstrap passes live in `.chezmoiscripts/` and source shared helpers
from `script/lib/bootstrap.sh`. `script/lib/bootstrap.bats` fails on a
pass that doesn't. Each pass owns one product family: a tool that needs
both `apt` and a download lives in one pass.

Each pass reports its own failure: its name, the failing command and
line, and that re-running `chezmoi apply` is safe. The library turns on
`set -E`, so the report also covers failures inside helpers. An `exit`
skips the report, so a pass fails by letting a command fail.

| Prefix | Used for |
| ------ | -------- |
| `run_` | every pass with a local guard |
| `run_onchange_` | a pass whose only guard costs a network round-trip or a password prompt, keyed on the content that should re-fire it |
| `run_once_` | nothing: `script/checks/bootstrap-convergence` fails the build on one |

A `run_` pass checks host state before acting. Local guards: a pinned
`--version`, a file's presence.

`configure-system-layer` reaches `sudo` on every apply, because it runs
the playbook in `ansible/` with `become`. The playbook's modules are its
guards: a converged host reports `changed=0`.

No other pass calls `sudo`. `script/checks/bootstrap-convergence`
fails on one.

A `run_onchange_` pass that can't do its work exits non-zero. chezmoi
records the hash on exit 0, so the pass reruns only when hashed content
changes. A skip waiting on an input that hash covers may exit 0, marked
`# rerun-on: <name>-hash`. `script/checks/bootstrap-convergence` fails
on an unmarked `exit 0`.

## Phases and order

| Phase | Name | Belongs here when |
| ----- | ---- | ----------------- |
| `before` | `run_*_before_NN-<concern>` | the pass needs nothing `apply` deploys |
| `after` | `run_*_after_<concept>` | the pass reads a user unit, decrypted token, or the mise config that `apply` deploys |

- `before` passes run in `NN` order, a sort key where one install
  depends on another. Gaps are fine.
- `after` passes are mutually independent and carry no number.
- A new `after` pass's name sorts before `zz-report-skipped-units`,
  which lists the units the others couldn't enable.
- An `after` pass enables user units through `enable_user_units`. With
  no user systemd manager running, it records them for
  `zz-report-skipped-units`.
- `host-status` checks only the units in its `system_units` and
  `user_units` arrays, so a pass or playbook task that enables a unit
  adds it there.

[ADR 0006](../adr/0006-run-units-at-least-privilege.md) sets which
systemd manager a unit belongs in and what it runs as.

## Install sources

| Kind | Declared in | Installed by | Pinned by |
| ---- | ----------- | ------------ | --------- |
| apt packages | `apt_packages` in `ansible/group_vars/all/packages.yml` | `configure-system-layer`, one transaction | the apt repository |
| Docker | `geerlingguy.docker` defaults, `ansible/group_vars/all/docker.yml` | `configure-system-layer`, through the role | the apt repository |
| mise | `dot_config/mise/config.toml` | `install-mise`, through the mise on `PATH` | `dot_config/mise/mise.lock` |
| Release binaries, Rust, cargo crates | `dot_config/mise/config.toml` | `install-pinned-tools`, through `mise install` | `dot_config/mise/mise.lock` |
| Python tools | `install-via-mise-tools` | `uv tool install` | `*_VERSION` in the pass |
| Node, Haskell | `install-{node,haskell}-ecosystem` | each ecosystem's own manager | `*_VERSION` in the pass |
| Galaxy roles and collections | `ansible/requirements.yml` | `configure-system-layer`, through `ansible-galaxy` | the version in `requirements.yml` |
| Claude Code | `install-claude-code` | Anthropic's native installer | nothing: it updates itself |
| Zellij plugins | `plugins` block of `dot_config/zellij/config.kdl` | Zellij at load | the version in the download address |

Every apt package except Docker's goes in `apt_packages`. A package
whose install script maintains its own apt source (1Password, Keybase,
VS Code) also has an upstream `.deb` in `ansible/tasks/apt.yml`, which
installs it once when it's missing. Every other repository is a deb822
`.sources` file that the playbook writes.

A pass that runs `mise install` calls `use_pinned_mise` first.
`mise install` links every shim to the first `mise` on `PATH`, which on
a first apply is the tutorial's seed.

`install-pinned-tools` runs after `configure-system-layer`, because cargo
crates build against its `build-essential`. `configure-system-layer`
installs only the tools its playbook runs on.

Callers reach mise tools through the shims in
`~/.local/share/mise/shims`, which keep one path across version bumps.
On the host, a shim reads only `~/.config/mise/config.toml`. It ignores
a checkout's `mise.toml`, `.tool-versions`, `.miserc.toml`, and
`mise.<env>.toml`, so a checkout neither pins host tools nor asks for
trust. The variables in `~/.config/environment.d/mise.conf` set this.
`mise-isolation-probe`, run by `host-status` and CI, fails if a checkout
can change a host tool. Add any new file that mise discovers to the
probe's hostile checkout. To use a checkout's config for one command,
unset the variables:

```bash
env -u MISE_OVERRIDE_CONFIG_FILENAMES -u MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES \
  -u MISE_ENV -u MISE_AUTO_ENV <command>
```

A shim for a version that isn't installed fails, so run `mise install`
first.

The Rust shims set `RUSTUP_TOOLCHAIN` to the host's pin, which rustup
ranks above a checkout's `rust-toolchain.toml`. To build with a
checkout's toolchain on the host, name it: `cargo +<toolchain> build`.
A binary that `cargo install` adds to `~/.cargo/bin` reaches `PATH`
after `mise reshim`.

`gh` looks for extensions only in its data directory, so
`~/.local/share/gh/extensions/gh-poi/gh-poi` links to the gh-poi shim.

## System layer

`ansible/site.yml` configures apt sources and packages, files under
`/etc`, and system units.

- Literal files live in `etc/` at their path under `/etc`. The
  playbook installs them with `backup: true`, keeping a timestamped
  copy of any file it replaces.
- Docker's `daemon.json` has no copy in `etc/`: `geerlingguy.docker`
  renders it from `docker_daemon_options`.
- A unit file or drop-in change triggers `daemon-reload` before the
  playbook enables units.
- The playbook avoids `command` and `shell` tasks: check mode can't
  predict what they change.

Preview the system layer from a checkout:

```bash
ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook --check --diff ansible/site.yml
```

## Secrets

Every secret but the Cloudflare token lives in the `chezmoi` 1Password
vault. Apply reads each through the 1Password desktop app, except the SSH
key, which `ssh-load` reads into the OpenSSH agent for eight hours without
writing it to disk.
`.chezmoidata/onepassword.yaml` holds every vault reference. Setting
`CHEZMOI_NO_1PASSWORD` renders every 1Password secret empty. The checks
and the first bootstrap pass set it.

| Secret | Source | Unlocks with |
| ------ | ------ | ------------ |
| SSH and commit-signing key | `ssh-load` into `ssh-agent.service` | 1Password |
| Service tokens | `dot_config/<service>/private_*.tmpl` | 1Password |
| Cloudflare token | `dot_config/cloudflare/encrypted_private_token.age` | age key |
