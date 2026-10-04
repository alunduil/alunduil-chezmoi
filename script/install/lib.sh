# shellcheck shell=bash
# Shared helpers for script/install/* scripts. Source from the same dir.

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

# download URL DEST: fetch URL to DEST, retrying on any failure.
# Plain --retry skips connection errors such as a reset during the TLS
# handshake, so --retry-all-errors is required. DEST is a file because curl
# discards a partial body before retrying only when writing to a named file.
download() {
  local url="$1" dest="$2"
  curl -fsSL --retry 3 --retry-all-errors --retry-delay 1 -o "$dest" "$url"
}

# installed_version_matches BIN VERSION: succeeds when BIN is executable and
# its `--version` output contains VERSION with any leading `v` stripped.
# Release tags carry the `v` (v0.2.88); the binary's own --version usually
# reports it without. Lets every installer share one already-installed guard.
installed_version_matches() {
  local bin="$1" version="$2"
  [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -qF "${version#v}"
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
