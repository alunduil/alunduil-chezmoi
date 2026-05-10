#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  POI="$REPO_ROOT/dot_local/bin/executable_git-worktree-poi"

  TMPROOT="$(mktemp -d)"
  export HOME="$TMPROOT/home"
  export XDG_DATA_HOME="$TMPROOT/xdg-data"
  mkdir -p "$HOME" "$XDG_DATA_HOME/git-worktrees"
}

teardown() {
  rm -rf "$TMPROOT"
}

# --- is_in_use: boundary semantics ---

@test "is_in_use: exact match succeeds" {
  run bash -c 'source "$1"; IN_USE_CWDS=("$2"); is_in_use "$2"' \
    _ "$POI" /foo/bar
  [ "$status" -eq 0 ]
}

@test "is_in_use: nested cwd succeeds" {
  run bash -c 'source "$1"; IN_USE_CWDS=("$3"); is_in_use "$2"' \
    _ "$POI" /foo/bar /foo/bar/sub/dir
  [ "$status" -eq 0 ]
}

@test "is_in_use: prefix without path boundary fails" {
  run bash -c 'source "$1"; IN_USE_CWDS=("$3"); is_in_use "$2"' \
    _ "$POI" /foo/bar /foo/bar2
  [ "$status" -eq 1 ]
}

@test "is_in_use: unrelated cwd fails" {
  run bash -c 'source "$1"; IN_USE_CWDS=("$3"); is_in_use "$2"' \
    _ "$POI" /foo/bar /elsewhere
  [ "$status" -eq 1 ]
}

@test "is_in_use: empty IN_USE_CWDS fails" {
  run bash -c 'source "$1"; IN_USE_CWDS=(); is_in_use "$2"' \
    _ "$POI" /foo/bar
  [ "$status" -eq 1 ]
}

# --- classify: in-use override ---

# Build a worktree under $WORKTREE_ROOT with upstream tracking, plus a `gh`
# stub reporting the requested PR state. Sets $WT and prepends the stub to
# PATH in the caller's scope (no subshell).
_mkworktree() {
  local pr_state=$1
  local wtroot="$XDG_DATA_HOME/git-worktrees/me/repo"
  local canonical="$HOME/me/repo"
  local bare="$TMPROOT/remote.git"

  mkdir -p "$wtroot" "$(dirname "$canonical")"
  git init --quiet --bare --initial-branch=main "$bare"
  git init --quiet --initial-branch=main "$canonical"
  git -C "$canonical" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init
  git -C "$canonical" remote add origin "$bare"
  git -C "$canonical" push --quiet -u origin main
  git -C "$canonical" worktree add -B feature "$wtroot/feature" >/dev/null 2>&1
  git -C "$wtroot/feature" push --quiet -u origin feature

  local stub_dir="$TMPROOT/stubs"
  mkdir -p "$stub_dir"
  cat >"$stub_dir/gh" <<STUB
#!/usr/bin/env bash
# Stub: report '$pr_state' as TSV for any 'pr list --head' query.
printf '%s\t99\n' '$pr_state'
STUB
  chmod +x "$stub_dir/gh"

  WT="$wtroot/feature"
  PATH="$stub_dir:$PATH"
}

@test "classify: idle worktree with merged PR is removed" {
  _mkworktree MERGED
  run bash -c 'source "$1"; IN_USE_CWDS=(); classify "$2"' \
    _ "$POI" "$WT"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == remove$'\t'* ]]
  [[ "$output" == *"PR #99 merged"* ]]
}

@test "classify: in-use worktree with merged PR is kept" {
  _mkworktree MERGED
  run bash -c 'source "$1"; IN_USE_CWDS=("$3"); classify "$2"' \
    _ "$POI" "$WT" "$WT/nested/subdir"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == keep$'\t'* ]]
  [[ "$output" == *"in-use"* ]]
  [[ "$output" == *"PR #99 merged"* ]]
}
