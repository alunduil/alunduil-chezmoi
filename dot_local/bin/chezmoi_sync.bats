#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  STUB_DIR="$(mktemp -d)"
  WRAPPER_DIR="$(mktemp -d)"
  TOKEN_DIR="$(mktemp -d)"

  # op stub: `whoami` succeeds only for the token value "good".
  cat >"$STUB_DIR/op" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  whoami) [ "${OP_SERVICE_ACCOUNT_TOKEN:-}" = good ] && exit 0 || exit 1 ;;
esac
exit 0
STUB
  chmod +x "$STUB_DIR/op"

  # chezmoi stub: echo the args so tests can assert pass-through.
  cat >"$STUB_DIR/chezmoi" <<'STUB'
#!/usr/bin/env bash
echo "chezmoi $*"
STUB
  chmod +x "$STUB_DIR/chezmoi"

  install -m 0755 "$REPO_ROOT/dot_local/bin/executable_chezmoi-sync" "$WRAPPER_DIR/chezmoi-sync"

  export PATH="$WRAPPER_DIR:$STUB_DIR:/usr/bin:/bin"
  export OP_TOKEN_FILE="$TOKEN_DIR/token"
}

teardown() {
  rm -rf "$STUB_DIR" "$WRAPPER_DIR" "$TOKEN_DIR"
}

@test "valid token passes through and defaults to apply" {
  printf 'good' >"$OP_TOKEN_FILE"
  run "$WRAPPER_DIR/chezmoi-sync"
  [ "$status" -eq 0 ]
  [[ "$output" == *"chezmoi apply"* ]]
}

@test "arguments pass through to chezmoi" {
  printf 'good' >"$OP_TOKEN_FILE"
  run "$WRAPPER_DIR/chezmoi-sync" update --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"chezmoi update --dry-run"* ]]
}

@test "rejected token with no terminal fails instead of hanging" {
  printf 'bad' >"$OP_TOKEN_FILE"
  run "$WRAPPER_DIR/chezmoi-sync"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no terminal"* ]]
}

@test "missing token file with no terminal fails cleanly" {
  run "$WRAPPER_DIR/chezmoi-sync"
  [ "$status" -ne 0 ]
  [[ "$output" == *"no terminal"* ]]
}

@test "missing op is reported" {
  ONLY="$(mktemp -d)"
  for bin in bash printf cat mktemp dirname; do
    p="$(command -v "$bin" 2>/dev/null)" && ln -sf "$p" "$ONLY/$bin"
  done
  install -m 0755 "$STUB_DIR/chezmoi" "$ONLY/chezmoi"
  run env PATH="$WRAPPER_DIR:$ONLY" OP_TOKEN_FILE="$OP_TOKEN_FILE" "$WRAPPER_DIR/chezmoi-sync"
  rm -rf "$ONLY"
  [ "$status" -ne 0 ]
  [[ "$output" == *"op) is not on PATH"* ]]
}
