# shellcheck shell=bash
# Shared helpers for .chezmoiscripts/ bootstrap passes. Passes source this
# from {{ .chezmoi.sourceDir }}:
# .chezmoiignore keeps script/ out of $HOME, but the source tree is always
# present at apply time.

log() { printf '==> %s\n' "$*" >&2; }

# The ERR handler for every pass that sources this file. chezmoi runs a pass
# from a randomly named temp file, so CHEZMOI_SOURCE_FILE supplies its name
# and phase.
_report_failed_pass() {
  local status=$?
  # Report from the top-level shell only. A subshell without set -e carries on
  # past its failure, and one that fails the pass fails its parent too.
  [ "$BASH_SUBSHELL" -eq 0 ] || return
  local cmd="$1" line="$2" pass="${CHEZMOI_SOURCE_FILE:-$0}"
  local file="${BASH_SOURCE[1]}"
  [ "$file" = "$0" ] && file="$pass"
  # When a helper's own `return N` reaches the trap, BASH_COMMAND still reads
  # `return N`. The line already points at the call.
  case "$cmd" in
  return | return\ *) cmd= ;;
  esac
  log "${pass##*/} failed${cmd:+: $cmd} (exit $status at ${file##*/}:$line)"
  case "$pass" in
  *_before_*) log "no files were written: before-phase passes run ahead of deployment" ;;
  esac
  log "fix the cause, then re-run chezmoi apply (passes converge)"
}

# errtrace carries the trap into helper functions, where set -e exits first.
set -E
trap '_report_failed_pass "$BASH_COMMAND" "$LINENO"' ERR

# chezmoi runs passes from $HOME, where unrestricted mise reads
# ~/.config/mise/config.toml, ~/.tool-versions, and ~/mise.toml as project
# config. Before deployment, ~/.config/mise/config.toml still holds the last
# apply's pins. The calling shell may predate the restriction's variables.
restrict_mise_to_global_config() {
  set -a
  # shellcheck source=dot_config/environment.d/mise.conf
  . "${BASH_SOURCE[0]%/*}/../../dot_config/environment.d/mise.conf"
  set +a
}

mise_shims="$HOME/.local/share/mise/shims"

# `mise install` links every shim to the first mise on PATH. On a first apply
# that is the tutorial's seed.
use_pinned_mise() {
  local pin
  restrict_mise_to_global_config
  pin="$(readlink -f "$mise_shims/mise")"
  PATH="${pin%/*}:$PATH"
}

# Until apply deploys it, ~/.config/mise is stale or missing.
use_source_mise_config() {
  restrict_mise_to_global_config
  export MISE_GLOBAL_CONFIG_FILE="${BASH_SOURCE[0]%/*}/../../dot_config/mise/config.toml"
}

# Shims resolve through the deployed ~/.config/mise, so only after-phase
# passes can call this. A first apply runs with MISE_GLOBAL_CONFIG_FILE naming
# the source tree's config.
use_mise_shims() {
  restrict_mise_to_global_config
  unset MISE_GLOBAL_CONFIG_FILE
  PATH="$mise_shims:$PATH"
}

# install-claude-code links claude here. A first apply runs before any shell
# sources the deployed ~/.profile that puts it on PATH.
use_local_bin() { PATH="$HOME/.local/bin:$PATH"; }

# reregister_mcp NAME ARG...: replace NAME's user-scope registration with
# `claude mcp add NAME ARG...`. The add refuses an existing name, so a failed
# add leaves NAME unregistered.
reregister_mcp() {
  local name="$1"
  shift
  if ! command -v claude >/dev/null; then
    log "$name: claude not on PATH, registration unchanged"
    return 1
  fi
  claude mcp remove "$name" --scope user >/dev/null 2>&1 || true
  log "$name: registering"
  if ! claude mcp add "$name" --scope user "$@"; then
    log "$name: add failed, nothing registered"
    return 1
  fi
}

_bootstrap_skipped="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-bootstrap/skipped"

# Headless applies (SSH without lingering, container builds) have no user
# systemd manager.
has_user_manager() { systemctl --user show-environment >/dev/null 2>&1; }

user_manager_remedy() {
  printf 're-run chezmoi apply from a login session, or after sudo loginctl enable-linger %s' "$(id -un)"
}

# enable_user_units NAME UNIT...: enable and start each UNIT. Without a user
# manager, it records the UNITs under NAME for report_skipped_units instead.
enable_user_units() {
  local name="$1"
  shift
  if ! has_user_manager; then
    log "$name: no user systemd session; leaving $* disabled — $(user_manager_remedy)"
    mkdir -p "$_bootstrap_skipped"
    printf '%s\n' "$@" >"$_bootstrap_skipped/$name"
    return 0
  fi
  rm -f "$_bootstrap_skipped/$name"
  systemctl --user daemon-reload
  systemctl --user enable --now "$@"
}

# Prints the units enable_user_units left disabled, if any.
report_skipped_units() {
  local records=("$_bootstrap_skipped"/*)
  [ -e "${records[0]}" ] || return 0
  log "left disabled (no user systemd session):"
  sed 's/^/      /' "${records[@]}" >&2
  printf '    enable: %s\n' "$(user_manager_remedy)" >&2
}
