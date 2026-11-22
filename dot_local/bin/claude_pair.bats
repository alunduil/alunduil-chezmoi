#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises the host-vs-devcontainer and resume-vs-fresh branches the zellij
# pair tab depends on. A stub `claude` echoes its args so we can assert which
# mode was chosen. A stub `devcontainer` logs each call and, for `exec`,
# applies --remote-env and runs the command locally in place of the container.
# STUB_UP_FAIL=always fails every `up`; STUB_UP_FAIL=stale fails until `up`
# gets --remove-existing-container.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  STUB_DIR="$(mktemp -d)"
  WRAPPER_DIR="$(mktemp -d)"
  export HOME="$(mktemp -d)"
  WORKTREE="$(mktemp -d)"
  export DEVCONTAINER_LOG="$STUB_DIR/devcontainer.log"
  unset CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN XDG_CONFIG_HOME

  cat >"$STUB_DIR/claude" <<'STUB'
#!/usr/bin/env bash
printf 'args:[%s] author:[%s]\n' "$*" "${GIT_AUTHOR_NAME:-}"
STUB
  chmod +x "$STUB_DIR/claude"

  cat >"$STUB_DIR/devcontainer" <<'STUB'
#!/usr/bin/env bash
sub="$1"; shift
printf '%s token:[%s] %s\n' "$sub" "${CLAUDE_CODE_OAUTH_TOKEN:-}" "$*" >>"$DEVCONTAINER_LOG"
if [[ "$sub" == up ]]; then
  case "${STUB_UP_FAIL:-}" in
    always) ;;
    stale) [[ " $* " == *" --remove-existing-container "* ]] && exit 0 ;;
    *) exit 0 ;;
  esac
  echo "build failed: bad feature" >&2
  exit 1
fi
envs=()
while [[ "$1" == --* ]]; do
  [[ "$1" == --remote-env ]] && envs+=("$2")
  shift 2
done
exec env "${envs[@]}" "$@"
STUB
  chmod +x "$STUB_DIR/devcontainer"

  install -m 0755 "$REPO_ROOT/dot_local/bin/executable_claude-pair" "$WRAPPER_DIR/claude-pair"

  export PATH="$WRAPPER_DIR:$STUB_DIR:/usr/bin:/bin"
}

teardown() {
  rm -rf "$STUB_DIR" "$WRAPPER_DIR" "$HOME" "$WORKTREE"
}

# Mirror claude's project-dir encoding for a given config dir and path.
project_dir_for() {
  printf '%s/projects/%s' "$1" "$(printf '%s' "$2" | sed 's/[^a-zA-Z0-9]/-/g')"
}

# seed_conversation <config dir> [empty]: give $WORKTREE a project dir under
# the config dir, holding a conversation unless "empty" is passed.
seed_conversation() {
  local dir
  dir="$(project_dir_for "$1" "$WORKTREE")"
  mkdir -p "$dir"
  [[ "${2:-}" == empty ]] || : >"$dir/session.jsonl"
}

run_pair() {
  run bash -c "cd '$WORKTREE' && claude-pair"
}

# Turn $WORKTREE into a git worktree of a fresh clone with a devcontainer.
make_devcontainer_worktree() {
  CLONE="$HOME/clone"
  git init -q "$CLONE"
  git -C "$CLONE" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m init
  rmdir "$WORKTREE"
  git -C "$CLONE" worktree add -q "$WORKTREE"
  git -C "$WORKTREE" config user.name "Pair Person"
  git -C "$WORKTREE" config user.email pair@example.com
  mkdir -p "$WORKTREE/.devcontainer"
  echo '{}' >"$WORKTREE/.devcontainer/devcontainer.json"
  mkdir -p "$HOME/.config/claude-pair"
  echo secret-token >"$HOME/.config/claude-pair/token"
}

@test "host: resumes when the worktree has prior conversations" {
  seed_conversation "$HOME/.claude"

  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[--continue] author:[]" ]]
}

@test "host: starts fresh when no project dir exists" {
  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[] author:[]" ]]
}

@test "host: starts fresh when the project dir has no conversations" {
  seed_conversation "$HOME/.claude" empty

  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[] author:[]" ]]
}

@test "host: never calls devcontainer" {
  run_pair
  [ "$status" -eq 0 ]
  [ ! -e "$DEVCONTAINER_LOG" ]
}

@test "devcontainer: up mounts the git common dir at its host path" {
  make_devcontainer_worktree

  run_pair
  [ "$status" -eq 0 ]
  grep -qxF "up token:[secret-token] --workspace-folder . --mount type=bind,source=$CLONE/.git,target=$CLONE/.git" "$DEVCONTAINER_LOG"
}

@test "devcontainer: up and exec both see the token" {
  make_devcontainer_worktree

  run_pair
  [ "$status" -eq 0 ]
  [ "$(grep -c 'token:\[secret-token\]' "$DEVCONTAINER_LOG")" -eq 2 ]
}

@test "devcontainer: exec passes the host git identity" {
  make_devcontainer_worktree

  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == *" author:[Pair Person]" ]]
  grep -qF -- "--remote-env GIT_COMMITTER_EMAIL=pair@example.com" "$DEVCONTAINER_LOG"
}

@test "devcontainer: claude gets the model and the push boundary" {
  make_devcontainer_worktree

  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[--model opus --append-system-prompt "*"no GitHub credentials"*"Leave SSH host trust and credentials to the operator"*"] author:[Pair Person]" ]]
}

@test "devcontainer: resumes from CLAUDE_CONFIG_DIR" {
  make_devcontainer_worktree
  export CLAUDE_CONFIG_DIR="$HOME/container-claude"
  seed_conversation "$CLAUDE_CONFIG_DIR"

  run_pair
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[--continue "*"] author:[Pair Person]" ]]
}

@test "devcontainer: quitting a failed build exits with its error and skips exec" {
  make_devcontainer_worktree

  STUB_UP_FAIL=always run_pair <<<q
  [ "$status" -ne 0 ]
  [[ "$output" == *"build failed: bad feature"* ]]
  ! grep -q '^exec' "$DEVCONTAINER_LOG"
}

@test "devcontainer: a failed build with no input quits" {
  make_devcontainer_worktree

  STUB_UP_FAIL=always run_pair </dev/null
  [ "$status" -ne 0 ]
  [ "$(grep -c '^up' "$DEVCONTAINER_LOG")" -eq 1 ]
}

@test "devcontainer: retry runs up again without rebuilding" {
  make_devcontainer_worktree

  STUB_UP_FAIL=always run_pair <<<rq
  [ "$status" -ne 0 ]
  [ "$(grep -c '^up' "$DEVCONTAINER_LOG")" -eq 2 ]
  ! grep -q -- '--remove-existing-container' "$DEVCONTAINER_LOG"
}

@test "devcontainer: rebuild replaces the container and starts claude" {
  make_devcontainer_worktree

  STUB_UP_FAIL=stale run_pair <<<R
  [ "$status" -eq 0 ]
  [[ "$output" == *"args:["*"] author:[Pair Person]"* ]]
  grep -q '^up .*--remove-existing-container' "$DEVCONTAINER_LOG"
}
