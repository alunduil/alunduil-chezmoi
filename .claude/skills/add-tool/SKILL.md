---
name: add-tool
description: Decide where a new tool slots into the chezmoi bootstrap and README. Use when adding a CLI/binary to the host bootstrap so it lands in the right install pass and the right README block. Routes auth-required tools to "Interactive logins" and fire-and-forget binaries to "PATH check".
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
   here: no bootstrap change, no README line.

Install a CLI front-end that wraps the library only when its command
is itself wanted.

## Auth axis

Does the tool need interactive auth (login, browser flow, API token)
to do real work?

- **Yes** (gh, claude, gcx, readwise, tailscale): list in README
  "Interactive logins" with a config-path comment so a fresh-host
  bootstrap surfaces where state lands. No PATH-check line — running
  the login command itself proves reachability. Auth state is
  runtime, never managed by chezmoi.
- **No** (zellij, lazygit, act, gh-poi): list in README "PATH
  check" line.

## Install mechanism

All passes live under `.chezmoiscripts/`.

Pick the canonical installer for the ecosystem:

| Source                | Where                                 | Pattern                        |
| --------------------- | ------------------------------------- | ------------------------------ |
| Debian package        | `.chezmoidata/packages.yaml`          | append to `packages.apt`       |
| Pinned binary release | `dot_config/mise/config.toml`         | mise entry below               |
| npm package           | `run_before_03`                       | `npm install -g`, `command -v` |
| Cargo crate           | `run_before_09`                       | `cargo install`, `command -v`  |
| `gh` extension        | `run_before_05`                       | `gh extension install --pin`   |
| PyPI package          | `run_after_install-via-mise-tools`    | mirror the `beets` block       |

A release binary whose publisher check mise can't perform, such as a
GPG signature against a pinned key, has no settled install path. Stop
and raise it with the user before adding the tool.

Auth and install axes are independent: `gcx` is auth-required *and*
a mise tool; `gh-poi` is fire-and-forget *and* uses
`gh extension install`.

## Pin the version

Annotate each PyPI `*_VERSION` pin on the line directly above it with
`# renovate: datasource=pypi depName=<pkg>`, one per `--with` extra
too.

A mise tool needs no annotation: Renovate's mise manager reads
`config.toml` and updates `mise.lock` in the same PR.

## mise entry

Add the tool under `[tools]` in `dot_config/mise/config.toml`, at an
exact version, sorted by tool name. Use the short name when
`mise registry <tool>` lists one; otherwise use
`"github:<owner>/<repo>"`. Then lock it with `just lock-tools`.

Add the tool's version command to `VERSION_COMMANDS` in
`script/checks/pinned-tools`, keyed by its `config.toml` name. The
command's output must contain the pinned version.

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
4. Update README:
   - Auth-required → add to "Interactive logins" with config-path comment
   - Fire-and-forget → add to "PATH check" line
5. Annotate every pin per [Pin the version](#pin-the-version).
6. Add a [Shell completion](#shell-completion) file if the tool
   generates one.
7. Run sensors before claiming done:

   ```bash
   pre-commit run --all-files
   bats --recursive dot_local dot_claude script
   script/checks/chezmoi-apply
   script/checks/pinned-tools
   ```
