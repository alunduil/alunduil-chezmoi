#!/usr/bin/env python3
"""PreToolUse hook: block forward-looking CHANGELOG edits.

Gates Edit/Write/MultiEdit on files whose basename matches *CHANGELOG*
(case-insensitive). Blocks when the post-edit content introduces any of:
  - a version heading dated in the future (## [X.Y.Z] - YYYY-MM-DD)
  - a pre-announcement phrase ("coming soon", "planned", "upcoming")
  - new content under a released-version heading (date in past) —
    released sections are immutable per Keep-a-Changelog; entries go
    under [Unreleased] instead

Exit 0 = allow; exit 2 = block (per Claude Code's hook protocol).
Parse failures exit 2 to fail closed — schema drift shouldn't let
pre-announcement edits slip through.
"""

import datetime
import json
import os
import re
import sys

H2_RE = re.compile(r"^##\s+")
HEADING_RE = re.compile(r"^##\s+\[[^\]]+\]\s+-\s+(\d{4}-\d{2}-\d{2})\s*$")
PHRASE_RE = re.compile(r"\b(coming soon|planned|upcoming)\b", re.IGNORECASE)


def apply_edit(text, old, new, replace_all):
    if not old or old not in text:
        return None
    return text.replace(old, new) if replace_all else text.replace(old, new, 1)


def post_edit_content(tool_name, tool_input, before):
    if tool_name == "Write":
        return tool_input.get("content", "")
    if tool_name == "Edit":
        return apply_edit(
            before,
            tool_input.get("old_string", ""),
            tool_input.get("new_string", ""),
            tool_input.get("replace_all", False),
        )
    if tool_name == "MultiEdit":
        after = before
        for edit in tool_input.get("edits", []):
            after = apply_edit(
                after,
                edit.get("old_string", ""),
                edit.get("new_string", ""),
                edit.get("replace_all", False),
            )
            if after is None:
                return None
        return after
    return None


def detect_problems(before, after, today):
    before_set = set(before.splitlines())
    problems = []
    current_heading = None  # (heading_line, date_str) or None

    for line in after.splitlines():
        stripped = line.strip()
        if H2_RE.match(stripped):
            match = HEADING_RE.match(stripped)
            if match:
                current_heading = (stripped, match.group(1))
                if stripped not in before_set and match.group(1) > today:
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

    return problems


def main():
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"changelog-guard: invalid JSON ({exc})\n")
        sys.exit(2)

    tool_name = data.get("tool_name", "")
    if tool_name not in {"Edit", "Write", "MultiEdit"}:
        sys.exit(0)

    tool_input = data.get("tool_input", {})
    file_path = tool_input.get("file_path", "")
    if not file_path:
        sys.exit(0)

    if "changelog" not in os.path.basename(file_path).lower():
        sys.exit(0)

    try:
        with open(file_path, "r", encoding="utf-8") as fh:
            before = fh.read()
    except FileNotFoundError:
        before = ""
    except OSError as exc:
        sys.stderr.write(f"changelog-guard: cannot read {file_path} ({exc})\n")
        sys.exit(2)

    after = post_edit_content(tool_name, tool_input, before)
    if after is None:
        # Edit will fail at tool dispatch; nothing for the guard to do.
        sys.exit(0)

    today = datetime.date.today().isoformat()
    problems = detect_problems(before, after, today)
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


if __name__ == "__main__":
    main()
