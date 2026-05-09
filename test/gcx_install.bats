#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Catches gcx CLI renames/removals (e.g. v0.2.13->v0.2.14 moved `skills`
# under `agent`) before they break `chezmoi apply`. The chezmoi CI check
# excludes scripts, so run_once_before_* never executes there — this
# test fills that gap by exercising the pinned binary directly. Keep
# args in sync with run_once_before_02-install-binary-tools.sh.tmpl.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BIN_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$BIN_DIR"
}

@test "pinned gcx accepts bootstrap skills-install invocation" {
  "$REPO_ROOT/script/install/gcx" --bin-dir "$BIN_DIR"
  run "$BIN_DIR/gcx" agent skills install --all --force --dry-run
  [ "$status" -eq 0 ]
}
