#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Passes run on every apply, so a converged host must never reach sudo.

setup() {
  WORK="$(mktemp -d)"
  export XDG_STATE_HOME="$WORK/state"
  # shellcheck source=script/lib/bootstrap.sh
  . "$BATS_TEST_DIRNAME/bootstrap.sh"
  SUDO_LOG="$WORK/sudo.log"
  : >"$SUDO_LOG"
  sudo() {
    printf '%s\n' "$*" >>"$SUDO_LOG"
    case "$1" in
    install | cp) command "$@" ;;
    esac
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
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null </dev/null
  [ ! -e "$WORK/dest.bak" ]
  cmp -s "$WORK/src" "$WORK/dest"
}

# script(1) gives install_if_changed a terminal on stdin.
on_terminal() {
  local answer="$1"
  printf '%s\n' "$answer" | script -qec "bash -c '
    export XDG_STATE_HOME=\"$XDG_STATE_HOME\"
    . \"$BATS_TEST_DIRNAME/bootstrap.sh\"
    sudo() { case \"\$1\" in install | cp) command \"\$@\" ;; esac; }
    install_if_changed -m 0644 \"$WORK/src\" \"$WORK/dest\"
  '" /dev/null >/dev/null
}

@test "on a terminal, declining keeps a file edited since the last apply" {
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null </dev/null
  printf 'hand-edit\n' >"$WORK/dest"
  printf 'next\n' >"$WORK/src"
  on_terminal n
  [ "$(cat "$WORK/dest")" = hand-edit ]
}

@test "on a terminal, a source change to an unedited file installs unasked" {
  install_if_changed -m 0644 "$WORK/src" "$WORK/dest" 2>/dev/null </dev/null
  printf 'next\n' >"$WORK/src"
  on_terminal n
  cmp -s "$WORK/src" "$WORK/dest"
}
