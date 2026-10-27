#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Passes run on every apply, so a converged host must never reach sudo.

setup() {
  WORK="$(mktemp -d)"
  export XDG_STATE_HOME="$WORK/state"
  # shellcheck source=script/lib/bootstrap.sh
  . "$BATS_TEST_DIRNAME/bootstrap.sh"
  export SUDO_LOG="$WORK/sudo.log"
  : >"$SUDO_LOG"
  sudo() {
    printf '%s\n' "$*" >>"$SUDO_LOG"
    case "$1" in
    install | cp) command "$@" ;;
    esac
  }
  export -f sudo
  printf 'unit\n' >"$WORK/src"
}

teardown() {
  rm -rf "$WORK"
}

install_src() {
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null </dev/null
}

@test "an unchanged file neither installs nor reloads" {
  cp "$WORK/src" "$WORK/dest"
  install_src
  daemon_reload_if_installed
  [ ! -s "$SUDO_LOG" ]
}

@test "a changed file installs, then reloads once" {
  printf 'stale\n' >"$WORK/dest"
  install_src
  daemon_reload_if_installed
  daemon_reload_if_installed
  cmp -s "$WORK/src" "$WORK/dest"
  [ "$(grep -c '^systemctl daemon-reload$' "$SUDO_LOG")" -eq 1 ]
}

@test "replacing a changed file shows the diff and keeps a backup" {
  printf 'hand-edit\n' >"$WORK/dest"
  run --separate-stderr install_if_changed -m 0644 "$WORK/src" "$WORK/dest" </dev/null
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"-hand-edit"* ]]
  [[ "$stderr" == *"+unit"* ]]
  [ "$(cat "$WORK/dest.bak")" = hand-edit ]
  cmp -s "$WORK/src" "$WORK/dest"
}

@test "installing a new file leaves no backup" {
  install_src
  [ ! -e "$WORK/dest.bak" ]
  cmp -s "$WORK/src" "$WORK/dest"
}

# script(1) gives install_if_changed a terminal on stdin.
on_terminal() {
  local answer="$1"
  printf '%s\n' "$answer" | script -qec "bash -c '
    . \"$BATS_TEST_DIRNAME/bootstrap.sh\"
    install_if_changed -m 0644 \"$WORK/src\" \"$WORK/dest\"
  '" /dev/null >/dev/null
}

@test "on a terminal, declining keeps a file edited since the last apply" {
  install_src
  printf 'hand-edit\n' >"$WORK/dest"
  printf 'next\n' >"$WORK/src"
  on_terminal n
  [ "$(cat "$WORK/dest")" = hand-edit ]
}

@test "on a terminal, a source change to an unedited file installs unasked" {
  install_src
  printf 'next\n' >"$WORK/src"
  on_terminal n
  cmp -s "$WORK/src" "$WORK/dest"
}

@test "reregister_mcp without claude fails naming it" {
  without_claude() { PATH="$WORK" reregister_mcp "$@"; }
  run --separate-stderr without_claude github --transport http https://example.com
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"github: claude not on PATH"* ]]
}

@test "reregister_mcp reports a failed add with the retry" {
  claude() { [ "$2" = remove ]; }
  run --separate-stderr reregister_mcp github --transport http https://example.com
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"github: add failed, nothing registered — run chezmoi apply again"* ]]
}

# Runs a pass that sources the library and fails inside enable_now, in a clean
# bash as chezmoi would, so the sudo stub above stays out of it.
run_failing_pass() {
  mkdir -p "$WORK/bin"
  printf '#!/bin/sh\nexit 1\n' >"$WORK/bin/systemctl"
  printf '#!/bin/sh\nexit 1\n' >"$WORK/bin/sudo"
  chmod +x "$WORK/bin/systemctl" "$WORK/bin/sudo"
  cat >"$WORK/pass" <<EOF
set -euo pipefail
. "$BATS_TEST_DIRNAME/bootstrap.sh"
enable_now foo.service
EOF
  run --separate-stderr env -i HOME="$WORK" PATH="$WORK/bin:$PATH" \
    CHEZMOI_SOURCE_FILE=".chezmoiscripts/$1" bash "$WORK/pass"
}

@test "a pass failing in a helper names itself, the command, and the retry" {
  run_failing_pass run_after_enable-foo.sh.tmpl
  [ "$status" -eq 1 ]
  [[ "$stderr" == *'run_after_enable-foo.sh.tmpl failed: sudo systemctl enable --now "$unit" (exit 1 at bootstrap.sh:'* ]]
  [[ "$stderr" == *"re-run chezmoi apply (passes converge)"* ]]
  [[ "$stderr" != *"no files were written"* ]]
}

@test "a failing before-phase pass says no files were written" {
  run_failing_pass run_before_04-configure-foo.sh.tmpl
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"no files were written"* ]]
}
