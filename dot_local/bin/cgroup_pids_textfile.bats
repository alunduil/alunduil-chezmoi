#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SAMPLER="$REPO_ROOT/dot_local/bin/executable_cgroup-pids-textfile"

  TMPROOT="$(mktemp -d)"
  export NODE_TEXTFILE_DIR="$TMPROOT/textfile"
  export CGROUP_PIDS_ROOT="$TMPROOT/cgroup"
  SLICE_DIR="$CGROUP_PIDS_ROOT/user.slice/user-$(id -u).slice"
  mkdir -p "$SLICE_DIR"
  PROM="$NODE_TEXTFILE_DIR/cgroup_pids.prom"
}

teardown() { rm -rf "$TMPROOT"; }

@test "publishes the slice's pids counters" {
  echo 42 >"$SLICE_DIR/pids.current"
  echo 10813 >"$SLICE_DIR/pids.max"

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_current{slice=\"user-$(id -u).slice\"} 42" "$PROM"
  grep -qx "cgroup_pids_max{slice=\"user-$(id -u).slice\"} 10813" "$PROM"
}

@test "an unlimited pool publishes +Inf" {
  echo 42 >"$SLICE_DIR/pids.current"
  echo max >"$SLICE_DIR/pids.max"

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_max{slice=\"user-$(id -u).slice\"} +Inf" "$PROM"
}

@test "a failed read withdraws the previous sample" {
  echo 42 >"$SLICE_DIR/pids.current"
  echo 10813 >"$SLICE_DIR/pids.max"
  run bash "$SAMPLER"
  [ -f "$PROM" ]

  rm "$SLICE_DIR/pids.max"
  run bash "$SAMPLER"

  [ "$status" -ne 0 ]
  [ -z "$(ls -A "$NODE_TEXTFILE_DIR")" ]
}
