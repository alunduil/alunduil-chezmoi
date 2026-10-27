#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  # The check reads the git repo it lives in, so each test gets its own.
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/script/checks" "$WORK/.chezmoiscripts"
  cp "$BATS_TEST_DIRNAME/bootstrap-convergence" "$WORK/script/checks/"
  git -C "$WORK" init -q
}

teardown() {
  rm -rf "$WORK"
}

add_pass() {
  local name="$1"
  cat >"$WORK/.chezmoiscripts/$name"
  git -C "$WORK" add .
}

run_check() {
  run "$WORK/script/checks/bootstrap-convergence"
}

@test "an unmarked exit 0 in a run_onchange_ pass fails" {
  add_pass run_onchange_after_restart.sh.tmpl <<'EOF'
# token-hash: abc
if ! systemctl --user show-environment; then
  exit 0
fi
EOF
  run_check
  assert_failure
  assert_output --partial 'run_onchange_after_restart.sh.tmpl:3: exit 0 records the hash'
}

@test "a skip marked with the pass's own hash line passes" {
  add_pass run_onchange_after_register.sh.tmpl <<'EOF'
# token-hash: abc
if [ ! -r "$token_file" ]; then
  exit 0 # rerun-on: token-hash
fi
EOF
  run_check
  assert_success
}

@test "a marker naming a hash line the pass lacks fails" {
  add_pass run_onchange_after_register.sh.tmpl <<'EOF'
# token-hash: abc
if [ ! -r "$key_file" ]; then
  exit 0 # rerun-on: key-hash
fi
EOF
  run_check
  assert_failure
  assert_output --partial 'run_onchange_after_register.sh.tmpl:3:'
}
