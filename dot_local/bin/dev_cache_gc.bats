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

# run_dev_cache_gc [ARGS...]: run dev-cache-gc under an emptied environment,
# as the systemd unit does, passing through only what the stubs read.
run_dev_cache_gc() {
  run env -i HOME="$HOME" PATH="$PATH" GC_LOG="$GC_LOG" GC_FAIL="$GC_FAIL" bash "$GC" "$@"
}

@test "runs each tool's native GC with the expected flags" {
  stub_tools ghcup npm cargo-cache pnpm prek pre-commit mise
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  grep -qx "ghcup	gc -c -t" "$GC_LOG"
  grep -qx "npm	cache npx rm --force" "$GC_LOG"
  grep -qx "npm	cache verify" "$GC_LOG"
  grep -qx "cargo-cache	--autoclean" "$GC_LOG"
  grep -qx "pnpm	store prune" "$GC_LOG"
  grep -qx "prek	cache gc" "$GC_LOG"
  grep -qx "pre-commit	gc" "$GC_LOG"
  grep -qx "mise	prune --yes" "$GC_LOG"
}

@test "mise shims are put on PATH so mise-pinned tools resolve" {
  mkdir -p "$HOME/.local/share/mise/shims"
  ln -sf "$STUB_DIR/stub" "$HOME/.local/share/mise/shims/prek"
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  grep -qx "prek	cache gc" "$GC_LOG"
}

@test "a missing tool is skipped, not a failure" {
  stub_tools ghcup npm cargo-cache
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  # pnpm never ran, and the run still succeeded.
  [ "$(grep -c '^pnpm' "$GC_LOG")" -eq 0 ]
  [[ "$output" == *"pnpm store: pnpm absent, skipping"* ]]
}

@test "registry GC never dispatches through the cargo shim" {
  # `cargo` on PATH is rustup's shim, which fails with no default toolchain.
  stub_tools ghcup npm cargo cargo-cache pnpm
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  [ "$(grep -c '^cargo	' "$GC_LOG")" -eq 0 ]
  grep -qx "cargo-cache	--autoclean" "$GC_LOG"
}

@test "a failing tool is reported and non-fatal" {
  stub_tools ghcup npm cargo-cache pnpm
  export GC_FAIL="npm"
  run_dev_cache_gc
  [ "$status" -eq 1 ]
  # Every tool was still attempted — the npm failure didn't abort the sweep.
  grep -qx "ghcup	gc -c -t" "$GC_LOG"
  grep -qx "cargo-cache	--autoclean" "$GC_LOG"
  grep -qx "pnpm	store prune" "$GC_LOG"
  [[ "$output" == *"failed"* ]]
  [[ "$output" == *"npm cache"* ]]
}

@test "-h prints usage and exits 0" {
  run_dev_cache_gc -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-cache-gc"* ]]
}

@test "--help prints usage and exits 0" {
  run_dev_cache_gc --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: dev-cache-gc"* ]]
}

@test "an unknown option is rejected before any GC runs" {
  stub_tools ghcup npm cargo-cache pnpm
  run_dev_cache_gc --dry-run
  [ "$status" -eq 2 ]
  [[ "$output" == *"Error: No such option: --dry-run"* ]]
  [[ "$output" == *"Try 'dev-cache-gc --help' for help."* ]]
  [ ! -s "$GC_LOG" ]
}

@test "a stray argument is rejected before any GC runs" {
  stub_tools ghcup npm cargo-cache pnpm
  run_dev_cache_gc now
  [ "$status" -eq 2 ]
  [[ "$output" == *"Error: Got unexpected extra argument (now)"* ]]
  [ ! -s "$GC_LOG" ]
}
