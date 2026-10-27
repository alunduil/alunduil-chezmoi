#!/usr/bin/env bash
# PreToolUse hook: require PRs from the GitHub MCP tools to be drafts,
# and stay drafts. The `gh pr create` path is enforced separately by
# ~/.local/bin/gh and `gh pr ready` by the settings.json ask list;
# this only covers the MCP tools.
#
# Exit 0 = allow; exit 2 = block (per Claude Code's hook protocol).
# Other non-zero is non-blocking, so parse failures exit 2 explicitly
# to fail closed.
#
# settings.json's `matcher` regex pre-filters; the case statement
# below is the authoritative gate (don't delete it in favor of the
# matcher).

set -euo pipefail

input="$(cat)"

if ! tool_name="$(jq -r '.tool_name // ""' <<<"$input")"; then
  printf 'pr-draft-guard: failed to parse PreToolUse JSON\n' >&2
  exit 2
fi

case "$tool_name" in
  mcp__github__create_pull_request | mcp__github__create_pull_request_with_copilot)
    if ! draft="$(jq -r '.tool_input.draft // false' <<<"$input")"; then
      printf 'pr-draft-guard: failed to read tool_input.draft\n' >&2
      exit 2
    fi
    if [ "$draft" != "true" ]; then
      cat >&2 <<EOF
Blocked by ${BASH_SOURCE[0]}: PRs must be opened as drafts.
Retry the same call with draft=true. The user will mark it ready after reviewing.
EOF
      exit 2
    fi
    ;;
  mcp__github__update_pull_request)
    if ! draft="$(jq -r '.tool_input.draft' <<<"$input")"; then
      printf 'pr-draft-guard: failed to read tool_input.draft\n' >&2
      exit 2
    fi
    if [ "$draft" = "false" ]; then
      cat >&2 <<EOF
Blocked by ${BASH_SOURCE[0]}: only the user marks a PR ready for review.
Retry without the draft field.
EOF
      exit 2
    fi
    ;;
esac
exit 0
