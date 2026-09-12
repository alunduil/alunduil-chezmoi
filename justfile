# Local sensor entrypoint: the fast pre-claim sweep. CI is the source of
# truth — each sensor also runs there, so a stale list here
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
    for c in check-pre-commit check-bats check-zellij check-chezmoi check-chezmoi-templates check-settings-permissions check-telemetry check-systemd check-bootstrap-convergence check-dfd check-unit; do
      just "$c" || rc=1
    done
    exit "$rc"

# Lints and formatters across all files.
check-pre-commit:
    pre-commit run --all-files

# Unit tests. bats-support/bats-assert live in ~/.local/lib/bats (installed by
# script/install/bats-libs); point BATS_LIB_PATH there so bats_load_library
# resolves them. CI sets the same var from the bats-action lib-path output.
check-bats:
    BATS_LIB_PATH="${BATS_LIB_PATH:+$BATS_LIB_PATH:}$HOME/.local/lib/bats" \
      bats --recursive dot_local dot_claude script

# Zellij KDL validation (needs zellij on PATH).
check-zellij:
    script/checks/zellij-config

# Apply round-trip (needs chezmoi + age on PATH).
check-chezmoi:
    script/checks/chezmoi-apply

# Render run_*.sh.tmpl script templates (needs chezmoi on PATH).
check-chezmoi-templates:
    script/checks/chezmoi-template

# Validate settings.json permission-rule grammar (needs chezmoi + age on PATH).
check-settings-permissions:
    script/checks/settings-permissions

# Alloy shipper config validation (skips when alloy is absent).
check-telemetry:
    script/checks/telemetry-config

# systemd user unit validation (skips when the units' referenced binaries are
# absent).
check-systemd:
    script/checks/systemd-units

# Bootstrap passes stay convergent (no run_once_, no `dpkg -s` presence guard).
check-bootstrap-convergence:
    script/checks/bootstrap-convergence

# Data flow diagram levels balance and obey the drawing rules.
check-dfd:
    script/checks/dfd_balance.py

# Python unit tests, beside the scripts they exercise.
check-unit:
    python3 -m unittest discover --start-directory script/checks --pattern '*_test.py'
