# alunduil-chezmoi

This repo is the chezmoi source directory. Files deploy to `$HOME` via `chezmoi apply`;
names follow chezmoi rules (`dot_` → `.`, `executable_` → +x, `.tmpl` →
Go template, `.chezmoiscripts/run_*_before_NN-…` → ordered convergent bootstrap).
`docs/tutorials/bootstrap.md` has the bootstrap walkthrough; `docs/explanation/architecture.md` has the human-facing rationale; `docs/reference/bootstrap-reference.md` has the lookup tables.

Rules for any coding agent editing this chezmoi source. A tool that reads
`AGENTS.md` needs no file of its own. A tool that reads only its own path
gets a file there that imports or points at this one and holds only rules
false for every other agent; `CLAUDE.md` is that file for Claude Code. A
rule that holds for more than one tool goes here.

## Source vs. apply path

`chezmoi diff`/`apply` read the *applied* clone at
`~/.local/share/chezmoi`, not this working tree. Edits here don't take
effect on `apply` until committed and pulled into the apply clone. Use
`chezmoi diff --source-path .` to preview from this checkout.

## Invariants

- Bootstrap passes in `.chezmoiscripts/` converge on host state. Read
  `docs/reference/bootstrap-reference.md` before adding a pass, a tool,
  or a guard, or changing a pass's prefix, phase, or number.
- The shellcheck hook reads `.sh.tmpl` files unrendered, so a `{{ … }}`
  expression must sit inside quotes or a comment. That is why the package
  lists arrive via `read -ra <<<'{{ … }}'` rather than an array literal.
- Pinned tools live in `dot_config/mise/config.toml`. After editing it,
  run `just lock-tools` and commit `mise.lock` with the npm sidecars under
  `dot_config/mise/.mise/locks/`. chezmoi skips that dot-directory, so
  `symlink_dot_mise.tmpl` points `~/.config/mise/.mise` at it in the
  source tree.
- Write a version pinned inside a URL (the Zellij `plugins` block) out
  in full and leave it unannotated: Renovate bumps every copy of it.
- Every `*_VERSION` pin carries a `# renovate: datasource=… depName=…`
  line directly above it (order: `datasource`, `depName`, `packageName`,
  `versioning`, `extractVersion`). One generic manager in `renovate.json`
  reads them all — a new pinned tool needs no Renovate config change.
  An unannotated pin is invisible to Renovate rather than an error, so
  `script/checks/renovate-pins` (a prek hook) fails the build on
  one.
- The repo requires every action pinned to a full-length SHA,
  including the actions a third-party action calls. Renovate's digest
  pinning stops at our own `uses:` line. Before adopting or bumping a
  third-party action, read its `action.yml` at the new SHA and confirm
  every `uses:` under `runs.steps` is a full-length SHA.
- `dot_local/bin/executable_gh` shadows system `gh` to enforce `--draft`
  on `gh pr create`. PRs opened on this host go through this wrapper.
- A new root file that isn't a chezmoi target gets a `.chezmoiignore`
  entry, or `apply` deploys it into `$HOME`.

## Pull request descriptions

This repo squash-merges with `squash_merge_commit_message: PR_BODY`, so
the description lands in `git log` verbatim and the branch commits go
with the squash. Write it as a commit message: prose wrapped at 72
columns, no H1 repeating the title, no `##` section headings, no
checkbox lists. A trailer that has to persist goes in the description,
since the ones on branch commits are discarded.

## Sensors

CI is authoritative. Run all sensors locally before claiming done:

```bash
just check                     # runs every sensor below, reports all failures
```

Each runs in its own CI workflow and can be invoked alone:

```bash
prek run --all-files           # shellcheck, shfmt, ruff, mypy, check-json
bats --recursive dot_local dot_claude etc script  # shell unit tests
just check-python              # python unit tests (pytest via uv)
script/checks/zellij-config    # zellij KDL validation (needs zellij)
script/checks/theme-contrast   # theme colors meet WCAG AAA
script/checks/chezmoi-apply    # apply round-trip (needs chezmoi + age)
```

`script/checks/fresh-host` bootstraps a systemd container from scratch and
fails on anything a second apply changes. It installs the whole workstation,
so `just check` leaves it to CI.

## Deployed Claude Code config

`dot_claude/` is payload, not guidance for editing this repo.
`dot_claude/CLAUDE.md` deploys to `~/.claude/CLAUDE.md`, and edits there
change Claude Code's host-wide behaviour on the next `chezmoi apply`. Keep
its name: Claude Code loads only that path.
