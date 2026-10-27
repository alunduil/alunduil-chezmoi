#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  CODECOV_API="$REPO_ROOT/dot_local/bin/executable_codecov-api"

  TMPROOT="$(mktemp -d)"

  # The curl stub logs its arguments, so tests can tell whether a request went
  # out.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CURL_LOG"
STUB
  chmod +x "$STUB_DIR/curl"
  export CURL_LOG="$TMPROOT/curl.log"
  export PATH="$STUB_DIR:/usr/bin:/bin"
  export CODECOV_API_TOKEN="token"
}

teardown() { rm -rf "$TMPROOT"; }

@test "forwards the path and curl arguments with the token" {
  run bash "$CODECOV_API" /graphql/ -X POST
  [ "$status" -eq 0 ]
  [[ "$(cat "$CURL_LOG")" == *"Authorization: bearer token https://api.codecov.io/graphql/ -X POST" ]]
}

@test "--help prints usage and exits 0 without a token" {
  unset CODECOV_API_TOKEN
  run bash "$CODECOV_API" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: codecov-api PATH"* ]]
  [ ! -e "$CURL_LOG" ]
}

@test "an unknown option is rejected without a request" {
  run bash "$CODECOV_API" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"Error: No such option: --bogus"* ]]
  [[ "$output" == *"Try 'codecov-api --help' for help."* ]]
  [ ! -e "$CURL_LOG" ]
}
