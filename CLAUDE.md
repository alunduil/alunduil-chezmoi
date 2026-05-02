# alunduil-chezmoi

Chezmoi source directory. Files deploy to `$HOME` via `chezmoi apply`;
names follow chezmoi rules (`dot_` → `.`, `executable_` → +x, `.tmpl` →
Go template, `run_once_before_NN-…` → ordered idempotent bootstrap).
README.md has the bootstrap walkthrough.

## Source vs. apply path

`chezmoi diff`/`apply` read the *applied* clone at
`~/.local/share/chezmoi`, not this working tree. Edits here don't take
effect on `apply` until committed and pulled into the apply clone. Use
`chezmoi diff --source-path .` to preview from this checkout.

## Invariants

- Bootstrap scripts (`run_once_before_NN-*.sh.tmpl`) are idempotent;
  re-running is safe. Numeric prefix orders them.
- Tool versions live in `script/install/{zellij,lazygit,act,gcx}` and are
  reused by both bootstrap and CI. Bump in one place. Zellij *plugins*
  (`zellaude`, `zjstatus`) are pinned separately as alias tags in
  `dot_config/zellij/config.kdl`.
- `gh` extensions install in script 05 alongside other bespoke
  installers, not script 02 — they're managed by `gh extension`, not
  the `script/install/` download-and-verify pattern. Version pin lives
  inline in the script (e.g. `GH_POI_VERSION`).
- `dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft`
  on `gh pr create`. PRs Claude opens go through this wrapper.

## Adding a new tool

Decide first: does the tool need interactive auth (login, browser
flow, API token) to do real work?

- **Yes** (gh, claude, gcx, readwise, tailscale): list in README
  "Interactive logins" with a config-path comment so a fresh-host
  bootstrap surfaces where state lands. No PATH-check line — running
  the login command itself proves reachability. Auth state is
  runtime, never managed by chezmoi.
- **No** (zellij, lazygit, act, rtk, gh-poi): list in README "PATH
  check". If the tool isn't in apt/npm/cargo, follow the
  `script/install/<tool>` pattern: pinned version, SHA-256 verified
  via `lib.sh`, `--bin-dir DIR` interface, idempotent on `--version`
  match. Add a `{{ include "script/install/<tool>" | sha256sum }}`
  line in `run_once_before_02` so version bumps re-fire bootstrap.

Auth and install mechanism are independent: `gcx` uses
`script/install/` *and* lands in interactive logins; `gh-poi` uses
`gh extension install` *and* lands in PATH check.

## Sensors

CI is authoritative. Run locally before claiming done:

```bash
pre-commit run --all-files     # shellcheck, shfmt, check-json
bats test/                     # unit tests
script/checks/zellij-config    # zellij KDL validation (needs zellij)
script/checks/chezmoi-apply    # apply round-trip (needs chezmoi + age)
```

## Two CLAUDE.md files

- This file: rules for AI editing the chezmoi *source*.
- `dot_claude/CLAUDE.md` → deploys to `~/.claude/CLAUDE.md`. Edits there
  change Claude's host-wide behaviour on next `chezmoi apply`.
