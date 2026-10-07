# 9. Converge bootstrap passes on every apply

## Status

Accepted

## Context

Bootstrap runs as scripts under `.chezmoiscripts/`, and chezmoi decides
when each one runs from its filename prefix:

- `run_once_` runs once per distinct script content.
- `run_onchange_` runs whenever the script's content changes.
- `run_` runs on every apply.

[chezmoi's package-install
guide](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/)
recommends `run_onchange_` keyed on a package list. The passes here
started that way, under `run_once_` and `run_onchange_`.

Both prefixes key off the script's own text, not the host. A package
removed by `apt autoremove`, a deleted binary, or a hand-edited file
under `/etc` leaves the script untouched, so the pass never fires again
and the drift stays. `rsync` sat in the package list and was still
missing from this host for that reason. The passes already checked host
state before acting. The trigger was the part that couldn't see drift.

Running every pass on every apply has two costs. A guard that reaches
the network or prompts for a password makes every apply slow or
interactive. A guard that reports "already done" when it isn't hides
the drift it exists to catch: `dpkg -s` exits 0 for a package in
`config-files` state, removed with its configuration files kept.

Two passes have content as their real trigger. `_07` registers Claude
Model Context Protocol (MCP) servers, and its `claude mcp list` guard
costs a network round-trip per server. Nothing removes a registration
behind the user's back, so re-checking buys nothing. The
`register-*-mcp` passes carry rotating secrets and must re-register
when a secret changes, whatever state the host is in.

## Decision

Bootstrap passes are plain `run_` and converge. Each runs on every apply,
checks host state first, and acts only on a difference. A converged
host makes no `sudo` call.

Guards stay local and cheap: `dpkg-query` status compared to
`installed`, a pinned `--version`, `cmp` before `sudo install`. A pass
whose only workable guard costs a network round-trip or a password
prompt uses `run_onchange_` instead, keyed on the content that should
re-fire it. `_07` and the `register-*-mcp` passes are the current cases.

No pass uses `run_once_`.

## Consequences

- Drift heals on the next apply: a removed package, a deleted binary, or
  a hand-edited `/etc` file comes back without a source change.
- Every apply runs every pass. On this host a converged apply takes
  about four seconds.
- A guard that lies is now the main failure mode. Neither a `run_once_`
  pass nor a `dpkg -s` guard fails an apply, so
  `script/checks/bootstrap-convergence` fails the build on either.
- A new pass has to converge. Its guard must be local, accurate, and
  free of `sudo` when nothing needs doing.
- Converging passes compare the real files rather than embedding an
  input hash, which only ever existed to re-fire a `run_onchange_` pass.
