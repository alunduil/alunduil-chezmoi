# shellcheck shell=bash
# Shared helpers for script/checks/ sensors and the `just check` recipe.

# A sensor exits SKIP when a tool it needs is missing, so `just check` lists it
# apart from a pass. 77 is the automake and meson skip code.
SKIP=77

# A missing tool locally just means an unbootstrapped host. CI installs every
# tool first, so there it is a broken installer and must not skip into a false
# pass.
skip() {
  if [ -n "${CI:-}" ]; then
    printf 'FAIL: %s: %s\n' "${0##*/}" "$*" >&2
    exit 1
  fi
  printf '==> %s: %s; skipping\n' "${0##*/}" "$*" >&2
  exit "$SKIP"
}
