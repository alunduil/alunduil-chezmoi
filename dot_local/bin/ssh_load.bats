#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  TMPROOT="$(mktemp -d)"
  export XDG_RUNTIME_DIR="$TMPROOT/run"
  mkdir -p "$XDG_RUNTIME_DIR"

  # Render the one template expression with a stand-in reference.
  SSH_LOAD="$TMPROOT/ssh-load"
  sed 's|{{ .onepassword.ssh_key }}|op://vault/item/private key|' \
    "$REPO_ROOT/dot_local/bin/executable_ssh-load.tmpl" >"$SSH_LOAD"
  chmod +x "$SSH_LOAD"

  # Stand-ins:
  # - The agent holds a key while $AGENT_KEY exists.
  # - op fails when $OP_FAIL is set.
  # - op leaves a child running, as op daemon does, when $OP_DAEMON is set.
  #   setsid keeps it alive when the test terminal closes, as op daemon does.
  # - logger appends its arguments to $LOGGER_LOG.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/ssh-add" <<'STUB'
#!/usr/bin/env bash
case "$1" in
  -l) [ -e "$AGENT_KEY" ] ;;
  -t) printf '%s\n' "$2" >"$AGENT_LIFETIME" && cat >"$AGENT_KEY" ;;
esac
STUB
  cat >"$STUB_DIR/op" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$OP_LOG"
if [ -n "$OP_FAIL" ]; then
  echo "cannot connect to 1Password app" >&2
  exit 1
fi
if [ -n "$OP_DAEMON" ]; then
  setsid sleep 60 </dev/null >/dev/null 2>&1 3>&- &
  printf '%s\n' "$!" >"$OP_DAEMON_PID"
fi
printf 'FAKE KEY\n'
STUB
  cat >"$STUB_DIR/logger" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LOGGER_LOG"
STUB
  chmod +x "$STUB_DIR/ssh-add" "$STUB_DIR/op" "$STUB_DIR/logger"

  export AGENT_KEY="$TMPROOT/agent-key"
  export AGENT_LIFETIME="$TMPROOT/agent-lifetime"
  export OP_LOG="$TMPROOT/op.log"
  export OP_FAIL=""
  export OP_DAEMON=""
  export OP_DAEMON_PID="$TMPROOT/op-daemon.pid"
  export LOGGER_LOG="$TMPROOT/logger.log"
  export PATH="$STUB_DIR:/usr/bin:/bin"
}

# Runs ssh-load with a controlling terminal, as ssh passes one through
# `Match exec` when a person runs it.
in_terminal() {
  script -qec "$*" /dev/null </dev/null
}

# Runs ssh-load in a new session with no controlling terminal, as status bars
# and timers do.
without_terminal() {
  setsid -w "$@" </dev/null
}

teardown() {
  if [ -s "$OP_DAEMON_PID" ]; then
    kill "$(cat "$OP_DAEMON_PID")" 2>/dev/null || true
  fi
  rm -rf "$TMPROOT"
}

@test "leaves 1Password alone when the agent holds a key, even without a terminal" {
  : >"$AGENT_KEY"
  run without_terminal "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ ! -e "$OP_LOG" ]
}

@test "loads the key from 1Password for eight hours when the agent is empty" {
  run in_terminal "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ "$(cat "$OP_LOG")" = "read op://vault/item/private key" ]
  [ "$(cat "$AGENT_KEY")" = "FAKE KEY" ]
  [ "$(cat "$AGENT_LIFETIME")" = "8h" ]
}

@test "fails fast without a terminal, leaving 1Password and the lock alone" {
  run without_terminal timeout 5 "$SSH_LOAD"
  [ "$status" -eq 1 ]
  [[ "$output" == *"run ssh-load from a terminal"* ]]
  [ ! -e "$OP_LOG" ]
  [ ! -e "$XDG_RUNTIME_DIR/ssh-load.lock" ]
}

@test "records each read in the journal" {
  run in_terminal "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [[ "$(cat "$LOGGER_LOG")" == "-t ssh-load op read exited 0 after "* ]]
}

@test "a daemon left by 1Password does not block the next load" {
  OP_DAEMON=1 run in_terminal "$SSH_LOAD"
  [ "$status" -eq 0 ]
  rm "$AGENT_KEY"
  run in_terminal timeout 5 "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ "$(cat "$AGENT_KEY")" = "FAKE KEY" ]
}

@test "fails without calling ssh-add when 1Password refuses the read, saying why" {
  OP_FAIL=1 run in_terminal "$SSH_LOAD"
  [ "$status" -ne 0 ]
  [ ! -e "$AGENT_LIFETIME" ]
  [[ "$output" == *"cannot connect to 1Password app"* ]]
  [[ "$(cat "$LOGGER_LOG")" == *"exited 1 after "*": cannot connect to 1Password app"* ]]
}
