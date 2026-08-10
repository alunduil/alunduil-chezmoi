#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises the correction the pair layout depends on: a claude pane
# discovered as its stdio MCP server has to serialize as the launcher, and
# every other pane has to survive the hook unchanged.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  BIN_DIR="$(mktemp -d)"
  install -m 0755 "$REPO_ROOT/dot_local/bin/executable_zellij-resurrect-command" \
    "$BIN_DIR/zellij-resurrect-command"

  export PATH="$BIN_DIR:$PATH"
}

teardown() {
  rm -rf "$BIN_DIR"
}

@test "the claude pane's MCP child is corrected to the launcher" {
  export RESURRECT_COMMAND="/home/alunduil/.local/bin/truenas-mcp --insecure"

  run zellij-resurrect-command
  [ "$status" -eq 0 ]
  [ "$output" = "claude-pair" ]
}

@test "other pane commands pass through unchanged" {
  export RESURRECT_COMMAND="lazygit"

  run zellij-resurrect-command
  [ "$status" -eq 0 ]
  [ "$output" = "lazygit" ]
}

@test "an undiscovered command does not fail the hook" {
  unset RESURRECT_COMMAND

  run zellij-resurrect-command
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}
