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

# run_dev_cache_gc [ARGS...]: run the script with the bare environment the
# systemd unit gives it.
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

@test "mise-pinned tools resolve through the mise shims" {
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

# stub_rustup LIST_LINE...: a rustup whose `toolchain list` prints the given
# lines, logging every other call. Uninstalls honour $GC_FAIL.
stub_rustup() {
  printf '%s\n' "$@" >"$TMPROOT/toolchains"
  cat >"$STUB_DIR/rustup" <<STUB
#!/usr/bin/env bash
if [[ "\$*" == "toolchain list" ]]; then
  cat "$TMPROOT/toolchains"
  exit 0
fi
printf 'rustup\t%s\n' "\$*" >>"\$GC_LOG"
[[ " \$GC_FAIL " != *" rustup "* ]]
STUB
  chmod +x "$STUB_DIR/rustup"
}

# pin_toolchain PATH CONTENT: write a rust-toolchain file under $HOME.
pin_toolchain() {
  mkdir -p "$(dirname "$HOME/$1")"
  printf '%s\n' "$2" >"$HOME/$1"
}

TRIPLE=x86_64-unknown-linux-gnu

@test "rust toolchains: only those neither default nor pinned are uninstalled" {
  stub_rustup "1.97.1-$TRIPLE" "1.98.1-$TRIPLE" "1.99.1-$TRIPLE (active, default)"
  pin_toolchain .local/share/git-worktrees/me/repo/pet/rust-toolchain.toml \
    $'[toolchain]\nchannel = "1.98.1"\ncomponents = ["clippy"]'
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  [ "$(grep -c '^rustup' "$GC_LOG")" -eq 1 ]
  grep -qx "rustup	toolchain uninstall 1.97.1-$TRIPLE" "$GC_LOG"
}

@test "rust toolchains: main clones and plain rust-toolchain files count as pins" {
  stub_rustup "1.97.1-$TRIPLE" "1.98.1-$TRIPLE" "1.99.1-$TRIPLE (default)"
  pin_toolchain repo/rust-toolchain.toml $'[toolchain]\nchannel = \'1.98.1\''
  pin_toolchain other/rust-toolchain "1.97.1"
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  [ "$(grep -c '^rustup' "$GC_LOG")" -eq 0 ]
}

@test "rust toolchains: a channel-name pin never removes the default" {
  stub_rustup "stable-$TRIPLE (default)" "1.97.1-$TRIPLE"
  pin_toolchain repo/rust-toolchain.toml $'[toolchain]\nchannel = "nightly"'
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  [ "$(grep -c '^rustup' "$GC_LOG")" -eq 1 ]
  grep -qx "rustup	toolchain uninstall 1.97.1-$TRIPLE" "$GC_LOG"
}

@test "rust toolchains: a pin is matched whole, not as a version prefix" {
  stub_rustup "1.98.1-$TRIPLE" "1.99.1-$TRIPLE (default)"
  pin_toolchain repo/rust-toolchain.toml $'[toolchain]\nchannel = "1.98"'
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  grep -qx "rustup	toolchain uninstall 1.98.1-$TRIPLE" "$GC_LOG"
}

@test "rust toolchains: pins in dependency and hidden directories don't count" {
  stub_rustup "1.97.1-$TRIPLE" "1.99.1-$TRIPLE (default)"
  pin_toolchain repo/node_modules/dep/rust-toolchain "1.97.1"
  pin_toolchain repo/target/package/rust-toolchain "1.97.1"
  pin_toolchain .cargo/registry/src/dep/rust-toolchain "1.97.1"
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  grep -qx "rustup	toolchain uninstall 1.97.1-$TRIPLE" "$GC_LOG"
}

@test "rust toolchains: a missing rustup is skipped like any other tool" {
  run_dev_cache_gc
  [ "$status" -eq 0 ]
  [[ "$output" == *"rust toolchains: rustup absent, skipping"* ]]
  [[ "$output" != *"==> rust toolchains"* ]]
}

@test "rust toolchains: a failed uninstall is reported and non-fatal" {
  stub_tools pnpm
  stub_rustup "1.97.1-$TRIPLE" "1.99.1-$TRIPLE (default)"
  export GC_FAIL="rustup"
  run_dev_cache_gc
  [ "$status" -eq 1 ]
  [[ "$output" == *"rust toolchains"* ]]
  grep -qx "pnpm	store prune" "$GC_LOG"
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
