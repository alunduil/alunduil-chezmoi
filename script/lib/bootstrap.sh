# shellcheck shell=bash
# Shared helpers for .chezmoiscripts/ bootstrap passes. None reaches sudo on
# a converged host. Passes source this from {{ .chezmoi.sourceDir }}:
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

# Shims resolve through the deployed ~/.config/mise, so only after-phase
# passes can call this.
use_mise_shims() { PATH="$HOME/.local/share/mise/shims:$PATH"; }

# The deployed ~/.profile puts ~/.local/bin, where install-claude-code links
# claude, on PATH. A first apply runs before any shell has sourced it.
use_local_bin() { PATH="$HOME/.local/bin:$PATH"; }

_bootstrap_installed=0

# A checksum of each file the last apply installed, kept user-owned so reading
# it never needs sudo. It separates a hand-edit under /etc from a source change.
_bootstrap_state="${XDG_STATE_HOME:-$HOME/.local/state}/chezmoi-bootstrap"

_sha256() { sha256sum <"$1" | cut -d' ' -f1; }

_record_installed() {
  local src="$1" record="$2"
  mkdir -p "${record%/*}"
  _sha256 "$src" >"$record"
}

_edited_since_apply() {
  local dest="$1" record="$2"
  [ -f "$record" ] && [ "$(_sha256 "$dest")" != "$(<"$record")" ]
}

_confirm_replace() {
  local answer
  read -rp "$1 was edited since the last apply; replace it? [y/N] " answer
  [ "$answer" = y ]
}

# Takes `install`'s arguments; leaves an unchanged DEST alone. A replaced DEST
# is diffed and kept in DEST.bak; on a terminal, a hand-edited one asks first.
install_if_changed() {
  local src="${*: -2:1}" dest="${*: -1}"
  local record="$_bootstrap_state$dest.sha256"
  if cmp -s "$src" "$dest"; then
    [ -f "$record" ] || _record_installed "$src" "$record"
    return 0
  fi
  if [ -e "$dest" ]; then
    diff -u "$dest" "$src" >&2 || true
    if [ -t 0 ] && _edited_since_apply "$dest" "$record" &&
      ! _confirm_replace "$dest"; then
      log "keeping $dest"
      return 0
    fi
    log "backing up $dest to $dest.bak"
    sudo cp -p "$dest" "$dest.bak"
  fi
  log "installing $dest"
  sudo install "$@"
  _record_installed "$src" "$record"
  _bootstrap_installed=1
}

# Reloads systemd if install_if_changed placed a file since the last reload.
daemon_reload_if_installed() {
  if [ "$_bootstrap_installed" -eq 1 ]; then
    sudo systemctl daemon-reload
    _bootstrap_installed=0
  fi
}

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

_bootstrap_skipped="$_bootstrap_state/skipped"

_user_manager_remedy() {
  printf 're-run chezmoi apply from a login session, or after sudo loginctl enable-linger %s' "$(id -un)"
}

# enable_user_units NAME UNIT...: enable and start each UNIT. Headless applies
# (SSH without lingering, container builds) have no user systemd manager; there
# it records the UNITs under NAME for report_skipped_units instead.
enable_user_units() {
  local name="$1"
  shift
  if ! systemctl --user show-environment >/dev/null 2>&1; then
    log "$name: no user systemd session; leaving $* disabled — $(_user_manager_remedy)"
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
  printf '    enable: %s\n' "$(_user_manager_remedy)" >&2
}

# enable_now UNIT...: enable and start each UNIT not already enabled and
# active.
enable_now() {
  local unit
  for unit in "$@"; do
    if ! systemctl is-enabled --quiet "$unit" 2>/dev/null ||
      ! systemctl is-active --quiet "$unit" 2>/dev/null; then
      log "enabling $unit"
      sudo systemctl enable --now "$unit"
    fi
  done
}
