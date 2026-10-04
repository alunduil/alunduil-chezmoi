#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Catches gcx CLI renames/removals (e.g. v0.2.13->v0.2.14 moved `skills`
# under `agent`) before they break `chezmoi apply`. The chezmoi CI check
# excludes scripts, so the .chezmoiscripts/ bootstrap never executes there —
# this test fills that gap by exercising the pinned binary directly. Keep
# args in sync with .chezmoiscripts/run_after_install-gcx-skills.sh.tmpl.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  DEST="$(mktemp -d)"
  mkdir -p "$DEST/.local/bin"
}

teardown() {
  rm -rf "$DEST"
}

@test "pinned gcx accepts bootstrap skills-install invocation" {
  chezmoi apply --source="$REPO_ROOT" --destination="$DEST" \
    --include=externals "$DEST/.local/bin/gcx"
  run "$DEST/.local/bin/gcx" agent skills install --all --force --dry-run
  [ "$status" -eq 0 ]
}
