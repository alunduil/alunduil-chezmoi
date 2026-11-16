#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  SAMPLER="$REPO_ROOT/dot_local/bin/executable_cgroup-pids-textfile"

  TMPROOT="$(mktemp -d)"
  export NODE_TEXTFILE_DIR="$TMPROOT/textfile"
  export CGROUP_ROOT="$TMPROOT/cgroup"
  SLICE="user-$(id -u).slice"
  SLICE_DIR="$CGROUP_ROOT/pids/user.slice/$SLICE"
  PROM="$NODE_TEXTFILE_DIR/cgroup_pids.prom"
}

teardown() { rm -rf "$TMPROOT"; }

counters() {
  local dir="${3:-$SLICE_DIR}"
  mkdir -p "$dir"
  echo "$1" >"$dir/pids.current"
  echo "$2" >"$dir/pids.max"
}

@test "publishes the slice's pids counters" {
  counters 42 10813

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_current{slice=\"$SLICE\"} 42" "$PROM"
  grep -qx "cgroup_pids_max{slice=\"$SLICE\"} 10813" "$PROM"
}

@test "reads the unified hierarchy when no pids controller is mounted" {
  counters 7 4096 "$CGROUP_ROOT/user.slice/$SLICE"

  run bash "$SAMPLER"

  [ "$status" -eq 0 ]
  grep -qx "cgroup_pids_current{slice=\"$SLICE\"} 7" "$PROM"
  grep -qx "cgroup_pids_max{slice=\"$SLICE\"} 4096" "$PROM"
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

@test "--help prints usage without publishing" {
  counters 42 10813

  run bash "$SAMPLER" --help

  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: cgroup-pids-textfile"* ]]
  [ ! -e "$PROM" ]
}

@test "an unknown option is rejected without publishing" {
  counters 42 10813

  run bash "$SAMPLER" --bogus

  [ "$status" -eq 2 ]
  [[ "$output" == *"Error: No such option: --bogus"* ]]
  [[ "$output" == *"Try 'cgroup-pids-textfile --help' for help."* ]]
  [ ! -e "$PROM" ]
}
