#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

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
