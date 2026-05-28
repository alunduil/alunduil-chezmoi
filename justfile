# Local sensor entrypoint. CI runs each of these in its own workflow;
# `just check` is the single command to run them all before claiming done.

# List available recipes.
default:
    @just --list

# Claude's primary use is a post-change sanity sweep, so this reports
# every sensor's result in one run rather than stopping at the first
# failure — full signal lets it batch fixes instead of finding them
# serially across re-runs.

# Run every local sensor; report all failures, not just the first.
check:
    #!/usr/bin/env bash
    set -uo pipefail
    rc=0
    for c in check-pre-commit check-bats check-zellij check-chezmoi; do
      just "$c" || rc=1
    done
    exit "$rc"

# Lints and formatters across all files.
check-pre-commit:
    pre-commit run --all-files

# Unit tests.
check-bats:
    bats test/

# Zellij KDL validation (needs zellij on PATH).
check-zellij:
    script/checks/zellij-config

# Apply round-trip (needs chezmoi + age on PATH).
check-chezmoi:
    script/checks/chezmoi-apply
