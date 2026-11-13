#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

TOOLS=(act lazygit yq ormolu github:fourmolu/fourmolu github:grafana/alloy github:seachicken/gh-poi npm:bats-assert npm:bats-support)
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
    fake_tool "$bin"
  done
  # lazygit is in TUI, so its stand-in passes only in a pseudo-terminal.
  fake_tool lazygit '[ -t 0 ] && [ -t 1 ] || exit 1
exec sleep 30'
  printf '%s\n' "${TOOLS[@]}" >"$WORK/pins"

  # Stands in for mise.
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
  printf '#!/bin/sh\n%s\n' "${2:-}" >"$WORK/tools/$1"
  chmod +x "$WORK/tools/$1"
}

@test "every tool that runs passes" {
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial 'OK: lazygit'
  assert_output --partial 'OK: yq'
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

@test "a tool reading stdin leaves the rest of the pins checked" {
  printf '#!/bin/sh\ncat >/dev/null\n' >"$WORK/tools/act"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial 'OK: act'
  assert_output --partial 'OK: npm:bats-support'
}

@test "run commands start in the repository root" {
  printf '#!/bin/sh\ntest -d .github/workflows\n' >"$WORK/tools/act"
  cd "$WORK"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial 'OK: act'
}

@test "every tool renovate.json trusts pinned-tools to exercise has a run command" {
  run bash -c '
    source "$1"
    mapfile -t deps < <(jq -r ".packageRules[]
      | select(.description | contains(\"script/checks/pinned-tools\"))
      | .matchDepNames[]" "$2")
    [ "${#deps[@]}" -gt 0 ] || { echo "no renovate.json rule names pinned-tools"; exit 1; }
    for dep in "${deps[@]}"; do
      [ -n "${RUN_COMMANDS[$dep]:-}" ] || echo "no run command: $dep"
    done' _ "$BATS_TEST_DIRNAME/pinned-tools" "$BATS_TEST_DIRNAME/../../renovate.json"
  assert_success
  assert_output ''
}

@test "a missing binary fails" {
  rm "$WORK/tools/yq"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: yq: yq is not a mise bin'
}

@test "a binary that cannot execute fails" {
  printf '\x7fELF\x02\x01\x01garbage' >"$WORK/tools/yq"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: yq: `yq --version` exited non-zero'
}

@test "a TUI that exits before the timeout fails with its output" {
  fake_tool lazygit "echo 'config could not be parsed'"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: lazygit: `lazygit -ucf dot_config/lazygit/config.yml` exited before 3s'
  assert_output --partial 'config could not be parsed'
}
