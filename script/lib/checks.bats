#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  # shellcheck source=script/lib/checks.sh
  . "$BATS_TEST_DIRNAME/checks.sh"
}

@test "skip exits SKIP off CI" {
  unset CI
  run -"$SKIP" skip "tool not on PATH"
}

@test "skip fails under CI" {
  CI=true run -1 skip "tool not on PATH"
}
