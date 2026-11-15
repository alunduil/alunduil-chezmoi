"""Function-layer tests for script/checks/theme-contrast.

Loads the extensionless check by path and feeds each rule a palette it
should reject.
"""

import pathlib
import runpy
import unittest
from types import SimpleNamespace

tc = SimpleNamespace(
    **runpy.run_path(str(pathlib.Path(__file__).with_name("theme-contrast")))
)

RGB = tuple[int, int, int]
Blocks = dict[str, dict[str, RGB]]

WHITE: RGB = (255, 255, 255)
BLACK: RGB = (0, 0, 0)


def terminal(**overrides: RGB) -> dict[str, RGB]:
    """Sixteen distinct near-white slots, all above 7:1 on black."""
    colors = {
        slot: (200 + i, 200 + i, 200 + i) for i, slot in enumerate(tc.TERMINAL_SLOTS)
    }
    colors["black"] = (10, 10, 10)
    colors.update(overrides)
    return colors


def dark_theme(**terminal_overrides: RGB) -> Blocks:
    return {
        "text_unselected": {"base": WHITE, "background": BLACK},
        "terminal_colors": terminal(**terminal_overrides),
    }


class ParseTheme(unittest.TestCase):
    def test_reads_nested_blocks(self) -> None:
        text = "themes {\n    t {\n        text_unselected {\n            base 1 2 3\n            background 4 5 6\n        }\n    }\n}\n"
        self.assertEqual(
            tc.parse_theme(text),
            {"text_unselected": {"base": (1, 2, 3), "background": (4, 5, 6)}},
        )


class UiFailures(unittest.TestCase):
    def test_flags_foreground_below_aaa_against_its_own_block(self) -> None:
        blocks = dark_theme()
        blocks["ribbon"] = {"base": (120, 120, 120), "background": (100, 100, 100)}
        self.assertEqual(len(tc.ui_failures(blocks)), 1)

    def test_block_without_background_is_measured_against_the_page(self) -> None:
        blocks = dark_theme()
        blocks["multiplayer_user_colors"] = {"player_1": (30, 30, 30)}
        self.assertIn("multiplayer_user_colors.player_1", tc.ui_failures(blocks)[0])


class TerminalFailures(unittest.TestCase):
    def test_passing_palette(self) -> None:
        self.assertEqual(tc.terminal_failures(dark_theme()), [])

    def test_background_role_slot_is_exempt_only_for_its_hue(self) -> None:
        self.assertEqual(tc.terminal_failures(dark_theme(black=BLACK)), [])
        self.assertEqual(len(tc.terminal_failures(dark_theme(white=(20, 20, 20)))), 1)

    def test_merged_slots_fail(self) -> None:
        failures = tc.terminal_failures(dark_theme(bright_red=terminal()["red"]))
        self.assertTrue(any("15 distinct" in f for f in failures))

    def test_missing_slot_fails(self) -> None:
        blocks = dark_theme()
        del blocks["terminal_colors"]["cyan"]
        self.assertTrue(any("lacks cyan" in f for f in tc.terminal_failures(blocks)))


class KittyFailures(unittest.TestCase):
    def kitty_for(self, blocks: Blocks) -> dict[str, RGB]:
        colors = {"foreground": WHITE, "background": BLACK}
        for i, slot in enumerate(tc.TERMINAL_SLOTS):
            colors[f"color{i}"] = blocks["terminal_colors"][slot]
        return colors

    def test_matching_kitty_passes(self) -> None:
        blocks = dark_theme()
        self.assertEqual(tc.kitty_failures(self.kitty_for(blocks), blocks), [])

    def test_drifted_slot_fails(self) -> None:
        blocks = dark_theme()
        kitty = self.kitty_for(blocks)
        kitty["color4"] = (1, 2, 3)
        self.assertEqual(
            tc.kitty_failures(kitty, blocks),
            ["kitty color4 differs from chromeos-dark"],
        )


class ParseKitty(unittest.TestCase):
    def test_reads_hex(self) -> None:
        self.assertEqual(
            tc.parse_kitty("color4  #9ad3ff\nbackground #493544\n"),
            {"color4": (0x9A, 0xD3, 0xFF), "background": (0x49, 0x35, 0x44)},
        )
