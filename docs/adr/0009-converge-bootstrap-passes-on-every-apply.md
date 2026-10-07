# 9. Converge bootstrap passes on every apply

## Status

Accepted

## Context

chezmoi runs a `run_once_` or `run_onchange_` script when the script's
own content changes, and a `run_` script on every apply. [chezmoi's
package-install
guide](https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/)
recommends `run_onchange_` keyed on a package list.

A content trigger can't see the host. A package removed by
`apt autoremove`, a deleted binary, or a hand-edited file under `/etc`
leaves the script untouched, so the pass never fires again and the
drift stays.

Running every pass on every apply moves the weight onto guards. A guard
that reaches the network or prompts for a password makes every apply
slow or interactive. A guard that reports "already done" when it isn't
hides the drift it exists to catch: `dpkg -s` exits 0 for a package in
`config-files` state, removed with its configuration files kept.

Two kinds of pass have content as their real trigger.
`register-claude-mcp-servers` guards with `claude mcp list`, which costs
a network round-trip per server, and nothing removes a registration
behind the user's back. The `register-*-mcp` passes carry rotating
secrets and must re-register when a secret changes, whatever state the
host is in.

## Decision

Bootstrap passes are plain `run_` and converge. Each runs on every apply,
checks host state first, and acts only on a difference. A converged
host makes no `sudo` call.

Guards stay local and cheap: `dpkg-query` status compared to
`installed`, a pinned `--version`, `cmp` before `sudo install`. A pass
whose only workable guard costs a network round-trip or a password
prompt uses `run_onchange_`, keyed on the content that should re-fire
it.

No pass uses `run_once_`.

## Consequences

- Drift heals on the next apply: a removed package, a deleted binary, or
  a hand-edited `/etc` file comes back without a source change.
- Every apply runs every pass, so one slow guard slows every apply.
- A guard that lies raises no error. Neither a `run_once_` pass nor a
  `dpkg -s` guard fails an apply, so
  `script/checks/bootstrap-convergence` fails the build on either.
