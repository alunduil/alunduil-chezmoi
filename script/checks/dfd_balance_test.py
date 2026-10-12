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


def mutate(old, new):
    source = document()
    assert old in source, f"fixture text gone from the live document: {old!r}"
    return source.replace(old, new, 1)


class ReviewsTheLiveDocument(unittest.TestCase):
    def test_reports_nothing(self):
        self.assertEqual(dfd_balance.review(document()), [])

    def test_parses_every_level(self):
        diagrams, context, top = dfd_balance.parse(document())
        self.assertEqual(context.name(), "context")
        self.assertEqual(top.name(), "level 0")
        self.assertGreater(
            len([d for d in diagrams if d.depth() > 1]),
            0,
            "expected at least one decomposition below level 0",
        )


class CatchesBalanceDefects(unittest.TestCase):
    def test_flow_dropped_from_a_decomposition(self):
        broken = mutate("  logins -->|Anthropic session credential| turns\n", "")
        self.assertIn(
            "3.0 inflow: parent has 'Anthropic session credential', decomposition does not",
            dfd_balance.review(broken),
        )

    def test_flow_invented_by_a_decomposition(self):
        broken = mutate(
            "  user -->|prompt| turns\n",
            "  user -->|prompt| turns\n  user -->|whim| turns\n",
        )
        self.assertIn("3.0 inflow: decomposition has 'whim', parent does not", dfd_balance.review(broken))

    def test_level_zero_flow_missing_from_the_context(self):
        broken = mutate("  system -->|status line| user\n", "")
        self.assertIn("0 outflow: decomposition has 'status line', parent does not", dfd_balance.review(broken))

    def test_store_drawn_at_the_parent_stays_outside_the_child(self):
        # D3 sits outside 1.0, so 1.4 reading it must balance against level 0.
        broken = mutate("  tokens -->|service token| apply\n", "")
        self.assertIn("1.0 inflow: decomposition has 'service token', parent does not", dfd_balance.review(broken))

    def test_decomposition_of_a_process_no_diagram_draws(self):
        # Skipping a comparison for want of a parent would read as balanced.
        broken = mutate("session(3.0 Run a Claude Code session)", "session(9.0 Run something else)")
        self.assertIn("the 3.0 decomposition decomposes 3.0, which no diagram draws", dfd_balance.review(broken))


class CatchesContextDrift(unittest.TestCase):
    def test_entity_missing_from_the_context(self):
        broken = mutate("  codecov[Codecov]\n", "  codecov[Codeanalysis]\n")
        self.assertIn("context: level 0 has 'Codecov', context does not", dfd_balance.review(broken))

    def test_entity_missing_from_level_zero(self):
        broken = mutate("  tailnet[Tailnet peers]\n", "  tailnet[Tailnet peers]\n  pager[Pagerduty]\n")
        self.assertIn("context: has 'Pagerduty', level 0 does not", dfd_balance.review(broken))


class CatchesDrawingDefects(unittest.TestCase):
    def test_process_without_an_output(self):
        broken = mutate("  serveTailnet -->|outbound peer connection| tailnet\n", "")
        self.assertIn("level 0: 8.0 has no output (black hole)", dfd_balance.review(broken))

    def test_process_without_an_input(self):
        broken = mutate("  user -->|login credential| login\n", "")
        self.assertIn("level 0: 6.0 has no input (miracle)", dfd_balance.review(broken))

    def test_flow_between_two_passive_elements(self):
        broken = mutate(
            "  tokens -->|Grafana Cloud token| ship\n",
            "  tokens -->|Grafana Cloud token| ship\n  tokens -->|leaked token| registry\n",
        )
        self.assertIn(
            "level 0: 'leaked token' runs between two passive elements "
            "(tokens to registry); a process belongs between them",
            dfd_balance.review(broken),
        )


class CatchesThreatModelReasoning(unittest.TestCase):
    def test_conclusion_that_needs_an_adversary(self):
        broken = mutate(
            "The SSH key stays in D4",
            "A compromise of D3 never reaches the key, which stays in D4",
        )
        self.assertTrue(
            [f for f in dfd_balance.review(broken) if "reasons about an adversary" in f],
            "a compromise claim should be a finding",
        )

    def test_pointing_at_the_threat_model_stays_legal(self):
        allowed = mutate("What crosses a tailnet tunnel.", "What crosses a tailnet tunnel; the threat model covers it.")
        self.assertEqual(dfd_balance.review(allowed), [])

    def test_ignores_diagram_bodies(self):
        # Flow names are data, not prose; a store called "compromised backup"
        # would be an element name rather than an inference.
        allowed = mutate(
            "  logins -->|node key| serveTailnet\n",
            "  logins -->|node key| serveTailnet\n  logins -->|compromised backup| serveTailnet\n",
        )
        self.assertEqual([f for f in dfd_balance.review(allowed) if "adversary" in f], [])


class RefusesDocumentsItCannotTrust(unittest.TestCase):
    def test_no_diagrams(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "no mermaid blocks"):
            dfd_balance.review("# Data flow\n\nNothing drawn.\n")

    def test_no_context(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "expected one context"):
            dfd_balance.review(mutate("system(0 Workstation)", "system(9.0 Workstation)"))

    def test_no_level_zero(self):
        with self.assertRaisesRegex(dfd_balance.Malformed, "expected one level 0"):
            dfd_balance.review(mutate("(1.0 Apply", "(1.1 Apply"))


if __name__ == "__main__":
    unittest.main()
