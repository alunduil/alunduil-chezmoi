---
name: add-tool
description: Decide where a new tool slots into the chezmoi bootstrap and README. Use when adding a CLI/binary to the host bootstrap so it lands in the right install pass and the right README block. Routes auth-required tools to "Interactive logins" and fire-and-forget binaries to "PATH check".
---

# Add a tool to bootstrap

Two decisions, made independently.

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

Pick the canonical installer for the ecosystem:

All passes live under `.chezmoiscripts/`.

| Source                | Pass                                      | Pattern                        |
| --------------------- | ----------------------------------------- | ------------------------------ |
| Debian package        | `.chezmoidata/packages.yaml`              | append to `packages.apt`       |
| Pinned binary release | `run_before_02` + `script/install/<tool>` | template below                 |
| npm package           | `run_before_03`                           | `npm install -g`, `command -v` |
| Cargo crate           | `run_before_09`                           | `cargo install`, `command -v`  |
| `gh` extension        | `run_before_05`                           | `gh extension install --pin`   |
| PyPI package          | `run_before_02`                           | `uv tool install` (below)      |

Auth and install axes are independent: `gcx` is auth-required *and*
uses `script/install/`; `gh-poi` is fire-and-forget *and* uses
`gh extension install`.

## `script/install/<tool>` template

Mirror `script/install/{zellij,lazygit,act,gcx}`. Mode 0755:

```bash
#!/usr/bin/env bash
set -euo pipefail

TOOL_VERSION="vX.Y.Z"
ARCH="<release-arch-string>"

# shellcheck source-path=SCRIPTDIR source=lib.sh
. "$(dirname "$0")/lib.sh"

parse_bin_dir "$@"

bin="$BIN_DIR/<tool>"
if [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -qF "${TOOL_VERSION#v}"; then
  printf '==> <tool>: %s already installed at %s\n' "$TOOL_VERSION" "$bin" >&2
  exit 0
fi

printf '==> <tool>: downloading %s\n' "$TOOL_VERSION" >&2
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

base="https://github.com/<owner>/<tool>/releases/download/${TOOL_VERSION}"
asset="<tool>_${TOOL_VERSION#v}_${ARCH}.tar.gz"
curl -fsSL -o "$tmp/$asset" "$base/$asset"
curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"

expected="$(expected_from_checksums "$tmp/checksums.txt" "$asset")"
verify_sha256 "$tmp/$asset" "$expected"

tar -xzf "$tmp/$asset" -C "$tmp" <tool>
mkdir -p "$BIN_DIR"
install -m 0755 "$tmp/<tool>" "$bin"
```

In `.chezmoiscripts/run_before_02-install-binary-tools.sh.tmpl`, add
`"$INSTALL_DIR/<tool>" --bin-dir "$HOME/.local/bin"` to the call list.
That pass runs on every apply, so the installer's own
`installed_version_matches` guard is what makes a bump take effect — the
install script must no-op when the pinned version is already on disk.

Put `# renovate: datasource=github-releases depName=<owner>/<tool>`
directly above `TOOL_VERSION`. The regex manager in `renovate.json`
reads every annotated `*_VERSION` pin under `script/install/` and
`.chezmoiscripts/`, so no Renovate config change is needed.

## PyPI packages

Mirror the `beets` block in
`.chezmoiscripts/run_before_02-install-binary-tools.sh.tmpl`:

- `# renovate: datasource=pypi depName=<pkg>` directly above each
  `<PKG>_VERSION` pin, including every `--with` extra.
- Guard on `uv tool list --show-with --show-version-specifiers`,
  matching the full requirement line with `grep -qxF`, so bumping any
  pin in the set reinstalls. `<tool> --version` cannot tell a uv
  install from a pip one at the same version.
- `uv tool install --force` so it replaces any earlier install of the
  same command on PATH.

### Libraries with no console script

`uv tool install` needs an executable, so a library takes one of two
shapes:

1. An installed tool imports it (plugins, optional backends): add it
   as a pinned `--with` extra on that tool, as `beets` carries
   `pyacoustid`.
2. Otherwise, keep it off the host. The caller runs
   `uv run --with <pkg>==<version> <script>` and owns the pin. No
   bootstrap change, no README line.

Install a CLI front-end that wraps the library only when its command
is itself wanted.

## Procedure

1. Identify the auth axis and install mechanism.
2. Wire the installer into the right `.chezmoiscripts/run_*_before_NN` pass.
3. Update README:
   - Auth-required → add to "Interactive logins" with config-path comment
   - Fire-and-forget → add to "PATH check" line
4. Annotate every `*_VERSION` pin with its `# renovate:` comment.
5. Run sensors before claiming done:

   ```bash
   pre-commit run --all-files
   bats --recursive dot_local dot_claude script
   script/checks/chezmoi-apply
   ```
