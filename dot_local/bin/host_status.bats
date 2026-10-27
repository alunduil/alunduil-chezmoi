#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
bats_load_library bats-support
bats_load_library bats-assert

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

  TMPROOT="$(mktemp -d)"
  export HOME="$TMPROOT/home"

  # Render the one template expression with a stand-in package list.
  HOST_STATUS="$TMPROOT/host-status"
  sed 's|{{ join " " .packages.apt }}|gh gource|' \
    "$REPO_ROOT/dot_local/bin/executable_host-status.tmpl" >"$HOST_STATUS"

  # A fully set-up host: every credential present, every stub succeeding.
  for f in .claude/.credentials.json .config/gcx/config.yaml .readwise-cli.json \
    .config/keybase/config.json .config/Signal/sql/db.sqlite; do
    mkdir -p "$(dirname "$HOME/$f")"
    printf 'x' >"$HOME/$f"
  done

  # PATH holds only these stubs, so the host's own tools never answer.
  # - gh fails `auth token` when $GH_LOGGED_OUT is set.
  # - systemctl fails for units named in $INACTIVE_UNITS, and fails
  #   show-environment when $NO_USER_MANAGER is set.
  # - dpkg-query reports each package installed except those in $MISSING_PKGS.
  # - mise prints $MISE_MISSING as its missing-tool listing.
  STUB_DIR="$TMPROOT/stubs"
  mkdir -p "$STUB_DIR"
  stub gh '[ -z "${GH_LOGGED_OUT:-}" ]'
  stub systemctl '
[ "$2" = show-environment ] && { [ -z "${NO_USER_MANAGER:-}" ]; exit; }
for u in $INACTIVE_UNITS; do [ "$u" = "${!#}" ] && exit 3; done
exit 0'
  stub dpkg-query '
shift 2
for p; do
  case " $MISSING_PKGS " in *" $p "*) ;; *) printf "%s installed\n" "$p" ;; esac
done'
  stub mise 'printf "%s" "${MISE_MISSING:-}"'
  local cmd
  while read -r cmd; do
    [ -e "$STUB_DIR/$cmd" ] || stub "$cmd" 'exit 0'
  done < <(bash -c 'source "$1"; printf "%s\n" "${commands[@]}"' _ "$HOST_STATUS")
  export INACTIVE_UNITS='' MISSING_PKGS=''
}

teardown() {
  rm -rf "$TMPROOT"
}

stub() {
  printf '#!%s\n%s\n' "$BASH" "$2" >"$STUB_DIR/$1"
  chmod +x "$STUB_DIR/$1"
}

run_host_status() {
  run env PATH="$STUB_DIR" "$BASH" "$HOST_STATUS"
}

@test "fully set-up host prints nothing and exits 0" {
  run_host_status
  assert_success
  refute_output
}

@test "gh logged out prints gh auth login and exits non-zero" {
  GH_LOGGED_OUT=1 run_host_status
  assert_failure
  assert_output --regexp '^gh: not logged in +gh auth login$'
}

@test "a missing credential file names its login command" {
  rm "$HOME/.config/gcx/config.yaml"
  run_host_status
  assert_failure
  assert_output --regexp '^gcx: not logged in +gcx login$'
}

@test "inactive units name the scoped enable command" {
  INACTIVE_UNITS='alloy.service sysstat-collect.timer' run_host_status
  assert_failure
  assert_line --regexp '^alloy\.service: not running +systemctl --user enable --now alloy\.service$'
  assert_line --regexp '^sysstat-collect\.timer: not running +sudo systemctl enable --now sysstat-collect\.timer$'
  assert_equal "${#lines[@]}" 2
}

@test "an inactive 1password unit passes while the app runs" {
  stub pgrep '[ "$2" = 1password ]'
  INACTIVE_UNITS=1password.service run_host_status
  assert_success
  refute_output
}

@test "no user manager reports once instead of per user unit" {
  NO_USER_MANAGER=1 run_host_status
  assert_failure
  assert_output --regexp '^user units: no user systemd session +.*enable-linger [^ ]+$'
}

@test "missing apt package, mise tool, and command each name chezmoi apply" {
  rm "$STUB_DIR/beet"
  MISSING_PKGS=gource MISE_MISSING=$'zellij  0.45.1 (missing)  ~/.config/mise/config.toml  0.45.1\n' \
    run_host_status
  assert_failure
  assert_line --regexp '^gource: not installed +chezmoi apply$'
  assert_line --regexp '^zellij 0\.45\.1: not installed +chezmoi apply$'
  assert_line --regexp '^beet: not on PATH +chezmoi apply$'
  assert_equal "${#lines[@]}" 3
}

@test "an unknown option exits 2" {
  run env PATH="$STUB_DIR" "$BASH" "$HOST_STATUS" --bogus
  assert_failure 2
}
