#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# can_escalate() (script/lib.sh) gates the sudo-requiring bootstrap steps in
# run_once_before_01/04: capable -> run them, incapable -> skip with a warning.
# Misclassifying either way silently breaks bootstrap, so exercise each branch
# with stubbed id/sudo. chezmoi CI excludes scripts, so run_once_before_* never
# runs there -- this is the only check covering the helper.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  STUB_DIR="$(mktemp -d)"
  # shellcheck source=../script/lib.sh
  . "$REPO_ROOT/script/lib.sh"
}

teardown() {
  rm -rf "$STUB_DIR"
}

# Stubs use an absolute-path shebang and shell builtins only: the tests run
# can_escalate with PATH restricted to STUB_DIR, so a `/usr/bin/env bash`
# shebang could not resolve its interpreter.
stub_id() { # uid
  printf '#!/bin/sh\nprintf "%%s\\n" %s\n' "$1" >"$STUB_DIR/id"
  chmod +x "$STUB_DIR/id"
}

stub_sudo() { # exit-code
  printf '#!/bin/sh\nexit %s\n' "$1" >"$STUB_DIR/sudo"
  chmod +x "$STUB_DIR/sudo"
}

@test "root is capable without consulting sudo" {
  stub_id 0
  # no sudo stub: PATH holds only id, proving root never reaches the sudo path
  PATH="$STUB_DIR" run can_escalate
  [ "$status" -eq 0 ]
}

@test "non-root sudoer is capable when sudo validates" {
  stub_id 1000
  stub_sudo 0
  PATH="$STUB_DIR" run can_escalate
  [ "$status" -eq 0 ]
}

@test "non-root non-sudoer is not capable when sudo refuses" {
  stub_id 1000
  stub_sudo 1
  PATH="$STUB_DIR" run can_escalate
  [ "$status" -ne 0 ]
}

@test "no sudo binary is not capable" {
  stub_id 1000
  # PATH holds only id, so command -v sudo fails
  PATH="$STUB_DIR" run can_escalate
  [ "$status" -ne 0 ]
}
