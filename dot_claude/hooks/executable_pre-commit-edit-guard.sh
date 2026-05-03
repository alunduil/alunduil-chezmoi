#!/usr/bin/env bash
# PostToolUse hook: run pre-commit on the just-edited file so lint
# failures surface immediately instead of piling up at commit time.
# Matched on Edit/Write/MultiEdit/NotebookEdit by settings.json.
#
# Exit 0 = silent pass / nothing to do; exit 2 surfaces stderr to
# Claude as feedback for the next turn. Parse failures exit 0 — we
# lose lint coverage rather than loop on infrastructure noise.
#
# Skips when the edited path isn't in a git repo, the repo has no
# .pre-commit-config.yaml, or pre-commit isn't on PATH.

set -euo pipefail

input="$(cat)"

file_path="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input" 2>/dev/null || true)"
[ -n "$file_path" ] || exit 0
[ -e "$file_path" ] || exit 0

command -v pre-commit >/dev/null || exit 0

repo_root="$(git -C "$(dirname "$file_path")" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || exit 0
[ -f "$repo_root/.pre-commit-config.yaml" ] || exit 0

if ! output="$(cd "$repo_root" && pre-commit run --files "$file_path" 2>&1)"; then
  cat >&2 <<EOF
pre-commit reported issues on $file_path (some hooks may have auto-fixed —
re-read the file before continuing):

$output
EOF
  exit 2
fi
exit 0
