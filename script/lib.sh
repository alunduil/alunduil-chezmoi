# shellcheck shell=bash
# Shared helpers for the run_once_before_* bootstrap scripts. Bootstrap
# scripts source this via "{{ .chezmoi.sourceDir }}/script/lib.sh".
# Distinct from script/install/lib.sh, which serves the binary installers
# under script/install/ (download/verify into ~/.local/bin, never sudo).

# Reports whether the current user can run privileged (sudo) commands.
# - root (uid 0): yes, no sudo binary required.
# - sudo present and `sudo -v` validates (prompting for a password when the
#   credentials aren't cached): yes. The validated credential is cached, so
#   the sudo calls that follow reuse it without re-prompting.
# - otherwise (no sudo binary, or the user is not a sudoer): no.
# Gates sudo-requiring bootstrap steps so a host without escalation skips
# them with a warning instead of aborting at the first sudo under
# `set -euo pipefail`. Stderr is left attached so the sudo password prompt
# (sudoer) or "may not run sudo" notice (non-sudoer) is visible.
can_escalate() {
  [ "$(id -u)" -eq 0 ] && return 0
  command -v sudo >/dev/null 2>&1 || return 1
  sudo -v
}
