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
