#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
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
  export PR_CACHE_DIR="$TMPROOT/pr_cache"
  mkdir -p "$PR_CACHE_DIR"
  unset FZF_OUTPUT ZELLIJ_TAB_NAMES GH_CLONE_SRC GH_REPO_LIST PETNAME
  # Drop any GH_PR_VIEW_* leakage from prior tests.
  while IFS= read -r var; do unset "$var"; done < <(compgen -e | grep '^GH_PR_VIEW_' || true)
}

# Seed a worktree under $WORKTREE_ROOT/<org>/<repo>/<petname> so
# `print_worktrees` walks find it the same way the real picker does.
mkworktree() {
  local org="$1" repo="$2" petname="$3"
  local dir="$XDG_DATA_HOME/git-worktrees/$org/$repo/$petname"
  mkdir -p "$dir"
  : >"$dir/.git"
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
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'me\tzfs-replicate\t%s' "$HOME/me/zfs-replicate")" ]
}

@test "collect_locals: HTTPS origin parses to org/repo" {
  mklocal "$HOME/grafana/k6" "https://github.com/grafana/k6.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'grafana\tk6\t%s' "$HOME/grafana/k6")" ]
}

@test "collect_locals: token-auth HTTPS origin parses to org/repo" {
  mklocal "$HOME/owner/repo" "https://x-access-token:abc123@github.com/owner/repo.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'owner\trepo\t%s' "$HOME/owner/repo")" ]
}

@test "collect_locals: non-github origin is dropped" {
  mklocal "$HOME/elsewhere/repo" "git@gitlab.com:elsewhere/repo.git"
  run bash -c 'source "$1"; collect_locals' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- fmt_repo / fmt_tab: org elision ---

@test "fmt_repo: elides org when it matches \$ME" {
  run bash -c 'source "$1"; ME=me fmt_repo me hello' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "fmt_repo: keeps org/repo when org differs from \$ME" {
  run bash -c 'source "$1"; ME=me fmt_repo grafana k6' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "grafana/k6" ]
}

@test "fmt_tab: elides own org and appends petname" {
  run bash -c 'source "$1"; ME=me fmt_tab me hello kind-newt' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "hello (kind-newt)" ]
}

@test "fmt_tab: keeps other-org prefix and appends petname" {
  run bash -c 'source "$1"; ME=me fmt_tab grafana k6 kind-newt' _ "$PICKER"
  [ "$status" -eq 0 ]
  [ "$output" = "grafana/k6 (kind-newt)" ]
}

# --- print_worktrees: dim when a tab is already open ---

@test "print_worktrees: open tab emits dimmed focus row" {
  mkworktree me hello kind-newt
  export ZELLIJ_TAB_NAMES=$'hello (kind-newt)\n'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '\033[2mworktree:hello (kind-newt)\033[0m\tfocus\thello (kind-newt)')" ]
}

@test "print_worktrees: closed tab emits undimmed spawn row" {
  mkworktree me hello kind-newt
  export ZELLIJ_TAB_NAMES=""
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_worktrees' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  local petdir="$XDG_DATA_HOME/git-worktrees/me/hello/kind-newt"
  [ "$output" = "$(printf 'worktree:hello (kind-newt)\tspawn\t%s\thello (kind-newt)' "$petdir")" ]
}

# --- TSV dispatch (end-to-end) ---

@test "dispatch focus: zellij go-to-tab-name fires with selected tab" {
  export FZF_OUTPUT=$'\033[2mworktree:hello (kind-newt)\033[0m\tfocus\thello (kind-newt)'
  run bash "$PICKER"
  [ "$status" -eq 0 ]
  grep -Fxq "action go-to-tab-name hello (kind-newt)" "$ZELLIJ_RECORDER"
}

@test "dispatch spawn: zellij new-tab + rename-tab fire with petdir and tab name" {
  local petdir="$XDG_DATA_HOME/git-worktrees/me/hello/kind-newt"
  export FZF_OUTPUT=$'worktree:hello (kind-newt)\tspawn\t'"$petdir"$'\thello (kind-newt)'
  run bash "$PICKER"
  [ "$status" -eq 0 ]
  grep -Fxq "action new-tab --layout pair --cwd $petdir" "$ZELLIJ_RECORDER"
  grep -Fxq "action rename-tab hello (kind-newt)" "$ZELLIJ_RECORDER"
}

@test "dispatch spawn-fresh: reuses canonical hint, creates worktree, spawns tab" {
  mkcanonical "$HOME/hello" hello >/dev/null
  export PETNAME=fresh-petname
  export FZF_OUTPUT=$'local:hello\tspawn-fresh\tme\thello\t'"$HOME/hello"
  run bash "$PICKER"
  [ "$status" -eq 0 ]

  local wt="$XDG_DATA_HOME/git-worktrees/me/hello/fresh-petname"
  [ -d "$wt" ]
  [ "$(git -C "$wt" rev-parse --abbrev-ref HEAD)" = "me/worktree/fresh-petname" ]
  grep -Fxq "action new-tab --layout pair --cwd $wt" "$ZELLIJ_RECORDER"
  grep -Fxq "action rename-tab hello (fresh-petname)" "$ZELLIJ_RECORDER"
}

# --- print_pr_rows: pr:<N> resolution ---

@test "print_pr_rows: matching worktree emits spawn row" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_VIEW_123=$'me\thello\tfeature/x'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  local petdir="$XDG_DATA_HOME/git-worktrees/me/hello/kind-newt"
  [ "$output" = "$(printf 'pr:123 → worktree:hello (kind-newt)\tspawn\t%s\thello (kind-newt)' "$petdir")" ]
}

@test "print_pr_rows: matching worktree with open tab emits focus row" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_VIEW_123=$'me\thello\tfeature/x'
  export ZELLIJ_TAB_NAMES=$'hello (kind-newt)\n'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'pr:123 → \033[2mworktree:hello (kind-newt)\033[0m\tfocus\thello (kind-newt)')" ]
}

@test "print_pr_rows: no matching worktree emits noop hint with head ref" {
  mkpr_worktree me hello kind-newt feature/unrelated
  export GH_PR_VIEW_123=$'me\thello\tfeature/missing'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [[ "$output" == *"noop"* ]]
  [[ "$output" == *"no matching worktree"* ]]
  [[ "$output" == *"feature/missing"* ]]
}

@test "print_pr_rows: ignores same-branch worktree in a different repo" {
  # Branch name collision across repos: only the one under the PR's base repo
  # should match. Without the scope guard this test would false-positive.
  mkpr_worktree other hello kind-newt feature/x
  export GH_PR_VIEW_123=$'me\thello\tfeature/x'
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [[ "$output" == *"noop"* ]]
  [[ "$output" == *"no matching worktree"* ]]
}

@test "print_pr_rows: unknown PR emits noop error row" {
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 999' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [[ "$output" == *"noop"* ]]
  [[ "$output" == *"no such PR"* ]]
}

@test "print_pr_rows: caches resolution to avoid repeated gh calls" {
  mkpr_worktree me hello kind-newt feature/x
  export GH_PR_VIEW_123=$'me\thello\tfeature/x'
  # First call populates the cache.
  bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123 >/dev/null' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  # Drop the fixture so a re-fetch would fail with "no such PR".
  unset GH_PR_VIEW_123
  run bash -c 'source "$1"; ME=me WORKTREE_ROOT="$2" print_pr_rows 123' \
    _ "$PICKER" "$XDG_DATA_HOME/git-worktrees"
  [ "$status" -eq 0 ]
  [[ "$output" == *"worktree:hello (kind-newt)"* ]]
}

@test "dispatch noop: no zellij action fires beyond the upfront query" {
  export FZF_OUTPUT=$'pr:123 → \033[2mno such PR\033[0m\tnoop'
  run bash "$PICKER"
  [ "$status" -eq 0 ]
  # query-tab-names is fired upfront by print_worktrees; nothing else should run.
  ! grep -v "action query-tab-names" "$ZELLIJ_RECORDER" | grep -q .
}

@test "dispatch clone-and-spawn: clones canonical, creates worktree, spawns tab" {
  GH_CLONE_SRC="$(mkcanonical "$TMPROOT/remote-only" hello)"
  rm -rf "$TMPROOT/remote-only"  # only the bare remains; canonical must be cloned by the picker
  export GH_CLONE_SRC
  export PETNAME=cloned-petname
  export FZF_OUTPUT=$'remote:hello\tclone-and-spawn\tme\thello'
  run bash "$PICKER"
  [ "$status" -eq 0 ]

  [ -d "$HOME/hello/.git" ]
  local wt="$XDG_DATA_HOME/git-worktrees/me/hello/cloned-petname"
  [ -d "$wt" ]
  grep -Fxq "action new-tab --layout pair --cwd $wt" "$ZELLIJ_RECORDER"
  grep -Fxq "action rename-tab hello (cloned-petname)" "$ZELLIJ_RECORDER"
}
