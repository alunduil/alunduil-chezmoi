#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises the pinned uv binary directly: the chezmoi CI check excludes
# scripts, so the .chezmoiscripts/ bootstrap never runs there. Catches a
# broken release asset (URL/name) on a version bump, and a `uv tool install`
# interface change that would break the bootstrap's pre-commit step, before
# either reaches `chezmoi apply`. Keep the install flags in sync with
# .chezmoiscripts/run_after_install-uv-tools.sh.tmpl.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DEST="$(mktemp -d)"
  mkdir -p "$DEST/.local/bin"
}

teardown() {
  rm -rf "$DEST"
}

@test "pinned uv installs and exposes the tool-install interface" {
  chezmoi apply --source="$REPO_ROOT" --destination="$DEST" \
    --include=externals "$DEST/.local/bin/uv"
  run "$DEST/.local/bin/uv" tool install --force --help
  [ "$status" -eq 0 ]
}
