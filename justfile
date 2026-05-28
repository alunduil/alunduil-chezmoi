# Local sensor entrypoint. CI runs each of these in its own workflow;
# `just check` is the single command to run them all before claiming done.

# List available recipes.
default:
    @just --list

# Run every local sensor (fail-fast, in CLAUDE.md order).
check: check-pre-commit check-bats check-zellij check-chezmoi

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
