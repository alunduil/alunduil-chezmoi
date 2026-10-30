#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

TOOLS=(lazygit yq github:grafana/alloy github:seachicken/gh-poi npm:bats-assert npm:bats-support)
# Read in a subshell so the script's shell options stay out of bats.
mapfile -t BINARIES < <(bash -c '
  source "$1"
  shift
  for tool; do
    read -r bin _ <<<"$(run_command "$tool")"
    [ -z "$bin" ] || printf "%s\n" "$bin"
  done' _ "$BATS_TEST_DIRNAME/pinned-tools" "${TOOLS[@]}")

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  WORK="$(mktemp -d)"
  mkdir -p "$WORK/stub" "$WORK/tools"
  for bin in "${BINARIES[@]}"; do
    fake_tool "$bin" "$bin"
  done
  printf '%s\n' "${TOOLS[@]}" >"$WORK/pins"

  # Stands in for mise: every tool in $WORK/pins is pinned.
  cat >"$WORK/stub/mise" <<EOF
#!/usr/bin/env bash
case "\$1" in
  ls) jq -Rn '[inputs | {(.): []}] | add' "$WORK/pins" ;;
  which) [ -x "$WORK/tools/\$2" ] && echo "$WORK/tools/\$2" || { echo "\$2 is not a mise bin" >&2; exit 1; } ;;
esac
EOF
  chmod +x "$WORK/stub/mise"
  PATH="$WORK/stub:$PATH"
}

teardown() {
  rm -rf "$WORK"
}

fake_tool() {
  printf '#!/bin/sh\necho "%s"\n' "$2" >"$WORK/tools/$1"
  chmod +x "$WORK/tools/$1"
}

@test "every tool that runs passes" {
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial 'OK: lazygit'
  assert_output --partial 'OK: github:grafana/alloy'
  assert_output --partial 'OK: github:seachicken/gh-poi'
}

@test "a library passes with nothing to run" {
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial 'OK: npm:bats-support'
}

@test "a backend-qualified pin runs the binary its last segment names" {
  rm "$WORK/tools/alloy"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: github:grafana/alloy: alloy is not a mise bin'
}

@test "a run command for an unpinned tool fails" {
  grep -vx npm:bats-assert "$WORK/pins" >"$WORK/pins.new"
  mv "$WORK/pins.new" "$WORK/pins"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'RUN_COMMANDS lists npm:bats-assert, which is not pinned'
}

@test "a missing binary fails" {
  rm "$WORK/tools/lazygit"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: lazygit: lazygit is not a mise bin'
}

@test "a binary that cannot execute fails" {
  printf '\x7fELF\x02\x01\x01garbage' >"$WORK/tools/lazygit"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: lazygit: `lazygit --version` exited non-zero'
}
