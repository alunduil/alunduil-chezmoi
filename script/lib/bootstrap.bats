#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  WORK="$(mktemp -d)"
  export XDG_STATE_HOME="$WORK/state"
  # shellcheck source=script/lib/bootstrap.sh
  . "$BATS_TEST_DIRNAME/bootstrap.sh"
}

teardown() {
  rm -rf "$WORK"
}

@test "reregister_mcp without claude fails naming it" {
  without_claude() { PATH="$WORK" reregister_mcp "$@"; }
  run --separate-stderr without_claude github --transport http https://example.com
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"github: claude not on PATH"* ]]
}

@test "reregister_mcp reports a failed add" {
  claude() { [ "$2" = remove ]; }
  run --separate-stderr reregister_mcp github --transport http https://example.com
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"github: add failed, nothing registered"* ]]
}

# run_pass PASS FILE: run FILE as pass PASS with systemctl and claude failing.
run_pass() {
  local tool
  mkdir -p "$WORK/bin"
  for tool in systemctl claude; do
    printf '#!/bin/sh\nexit 1\n' >"$WORK/bin/$tool"
    chmod +x "$WORK/bin/$tool"
  done
  run --separate-stderr env -i HOME="$WORK" PATH="$WORK/bin:$PATH" \
    CHEZMOI_SOURCE_FILE=".chezmoiscripts/$1" bash "$2"
}

# run_failing_pass PASS [CALL]: run CALL as pass PASS. The default CALL,
# use_pinned_mise, fails because no mise is installed.
run_failing_pass() {
  cat >"$WORK/pass" <<EOF
set -euo pipefail
. "$BATS_TEST_DIRNAME/bootstrap.sh"
${2:-use_pinned_mise}
EOF
  run_pass "$1" "$WORK/pass"
}

@test "a pass failing in a helper names itself, the command, and the retry" {
  run_failing_pass run_after_enable-foo.sh.tmpl
  [ "$status" -eq 1 ]
  [[ "$stderr" == *'run_after_enable-foo.sh.tmpl failed: pin="$(readlink -f "$mise_shims/mise")" (exit 1 at bootstrap.sh:'* ]]
  [[ "$stderr" == *"re-run chezmoi apply (passes converge)"* ]]
  [[ "$stderr" != *"no files were written"* ]]
}

@test "a helper that returns non-zero is reported at its call site" {
  run_failing_pass run_onchange_after_register-foo-mcp.sh.tmpl \
    'reregister_mcp foo https://example.com'
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"run_onchange_after_register-foo-mcp.sh.tmpl failed (exit 1 at run_onchange_after_register-foo-mcp.sh.tmpl:3)"* ]]
}

@test "a failing before-phase pass says no files were written" {
  run_failing_pass run_before_04-configure-foo.sh.tmpl
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"no files were written"* ]]
}

without_user_manager() { systemctl() { return 1; }; }
with_user_manager() { systemctl() { printf '%s\n' "$*" >>"$WORK/systemctl.log"; }; }

@test "a headless apply ends listing every skipped unit with the remedy" {
  without_user_manager
  enable_user_units ssh-agent ssh-agent.service 2>/dev/null
  enable_user_units git-maintenance a.timer b.timer 2>/dev/null
  run --separate-stderr report_skipped_units
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"ssh-agent.service"* ]]
  [[ "$stderr" == *"a.timer"*"b.timer"* ]]
  [[ "$stderr" == *"enable: re-run chezmoi apply"*"loginctl enable-linger"* ]]
}

@test "a skip names its units and the remedy" {
  without_user_manager
  run --separate-stderr enable_user_units ssh-agent ssh-agent.service
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"leaving ssh-agent.service disabled — re-run chezmoi apply"* ]]
}

@test "a later apply with a user manager enables the unit and drops it from the report" {
  without_user_manager
  enable_user_units ssh-agent ssh-agent.service 2>/dev/null
  with_user_manager
  enable_user_units ssh-agent ssh-agent.service
  grep -qx -- '--user enable --now ssh-agent.service' "$WORK/systemctl.log"
  run --separate-stderr report_skipped_units
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "the pinned mise comes ahead of any other mise on PATH" {
  local pin="$WORK/installs/github-jdx-mise/1.0.0/bin"
  mise_shims="$WORK/shims"
  mkdir -p "$pin" "$mise_shims" "$WORK/seed"
  printf '#!/bin/sh\n' | tee "$pin/mise" >"$WORK/seed/mise"
  chmod +x "$pin/mise" "$WORK/seed/mise"
  ln -s "$pin/mise" "$mise_shims/mise"
  PATH="$WORK/seed:$PATH"
  use_pinned_mise
  [ "$(command -v mise)" = "$pin/mise" ]
}

@test "every pass sources bootstrap.sh" {
  run grep -L '^\. "{{ \.chezmoi\.sourceDir }}/script/lib/bootstrap\.sh"$' \
    "$BATS_TEST_DIRNAME"/../../.chezmoiscripts/*
  [ -z "$output" ]
}

@test "a headless alloy restart names the pass, the command, and the retry" {
  local pass=run_onchange_after_restart-alloy-on-token-change.sh.tmpl
  local root="$BATS_TEST_DIRNAME/../.."
  sed "s|{{ .chezmoi.sourceDir }}|$root|" "$root/.chezmoiscripts/$pass" >"$WORK/pass"
  run_pass "$pass" "$WORK/pass"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"alloy: no user systemd session; restart fails — re-run chezmoi apply"*"loginctl enable-linger"* ]]
  [[ "$stderr" == *"$pass failed: systemctl --user try-restart alloy.service (exit 1 at $pass:"* ]]
  [[ "$stderr" == *"re-run chezmoi apply (passes converge)"* ]]
}
