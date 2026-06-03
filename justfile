# Local sensor entrypoint: the fast pre-claim sweep. CI is the source of
# truth — each sensor also runs in its own workflow, so a stale list here
# can only cause a local false-pass that CI then catches, never a bad
# merge. lychee (link-checking) runs in CI only; it's not a pre-claim
# sensor and needs its own binary.

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
    for c in check-pre-commit check-bats check-python check-zellij check-chezmoi check-chezmoi-templates check-observability; do
      just "$c" || rc=1
    done
    exit "$rc"

# Lints and formatters across all files.
check-pre-commit:
    pre-commit run --all-files

# Unit tests.
check-bats:
    bats --recursive dot_local dot_claude script

# Python unit tests (zellijstat parsers).
check-python:
    python3 dot_local/bin/zellijstat_test.py

# Zellij KDL validation (needs zellij on PATH).
check-zellij:
    script/checks/zellij-config

# Apply round-trip (needs chezmoi + age on PATH).
check-chezmoi:
    script/checks/chezmoi-apply

# Render run_*.sh.tmpl script templates (needs chezmoi on PATH).
check-chezmoi-templates:
    script/checks/chezmoi-template

# Observability config validation (skips when the stack binaries are absent;
# the live metrics smoke is CI-only — it binds the running stack's ports).
check-observability:
    script/checks/observability-config
