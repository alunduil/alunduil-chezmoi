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

# Build a worktree under $WORKTREE_ROOT with upstream tracking. PR state is
# fed to classify() via PR_STATE_BY_WT in each test rather than a `gh` stub
# — classify() no longer calls `gh` itself; batch_fetch_pr_states does. Sets
# $WT in the caller's scope.
_mkworktree() {
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

  WT="$wtroot/feature"
}

@test "classify: idle worktree with merged PR is removed" {
  _mkworktree
  run bash -c '
    source "$1"
    PR_STATE_BY_WT[$2]=MERGED
    PR_NUM_BY_WT[$2]=99
    IN_USE_CWDS=()
    classify "$2"
  ' _ "$POI" "$WT"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == remove$'\t'* ]]
  [[ "$output" == *"PR #99 merged"* ]]
}

@test "classify: in-use worktree with merged PR is kept" {
  _mkworktree
  run bash -c '
    source "$1"
    PR_STATE_BY_WT[$2]=MERGED
    PR_NUM_BY_WT[$2]=99
    IN_USE_CWDS=("$3")
    classify "$2"
  ' _ "$POI" "$WT" "$WT/nested/subdir"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == keep$'\t'* ]]
  [[ "$output" == *"in-use"* ]]
  [[ "$output" == *"PR #99 merged"* ]]
}

# --- classify: gone vs. never-pushed upstreams ---

@test "classify: merged PR with gone upstream is removed" {
  # Simulates post-merge auto-prune: branch.<name>.remote/.merge stay set,
  # but refs/remotes/origin/<branch> is gone. The PR's merged state proves
  # the work was pushed, so the missing remote ref must not block removal.
  _mkworktree
  git -C "$WT" update-ref -d refs/remotes/origin/feature
  run bash -c '
    source "$1"
    PR_STATE_BY_WT[$2]=MERGED
    PR_NUM_BY_WT[$2]=42
    IN_USE_CWDS=()
    classify "$2"
  ' _ "$POI" "$WT"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == remove$'\t'* ]]
  [[ "$output" == *"PR #42 merged"* ]]
}

@test "classify: merged PR with no upstream config is kept" {
  # Regression guard against the gone-upstream fix: when branch.<name>.merge
  # is unset, there's no proof the work was ever pushed — keep, even if a
  # merged PR happens to share the branch name.
  _mkworktree
  git -C "$WT" branch --unset-upstream
  run bash -c '
    source "$1"
    PR_STATE_BY_WT[$2]=MERGED
    PR_NUM_BY_WT[$2]=42
    IN_USE_CWDS=()
    classify "$2"
  ' _ "$POI" "$WT"
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == keep$'\t'* ]]
  [[ "$output" == *"no upstream"* ]]
}

# --- batch_fetch_pr_states: one query per repo ---

@test "batch fetch: one graphql call serves three same-repo worktrees" {
  local wtroot="$XDG_DATA_HOME/git-worktrees/me/repo"
  local canonical="$HOME/me/repo"
  local bare="$TMPROOT/remote.git"

  mkdir -p "$wtroot" "$(dirname "$canonical")"
  git init --quiet --bare --initial-branch=main "$bare"
  git init --quiet --initial-branch=main "$canonical"
  git -C "$canonical" -c user.email=t@t -c user.name=t commit --allow-empty -q -m init
  git -C "$canonical" remote add origin "$bare"
  git -C "$canonical" push --quiet -u origin main

  local b
  for b in alpha beta gamma; do
    git -C "$canonical" worktree add -B "$b" "$wtroot/$b" >/dev/null 2>&1
  done
  # Push alpha and beta so MERGED→remove and OPEN→keep can fire on a clean
  # worktree. Leave gamma unpushed so the NONE+ahead==0 path triggers on its
  # "no commits, no PR" verdict.
  git -C "$wtroot/alpha" push --quiet -u origin alpha
  git -C "$wtroot/beta" push --quiet -u origin beta
  # Swap origin to a GitHub URL so github_slug resolves; pushes are done.
  git -C "$canonical" remote set-url origin "git@github.com:me/repo.git"

  local stub_dir="$TMPROOT/stubs"
  local count_file="$TMPROOT/gh_count"
  local tsv_file="$TMPROOT/gh_tsv"
  mkdir -p "$stub_dir"
  : >"$count_file"
  # find $WORKTREE_ROOT | sort emits alpha, beta, gamma → aliases pr0,pr1,pr2.
  printf 'pr0\t1\tMERGED\npr1\t2\tOPEN\npr2\t\tNONE\n' >"$tsv_file"
  cat >"$stub_dir/gh" <<'STUB'
#!/usr/bin/env bash
# Stub: count `gh api graphql` calls and replay canned post-jq TSV.
if [[ "${1:-}" == api && "${2:-}" == graphql ]]; then
    printf 'invoked\n' >>"$GH_STUB_COUNT_FILE"
    cat "$GH_STUB_TSV_FILE"
    exit 0
fi
exit 1
STUB
  chmod +x "$stub_dir/gh"

  PATH="$stub_dir:$PATH" \
    GH_STUB_COUNT_FILE="$count_file" \
    GH_STUB_TSV_FILE="$tsv_file" \
    run bash "$POI" -n
  [ "$status" -eq 0 ]

  local invocations
  invocations=$(wc -l <"$count_file")
  [ "$invocations" -eq 1 ]

  [[ "$output" == *"== DRY RUN =="* ]]
  [[ "$output" == *"Would remove"* ]]
  [[ "$output" == *"Would keep"* ]]
  [[ "$output" != *"Would remove (2)"* ]]
  [[ "$output" != *"Would keep (1)"* ]]
  [[ "$output" == *"PR #1 merged"* ]]
  [[ "$output" == *"PR #2 open"* ]]
  [[ "$output" == *"no commits, no PR"* ]]
  # Inline layout: no second-line tree glyph (cardinality is always 1).
  [[ "$output" != *"└─"* ]]
}

# --- print_section: verdict-branched splitter ---

# The keep-row detail is comma-joined, so print_section splits on ", " to
# colour each reason. The "no commits, no PR" remove-row detail contains an
# embedded comma; without the verdict branch the splitter would shred it into
# two atoms and lose the green wrap. Forces colour vars on since bats stdout
# isn't a tty.
@test "print_section: empty data renders dimmed (none) placeholder" {
  run bash -c "
    source '$POI'
    DIM=\$'\\033[2m' RESET=\$'\\033[0m'
    CWD=/tmp
    print_section 'Would remove' ''
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would remove"* ]]
  [[ "$output" == *$'\033[2m'"(none)"$'\033[0m'* ]]
}

@test "print_section: row whose wt matches CWD gets BOLD_YELLOW asterisk marker" {
  run bash -c "
    source '$POI'
    BOLD_YELLOW=\$'\\033[1;33m' DIM=\$'\\033[2m' RESET=\$'\\033[0m'
    CWD=/tmp/wt
    row=\$(printf 'keep\\trepo/feature\\tu/worktree/feature\\tin-use\\t/tmp/wt')
    print_section 'Kept' \"\$row\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[1;33m'"*"$'\033[0m'* ]]
}

@test "print_section: branch matching rel slug is elided" {
  # Petname worktrees encode rel's slug in the branch name, so the branch
  # adds no information and would just inflate the rel column.
  run bash -c "
    source '$POI'
    DIM=\$'\\033[2m' RESET=\$'\\033[0m'
    CWD=/tmp
    row=\$(printf 'keep\\trepo/feature\\tu/worktree/feature\\tin-use\\t/tmp/wt')
    print_section 'Kept' \"\$row\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"u/worktree/feature"* ]]
}

@test "print_section: branch with divergent slug is shown" {
  # Manual rename or custom checkout — branch can't be read off rel, so
  # show it (dim) to preserve the identifier.
  run bash -c "
    source '$POI'
    DIM=\$'\\033[2m' RESET=\$'\\033[0m'
    CWD=/tmp
    row=\$(printf 'keep\\trepo/feature\\tunrelated-name\\tin-use\\t/tmp/wt')
    print_section 'Kept' \"\$row\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"(unrelated-name)"* ]]
}

@test "print_section: remove-row detail with embedded comma stays one coloured atom" {
  run bash -c "
    source '$POI'
    BOLD=\$'\\033[1m' DIM=\$'\\033[2m' RESET=\$'\\033[0m'
    GREEN=\$'\\033[32m' BOLD_YELLOW=\$'\\033[1;33m'
    CWD=/tmp
    row=\$(printf 'remove\\tx/y\\tbranch\\tno commits, no PR\\t/tmp/wt')
    print_section 'Would remove' \"\$row\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[32m'"no commits, no PR"$'\033[0m'* ]]
}

# --- resolve_target: NAME → single worktree ---

# Bare directories with a .git file are enough: walk_worktrees and
# resolve_target only test names, never invoke git on the path.
_mk_stub_wt() {
  local p="$XDG_DATA_HOME/git-worktrees/$1"
  mkdir -p "$p"
  : >"$p/.git"
}

@test "resolve_target: bare petname across two repos errors with candidates" {
  _mk_stub_wt me/alpha/dup
  _mk_stub_wt me/beta/dup
  run bash -c 'source "$1"; resolve_target dup' _ "$POI"
  [ "$status" -ne 0 ]
  [[ "$output" == *"alpha/dup"* ]]
  [[ "$output" == *"beta/dup"* ]]
}

@test "resolve_target: <repo>/<name> disambiguates the collision" {
  _mk_stub_wt me/alpha/dup
  _mk_stub_wt me/beta/dup
  run bash -c 'source "$1"; resolve_target alpha/dup; printf %s "$TARGET_WT"' _ "$POI"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/me/alpha/dup" ]]
}

@test "resolve_target: unique petname resolves to its path" {
  _mk_stub_wt me/repo/solo
  run bash -c 'source "$1"; resolve_target solo; printf %s "$TARGET_WT"' _ "$POI"
  [ "$status" -eq 0 ]
  [[ "$output" == *"/me/repo/solo" ]]
}

@test "resolve_target: no match errors" {
  _mk_stub_wt me/repo/solo
  run bash -c 'source "$1"; resolve_target nope' _ "$POI"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no worktree matches 'nope'"* ]]
}

# --- --force: override the keep verdict for a named worktree ---

# Real gh is absent in CI (other tests stub it), so the binary-presence check
# at the top of the script needs something on PATH. The forced paths below
# classify UNKNOWN — origin is a file:// bare repo, so github_slug bails and
# no gh call is made — leaving this stub uninvoked.
_stub_gh_absent() {
  local d="$TMPROOT/stubs"
  mkdir -p "$d"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$d/gh"
  chmod +x "$d/gh"
  printf '%s' "$d"
}

@test "force without NAME is rejected" {
  run bash "$POI" -f
  [ "$status" -ne 0 ]
  [[ "$output" == *"--force requires a worktree NAME"* ]]
}

@test "force removes a kept worktree and force-deletes its branch" {
  _mkworktree  # non-GitHub origin → PR state UNKNOWN → classifier keeps it
  local stub; stub=$(_stub_gh_absent)

  # Without force the target is kept, not removed.
  PATH="$stub:$PATH" run bash "$POI" -n feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"Would keep"* ]]
  [[ "$output" == *"PR state unknown"* ]]
  [ -e "$WT" ]

  # With force it goes, branch and all.
  PATH="$stub:$PATH" run bash "$POI" -f feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed"* ]]
  [ ! -e "$WT" ]
  run git -C "$HOME/me/repo" rev-parse --verify --quiet refs/heads/feature
  [ "$status" -ne 0 ]
}

@test "NAME scopes the run to the matched worktree" {
  _mkworktree
  git -C "$HOME/me/repo" worktree add -B other \
    "$XDG_DATA_HOME/git-worktrees/me/repo/other" >/dev/null 2>&1
  local stub; stub=$(_stub_gh_absent)

  PATH="$stub:$PATH" run bash "$POI" -n feature
  [ "$status" -eq 0 ]
  [[ "$output" == *"repo/feature"* ]]
  [[ "$output" != *"repo/other"* ]]
}
