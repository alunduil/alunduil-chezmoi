#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  GC="$REPO_ROOT/dot_local/bin/executable_dev-cache-gc"

  TMPROOT="$(mktemp -d)"
  export HOME="$TMPROOT/home"
  mkdir -p "$HOME"

  # One stub binary, linked under each tool name: logs "<name>\t<args>" per call
  # so tests assert which GC ran with which flags. Exits non-zero when its name
  # is listed in $GC_FAIL, letting a test force one tool to error.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\t%s\n' "${0##*/}" "$*" >>"$GC_LOG"
for f in $GC_FAIL; do
  [[ "${0##*/}" == "$f" ]] && exit 1
done
exit 0
STUB
  chmod +x "$STUB_DIR/stub"
  export GC_LOG="$TMPROOT/gc.log"
  : >"$GC_LOG"
  export GC_FAIL=""
  export PATH="$STUB_DIR:/usr/bin:/bin"
}

teardown() { rm -rf "$TMPROOT"; }

# Link the stub under each given tool name so `command -v` finds it and calls
# route through the logging stub.
stub_tools() {
  local t
  for t in "$@"; do ln -sf "$STUB_DIR/stub" "$STUB_DIR/$t"; done
}

@test "runs each tool's native GC with the expected flags" {
  # cargo-cache gates the `cargo cache` call, so both binaries are present.
  stub_tools ghcup npm cargo cargo-cache pnpm
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC"
  [ "$status" -eq 0 ]
  grep -qx "ghcup	gc -c -t" "$GC_LOG"
  grep -qx "npm	cache verify" "$GC_LOG"
  grep -qx "cargo	cache --autoclean" "$GC_LOG"
  grep -qx "pnpm	store prune" "$GC_LOG"
}

@test "a missing tool is skipped, not a failure" {
  stub_tools ghcup npm cargo cargo-cache
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC"
  [ "$status" -eq 0 ]
  # pnpm never ran, and the run still succeeded.
  [ "$(grep -c '^pnpm' "$GC_LOG")" -eq 0 ]
  [[ "$output" == *"pnpm store: pnpm absent, skipping"* ]]
}

@test "cargo GC is gated on cargo-cache, not cargo" {
  # cargo present but cargo-cache absent: the registry GC must not run, since
  # `cargo cache` would be an unknown subcommand.
  stub_tools ghcup npm cargo pnpm
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC"
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cargo	' "$GC_LOG")" -eq 0 ]
  [[ "$output" == *"cargo registry: cargo-cache absent, skipping"* ]]
}

@test "a failing tool is reported and non-fatal" {
  stub_tools ghcup npm cargo cargo-cache pnpm
  export GC_FAIL="npm"
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC"
  [ "$status" -eq 1 ]
  # Every tool was still attempted — the npm failure didn't abort the sweep.
  grep -qx "ghcup	gc -c -t" "$GC_LOG"
  grep -qx "cargo	cache --autoclean" "$GC_LOG"
  grep -qx "pnpm	store prune" "$GC_LOG"
  [[ "$output" == *"failed"* ]]
  [[ "$output" == *"npm cache"* ]]
}

@test "-h prints usage and exits 0" {
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-cache-gc"* ]]
}
