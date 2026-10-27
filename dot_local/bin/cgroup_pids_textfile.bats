#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SAMPLER="$REPO_ROOT/dot_local/bin/executable_cgroup-pids-textfile"

  TMPROOT="$(mktemp -d)"
  export NODE_TEXTFILE_DIR="$TMPROOT/textfile"
  export CGROUP_PIDS_ROOT="$TMPROOT/cgroup"
  SLICE="user-$(id -u).slice"
  SLICE_DIR="$CGROUP_PIDS_ROOT/user.slice/$SLICE"
  mkdir -p "$SLICE_DIR"
  PROM="$NODE_TEXTFILE_DIR/cgroup_pids.prom"
}

teardown() { rm -rf "$TMPROOT"; }

# Write the slice's pids.current and pids.max as the kernel would expose them.
counters() {
  echo "$1" >"$SLICE_DIR/pids.current"
  echo "$2" >"$SLICE_DIR/pids.max"
}

@test "publishes the slice's pids counters" {
  counters 42 10813

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_current{slice=\"$SLICE\"} 42" "$PROM"
  grep -qx "cgroup_pids_max{slice=\"$SLICE\"} 10813" "$PROM"
}

@test "an unlimited pool publishes +Inf" {
  counters 42 max

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_max{slice=\"$SLICE\"} +Inf" "$PROM"
}

@test "a failed read withdraws the previous sample" {
  counters 42 10813
  run bash "$SAMPLER"
  [ -f "$PROM" ]

  rm "$SLICE_DIR/pids.max"
  run bash "$SAMPLER"

  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$NODE_TEXTFILE_DIR")" ]
}
