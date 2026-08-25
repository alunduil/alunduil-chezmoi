# alunduil-chezmoi

Chezmoi source directory. Files deploy to `$HOME` via `chezmoi apply`;
names follow chezmoi rules (`dot_` → `.`, `executable_` → +x, `.tmpl` →
Go template, `.chezmoiscripts/run_*_before_NN-…` → ordered convergent bootstrap).
`docs/tutorials/bootstrap.md` has the bootstrap walkthrough; `docs/explanation/architecture.md` has the human-facing rationale.

## Source vs. apply path

`chezmoi diff`/`apply` read the *applied* clone at
`~/.local/share/chezmoi`, not this working tree. Edits here don't take
effect on `apply` until committed and pulled into the apply clone. Use
`chezmoi diff --source-path .` to preview from this checkout.

## Invariants

- Bootstrap scripts live in `.chezmoiscripts/` and converge: they run on
  every apply and each checks host state before acting (`dpkg-query`
  status, pinned `--version`, `cmp` before `sudo install`), so drift
  heals. Guards stay local and reach no `sudo` when the host already
  matches — one that costs a network round-trip or prompts for a password
  belongs behind `run_onchange_` instead. `run_*_before_NN-*`
  install/config passes carry a numeric prefix that orders them
  (dependencies); `run_*_after_*` passes are order-independent and named
  by concept, not numbered.
- `run_onchange_` is only for passes whose trigger is genuinely content,
  not host state: `_07` (its `claude mcp list` guard costs a network
  round-trip per server) and `run_onchange_after_register-*-mcp` (rotating
  secrets must re-register on change). Everything else is plain `run_`.
  No `run_once_` — it keys off script content, so it cannot see drift.
- `after` is for passes that consume something `chezmoi apply` deploys: a
  user unit from `dot_config/systemd/user/`, a decrypted token. That
  dependency is the only thing that forces the phase — everything else is
  `before`. Enabling a service the package itself shipped (tailscaled)
  forces nothing, so it stays in the pass that installed it rather than
  splitting one concern across two.
- Every apt package lives in `.chezmoidata/packages.yaml`, in one list, so
  one pass makes one apt transaction. Later passes configure what it
  installed rather than installing their own.
- pre-commit shellchecks `.sh.tmpl` files unrendered, so a `{{ … }}`
  expression must sit inside quotes or a comment. That is why the package
  lists arrive via `read -ra <<<'{{ … }}'` rather than an array literal.
- Tool versions live in `script/install/*` (one script per tool, each
  pinning its own `*_VERSION`) and are reused by both bootstrap and CI.
  Bump in one place. Zellij *plugins*
  (`zellaude`, `zjstatus`) are pinned separately as alias tags in
  `dot_config/zellij/config.kdl`.
- Every `*_VERSION` pin carries a `# renovate: datasource=… depName=…`
  line directly above it (order: datasource, depName, packageName,
  versioning, extractVersion, registryUrl). `registryUrl` is what lets a
  pin point at a forge other than the datasource's default — Codeberg,
  gitlab.freedesktop.org. One generic manager in `renovate.json`
  reads them all — a new pinned tool needs no Renovate config change.
  An unannotated pin is invisible to Renovate rather than an error, so
  `script/checks/renovate-pins` (a pre-commit hook) fails the build on
  one.
- `gh` extensions install in script 05 alongside other bespoke
  installers, not script 02 — they're managed by `gh extension`, not
  the `script/install/` download-and-verify pattern. Version pin lives
  inline in the script (e.g. `GH_POI_VERSION`).
- `dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft`
  on `gh pr create`. PRs Claude opens go through this wrapper.

## Sensors

CI is authoritative. Run all sensors locally before claiming done:

```bash
just check                     # runs every sensor below, reports all failures
```

Each runs in its own CI workflow and can be invoked alone:

```bash
pre-commit run --all-files     # shellcheck, shfmt, check-json
bats --recursive dot_local dot_claude script  # unit tests
script/checks/zellij-config    # zellij KDL validation (needs zellij)
script/checks/chezmoi-apply    # apply round-trip (needs chezmoi + age)
```

## Two CLAUDE.md files

- This file: rules for AI editing the chezmoi *source*.
- `dot_claude/CLAUDE.md` → deploys to `~/.claude/CLAUDE.md`. Edits there
  change Claude's host-wide behaviour on next `chezmoi apply`.
