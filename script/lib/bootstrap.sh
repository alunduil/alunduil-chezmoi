# shellcheck shell=bash
# Shared helpers for .chezmoiscripts/ bootstrap passes. Passes source this
# from {{ .chezmoi.sourceDir }}, which holds the full source tree at apply
# time even though .chezmoiignore keeps script/ out of $HOME.

log() { printf '==> %s\n' "$*" >&2; }

_bootstrap_installed=0

# Takes `install`'s own argument list; the difference is that an unchanged
# DEST is left alone, so a converged host never reaches sudo.
install_if_changed() {
  local src="${*: -2:1}" dest="${*: -1}"
  if cmp -s "$src" "$dest"; then
    return 0
  fi
  log "installing $dest"
  sudo install "$@"
  _bootstrap_installed=1
}

# Reloads systemd only when install_if_changed placed a file since the last
# reload, so a converged host never reaches sudo.
daemon_reload_if_installed() {
  if [ "$_bootstrap_installed" -eq 1 ]; then
    sudo systemctl daemon-reload
    _bootstrap_installed=0
  fi
}

# enable_now UNIT...: enable and start each UNIT unless it already is both,
# so a converged host never reaches sudo.
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
