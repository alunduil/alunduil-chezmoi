#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises the pinned uv binary directly: the chezmoi CI check excludes
# scripts, so .chezmoiscripts/run_onchange_before_02 never runs there. Catches a broken release
# asset (URL/name/checksum) on a version bump, and a `uv tool install`
# interface change that would break the bootstrap's pre-commit step, before
# either reaches `chezmoi apply`. Keep the install flags in sync with
# .chezmoiscripts/run_onchange_before_02-install-binary-tools.sh.tmpl.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  BIN_DIR="$(mktemp -d)"
}

teardown() {
  rm -rf "$BIN_DIR"
}

@test "pinned uv installs and exposes the tool-install interface" {
  "$REPO_ROOT/script/install/uv" --bin-dir "$BIN_DIR"
  run "$BIN_DIR/uv" tool install --force --help
  [ "$status" -eq 0 ]
}
