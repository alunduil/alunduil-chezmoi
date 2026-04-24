#!/usr/bin/env bash
# PreToolUse hook: require PRs from the GitHub MCP tools to be drafts.
#
# The `gh pr create` path is enforced separately by ~/.local/bin/gh
# (a PATH shim), so this hook only has to cover the MCP tools that
# call GitHub's API directly and never touch the gh binary.
#
# Input: Claude Code PreToolUse JSON on stdin.
# Exit 0 = allow; exit 2 = block and send stderr back to Claude.

set -euo pipefail

input="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<<"$input")"

case "$tool_name" in
  mcp__github__create_pull_request|mcp__github__create_pull_request_with_copilot)
    draft="$(jq -r '.tool_input.draft // false' <<<"$input")"
    if [ "$draft" != "true" ]; then
      cat >&2 <<'EOF'
Blocked by ~/.claude/hooks/pr-draft-guard.sh: PRs must be opened as drafts.
Retry the same call with draft=true. The user will mark it ready after reviewing.
EOF
      exit 2
    fi
    ;;
esac
exit 0
