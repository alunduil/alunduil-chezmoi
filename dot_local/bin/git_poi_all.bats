#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  POI_ALL="$REPO_ROOT/dot_local/bin/executable_git-poi-all"

  TMPROOT="$(mktemp -d)"
  export HOME="$TMPROOT/home"
  mkdir -p "$HOME"

  # gh stub: log "<cwd>\t<args>" per call so tests can assert which repos were
  # swept with which flags; exit non-zero when the cwd's basename is listed in
  # $GH_POI_FAIL, letting a test force one repo to error.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
printf '%s\t%s\n' "$PWD" "$*" >>"$GH_POI_LOG"
for f in $GH_POI_FAIL; do
  [[ "${PWD##*/}" == "$f" ]] && exit 1
done
exit 0
STUB
  chmod +x "$STUB_DIR/gh"
  export GH_POI_LOG="$TMPROOT/gh.log"
  : >"$GH_POI_LOG"
  export GH_POI_FAIL=""
  export PATH="$STUB_DIR:/usr/bin:/bin"
}

teardown() { rm -rf "$TMPROOT"; }

# Real checkout with the given origin, so discover_repos runs against actual
# `git remote get-url` plumbing rather than a parser harness. Commits once so
# the dir can host worktrees.
mkclone() {
  local dir="$1" url="$2"
  git init --quiet "$dir"
  git -C "$dir" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init
  git -C "$dir" remote add origin "$url"
}

# --- discover_repos: which clones the sweep visits ---

@test "discover_repos: HTTPS clone emits slug and dir" {
  mkclone "$HOME/me/repo" "https://github.com/me/repo.git"
  run bash -c 'source "$1"; discover_repos' _ "$POI_ALL"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'me/repo\t%s' "$HOME/me/repo")" ]
}

@test "discover_repos: SSH clone emits slug and dir" {
  mkclone "$HOME/grafana/k6" "git@github.com:grafana/k6.git"
  run bash -c 'source "$1"; discover_repos' _ "$POI_ALL"
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'grafana/k6\t%s' "$HOME/grafana/k6")" ]
}

@test "discover_repos: non-github clone is dropped" {
  mkclone "$HOME/elsewhere/repo" "git@gitlab.com:elsewhere/repo.git"
  run bash -c 'source "$1"; discover_repos' _ "$POI_ALL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "discover_repos: worktree of a clone is not visited separately" {
  mkclone "$HOME/me/repo" "https://github.com/me/repo.git"
  git -C "$HOME/me/repo" worktree add --quiet "$HOME/me/repo-wt" -b feature
  run bash -c 'source "$1"; discover_repos' _ "$POI_ALL"
  [ "$status" -eq 0 ]
  # Only the canonical clone, never the worktree (its .git is a file).
  [ "$output" = "$(printf 'me/repo\t%s' "$HOME/me/repo")" ]
}

@test "discover_repos: clone under a hidden dir is pruned" {
  mkclone "$HOME/.cache/repo" "https://github.com/me/repo.git"
  run bash -c 'source "$1"; discover_repos' _ "$POI_ALL"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- main flow ---

@test "runs gh poi once per repo, forwarding args" {
  mkclone "$HOME/me/alpha" "https://github.com/me/alpha.git"
  mkclone "$HOME/me/beta" "https://github.com/me/beta.git"
  run bash "$POI_ALL" --dry-run
  [ "$status" -eq 0 ]
  [ "$(grep -c "	poi --dry-run$" "$GH_POI_LOG")" -eq 2 ]
  grep -qx "$HOME/me/alpha	poi --dry-run" "$GH_POI_LOG"
  grep -qx "$HOME/me/beta	poi --dry-run" "$GH_POI_LOG"
}

@test "a failing repo is reported and non-fatal" {
  mkclone "$HOME/me/alpha" "https://github.com/me/alpha.git"
  mkclone "$HOME/me/beta" "https://github.com/me/beta.git"
  export GH_POI_FAIL="beta"
  run bash "$POI_ALL"
  [ "$status" -eq 1 ]
  # Both repos were still attempted — the failure didn't abort the sweep.
  [ "$(wc -l <"$GH_POI_LOG")" -eq 2 ]
  [[ "$output" == *"failed"* ]]
  [[ "$output" == *"me/beta"* ]]
}

@test "no clones found exits cleanly" {
  run bash "$POI_ALL"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no GitHub clones found"* ]]
  [ ! -s "$GH_POI_LOG" ]
}

@test "-h prints usage and exits 0" {
  run bash "$POI_ALL" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: git poi-all"* ]]
}
