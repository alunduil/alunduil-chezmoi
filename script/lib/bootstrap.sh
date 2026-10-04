# shellcheck shell=bash
# Shared helpers for .chezmoiscripts/ bootstrap passes. None reaches sudo on
# a converged host. Passes source this from {{ .chezmoi.sourceDir }}:
# .chezmoiignore keeps script/ out of $HOME, but the source tree is always
# present at apply time.

log() { printf '==> %s\n' "$*" >&2; }

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
