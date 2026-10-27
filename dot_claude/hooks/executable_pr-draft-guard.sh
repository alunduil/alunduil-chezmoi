#!/usr/bin/env bash
# PreToolUse hook: PRs from the GitHub MCP tools open as drafts and
# stay drafts. ~/.local/bin/gh and the settings.json ask list cover
# the `gh` path.
#
# Exit 0 = allow; exit 2 = block (per Claude Code's hook protocol).
# Other non-zero is non-blocking, so parse failures exit 2 explicitly
# to fail closed.
#
# settings.json's `matcher` regex pre-filters; the case statement
# below is the authoritative gate (don't delete it in favor of the
# matcher).

set -euo pipefail

block() {
  printf '%s\n' "$@" >&2
  exit 2
}

input="$(cat)"

# tostring, not //: jq's // treats an explicit false as missing.
if ! {
  read -r tool_name
  read -r draft
} < <(jq -r '.tool_name // "", (.tool_input.draft | tostring)' <<<"$input"); then
  block 'pr-draft-guard: failed to parse PreToolUse JSON'
fi

case "$tool_name" in
  mcp__github__create_pull_request | mcp__github__create_pull_request_with_copilot)
    [ "$draft" = "true" ] ||
      block "Blocked by ${BASH_SOURCE[0]}: PRs must be opened as drafts." \
        'Retry the same call with draft=true. The user will mark it ready after reviewing.'
    ;;
  mcp__github__update_pull_request)
    [ "$draft" != "false" ] ||
      block "Blocked by ${BASH_SOURCE[0]}: only the user marks a PR ready for review." \
        'Retry without the draft field.'
    ;;
esac
exit 0
