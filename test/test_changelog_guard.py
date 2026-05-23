"""Tests for the changelog-guard PreToolUse hook."""

import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest


HOOK_PATH = (
    pathlib.Path(__file__).resolve().parent.parent
    / "dot_claude"
    / "hooks"
    / "executable_changelog-guard.py"
)


def _load_hook():
    spec = importlib.util.spec_from_file_location("changelog_guard", HOOK_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


cg = _load_hook()


class DetectProblems(unittest.TestCase):
    TODAY = "2026-05-23"

    def test_unreleased_addition_allowed(self):
        before = "## [Unreleased]\n- foo\n"
        after = "## [Unreleased]\n- foo\n- bar\n"
        self.assertEqual(cg.detect_problems(before, after, self.TODAY), [])

    def test_future_dated_heading_flagged(self):
        before = "## [Unreleased]\n"
        after = "## [Unreleased]\n## [2.0.0] - 2099-12-31\n"
        problems = cg.detect_problems(before, after, self.TODAY)
        self.assertTrue(any("future-dated" in p for p in problems))

    def test_today_dated_heading_allowed(self):
        before = "## [Unreleased]\n"
        after = f"## [Unreleased]\n## [1.1.0] - {self.TODAY}\n"
        self.assertEqual(cg.detect_problems(before, after, self.TODAY), [])

    def test_coming_soon_phrase_flagged(self):
        before = "## [Unreleased]\n"
        after = "## [Unreleased]\n- Coming soon: SSO\n"
        problems = cg.detect_problems(before, after, self.TODAY)
        self.assertTrue(any("pre-announcement" in p for p in problems))

    def test_planned_phrase_flagged(self):
        before = "## [Unreleased]\n"
        after = "## [Unreleased]\n- Planned removal of legacy API\n"
        problems = cg.detect_problems(before, after, self.TODAY)
        self.assertTrue(any("pre-announcement" in p for p in problems))

    def test_upcoming_phrase_flagged(self):
        before = "## [Unreleased]\n"
        after = "## [Unreleased]\n- upcoming release notes\n"
        problems = cg.detect_problems(before, after, self.TODAY)
        self.assertTrue(any("pre-announcement" in p for p in problems))

    def test_content_under_released_flagged(self):
        before = "## [1.0.0] - 2025-01-01\n- initial\n"
        after = "## [1.0.0] - 2025-01-01\n- initial\n- forgotten\n"
        problems = cg.detect_problems(before, after, self.TODAY)
        self.assertTrue(any("released" in p for p in problems))

    # H2 reset: [Unreleased] coming after a dated release clears the
    # current heading so additions underneath are not attributed to
    # the prior released section.
    def test_unreleased_after_release_resets_context(self):
        before = "## [1.0.0] - 2025-01-01\n- old\n\n## [Unreleased]\n"
        after = "## [1.0.0] - 2025-01-01\n- old\n\n## [Unreleased]\n- new\n"
        self.assertEqual(cg.detect_problems(before, after, self.TODAY), [])

    # Release cut: moving entries from [Unreleased] into a today-dated
    # release section is the legitimate flow. Set-based line diff sees
    # the moved bullets as present in `before` and does not flag.
    def test_release_cut_from_unreleased_allowed(self):
        before = "## [Unreleased]\n\n### Added\n- foo\n"
        after = (
            f"## [Unreleased]\n\n## [1.1.0] - {self.TODAY}\n\n### Added\n- foo\n"
        )
        self.assertEqual(cg.detect_problems(before, after, self.TODAY), [])


class PostEditContent(unittest.TestCase):
    def test_write_returns_content(self):
        self.assertEqual(
            cg.post_edit_content("Write", {"content": "hello"}, "ignored"),
            "hello",
        )

    def test_edit_single_replacement(self):
        self.assertEqual(
            cg.post_edit_content(
                "Edit",
                {"old_string": "foo", "new_string": "bar"},
                "foo and foo",
            ),
            "bar and foo",
        )

    def test_edit_replace_all(self):
        self.assertEqual(
            cg.post_edit_content(
                "Edit",
                {"old_string": "foo", "new_string": "bar", "replace_all": True},
                "foo and foo",
            ),
            "bar and bar",
        )

    def test_edit_missing_old_returns_none(self):
        self.assertIsNone(
            cg.post_edit_content(
                "Edit", {"old_string": "nope", "new_string": "x"}, "foo"
            )
        )

    def test_multiedit_sequential(self):
        self.assertEqual(
            cg.post_edit_content(
                "MultiEdit",
                {
                    "edits": [
                        {"old_string": "a", "new_string": "b"},
                        {"old_string": "b", "new_string": "c"},
                    ]
                },
                "a",
            ),
            "c",
        )

    def test_multiedit_short_circuits_on_missing(self):
        self.assertIsNone(
            cg.post_edit_content(
                "MultiEdit",
                {
                    "edits": [
                        {"old_string": "a", "new_string": "b"},
                        {"old_string": "missing", "new_string": "x"},
                    ]
                },
                "a",
            )
        )

    def test_unknown_tool_returns_none(self):
        self.assertIsNone(cg.post_edit_content("WrenchTool", {}, ""))


class HookContract(unittest.TestCase):
    """End-to-end: pipe JSON to the script, check exit and stderr."""

    def _run(self, payload, *, file_path=None):
        if file_path is not None:
            payload = {
                **payload,
                "tool_input": {
                    **payload.get("tool_input", {}),
                    "file_path": file_path,
                },
            }
        return subprocess.run(
            [sys.executable, str(HOOK_PATH)],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
        )

    def test_malformed_json_exits_2(self):
        result = subprocess.run(
            [sys.executable, str(HOOK_PATH)],
            input="{ not json",
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)

    def test_unrelated_tool_allowed(self):
        result = self._run({"tool_name": "Read", "tool_input": {}})
        self.assertEqual(result.returncode, 0)

    def test_non_changelog_path_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "README.md")
            with open(path, "w") as fh:
                fh.write("# readme\n")
            result = self._run(
                {
                    "tool_name": "Edit",
                    "tool_input": {
                        "old_string": "# readme",
                        "new_string": "# readme Coming soon: 2.0",
                    },
                },
                file_path=path,
            )
            self.assertEqual(result.returncode, 0)

    def test_forward_looking_edit_blocked(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "CHANGELOG.md")
            with open(path, "w") as fh:
                fh.write("## [Unreleased]\n- foo\n")
            result = self._run(
                {
                    "tool_name": "Edit",
                    "tool_input": {
                        "old_string": "- foo",
                        "new_string": "- foo\n- Coming soon: SSO",
                    },
                },
                file_path=path,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("pre-announcement", result.stderr)

    def test_clean_edit_allowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "CHANGELOG.md")
            with open(path, "w") as fh:
                fh.write("## [Unreleased]\n- foo\n")
            result = self._run(
                {
                    "tool_name": "Edit",
                    "tool_input": {
                        "old_string": "- foo",
                        "new_string": "- foo\n- bar",
                    },
                },
                file_path=path,
            )
            self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
