#!/usr/bin/env python3
"""Cases mutate the live diagram rather than a fixture, so a check that stops
firing because the document outgrew its parser fails here.
"""

import pathlib
import unittest

import dfd_balance

DOC = pathlib.Path(__file__).resolve().parents[2] / dfd_balance.DEFAULT_DOC


def document():
    return DOC.read_text()


def findings_for(source):
    return dfd_balance.review(source)


class ReviewsTheLiveDocument(unittest.TestCase):
    def test_reports_nothing(self):
        self.assertEqual(findings_for(document()), [])

    def test_parses_every_level(self):
        blocks, top = dfd_balance.parse(document())
        self.assertGreater(len(blocks), 1)
        self.assertEqual(top.name(), "level 0")
        self.assertTrue(top.outside(), "level 0 should have external entities")


class CatchesBalanceDefects(unittest.TestCase):
    def test_flow_dropped_from_a_decomposition(self):
        broken = document().replace("  s9 -->|Anthropic session credential| p31\n", "", 1)
        self.assertIn(
            "3.0 inflow: parent has 'Anthropic session credential', decomposition does not",
            findings_for(broken),
        )

    def test_decomposition_of_a_process_level_zero_lacks(self):
        # Skipping a comparison for want of a parent would read as balanced.
        broken = document().replace("p3(3.0 Run a Claude Code session)", "p3(9.0 Run something else)", 1)
        self.assertIn(
            "the 3.0 decomposition decomposes 3.0, which level 0 does not have",
            findings_for(broken),
        )

    def test_flow_invented_by_a_decomposition(self):
        broken = document().replace(
            "  user -->|prompt| p31\n",
            "  user -->|prompt| p31\n  user -->|whim| p31\n",
            1,
        )
        self.assertIn(
            "3.0 inflow: decomposition has 'whim', parent does not",
            findings_for(broken),
        )


class CatchesContextDrift(unittest.TestCase):
    def test_entity_left_undescribed(self):
        broken = document().replace("- **Codecov.** Coverage", "- **Codeanalysis.** Coverage", 1)
        self.assertIn(
            "context: level 0 has 'Codecov', context describes no such system",
            findings_for(broken),
        )

    def test_system_described_but_absent(self):
        broken = document().replace(
            "- **Context7.**",
            "- **Pagerduty.** Nothing reaches it.\n- **Context7.**",
            1,
        )
        self.assertIn(
            "context: describes 'pagerduty', level 0 has no such entity",
            findings_for(broken),
        )


class CatchesDrawingDefects(unittest.TestCase):
    def test_process_without_an_output(self):
        broken = document().replace("  p8 -->|outbound peer connection| tailnet\n", "", 1)
        self.assertIn("level 0: 8.0 has no output (black hole)", findings_for(broken))

    def test_process_without_an_input(self):
        broken = document().replace("  user -->|login credential| p6\n", "", 1)
        self.assertIn("level 0: 6.0 has no input (miracle)", findings_for(broken))

    def test_flow_between_two_passive_elements(self):
        broken = document().replace(
            "  s3 -->|plaintext token| p2\n",
            "  s3 -->|plaintext token| p2\n  s3 -->|leaked token| s4\n",
            1,
        )
        self.assertIn(
            "level 0: 'leaked token' runs between two passive elements "
            "(s3 to s4); a process belongs between them",
            findings_for(broken),
        )


class CatchesThreatModelReasoning(unittest.TestCase):
    def test_conclusion_that_needs_an_adversary(self):
        broken = document().replace(
            "Only `4.2` reads the signing and transport identities",
            "A compromise of the registry never reaches the key, and only `4.2` reads them",
            1,
        )
        self.assertTrue(
            [f for f in findings_for(broken) if "reasons about an adversary" in f],
            "a compromise claim should be a finding",
        )

    def test_pointing_at_the_threat_model_stays_legal(self):
        allowed = document().replace(
            "belongs to the threat model.",
            "belongs to the threat model, which walks these levels.",
            1,
        )
        self.assertEqual(findings_for(allowed), [])

    def test_security_idiom_for_a_data_state(self):
        broken = document().replace(
            "Three stores hold unencrypted credentials.",
            "Three stores hold credentials in the clear.",
            1,
        )
        self.assertTrue(
            [f for f in findings_for(broken) if "in the clear" in f],
            "security idiom for a plain data state should be a finding",
        )

    def test_context_entry_naming_a_local_path(self):
        broken = document().replace(
            "authenticated by a bearer token.",
            "on a bearer token stored in `~/.claude.json`.",
            1,
        )
        self.assertTrue(
            [f for f in findings_for(broken) if "is a local path" in f],
            "a context entry naming local storage should be a finding",
        )

    def test_ignores_diagram_bodies(self):
        # Flow names are data, not prose; a store called "compromised backup"
        # would be an element name rather than an inference.
        allowed = document().replace(
            "  s9 -->|node key| p8\n",
            "  s9 -->|node key| p8\n  s9 -->|compromised backup| p8\n",
            1,
        )
        self.assertEqual(
            [f for f in findings_for(allowed) if "adversary" in f], []
        )


class RefusesDocumentsItCannotTrust(unittest.TestCase):
    def test_no_diagrams(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "no mermaid blocks"):
            findings_for("# Data flow\n\n## Context\n\n- **User.** Nothing.\n\n## End\n")

    def test_no_context_section(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "no '## Context' section"):
            findings_for(document().replace("## Context", "## Overview", 1))

    def test_no_level_zero(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "expected one level 0"):
            findings_for(document().replace("(1.0 Apply", "(1.1 Apply", 1))


if __name__ == "__main__":
    unittest.main()
