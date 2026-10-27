# Local sensor entrypoint: the fast pre-claim sweep. CI is the source of
# truth — each sensor also runs there, so a stale list here
# can only cause a local false-pass that CI then catches, never a bad
# merge. lychee (link-checking) runs in CI only; it's not a pre-claim
# sensor and needs its own binary.

# List available recipes.
default:
    @just --list

# Regenerate dot_config/mise/mise.lock after editing config.toml.
lock-tools:
    MISE_GLOBAL_CONFIG_FILE="{{ justfile_directory() }}/dot_config/mise/config.toml" mise lock --global

# Claude's primary use is a post-change sanity sweep, so this reports
# every sensor's result in one run rather than stopping at the first
# failure — full signal lets it batch fixes instead of finding them
# serially across re-runs. A sensor exits 77 when its tool is missing;
# that is listed as skipped, not counted as a pass, so a green run says
# which sensors did not run.

# Run every local sensor; report all failures, not just the first.
check:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=()
    skipped=()
    for c in check-hooks check-bats check-zellij check-chezmoi check-chezmoi-templates check-settings-permissions check-telemetry check-systemd check-bootstrap-convergence check-pinned-tools; do
      just "$c"
      case $? in
        0) ;;
        77) skipped+=("$c") ;;
        *) failed+=("$c") ;;
      esac
    done
    if [ "${#failed[@]}" -gt 0 ]; then
      printf '\nfailed:\n'
      printf '  %s\n' "${failed[@]}"
    fi
    if [ "${#skipped[@]}" -gt 0 ]; then
      printf '\nskipped:\n'
      printf '  %s\n' "${skipped[@]}"
    fi
    [ "${#failed[@]}" -eq 0 ]

# Lints and formatters across all files.
check-hooks:
    prek run --all-files

# Unit tests. CI builds the same BATS_LIB_PATH.
check-bats:
    #!/usr/bin/env bash
    set -euo pipefail
    mise_libs="$(mise where npm:bats-support)/node_modules:$(mise where npm:bats-assert)/node_modules"
    BATS_LIB_PATH="${BATS_LIB_PATH:+$BATS_LIB_PATH:}$mise_libs" \
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
[no-exit-message]
check-telemetry:
    script/checks/telemetry-config

# systemd user unit validation (skips when the units' referenced binaries are
# absent).
[no-exit-message]
check-systemd:
    script/checks/systemd-units

# Every pinned tool runs and reports its pinned version (needs mise).
check-pinned-tools:
    script/checks/pinned-tools

# Bootstrap passes stay convergent (no run_once_, no `dpkg -s` presence guard).
check-bootstrap-convergence:
    script/checks/bootstrap-convergence
