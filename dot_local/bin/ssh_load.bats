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
[ -z "$OP_FAIL" ] || exit 1
if [ -n "$OP_DAEMON" ]; then
  sleep 60 </dev/null >/dev/null 2>&1 3>&- &
  printf '%s\n' "$!" >"$OP_DAEMON_PID"
fi
printf 'FAKE KEY\n'
STUB
  chmod +x "$STUB_DIR/ssh-add" "$STUB_DIR/op"

  export AGENT_KEY="$TMPROOT/agent-key"
  export AGENT_LIFETIME="$TMPROOT/agent-lifetime"
  export OP_LOG="$TMPROOT/op.log"
  export OP_FAIL=""
  export OP_DAEMON=""
  export OP_DAEMON_PID="$TMPROOT/op-daemon.pid"
  export PATH="$STUB_DIR:/usr/bin:/bin"
}

teardown() {
  if [ -s "$OP_DAEMON_PID" ]; then
    kill "$(cat "$OP_DAEMON_PID")" 2>/dev/null || true
  fi
  rm -rf "$TMPROOT"
}

@test "leaves 1Password alone when the agent holds a key" {
  : >"$AGENT_KEY"
  run "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ ! -e "$OP_LOG" ]
}

@test "loads the key from 1Password for eight hours when the agent is empty" {
  run "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ "$(cat "$OP_LOG")" = "read op://vault/item/private key" ]
  [ "$(cat "$AGENT_KEY")" = "FAKE KEY" ]
  [ "$(cat "$AGENT_LIFETIME")" = "8h" ]
}

@test "a daemon left by 1Password does not block the next load" {
  OP_DAEMON=1 run "$SSH_LOAD"
  [ "$status" -eq 0 ]
  rm "$AGENT_KEY"
  run timeout 5 "$SSH_LOAD"
  [ "$status" -eq 0 ]
  [ "$(cat "$AGENT_KEY")" = "FAKE KEY" ]
}

@test "fails without calling ssh-add when 1Password refuses the read" {
  OP_FAIL=1 run "$SSH_LOAD"
  [ "$status" -ne 0 ]
  [ ! -e "$AGENT_LIFETIME" ]
}
