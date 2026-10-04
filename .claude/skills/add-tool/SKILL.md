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
| Pinned binary release | `.chezmoiexternal.toml.tmpl`          | external entry below           |
| npm package           | `run_before_03`                       | `npm install -g`, `command -v` |
| Cargo crate           | `run_before_09`                       | `cargo install`, `command -v`  |
| `gh` extension        | `run_before_05`                       | `gh extension install --pin`   |
| PyPI package          | `run_after_install-uv-tools`          | mirror the `beets` block       |

A release binary that needs more than a download (signature check,
source build) gets a `script/install/<tool>` script and its own
`run_before_NN` pass instead; mirror `script/install/signal-cli` and
`run_before_02-install-signal-cli`.

Auth and install axes are independent: `gcx` is auth-required *and*
a chezmoi external; `gh-poi` is fire-and-forget *and* uses
`gh extension install`.

## Pin the version

Annotate each `*_VERSION` pin on the line directly above it:

| Source                | Annotation                                                              |
| --------------------- | ----------------------------------------------------------------------- |
| Pinned binary release | `# renovate: datasource=github-releases depName=<owner>/<tool>`         |
| PyPI package          | `# renovate: datasource=pypi depName=<pkg>`, one per `--with` extra too |

## External entry

Add the version to `.chezmoidata/versions.yaml` under `versions`, with
its annotation above it:

```yaml
  # renovate: datasource=github-releases depName=<owner>/<tool>
  TOOL_VERSION: "vX.Y.Z"
```

Then add an entry to `.chezmoiexternal.toml.tmpl`, mirroring `vale` or
`lazygit`. Build the whole address from the version, including any
copy of it in the asset filename, so a Renovate bump stays complete:

```toml
[".local/bin/<tool>"]
    type = "archive-file"
    url = "https://github.com/<owner>/<tool>/releases/download/{{ $v.TOOL_VERSION }}/<tool>_{{ trimPrefix "v" $v.TOOL_VERSION }}_<arch>.tar.gz"
    path = "<tool>"
    executable = true
```

Use `type = "file"` for a raw binary asset. Store no checksum for a
release asset: the pinned address fixes its bytes (ADR 0008). Only a
GitHub source-archive tarball (`archive/refs/tags/…`) carries an inline
`checksum.sha256`.

A pass that runs the new binary is `run_after_`, since externals deploy
during apply.

## Procedure

1. For a library with no console script, settle its shape first; stop
   if it stays off the host.
2. Identify the auth axis and install mechanism.
3. Wire the installer into the right `.chezmoiscripts/` pass, or add
   the external entry.
4. Update README:
   - Auth-required → add to "Interactive logins" with config-path comment
   - Fire-and-forget → add to "PATH check" line
5. Annotate every pin per [Pin the version](#pin-the-version).
6. Run sensors before claiming done:

   ```bash
   pre-commit run --all-files
   bats --recursive dot_local dot_claude script
   script/checks/chezmoi-apply
   ```
