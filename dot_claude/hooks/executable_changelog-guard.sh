#!/usr/bin/env bash
# PreToolUse hook: block forward-looking CHANGELOG edits.
#
# Gates Edit/Write/MultiEdit on files whose basename matches *CHANGELOG*
# (case-insensitive). Blocks when the post-edit content introduces any of:
#   - a version heading dated in the future (## [X.Y.Z] - YYYY-MM-DD)
#   - a pre-announcement phrase ("coming soon", "planned", "upcoming")
#   - new content under a released-version heading (date in past) — released
#     sections are immutable per Keep-a-Changelog; entries go under
#     [Unreleased] instead
#
# Exit 0 = allow; exit 2 = block (per Claude Code's hook protocol).
# Parse failures exit 2 to fail closed — schema drift shouldn't let
# pre-announcement edits slip through.
#
# settings.json's `matcher` regex pre-filters to Edit|Write|MultiEdit;
# the case statement below is the authoritative gate.

set -euo pipefail

input="$(cat)"

if ! tool_name="$(jq -r '.tool_name // ""' <<<"$input")"; then
  printf 'changelog-guard: failed to parse PreToolUse JSON\n' >&2
  exit 2
fi

case "$tool_name" in
  Edit | Write | MultiEdit) ;;
  *) exit 0 ;;
esac

if ! file_path="$(jq -r '.tool_input.file_path // ""' <<<"$input")"; then
  printf 'changelog-guard: failed to read tool_input.file_path\n' >&2
  exit 2
fi
[ -n "$file_path" ] || exit 0

basename_lower="$(basename "$file_path" | tr '[:upper:]' '[:lower:]')"
case "$basename_lower" in
  *changelog*) ;;
  *) exit 0 ;;
esac

export HOOK_INPUT="$input"
export HOOK_FILE_PATH="$file_path"
HOOK_TODAY="$(date -u +%Y-%m-%d)"
export HOOK_TODAY

exec python3 - <<'PY'
import json
import os
import re
import sys

today = os.environ["HOOK_TODAY"]
file_path = os.environ["HOOK_FILE_PATH"]

try:
    data = json.loads(os.environ["HOOK_INPUT"])
except json.JSONDecodeError as exc:
    sys.stderr.write(f"changelog-guard: invalid JSON ({exc})\n")
    sys.exit(2)

tool_name = data.get("tool_name", "")
tool_input = data.get("tool_input", {})

try:
    with open(file_path, "r", encoding="utf-8") as fh:
        before = fh.read()
except FileNotFoundError:
    before = ""
except OSError as exc:
    sys.stderr.write(f"changelog-guard: cannot read {file_path} ({exc})\n")
    sys.exit(2)


def apply_edit(text, old, new, replace_all):
    if not old or old not in text:
        return None
    return text.replace(old, new) if replace_all else text.replace(old, new, 1)


if tool_name == "Write":
    after = tool_input.get("content", "")
elif tool_name == "Edit":
    after = apply_edit(
        before,
        tool_input.get("old_string", ""),
        tool_input.get("new_string", ""),
        tool_input.get("replace_all", False),
    )
    if after is None:
        # Edit will fail at tool dispatch; nothing for the guard to do.
        sys.exit(0)
elif tool_name == "MultiEdit":
    after = before
    for edit in tool_input.get("edits", []):
        result = apply_edit(
            after,
            edit.get("old_string", ""),
            edit.get("new_string", ""),
            edit.get("replace_all", False),
        )
        if result is None:
            sys.exit(0)
        after = result
else:
    sys.exit(0)

before_set = set(before.splitlines())
after_lines = after.splitlines()

H2_RE = re.compile(r"^##\s+")
HEADING_RE = re.compile(r"^##\s+\[[^\]]+\]\s+-\s+(\d{4}-\d{2}-\d{2})\s*$")
PHRASE_RE = re.compile(r"\b(coming soon|planned|upcoming)\b", re.IGNORECASE)

problems = []
current_heading = None  # (heading_line, date_str) or None

for line in after_lines:
    stripped = line.strip()
    if H2_RE.match(stripped):
        heading_match = HEADING_RE.match(stripped)
        if heading_match:
            current_heading = (stripped, heading_match.group(1))
            if stripped not in before_set and heading_match.group(1) > today:
                problems.append(f"future-dated version heading: {stripped}")
        else:
            current_heading = None
        continue

    if line in before_set:
        continue

    if PHRASE_RE.search(line):
        problems.append(f"pre-announcement phrase: {stripped}")
        continue

    if current_heading and current_heading[1] <= today and stripped:
        problems.append(
            f"new content under released {current_heading[0]}: {stripped}"
        )

if not problems:
    sys.exit(0)

sys.stderr.write(
    f"Blocked by changelog-guard: forward-looking CHANGELOG edits in {file_path}.\n"
)
for p in problems[:5]:
    sys.stderr.write(f"  - {p}\n")
if len(problems) > 5:
    sys.stderr.write(f"  - ... and {len(problems) - 5} more\n")
sys.stderr.write(
    "Released sections are immutable; new entries go under [Unreleased].\n"
    "Forward-looking content belongs in issues/PRs, not the changelog.\n"
)
sys.exit(2)
PY
