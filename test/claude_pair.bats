#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises the resume-vs-fresh branch the zellij pair tab depends on.
# A stub `claude` echoes its args so we can assert which mode was chosen.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  STUB_DIR="$(mktemp -d)"
  WRAPPER_DIR="$(mktemp -d)"
  export HOME="$(mktemp -d)"
  WORKTREE="$(mktemp -d)"

  cat >"$STUB_DIR/claude" <<'STUB'
#!/usr/bin/env bash
printf 'args:[%s]\n' "$*"
STUB
  chmod +x "$STUB_DIR/claude"

  install -m 0755 "$REPO_ROOT/dot_local/bin/executable_claude-pair" "$WRAPPER_DIR/claude-pair"

  export PATH="$WRAPPER_DIR:$STUB_DIR:/usr/bin:/bin"
}

teardown() {
  rm -rf "$STUB_DIR" "$WRAPPER_DIR" "$HOME" "$WORKTREE"
}

# Mirror claude's project-dir encoding for a given path.
project_dir_for() {
  printf '%s/.claude/projects/%s' "$HOME" "$(printf '%s' "$1" | sed 's/[^a-zA-Z0-9]/-/g')"
}

@test "resumes when the worktree has prior conversations" {
  mkdir -p "$(project_dir_for "$WORKTREE")"
  : >"$(project_dir_for "$WORKTREE")/session.jsonl"

  run bash -c "cd '$WORKTREE' && claude-pair"
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[--continue]" ]]
}

@test "starts fresh when no project dir exists" {
  run bash -c "cd '$WORKTREE' && claude-pair"
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[]" ]]
}

@test "starts fresh when the project dir has no conversations" {
  mkdir -p "$(project_dir_for "$WORKTREE")"

  run bash -c "cd '$WORKTREE' && claude-pair"
  [ "$status" -eq 0 ]
  [[ "$output" == "args:[]" ]]
}
