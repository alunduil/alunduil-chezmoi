# shellcheck shell=bash
# Shared helpers for .chezmoiscripts/ bootstrap passes. None reaches sudo on
# a converged host. Passes source this from {{ .chezmoi.sourceDir }}:
# .chezmoiignore keeps script/ out of $HOME, but the source tree is always
# present at apply time.

log() { printf '==> %s\n' "$*" >&2; }

# Shims resolve through the deployed ~/.config/mise, so only after-phase
# passes can call this.
use_mise_shims() { PATH="$HOME/.local/share/mise/shims:$PATH"; }

_bootstrap_installed=0

# Takes `install`'s arguments; leaves an unchanged DEST alone.
install_if_changed() {
  local src="${*: -2:1}" dest="${*: -1}"
  if cmp -s "$src" "$dest"; then
    return 0
  fi
  log "installing $dest"
  sudo install "$@"
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
# `claude mcp add NAME ARG...`. The add refuses a name already registered, so
# the old entry goes first and a failed add reports nothing is registered.
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
    log "$name: add failed, nothing registered — run chezmoi apply again"
    return 1
  fi
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
