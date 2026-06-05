"""Function-layer tests for the script/checks/vale gate.

Loads the no-suffix gate script by path and exercises its pure evaluators
against synthetic vale JSON and baselines. These cover only the gate's own
logic -- severity aggregation, regression detection, baseline-slack
detection -- not vale itself or stdlib behaviour.
"""

import importlib.util
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

sys.dont_write_bytecode = True

_SRC = Path(__file__).resolve().parent / "vale"
_loader = SourceFileLoader("vale_gate", str(_SRC))
_spec = importlib.util.spec_from_loader("vale_gate", _loader)
assert _spec is not None
vale = importlib.util.module_from_spec(_spec)
sys.modules["vale_gate"] = vale
_loader.exec_module(vale)


def _alert(severity, line=1, check="Microsoft.Passive", message="msg"):
    return {"Severity": severity, "Line": line, "Check": check, "Message": message}


class SuggestionCounts(unittest.TestCase):
    def test_counts_only_suggestions_per_file(self):
        findings = {
            "a.md": [_alert("suggestion"), _alert("suggestion"), _alert("warning")],
            "b.md": [_alert("suggestion")],
        }
        self.assertEqual(vale.suggestion_counts(findings), {"a.md": 2, "b.md": 1})

    def test_omits_files_with_no_suggestions(self):
        findings = {"a.md": [_alert("warning"), _alert("error")]}
        self.assertEqual(vale.suggestion_counts(findings), {})


class BlockingFindings(unittest.TestCase):
    def test_collects_warning_and_error_sorted(self):
        findings = {
            "b.md": [_alert("warning", line=5, check="Microsoft.We", message="we")],
            "a.md": [_alert("error", line=2, check="ADR.Readability", message="hard")],
            "c.md": [_alert("suggestion")],
        }
        self.assertEqual(
            vale.blocking_findings(findings),
            [
                "a.md:2 [ADR.Readability] hard",
                "b.md:5 [Microsoft.We] we",
            ],
        )

    def test_no_blocking_when_only_suggestions(self):
        self.assertEqual(vale.blocking_findings({"a.md": [_alert("suggestion")]}), [])


class Regressions(unittest.TestCase):
    def test_count_above_baseline_regresses(self):
        self.assertEqual(
            vale.regressions({"a.md": 3}, {"a.md": 2}),
            ["a.md: 3 suggestions, baseline 2"],
        )

    def test_count_at_baseline_passes(self):
        self.assertEqual(vale.regressions({"a.md": 2}, {"a.md": 2}), [])

    def test_count_below_baseline_passes(self):
        self.assertEqual(vale.regressions({"a.md": 1}, {"a.md": 2}), [])

    def test_new_file_with_suggestions_regresses_against_zero(self):
        self.assertEqual(
            vale.regressions({"new.md": 1}, {}),
            ["new.md: 1 suggestions, baseline 0"],
        )


class StaleBaseline(unittest.TestCase):
    def test_actual_below_baseline_is_stale(self):
        self.assertEqual(
            vale.stale_baseline({"a.md": 1}, {"a.md": 3}),
            ["a.md: 1 suggestions, baseline 3"],
        )

    def test_cleared_file_is_stale(self):
        self.assertEqual(
            vale.stale_baseline({}, {"a.md": 2}),
            ["a.md: 0 suggestions, baseline 2"],
        )

    def test_at_baseline_not_stale(self):
        self.assertEqual(vale.stale_baseline({"a.md": 2}, {"a.md": 2}), [])


if __name__ == "__main__":
    unittest.main()
