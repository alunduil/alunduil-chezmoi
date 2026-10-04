#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# A converged host must not reach sudo: passes run on every apply, and a
# sudo prompt there means the guard in front of it is broken. sudo is a
# function that records its arguments, so a test can assert it never ran.

setup() {
  # shellcheck source=script/lib/bootstrap.sh
  . "$BATS_TEST_DIRNAME/bootstrap.sh"
  WORK="$(mktemp -d)"
  SUDO_LOG="$WORK/sudo.log"
  : >"$SUDO_LOG"
  sudo() {
    printf '%s\n' "$*" >>"$SUDO_LOG"
    if [ "$1" = install ]; then
      shift
      command install "$@"
    fi
  }
  printf 'unit\n' >"$WORK/src"
}

teardown() {
  rm -rf "$WORK"
}

@test "an unchanged file neither installs nor reloads" {
  cp "$WORK/src" "$WORK/dest"
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null
  daemon_reload_if_installed
  [ ! -s "$SUDO_LOG" ]
}

@test "a changed file installs, then reloads once" {
  printf 'stale\n' >"$WORK/dest"
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null
  daemon_reload_if_installed
  daemon_reload_if_installed
  cmp -s "$WORK/src" "$WORK/dest"
  [ "$(grep -c '^systemctl daemon-reload$' "$SUDO_LOG")" -eq 1 ]
}
