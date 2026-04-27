#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$(mktemp)"
  install -m 0755 "$REPO_ROOT/dot_claude/hooks/executable_pr-draft-guard.sh" "$HOOK"
}

teardown() {
  rm -f "$HOOK"
}

@test "allows create_pull_request with draft=true" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__create_pull_request\",\"tool_input\":{\"draft\":true}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
}

@test "blocks create_pull_request with draft=false" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__create_pull_request\",\"tool_input\":{\"draft\":false}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be opened as drafts"* ]]
}

@test "blocks create_pull_request without draft field" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__create_pull_request\",\"tool_input\":{\"title\":\"test\"}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 2 ]
}

@test "allows copilot variant with draft=true" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__create_pull_request_with_copilot\",\"tool_input\":{\"draft\":true}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
}

@test "blocks copilot variant with draft=false" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__create_pull_request_with_copilot\",\"tool_input\":{\"draft\":false}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 2 ]
}

@test "allows unrelated tool calls" {
  run bash -c 'echo "{\"tool_name\":\"mcp__github__list_issues\",\"tool_input\":{}}" | "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
}

@test "allows empty input gracefully" {
  run bash -c 'echo "{}" | "$1"' -- "$HOOK"
  [ "$status" -eq 0 ]
}
