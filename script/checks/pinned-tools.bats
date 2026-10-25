#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  WORK="$(mktemp -d)"
  mkdir -p "$WORK/stub" "$WORK/tools" "$WORK/missing"
  fake_tool default 'version v1.2.3'
  for lib in bats-assert bats-support; do
    mkdir -p "$WORK/npm/node_modules/$lib"
    printf '{"version": "1.2.3"}\n' >"$WORK/npm/node_modules/$lib/package.json"
  done
  # Pins mirror VERSION_COMMANDS, so the fixture passes by construction.
  sed -n 's/^  \[\([^]]*\)\]=.*/\1/p' "$BATS_TEST_DIRNAME/pinned-tools" >"$WORK/pins"

  # Stands in for mise: every pin is at 1.2.3, and every binary reports it
  # unless overridden in $WORK/tools or hidden under $WORK/missing.
  cat >"$WORK/stub/mise" <<EOF
#!/usr/bin/env bash
case "\$1" in
  ls) jq -Rn '[inputs | {(.): [{requested_version: "1.2.3"}]}] | add' "$WORK/pins" ;;
  which)
    if [ -e "$WORK/missing/\$2" ]; then echo "\$2 is not a mise bin" >&2; exit 1
    elif [ -e "$WORK/tools/\$2" ]; then echo "$WORK/tools/\$2"
    else echo "$WORK/tools/default"
    fi ;;
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
  touch "$WORK/missing/lazygit"
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
