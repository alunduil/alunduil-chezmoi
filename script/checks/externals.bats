#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Exercises pinned externals the bootstrap invokes. The chezmoi CI check
# excludes scripts, so the .chezmoiscripts/ passes never run there. These
# catch a CLI rename (gcx v0.2.14 moved `skills` under `agent`) or an
# interface change before it breaks `chezmoi apply`. Keep the arguments in
# sync with .chezmoiscripts/run_after_install-via-externals.sh.tmpl.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DEST="$(mktemp -d)"
  mkdir -p "$DEST/.local/bin"
}

teardown() {
  rm -rf "$DEST"
}

apply_external() {
  chezmoi apply --source="$REPO_ROOT" --destination="$DEST" \
    --include=externals "$DEST/.local/bin/$1"
}

@test "pinned gcx accepts bootstrap skills-install invocation" {
  apply_external gcx
  run "$DEST/.local/bin/gcx" agent skills install --all --force --dry-run
  [ "$status" -eq 0 ]
}

@test "pinned uv exposes the tool-install interface" {
  apply_external uv
  run "$DEST/.local/bin/uv" tool install --force --help
  [ "$status" -eq 0 ]
}
