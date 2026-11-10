#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
bats_load_library bats-support
bats_load_library bats-assert

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/docker-prune-orphans.sh"
  TMPROOT="$(mktemp -d)"
  mkdir -p "$TMPROOT/stubs" "$TMPROOT/present"
  DOCKER_LOG="$TMPROOT/docker.log"
  # `ps` lists one container whose folder exists and one whose folder is gone.
  cat >"$TMPROOT/stubs/docker" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$DOCKER_LOG"
[[ "\$1" == ps ]] && printf 'aaa\t%s\nbbb\t%s\n' "$TMPROOT/present" "$TMPROOT/gone"
exit 0
STUB
  chmod +x "$TMPROOT/stubs/docker"
}

teardown() {
  rm -rf "$TMPROOT"
}

@test "removes only the containers whose folder is gone" {
  PATH="$TMPROOT/stubs:$PATH" run bash "$SCRIPT"
  assert_success
  assert_output --partial "removing bbb"
  run grep '^rm' "$DOCKER_LOG"
  assert_output 'rm -f bbb'
}
