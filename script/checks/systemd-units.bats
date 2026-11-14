#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  # shellcheck source=script/checks/systemd-units
  source "$BATS_TEST_DIRNAME/systemd-units"
  cd "$BATS_TEST_TMPDIR" || return 1
}

@test "a warning naming our unit by path is kept" {
  run warnings_about units/foo.service <<<"$PWD/units/foo.service:5: Unknown key 'Bogus' in section [Service], ignoring."
  assert_output "$PWD/units/foo.service:5: Unknown key 'Bogus' in section [Service], ignoring."
}

@test "a warning naming our unit by name is kept" {
  run warnings_about units/foo.service <<<'foo.service: Command /nonexistent is not executable'
  assert_output 'foo.service: Command /nonexistent is not executable'
}

@test "a warning about a host unit is dropped" {
  run warnings_about units/foo.service <<<'/usr/lib/systemd/system/walinuxagent.service:21: Support for option CPUAccounting= has been removed and it is ignored'
  assert_success
  assert_output ''
}

@test "a host unit sharing our unit's name is dropped" {
  run warnings_about units/foo.service <<<'/usr/lib/systemd/system/foo.service:3: Unknown key'
  assert_output ''
}
