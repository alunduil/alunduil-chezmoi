#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Read in a subshell so the script's shell options stay out of bats.
mapfile -t TOOLS < <(bash -c 'source "$1"; printf "%s\n" "${!VERSION_COMMANDS[@]}"' _ "$BATS_TEST_DIRNAME/pinned-tools")
mapfile -t BINARIES < <(bash -c '
  source "$1"
  for cmd in "${VERSION_COMMANDS[@]}"; do
    read -r bin _ <<<"$cmd"
    declare -F "$bin" >/dev/null || printf "%s\n" "$bin"
  done' _ "$BATS_TEST_DIRNAME/pinned-tools")

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  WORK="$(mktemp -d)"
  mkdir -p "$WORK/stub" "$WORK/tools"
  for bin in "${BINARIES[@]}"; do
    fake_tool "$bin" "$bin version v1.2.3"
  done
  # go_module_version reads the binary itself, so this fake carries Go's
  # module line.
  fake_tool gh-poi "$(printf 'mod\tgithub.com/seachicken/gh-poi\tv1.2.3')"
  for tool in "${TOOLS[@]}"; do
    [[ "$tool" == npm:* ]] || continue
    mkdir -p "$WORK/npm/node_modules/${tool#npm:}"
    printf '{"version": "1.2.3"}\n' >"$WORK/npm/node_modules/${tool#npm:}/package.json"
  done
  printf '%s\n' "${TOOLS[@]}" >"$WORK/pins"

  # Stands in for mise: every tool in $WORK/pins is pinned at 1.2.3.
  cat >"$WORK/stub/mise" <<EOF
#!/usr/bin/env bash
case "\$1" in
  ls) jq -Rn '[inputs | {(.): [{requested_version: "1.2.3"}]}] | add' "$WORK/pins" ;;
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
  assert_output --partial 'OK: lazygit 1.2.3'
  assert_output --partial 'OK: npm:bats-support 1.2.3'
  assert_output --partial 'OK: github:seachicken/gh-poi 1.2.3'
}

@test "a pin with no version command fails" {
  printf 'github:example/new-tool\n' >>"$WORK/pins"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'github:example/new-tool has no entry in VERSION_COMMANDS'
}

@test "a version command for an unpinned tool fails" {
  grep -vx yq "$WORK/pins" >"$WORK/pins.new"
  mv "$WORK/pins.new" "$WORK/pins"
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'VERSION_COMMANDS lists yq, which is not pinned'
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
  assert_output --partial 'FAIL: lazygit: `lazygit --version` does not report 1.2.3'
}

@test "a pin that prefixes the reported version fails" {
  fake_tool lazygit 'lazygit version v1.2.30'
  run "$BATS_TEST_DIRNAME/pinned-tools"
  assert_failure
  assert_output --partial 'does not report 1.2.3'
}
