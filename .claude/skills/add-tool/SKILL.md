---
name: add-tool
description: Decide where a new tool slots into the chezmoi bootstrap and host-status. Use when adding a CLI/binary to the host bootstrap so it lands in the right install pass and host-status reports it when missing or logged out.
---

# Add a tool to bootstrap

First check the tool belongs on the host, then make two decisions
independently.

## Libraries with no console script

`uv tool install` needs an executable, so a PyPI library takes one of
two shapes:

1. An installed tool imports it (plugins, optional backends): add it
   as a pinned `--with` extra on that tool, as `beets` carries
   `pyacoustid`.
2. Otherwise, keep it off the host. The caller runs
   `uv run --with <pkg>==<version> <script>` and owns the pin. Stop
   here: no bootstrap change, no `host-status` entry.

Install a CLI front-end that wraps the library only when its command
is itself wanted.

## Auth axis

Does the tool need interactive auth (login, browser flow, API token)
to do real work?

- **Yes** (gh, claude, gcx, readwise, tailscale): add a `login` line
  to `check_logins` in `dot_local/bin/executable_host-status.tmpl`,
  testing local state the login leaves behind (a credential file, or a
  command that reads it without the network). Auth state is runtime,
  never managed by chezmoi.
- **No** (zellij, lazygit, act, gh-poi): no login line.

## Missing-tool report

`host-status` derives apt packages from `.chezmoidata/packages.yaml`
and pinned tools from `mise ls --missing`, so those need no entry. A
tool installed any other way (npm, cargo, uv, ghcup, an upstream
installer) goes in its `commands` array.

## Install mechanism

All passes live under `.chezmoiscripts/`.

Pick the canonical installer for the ecosystem:

| Source                | Where                                 | Pattern                        |
| --------------------- | ------------------------------------- | ------------------------------ |
| Debian package        | `.chezmoidata/packages.yaml`          | append to `packages.apt`       |
| Pinned binary release | `dot_config/mise/config.toml`         | mise entry below               |
| npm package           | `run_before_03`                       | `npm install -g`, `command -v` |
| Cargo crate           | `run_before_09`                       | `cargo install`, `command -v`  |
| PyPI package          | `run_after_install-via-mise-tools`    | mirror the `beets` block       |

Raise a release binary that mise can't verify against its publisher,
such as one signed only with GPG, with the user before adding it.

Auth and install axes are independent: `gcx` is auth-required *and*
a mise tool.

Install a `gh` extension as a mise tool, then link
`~/.local/share/gh/extensions/gh-<name>/gh-<name>` to its shim, as
`gh-poi` does.

## Pin the version

Annotate each PyPI `*_VERSION` pin, `--with` extras included, with
`# renovate: datasource=pypi depName=<pkg>` on the line above it.

A mise tool needs no annotation: Renovate's mise manager reads
`config.toml` and updates `mise.lock` in the same PR.

## mise entry

Add the tool under `[tools]` in `dot_config/mise/config.toml`, at an
exact version, sorted by tool name. Use the short name when
`mise registry <tool>` lists one; otherwise use
`"github:<owner>/<repo>"`. Then lock it with `just lock-tools`.

`script/checks/pinned-tools` runs
`<last segment of the config.toml name> --version` and expects the
pinned version in its output. Add any tool that needs another command
to `VERSION_COMMANDS` there.

Commit `config.toml`, `mise.lock`, and any new sidecar under
`dot_config/mise/.mise/locks/`.

A pass that runs the new tool is `run_after_`, since shims resolve
through the `~/.config/mise` that apply deploys. Call
`use_mise_shims` from `script/lib/bootstrap.sh`, then the tool by name.

## Shell completion

When the tool prints a bash completion script, add
`dot_local/share/bash-completion/completions/<command>` holding one
line that evals it, mirroring `just`. bash-completion sources the file
on the first Tab, so the script always matches the installed version.

## Procedure

1. For a library with no console script, settle its shape first; stop
   if it stays off the host.
2. Identify the auth axis and install mechanism.
3. Wire the installer into the right `.chezmoiscripts/` pass, or add
   the mise entry.
4. Update `host-status`: a `login` line for an auth-required tool,
   and a `commands` entry for one installed outside apt and mise.
5. Annotate every pin per [Pin the version](#pin-the-version).
6. Add a [Shell completion](#shell-completion) file if the tool
   generates one.
7. Run sensors before claiming done:

   ```bash
   prek run --all-files
   bats --recursive dot_local dot_claude script
   script/checks/chezmoi-apply
   script/checks/pinned-tools
   ```
