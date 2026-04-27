#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  STUB_DIR="$(mktemp -d)"
  WRAPPER_DIR="$(mktemp -d)"

  cat >"$STUB_DIR/gh" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$STUB_DIR/gh"

  # Copy (not symlink) the wrapper so it has its own inode — readlink -f
  # will resolve to the copy, and the stub gets a different canonical path.
  install -m 0755 "$REPO_ROOT/dot_local/bin/executable_gh" "$WRAPPER_DIR/gh"

  export PATH="$WRAPPER_DIR:$STUB_DIR:/usr/bin:/bin"
  unset GH_DRAFT_GUARD
}

teardown() {
  rm -rf "$STUB_DIR" "$WRAPPER_DIR"
}

@test "blocks 'gh pr create' without --draft" {
  run "$WRAPPER_DIR/gh" pr create --title "test"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must include --draft"* ]]
}

@test "allows 'gh pr create --draft'" {
  run "$WRAPPER_DIR/gh" pr create --draft --title "test"
  [ "$status" -eq 0 ]
}

@test "allows 'gh pr create -d'" {
  run "$WRAPPER_DIR/gh" pr create -d --title "test"
  [ "$status" -eq 0 ]
}

@test "bypasses guard with GH_DRAFT_GUARD=off" {
  export GH_DRAFT_GUARD=off
  run "$WRAPPER_DIR/gh" pr create --title "test"
  [ "$status" -eq 0 ]
}

@test "passes through non-pr commands" {
  run "$WRAPPER_DIR/gh" repo list
  [ "$status" -eq 0 ]
}

@test "passes through pr subcommands other than create" {
  run "$WRAPPER_DIR/gh" pr list
  [ "$status" -eq 0 ]
}

@test "exits 127 when no real gh is on PATH" {
  EMPTY_DIR="$(mktemp -d)"
  for bin in readlink printf bash cat; do
    p="$(command -v "$bin" 2>/dev/null)" && ln -sf "$p" "$EMPTY_DIR/$bin"
  done
  run -127 env PATH="$WRAPPER_DIR:$EMPTY_DIR" "$WRAPPER_DIR/gh" --version
  rm -rf "$EMPTY_DIR"
  [ "$status" -eq 127 ]
  [[ "$output" == *"real gh not found"* ]]
}
