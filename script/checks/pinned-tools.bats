#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

TOOLS=(lazygit yq github:grafana/alloy github:seachicken/gh-poi npm:bats-assert npm:bats-support)
# Every fake tool is pinned at this version.
PIN=1.2.3
# Read in a subshell so the script's shell options stay out of bats.
mapfile -t BINARIES < <(bash -c '
  source "$1"
  shift
  for tool; do
    read -r bin _ <<<"$(version_command "$tool")"
    declare -F "$bin" >/dev/null || printf "%s\n" "$bin"
  done' _ "$BATS_TEST_DIRNAME/pinned-tools" "${TOOLS[@]}")

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  WORK="$(mktemp -d)"
  mkdir -p "$WORK/stub" "$WORK/tools"
  for bin in "${BINARIES[@]}"; do
    fake_tool "$bin" "$bin version v$PIN"
  done
  # go_module_version reads the binary itself, so this fake carries Go's
  # module line.
  fake_tool gh-poi "$(printf 'mod\tgithub.com/seachicken/gh-poi\tv%s' "$PIN")"
  for tool in "${TOOLS[@]}"; do
    [[ "$tool" == npm:* ]] || continue
    mkdir -p "$WORK/npm/node_modules/${tool#npm:}"
    printf '{"version": "%s"}\n' "$PIN" >"$WORK/npm/node_modules/${tool#npm:}/package.json"
  done
  printf '%s\n' "${TOOLS[@]}" >"$WORK/pins"

  # Stands in for mise: every tool in $WORK/pins is pinned at $PIN, written
  # as the release tag v$PIN.
  cat >"$WORK/stub/mise" <<EOF
#!/usr/bin/env bash
case "\$1" in
  ls) jq -Rn '[inputs | {(.): [{requested_version: "v$PIN", version: "$PIN"}]}] | add' "$WORK/pins" ;;
  which) [ -x "$WORK/tools/\$2" ] && echo "$WORK/tools/\$2" || { echo "\$2 is not a mise bin" >&2; exit 1; } ;;
  where) printf '%s\n' "$WORK/npm" ;;
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

@test "every tool reporting its pin passes" {
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial "OK: lazygit $PIN"
  assert_output --partial "OK: github:grafana/alloy $PIN"
  assert_output --partial "OK: npm:bats-support $PIN"
  assert_output --partial "OK: github:seachicken/gh-poi $PIN"
}

@test "a binary omitting the pin's v prefix passes" {
  fake_tool alloy "alloy version $PIN"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_success
  assert_output --partial "OK: github:grafana/alloy $PIN"
}

@test "a backend-qualified pin runs the binary its last segment names" {
  rm "$WORK/tools/alloy"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'FAIL: github:grafana/alloy: alloy is not a mise bin'
}

@test "a version command for an unpinned tool fails" {
  grep -vx npm:bats-assert "$WORK/pins" >"$WORK/pins.new"
  mv "$WORK/pins.new" "$WORK/pins"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'VERSION_COMMANDS lists npm:bats-assert, which is not pinned'
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

@test "a binary reporting another version fails" {
  fake_tool lazygit 'lazygit version v1.2.4'
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial "FAIL: lazygit: \`lazygit --version\` does not report $PIN"
}

@test "a pin that prefixes the reported version fails" {
  fake_tool lazygit "lazygit version v${PIN}0"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial "does not report $PIN"
}
