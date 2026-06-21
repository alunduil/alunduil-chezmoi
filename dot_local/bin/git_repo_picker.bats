#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
bats_load_library bats-support
bats_load_library bats-assert

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PICKER="$REPO_ROOT/dot_local/bin/executable_git-repo-picker"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures/git_repo_picker"

  TMPROOT="$(mktemp -d)"
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  for stub in fzf zellij gh golang-petname; do
    install -m 0755 "$FIXTURES/stubs/$stub" "$STUB_DIR/$stub"
  done

  export HOME="$TMPROOT/home"
  export XDG_DATA_HOME="$TMPROOT/xdg-data"
  mkdir -p "$HOME" "$XDG_DATA_HOME"

  export PATH="$STUB_DIR:/usr/bin:/bin"
  export ZELLIJ_RECORDER="$TMPROOT/zellij.log"
  : >"$ZELLIJ_RECORDER"
  export GH_USER=me
  # Unset ZELLIJ so the --all-worktrees pause-on-error trap takes its
  # outside-zellij path regardless of where bats itself runs.
  unset FZF_OUTPUT ZELLIJ_TAB_NAMES GH_CLONE_SRC GH_REPO_LIST PETNAME ZELLIJ
  # Drop any GH_PR_LIST_* leakage from prior tests.
  while IFS= read -r var; do unset "$var"; done < <(compgen -e | grep '^GH_PR_LIST_' || true)
}

# Seed a worktree under $WORKTREE_ROOT/<org>/<repo>/<petname> so
# `print_worktrees` walks find it the same way the real picker does.
mkworktree() {
  local org="$1" repo="$2" petname="$3"
  local dir="$XDG_DATA_HOME/git-worktrees/$org/$repo/$petname"
  mkdir -p "$dir"
  : >"$dir/.git"
}

# Render a worktree's pair tab name exactly as the picker would, by sourcing its
# fmt_tab in a subshell (the picker runs under `set -e`, so it can't be sourced
# into the test shell). The org-elision format then lives only in the picker.
tab_name() {
  ME="$GH_USER" bash -c 'source "$1"; fmt_tab "$2" "$3" "$4"' _ "$PICKER" "$@"
}

# The on-disk worktree path print_worktrees walks, built the one way the rest of
# the suite references it. Mirrors mkworktree's layout.
petdir() {
  printf '%s' "$XDG_DATA_HOME/git-worktrees/$1/$2/$3"
}

# Assert the picker spawned this worktree's pair tab: a single new-tab at its
# petdir, named via --name in the same call, reached $ZELLIJ_RECORDER.
assert_spawn() {
  grep -Fxq "action new-tab --layout pair --cwd $(petdir "$@") --name $(tab_name "$@")" "$ZELLIJ_RECORDER"
}

# Assert the picker did not spawn a pair tab for this worktree.
refute_spawn() {
  ! grep -Fxq "action new-tab --layout pair --cwd $(petdir "$@")" "$ZELLIJ_RECORDER"
}

# Assert the picker focused this worktree's existing tab via go-to-tab-name.
assert_focus() {
  grep -Fxq "action go-to-tab-name $(tab_name "$@")" "$ZELLIJ_RECORDER"
}

# Mark a worktree's pair tab as already open, the way print_worktrees sees it:
# append the tab name it would render to ZELLIJ_TAB_NAMES. Pairs with mkworktree.
mark_tab_open() {
  ZELLIJ_TAB_NAMES+="$(tab_name "$@")"$'\n'
  export ZELLIJ_TAB_NAMES
}

teardown() {
  rm -rf "$TMPROOT"
}

# Build a real git checkout with the given origin URL. URL parsing in
# collect_locals runs against `git remote get-url`, so the fixtures exercise
# the real plumbing rather than a parser harness.
mklocal() {
  local dir="$1" url="$2"
  git init --quiet "$dir"
  git -C "$dir" remote add origin "$url"
}

# Build a worktree under $WORKTREE_ROOT on a named branch, backed by a real
# canonical clone — so `git -C <wt> branch --show-current` returns the branch
# print_pr_rows compares against the PR's head ref.
mkpr_worktree() {
  local org="$1" repo="$2" petname="$3" branch="$4"
  local canonical="$TMPROOT/canonicals/$repo"
  mkcanonical "$canonical" "$repo" >/dev/null
  local petdir="$XDG_DATA_HOME/git-worktrees/$org/$repo/$petname"
  mkdir -p "$(dirname "$petdir")"
  git -C "$canonical" worktree add --quiet "$petdir" -b "$branch" >/dev/null
}

# Build a bare "remote" plus a canonical clone with origin/HEAD set up, so
# `make_worktree`'s symbolic-ref + pull + worktree-add chain succeeds.
mkcanonical() {
  local canonical="$1" name="$2"
  local bare="$TMPROOT/remotes/$name.git"
  local seed="$TMPROOT/seeds/$name"
  mkdir -p "$bare" "$seed"
  git init --quiet --bare --initial-branch=main "$bare"
  git init --quiet --initial-branch=main "$seed"
  git -C "$seed" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init
  git -C "$seed" push --quiet "$bare" main
  git clone --quiet "$bare" "$canonical"
  printf '%s' "$bare"
}

# --- collect_locals: origin URL parsing ---

@test "collect_locals: SSH origin parses to org/repo" {
  mklocal "$HOME/me/zfs-replicate" "git@github.com:me/zfs-replicate.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  assert_success
  assert_output "$(printf 'me\tzfs-replicate\t%s' "$HOME/me/zfs-replicate")"
}

@test "collect_locals: HTTPS origin parses to org/repo" {
  mklocal "$HOME/grafana/k6" "https://github.com/grafana/k6.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  assert_success
  assert_output "$(printf 'grafana\tk6\t%s' "$HOME/grafana/k6")"
}

@test "collect_locals: token-auth HTTPS origin parses to org/repo" {
  mklocal "$HOME/owner/repo" "https://x-access-token:abc123@github.com/owner/repo.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  assert_success
  assert_output "$(printf 'owner\trepo\t%s' "$HOME/owner/repo")"
}

@test "collect_locals: non-github origin is dropped" {
  mklocal "$HOME/elsewhere/repo" "git@gitlab.com:elsewhere/repo.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  assert_success
  refute_output
}

# --- fmt_repo / fmt_tab: org elision ---

@test "fmt_repo: elides org when it matches \$ME" {
  run bash -c 'source "$1"; ME=me fmt_repo me hello' _ "$PICKER"
  assert_success
  assert_output "hello"
}

@test "fmt_repo: keeps org/repo when org differs from \$ME" {
  run bash -c 'source "$1"; ME=me fmt_repo grafana k6' _ "$PICKER"
  assert_success
  assert_output "grafana/k6"
}

@test "fmt_tab: elides own org and appends petname" {
  run bash -c 'source "$1"; ME=me fmt_tab me hello kind-newt' _ "$PICKER"
  assert_success
  assert_output "hello (kind-newt)"
}

@test "fmt_tab: keeps other-org prefix and appends petname" {
  run bash -c 'source "$1"; ME=me fmt_tab grafana k6 kind-newt' _ "$PICKER"
  assert_success
  assert_output "grafana/k6 (kind-newt)"
}

# --- print_worktrees: dim when a tab is already open ---

@test "print_worktrees: open tab emits dimmed focus row" {
  mkworktree me hello kind-newt
  mark_tab_open me hello kind-newt
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  assert_output "$(printf '\033[2mworktree:hello (kind-newt)\033[0m\tfocus\thello (kind-newt)')"
}

@test "print_worktrees: closed tab emits undimmed spawn row" {
  mkworktree me hello kind-newt
  export ZELLIJ_TAB_NAMES=""
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  assert_output "$(printf 'worktree:hello (kind-newt)\tspawn\t%s\thello (kind-newt)' "$(petdir me hello kind-newt)")"
}

# --- TSV dispatch (end-to-end) ---

@test "dispatch focus: zellij go-to-tab-name fires with selected tab" {
  export FZF_OUTPUT=$'\033[2mworktree:hello (kind-newt)\033[0m\tfocus\thello (kind-newt)'
  run bash "$PICKER"
  assert_success
  assert_focus me hello kind-newt
}

@test "dispatch spawn: zellij new-tab fires with petdir and tab name" {
  export FZF_OUTPUT=$'worktree:hello (kind-newt)\tspawn\t'"$(petdir me hello kind-newt)"$'\thello (kind-newt)'
  run bash "$PICKER"
  assert_success
  assert_spawn me hello kind-newt
}

@test "dispatch spawn-fresh: reuses canonical hint, creates worktree, spawns tab" {
  mkcanonical "$HOME/hello" hello >/dev/null
  export PETNAME=fresh-petname
  export FZF_OUTPUT=$'local:hello\tspawn-fresh\tme\thello\t'"$HOME/hello"
  run bash "$PICKER"
  assert_success

  local wt; wt="$(petdir me hello fresh-petname)"
  [ -d "$wt" ]
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = "me/worktree/fresh-petname" ]
  assert_spawn me hello fresh-petname
}

@test "dispatch spawn-fresh: recovers from a stale origin/HEAD" {
  mkcanonical "$HOME/hello" hello >/dev/null
  # Simulate a default-branch rename upstream (develop -> main): origin/HEAD
  # dangles at a tracking ref that no longer exists. Pre-fix this aborts
  # worktree add with "not a valid object name: origin/develop".
  git -C "$HOME/hello" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  export PETNAME=stale-petname
  export FZF_OUTPUT=$'local:hello\tspawn-fresh\tme\thello\t'"$HOME/hello"
  run bash "$PICKER"
  assert_success

  local wt; wt="$(petdir me hello stale-petname)"
  [ -d "$wt" ]
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = "me/worktree/stale-petname" ]
  # Branched off the remote's real default (main), not the dangling develop.
  [ "$(git -C "$wt" rev-parse HEAD)" = "$(git -C "$HOME/hello" rev-parse origin/main)" ]
  assert_spawn me hello stale-petname
}

# --- print_worktrees_with_prs: pr:<N>-tagged worktree rows ---

@test "print_worktrees_with_prs: tags worktree with the branch's PR number" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_LIST_me_hello=$'feature/x\t174\nother-branch\t99'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees_with_prs' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  assert_output "$(printf 'worktree:hello (kind-newt) pr:174\tspawn\t%s\thello (kind-newt)' "$(petdir me hello kind-newt)")"
}

@test "print_worktrees_with_prs: open tab dims the enriched row and dispatches focus" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_LIST_me_hello=$'feature/x\t174'
  mark_tab_open me hello kind-newt
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees_with_prs' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  assert_output "$(printf '\033[2mworktree:hello (kind-newt) pr:174\033[0m\tfocus\thello (kind-newt)')"
}

@test "print_worktrees_with_prs: omits worktrees with no PR for their branch" {
  mkpr_worktree me hello kind-newt feature/no-pr
  export GH_PR_LIST_me_hello=$'feature/x\t174'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees_with_prs' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  refute_output
}

@test "print_worktrees_with_prs: surfaces PRs across distinct repos" {
  mkpr_worktree me hello kind-newt feature/x
  mkpr_worktree grafana k6 happy-mole feature/y
  export GH_PR_LIST_me_hello=$'feature/x\t174'
  export GH_PR_LIST_grafana_k6=$'feature/y\t88'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees_with_prs' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  assert_success
  assert_output --partial "worktree:hello (kind-newt) pr:174"
  assert_output --partial "worktree:grafana/k6 (happy-mole) pr:88"
}

# --- --rows handler: pr:* gate and cache ---

@test "--rows pr:174: lazily populates WORKTREE_PR_FILE and emits enriched rows" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_LIST_me_hello=$'feature/x\t174'
  export WORKTREE_PR_FILE STATIC_FILE REMOTES_FILE
  WORKTREE_PR_FILE="$TMPROOT/wt_pr"  # does not exist yet
  STATIC_FILE="$TMPROOT/static.tsv"; : >"$STATIC_FILE"
  REMOTES_FILE="$TMPROOT/remotes.tsv"; : >"$REMOTES_FILE"
  ME=me run bash "$PICKER" --rows "pr:174"
  assert_success
  assert_output --partial "worktree:hello (kind-newt) pr:174"
  [ -e "$WORKTREE_PR_FILE" ]  # gate file now exists; future reloads skip the fill
}

@test "--rows non-pr query: serves STATIC_FILE without touching WORKTREE_PR_FILE" {
  export WORKTREE_PR_FILE STATIC_FILE REMOTES_FILE
  WORKTREE_PR_FILE="$TMPROOT/wt_pr"
  STATIC_FILE="$TMPROOT/static.tsv"; printf 'worktree:foo\tspawn\t/x\tfoo\n' >"$STATIC_FILE"
  REMOTES_FILE="$TMPROOT/remotes.tsv"; : >"$REMOTES_FILE"
  ME=me run bash "$PICKER" --rows "f"
  assert_success
  assert_output "worktree:foo	spawn	/x	foo"
  [ ! -e "$WORKTREE_PR_FILE" ]
}

@test "dispatch clone-and-spawn: clones canonical, creates worktree, spawns tab" {
  GH_CLONE_SRC="$(mkcanonical "$TMPROOT/remote-only" hello)"
  rm -rf "$TMPROOT/remote-only"  # only the bare remains; canonical must be cloned by the picker
  export GH_CLONE_SRC
  export PETNAME=cloned-petname
  export FZF_OUTPUT=$'remote:hello\tclone-and-spawn\tme\thello'
  run bash "$PICKER"
  assert_success

  [ -d "$HOME/hello/.git" ]
  [ -d "$(petdir me hello cloned-petname)" ]
  assert_spawn me hello cloned-petname
}

# --- --all-worktrees: non-interactive fan-out ---

@test "--all-worktrees: spawns a pair tab for every worktree without an open tab" {
  mkworktree me hello kind-newt
  mkworktree grafana k6 happy-mole
  export ZELLIJ_TAB_NAMES=""
  run bash "$PICKER" --all-worktrees
  assert_success
  assert_spawn me hello kind-newt
  assert_spawn grafana k6 happy-mole
}

@test "--all-worktrees: skips worktrees that already have an open tab (idempotent)" {
  mkworktree me hello kind-newt
  mkworktree me world busy-gnat
  mark_tab_open me hello kind-newt
  run bash "$PICKER" --all-worktrees
  assert_success
  refute_spawn me hello kind-newt   # open tab → no respawn
  assert_spawn me world busy-gnat   # closed tab → spawned
}

@test "--all-worktrees: failure outside zellij exits nonzero without hanging" {
  # STUB_DIR lacks git, so the dependency check dies. ZELLIJ is unset, so the
  # pause-on-error trap must stay quiet rather than block on /dev/tty. bash is
  # absolute so only the picker's own dependency check sees the stripped PATH.
  local bash_bin; bash_bin="$(command -v bash)"
  run timeout 10 env PATH="$STUB_DIR" "$bash_bin" "$PICKER" --all-worktrees
  assert_failure 1    # die's exit, not 124 (timeout → the trap hung)
}
