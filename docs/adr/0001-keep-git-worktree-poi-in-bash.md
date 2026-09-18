# 1. Keep git-worktree-poi in bash, port its interface in place

## Status

Superseded by [0007](0007-port-git-worktree-poi-to-rust.md).

## Context

`dot_local/bin/executable_git-worktree-poi` started as a small
classifier (#104) and has accreted: gh-poi-style report (#134),
namespaced branches (#110), canonical-path resolution (#138), in-use
guard (#140), empty-worktree safe path (#141). GraphQL batching (#147)
is open.

Two pressures motivate the question (#150):

- **UX.** `gh poi`'s output—color, ✔/✕ progress, bold sections,
  dimmed metadata, single line per branch—is denser and easier to
  scan than the current two-line `└─` tree, especially with many
  worktrees in flight.
- **Complexity drift.** 234 lines of bash with more state, more
  parsing, more places shell quoting and `mapfile` plumbing get in the
  way. Each addition has been tractable. The trajectory is consistent.

The natural reference point is `gh-poi` itself: Go, `fatih/color`,
distributed via `gh extension install`. The host already runs it
(pinned in `.chezmoiscripts/run_before_05-install-standalone-tools.sh.tmpl`), so a
`gh-worktree-poi` rewrite would slot into the same install pass.

Three options stood open: a) stay bash and port the UX in place,
b) Go rewrite as `gh-worktree-poi`, c) Rust rewrite. Ecosystem fit
rules out option c—Go is the de facto language for `gh` extensions,
and a Rust binary buys little here.

The reversibility asymmetry between (a) and (b) is the dominant force.
Bash → rewrite is straightforward at any size. Rewrite → bash is rare
in practice. Picking the irreversible direction earlier than necessary
forfeits optionality. 234 lines sits below the threshold where bash
becomes a tax: `classify`/`gather`/`print_section` each do one bounded
job. The next pending feature (#147 GraphQL batching) is awkward in
bash but reachable with a `gh api graphql` heredoc and `jq`
distribution. The motivating UX pain (color, tighter rows, dimmed
metadata, progress markers) is reachable from `tput`/ANSI inside
`print_section` without touching the classifier.

## Decision

Keep `git-worktree-poi` in bash and port the `gh-poi`-style interface
in place. Defer the `gh-worktree-poi` Go rewrite (option b in #150)
rather than rejecting it.

Revisit when any trigger fires:

- A feature needs more than 100 lines of bash addition—for
  example, interactive selection, a real TUI, or anything beyond
  report-and-act.
- Test scenarios start straining the PATH-shim stub model in
  `dot_local/bin/git_worktree_poi.bats` past what `bats` handles cleanly.
- GraphQL batching (#147) or any successor classifier change ends up
  needing more `jq`/heredoc surgery than the equivalent Go rewrite
  would cost.

At any trigger, the reversibility argument no longer holds: the rewrite
is paying for itself, and porting 234 lines is cheaper now than porting
the post-trigger surface.

## Consequences

- chezmoi-managed deployment via `dot_local/bin/` stays in place, and
  existing `bats` coverage and the small dependency surface carry over.
- UX work (color, single-line rows, dimmed metadata, progress markers)
  goes ahead in `print_section` plus terminal-capability helpers. No new
  repo, no publishing flow, no Go in CI.
- #147 lands as bash. Future classifier additions continue paying the
  shell-quoting and `mapfile` tax.
- ANSI/`tput` in bash is awkward compared to `fatih/color`, and
  struct-based mocks remain unavailable. Complexity drift continues,
  bounded only by the re-evaluation triggers listed earlier.
- The triggers are the load-bearing part: without them this becomes
  "stay bash forever," which isn't the decision.
