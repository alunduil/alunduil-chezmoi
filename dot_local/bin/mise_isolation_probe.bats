#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
bats_load_library bats-support
bats_load_library bats-assert

# Runs the real mise, so the global config's just must be installed.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  PROBE="$BATS_TEST_DIRNAME/executable_mise-isolation-probe"
  ENV_FILE="$REPO_ROOT/dot_config/environment.d/mise.conf"
  TMP="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMP"
}

@test "passes with every variable in mise.conf" {
  run bash "$PROBE" --env-file "$ENV_FILE"
  assert_success
  assert_output --partial 'OK: login shell'
  assert_output --partial 'OK: systemd user unit'
}

@test "fails in both contexts without any one variable in mise.conf" {
  local var
  local -a vars
  mapfile -t vars < <(grep -oE '^MISE_[A-Z_]+' "$ENV_FILE")
  [ "${#vars[@]}" -gt 0 ]
  for var in "${vars[@]}"; do
    grep -v "^$var=" "$ENV_FILE" >"$TMP/mise.conf"
    run bash "$PROBE" --env-file "$TMP/mise.conf"
    assert_failure
    assert_output --partial 'FAIL: login shell'
    assert_output --partial 'FAIL: systemd user unit'
  done
}

@test "fails on an unreadable env file" {
  run bash "$PROBE" --env-file "$TMP/missing.conf"
  assert_failure
  assert_output --partial "cannot read $TMP/missing.conf"
}
