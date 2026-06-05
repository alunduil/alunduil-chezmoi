# 2. Port git-worktree-poi to Rust

## Status

Accepted

Supersedes [0001](0001-keep-git-worktree-poi-in-bash.md).

## Context

ADR 0001 kept `git-worktree-poi` in bash and deferred the rewrite behind
explicit re-evaluation triggers. Two have since fired:

- **Size.** ADR 0001 cited the script at 234 lines as evidence it sat
  below the threshold where bash becomes a tax. `dot_local/bin/executable_git-worktree-poi`
  is now 633 lines—2.7×—past the ADR's own "more than 100 lines
  of bash addition" trigger.
- **GraphQL batching.** ADR 0001 named #147 (batched PR-state lookup) as
  a revisit trigger. It landed as bash in #154 via a `gh api graphql`
  heredoc plus `jq`—the "more jq/heredoc surgery than the equivalent
  rewrite would cost" trigger.

ADR 0001's reversibility argument was explicit that, at a trigger,
porting is cheaper then than after further accretion. This repo is past
that point.

ADR 0001 also picked Go, on the reasoning that Go is the de facto
language for `gh` extensions and `gh-poi` is the reference point. That
framing no longer holds: `git-worktree-poi` never became a `gh`
extension—it's a standalone binary in `dot_local/bin/`—and the
companion CLIs have since standardized on Rust (`git-repo-picker`,
alunduil-infrastructure#54; `zellij-git-status`, alunduil-infrastructure#26).
rustup is already bootstrapped in chezmoi. Rust aligns the toolchain
with the tools `git-worktree-poi` ships alongside.

## Decision

Port `git-worktree-poi` out of chezmoi-managed bash into a
standalone Rust binary repository, reversing ADR 0001's "keep bash"
decision and its Go language pick.

Project execution—repo bootstrap, milestones, CI/release, and the
chezmoi consumer swap (`script/install/` pin, bash removal, systemd
`ExecStart` swap, bats removal)—is carried in
alunduil-infrastructure#116, mirroring the `git-repo-picker` planning
artifact (alunduil-infrastructure#54). This ADR records only the
decision to reverse 0001 and the language; the milestone tracking lives
in the infrastructure issue.

## Consequences

- Toolchain aligns with `git-repo-picker` and `zellij-git-status`:
  shared release/CI patterns, `cargo test` instead of the
  PATH-shim `bats` model, struct-based mocks, a real color crate in
  place of `tput`/ANSI.
- The #154 batched PR-state lookup moves from a `gh api graphql` heredoc
  and `jq` into typed code (`octocrab` or a structured `gh` shell-out).
- Costs: a new repository, its publishing and release flow, and Rust in
  that repo's CI. chezmoi gains a `script/install/` pin and loses the
  bash bin plus its `bats` coverage (moved to the new repo).
- ADR 0001 is retained as the historical record of why bash was
  originally chosen and which triggers governed the reversal.
