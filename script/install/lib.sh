# shellcheck shell=bash
# Shared helpers for script/install-* scripts. Source from the same dir.

# Parse --bin-dir DIR from the install script's arguments. Sets BIN_DIR.
# Errors (return 2) on missing or unknown arguments.
parse_bin_dir() {
  BIN_DIR=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --bin-dir)
        [ $# -ge 2 ] || {
          echo "${0##*/}: --bin-dir requires an argument" >&2
          return 2
        }
        BIN_DIR="$2"
        shift 2
        ;;
      *)
        echo "${0##*/}: unknown argument: $1" >&2
        return 2
        ;;
    esac
  done
  [ -n "$BIN_DIR" ] || {
    echo "${0##*/}: --bin-dir DIR required" >&2
    return 2
  }
}

# Look up the SHA256 of ASSET in a `<hash>  <filename>` style checksums
# file. Prints the hash on stdout. Returns 1 if no entry is found.
expected_from_checksums() {
  local file="$1" asset="$2"
  local hash
  hash="$(awk -v f="$asset" '$2 == f {print $1}' "$file")"
  if [ -z "$hash" ]; then
    printf '%s: no checksum entry for %s in %s\n' \
      "${0##*/}" "$asset" "${file##*/}" >&2
    return 1
  fi
  printf '%s' "$hash"
}

# Compare sha256(FILE) against EXPECTED. Returns 1 with a diagnostic on
# mismatch, 0 on match. Caller's set -e propagates the failure.
verify_sha256() {
  local file="$1" expected="$2"
  local actual
  actual="$(sha256sum "$file" | awk '{print $1}')"
  if [ "$expected" != "$actual" ]; then
    printf '%s: sha256 mismatch on %s -- expected %s, got %s\n' \
      "${0##*/}" "${file##*/}" "$expected" "$actual" >&2
    return 1
  fi
}
