#!/usr/bin/env bash
# PreToolUse hook: require PRs from the GitHub MCP tools to be drafts.
#
# The `gh pr create` path is enforced separately by ~/.local/bin/gh
# (a PATH shim), so this hook only has to cover the MCP tools that
# call GitHub's API directly and never touch the gh binary.
#
# Input: Claude Code PreToolUse JSON on stdin.
# Exit 0 = allow; exit 2 = block and send stderr back to Claude.
# Any other non-zero is treated by Claude Code as a non-blocking
# warning, so this script explicitly exits 2 on parse failure to
# fail closed rather than silently letting the PR through.
#
# settings.json filters which calls reach this hook via a `matcher`
# regex; the case statement below is the authoritative gate. The
# matcher is a perf filter, not a guard — keep them in sync, but
# never delete the case in favor of the matcher alone.

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
esac
exit 0
