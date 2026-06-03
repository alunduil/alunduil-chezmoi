#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures/pr_draft_guard"
  HOOK="$(mktemp)"
  install -m 0755 "$REPO_ROOT/dot_claude/hooks/executable_pr-draft-guard.sh" "$HOOK"
}

teardown() {
  rm -f "$HOOK"
}

@test "allows create_pull_request with draft=true" {
  run "$HOOK" <"$FIXTURES/create_pr_draft_true.json"
  [ "$status" -eq 0 ]
}

@test "blocks create_pull_request with draft=false" {
  run "$HOOK" <"$FIXTURES/create_pr_draft_false.json"
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be opened as drafts"* ]]
}

@test "blocks create_pull_request without draft field" {
  run "$HOOK" <"$FIXTURES/create_pr_no_draft.json"
  [ "$status" -eq 2 ]
}

@test "blocks create_pull_request with draft=null" {
  run "$HOOK" <"$FIXTURES/create_pr_draft_null.json"
  [ "$status" -eq 2 ]
}

# `jq -r` collapses string "true" and boolean true to "true". Locked in
# so a future tightening (e.g. `jq -e 'type == "boolean"'`) has to flip this.
@test "allows create_pull_request with draft=\"true\" string" {
  run "$HOOK" <"$FIXTURES/create_pr_draft_string_true.json"
  [ "$status" -eq 0 ]
}

@test "allows copilot variant with draft=true" {
  run "$HOOK" <"$FIXTURES/copilot_draft_true.json"
  [ "$status" -eq 0 ]
}

@test "blocks copilot variant with draft=false" {
  run "$HOOK" <"$FIXTURES/copilot_draft_false.json"
  [ "$status" -eq 2 ]
}

@test "allows unrelated tool calls" {
  run "$HOOK" <"$FIXTURES/unrelated_tool.json"
  [ "$status" -eq 0 ]
}

@test "allows empty input gracefully" {
  run "$HOOK" <"$FIXTURES/empty_object.json"
  [ "$status" -eq 0 ]
}

# Locks in fail-closed on malformed input: exits 2 (block), not 1
# (warning). Guards against schema drift letting PRs through.
@test "blocks on malformed JSON" {
  run "$HOOK" <"$FIXTURES/malformed.json"
  [ "$status" -eq 2 ]
}
