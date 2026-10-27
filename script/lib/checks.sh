# shellcheck shell=bash
# Shared helpers for script/checks/ sensors and the `just check` recipe.

# A sensor exits SKIP when a tool it needs is missing, so `just check` lists it
# apart from a pass. 77 is the automake and meson skip code.
SKIP=77

# Locally a missing tool means an unbootstrapped host. CI installs every tool
# first, so there a missing tool means a broken install.
skip() {
  if [ -n "${CI:-}" ]; then
    printf 'FAIL: %s: %s\n' "${0##*/}" "$*" >&2
    exit 1
  fi
  printf '==> %s: %s; skipping\n' "${0##*/}" "$*" >&2
  exit "$SKIP"
}
