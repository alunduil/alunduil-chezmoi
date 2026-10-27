#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SCRIPT="$REPO_ROOT/dot_local/bin/executable_zellij-rate-limit-status"

  STUB_DIR="$(mktemp -d)"
  export PATH="$STUB_DIR:$PATH"
}

teardown() {
  rm -rf "$STUB_DIR"
}

stub_gh() {
  printf '#!/usr/bin/env bash\n%s\n' "$1" >"$STUB_DIR/gh"
  chmod +x "$STUB_DIR/gh"
}

stub_rate_limit() {
  stub_gh "cat <<'JSON'
{\"resources\": {
  \"core\": {\"remaining\": $1, \"limit\": $2},
  \"graphql\": {\"remaining\": 4000, \"limit\": 5000},
  \"search\": {\"remaining\": 30, \"limit\": 30}}}
JSON"
}

@test "renders the unknown ribbon when gh api fails" {
  stub_gh 'exit 1'
  run -0 bash "$SCRIPT"
  [[ "$output" == *"gh ?"* ]]
  [[ "$output" != *"core"* ]]
}

@test "renders the unknown ribbon when the response is missing a bucket" {
  stub_gh "echo '{\"resources\": {}}'"
  run -0 bash "$SCRIPT"
  [[ "$output" == *"gh ?"* ]]
}

@test "renders a zero-limit bucket red instead of failing" {
  stub_rate_limit 0 0
  run -0 bash "$SCRIPT"
  [[ "$output" == *"#[bg=196,fg=16] core 0/0 "* ]]
  [[ "$output" != *"gh ?"* ]]
}

@test "renders every bucket when the budget is readable" {
  stub_rate_limit 4000 5000
  run -0 bash "$SCRIPT"
  [[ "$output" == *" core 4000/5000 "* ]]
  [[ "$output" == *" gql 4000/5000 "* ]]
  [[ "$output" == *" search 30/30 "* ]]
}
