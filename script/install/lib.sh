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

# installed_version_matches BIN VERSION: succeeds when BIN is executable and
# its `--version` output contains VERSION with any leading `v` stripped.
# Release tags carry the `v` (v0.2.88); the binary's own --version usually
# reports it without. Lets every installer share one already-installed guard.
installed_version_matches() {
  local bin="$1" version="$2"
  [ -x "$bin" ] && "$bin" --version 2>/dev/null | grep -qF "${version#v}"
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

# Verify a detached GPG signature when upstream publishes .asc but no
# .sha256 (e.g. AsamK/signal-cli). Imports KEY_URL into an ephemeral
# GNUPGHOME under GPGHOME, asserts the imported fingerprint equals
# EXPECTED_FPR (so a swapped key can't slip through), then verifies
# ASC over FILE. The ephemeral keyring keeps the user's ~/.gnupg
# untouched; caller is responsible for cleaning GPGHOME.
verify_gpg() {
  local file="$1" asc="$2" key_url="$3" expected_fpr="$4" gpghome="$5"
  local actual_fpr

  GNUPGHOME="$gpghome" gpg --quiet --batch --import \
    <(curl -fsSL "$key_url") 2>/dev/null
  actual_fpr="$(GNUPGHOME="$gpghome" gpg --list-keys --with-colons |
    awk -F: '$1 == "fpr" {print $10; exit}')"
  if [ "$actual_fpr" != "$expected_fpr" ]; then
    printf '%s: gpg fingerprint mismatch on %s -- expected %s, got %s\n' \
      "${0##*/}" "$key_url" "$expected_fpr" "$actual_fpr" >&2
    return 1
  fi
  if ! GNUPGHOME="$gpghome" gpg --quiet --batch --verify "$asc" "$file" 2>/dev/null; then
    printf '%s: gpg signature verification failed for %s\n' \
      "${0##*/}" "${file##*/}" >&2
    return 1
  fi
}
