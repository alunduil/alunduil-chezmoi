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

  # Stand-ins: the agent holds a key while $AGENT_KEY exists, and op fails
  # when $OP_FAIL is set.
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
printf 'FAKE KEY\n'
STUB
  chmod +x "$STUB_DIR/ssh-add" "$STUB_DIR/op"

  export AGENT_KEY="$TMPROOT/agent-key"
  export AGENT_LIFETIME="$TMPROOT/agent-lifetime"
  export OP_LOG="$TMPROOT/op.log"
  export OP_FAIL=""
  export PATH="$STUB_DIR:/usr/bin:/bin"
}

teardown() { rm -rf "$TMPROOT"; }

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

@test "fails when 1Password refuses the read" {
  OP_FAIL=1 run "$SSH_LOAD"
  [ "$status" -ne 0 ]
}
