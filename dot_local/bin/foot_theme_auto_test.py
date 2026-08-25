"""Function-layer tests for the foot daylight theme switcher.

Loads the chezmoi-managed executable (no .py suffix) by path and exercises its
pure logic: coordinate decoding, solar position, the theme threshold, and the
state-file round trip.

The solar assertions are anchored to astronomical identities rather than to
values this implementation produced -- noon elevation at a solstice is
``90 - latitude ± obliquity`` whatever the code does, so a regression in the
algorithm fails the test instead of being baked into it.
"""

import importlib.util
import signal
import sys
import tempfile
import unittest
from datetime import UTC, datetime, timezone
from importlib.machinery import SourceFileLoader
from pathlib import Path

# Don't drop a __pycache__ beside the chezmoi-managed source when importing it.
sys.dont_write_bytecode = True

_SRC = Path(__file__).resolve().parent / "executable_foot-theme-auto"
# The deployed file has no .py suffix, so name the loader explicitly rather
# than letting importlib infer it from the extension.
_loader = SourceFileLoader("foot_theme_auto", str(_SRC))
_spec = importlib.util.spec_from_loader("foot_theme_auto", _loader)
assert _spec is not None  # spec_from_loader always returns a spec for a loader
fta = importlib.util.module_from_spec(_spec)
sys.modules["foot_theme_auto"] = fta
_loader.exec_module(fta)

# Obliquity of the ecliptic — the sun's declination at either solstice.
OBLIQUITY = 23.44
LONDON_LAT, LONDON_LON = 51.5083, -0.1253


class ParseIso6709(unittest.TestCase):
    def test_degrees_minutes_seconds(self):
        latitude, longitude = fta.parse_iso6709("+513030-0000731")
        self.assertAlmostEqual(latitude, 51 + 30 / 60 + 30 / 3600, places=6)
        self.assertAlmostEqual(longitude, -(7 / 60 + 31 / 3600), places=6)

    def test_degrees_minutes_only(self):
        latitude, longitude = fta.parse_iso6709("+4042-07400")
        self.assertAlmostEqual(latitude, 40 + 42 / 60, places=6)
        self.assertAlmostEqual(longitude, -(74 + 0 / 60), places=6)

    def test_sign_survives_zero_degrees(self):
        """A west longitude under one degree must not lose its hemisphere.

        int("-000") is 0, so a parser that applies the sign via the degrees
        field alone places Greenwich-adjacent longitudes in the east.
        """
        _, longitude = fta.parse_iso6709("+0000-0000731")
        self.assertLess(longitude, 0)

    def test_southern_hemisphere(self):
        latitude, longitude = fta.parse_iso6709("-3352+15113")
        self.assertLess(latitude, 0)
        self.assertGreater(longitude, 0)

    def test_rejects_malformed(self):
        with self.assertRaises(ValueError):
            fta.parse_iso6709("51.5N 0.12W")


class CoordinatesForTimezone(unittest.TestCase):
    ZONE_TAB = "\n".join(
        [
            "# comment line",
            "GB,GG,IM,JE\t+513030-0000731\tEurope/London",
            "US\t+404251-0740023\tAmerica/New_York",
        ]
    )

    def test_finds_zone(self):
        latitude, longitude = fta.coordinates_for_timezone(
            "Europe/London", self.ZONE_TAB
        )
        self.assertAlmostEqual(latitude, LONDON_LAT, places=3)
        self.assertAlmostEqual(longitude, LONDON_LON, places=3)

    def test_matches_zone_not_country_code(self):
        latitude, _ = fta.coordinates_for_timezone("America/New_York", self.ZONE_TAB)
        self.assertAlmostEqual(latitude, 40 + 42 / 60 + 51 / 3600, places=6)

    def test_unknown_zone_raises(self):
        with self.assertRaises(LookupError):
            fta.coordinates_for_timezone("Mars/Olympus_Mons", self.ZONE_TAB)


class ThemeEncoding(unittest.TestCase):
    """The two ways foot is told to select a theme, which must not drift apart."""

    def test_sections_match_foot_125(self):
        self.assertEqual(fta.Theme.DARK.section, "1")
        self.assertEqual(fta.Theme.LIGHT.section, "2")

    def test_signals_match_foot_manual(self):
        """foot(1): SIGUSR1 switches to dark, SIGUSR2 to light."""
        self.assertEqual(fta.Theme.DARK.switch_signal, signal.SIGUSR1)
        self.assertEqual(fta.Theme.LIGHT.switch_signal, signal.SIGUSR2)

    def test_sections_are_distinct(self):
        sections = [theme.section for theme in fta.Theme]
        self.assertCountEqual(sections, set(sections))

    def test_from_section_round_trips(self):
        for theme in fta.Theme:
            self.assertIs(fta.Theme.from_section(theme.section), theme)

    def test_from_section_rejects_unknown(self):
        with self.assertRaises(ValueError):
            fta.Theme.from_section("3")

    def test_str_is_the_human_name(self):
        """--dry-run prints the theme, so this is user-facing output."""
        self.assertEqual(str(fta.Theme.DARK), "dark")
        self.assertEqual(str(fta.Theme.LIGHT), "light")


class JulianDay(unittest.TestCase):
    def test_j2000_epoch(self):
        """J2000.0 is 2000-01-01 12:00 UTC, Julian Day 2451545.0 by definition."""
        observed = fta.julian_day(datetime(2000, 1, 1, 12, 0, tzinfo=UTC))
        self.assertAlmostEqual(observed, 2451545.0, places=6)

    def test_century_is_zero_at_the_epoch(self):
        observed = fta.julian_century(datetime(2000, 1, 1, 12, 0, tzinfo=UTC))
        self.assertAlmostEqual(observed, 0.0, places=9)

    def test_advances_one_per_day(self):
        first = fta.julian_day(datetime(2026, 3, 1, 0, 0, tzinfo=UTC))
        second = fta.julian_day(datetime(2026, 3, 2, 0, 0, tzinfo=UTC))
        self.assertAlmostEqual(second - first, 1.0, places=9)

    def test_january_crosses_the_year_boundary(self):
        """January is month 13 of the prior year internally; the count must not jump."""
        december = fta.julian_day(datetime(2025, 12, 31, 0, 0, tzinfo=UTC))
        january = fta.julian_day(datetime(2026, 1, 1, 0, 0, tzinfo=UTC))
        self.assertAlmostEqual(january - december, 1.0, places=9)


class EquationOfTime(unittest.TestCase):
    """Checked against published extremes, not against this implementation."""

    def minutes(self, month, day):
        when = datetime(2026, month, day, 12, 0, tzinfo=UTC)
        return fta.equation_of_time(fta.solar_elements(fta.julian_century(when)))

    def test_february_minimum(self):
        self.assertAlmostEqual(self.minutes(2, 11), -14.2, delta=0.3)

    def test_november_maximum(self):
        self.assertAlmostEqual(self.minutes(11, 3), 16.4, delta=0.3)

    def test_stays_within_the_annual_envelope(self):
        """It never leaves roughly ±17 minutes; a runaway term would show here."""
        for month in range(1, 13):
            self.assertLess(abs(self.minutes(month, 15)), 17.0)


class SolarElevation(unittest.TestCase):
    def elevation(self, when, latitude=LONDON_LAT, longitude=LONDON_LON):
        return fta.solar_elevation(when, fta.Coordinates(latitude, longitude))

    def test_june_solstice_noon_matches_identity(self):
        """Noon elevation at the June solstice is 90 - latitude + obliquity."""
        observed = self.elevation(datetime(2026, 6, 21, 12, 2, tzinfo=UTC))
        self.assertAlmostEqual(observed, 90 - LONDON_LAT + OBLIQUITY, delta=0.1)

    def test_december_solstice_noon_matches_identity(self):
        """And 90 - latitude - obliquity at the December solstice."""
        observed = self.elevation(datetime(2026, 12, 21, 11, 58, tzinfo=UTC))
        self.assertAlmostEqual(observed, 90 - LONDON_LAT - OBLIQUITY, delta=0.1)

    def test_equator_equinox_noon_is_overhead(self):
        observed = self.elevation(
            datetime(2026, 3, 20, 12, 0, tzinfo=UTC),
            latitude=0.0,
            longitude=0.0,
        )
        self.assertGreater(observed, 87.0)

    def test_sun_is_down_at_midnight(self):
        observed = self.elevation(datetime(2026, 6, 21, 0, 0, tzinfo=UTC))
        self.assertLess(observed, 0.0)

    def test_crosses_horizon_at_published_sunset(self):
        """London set at 20:21 UTC on 2026-06-21; bracket the crossing.

        Ten minutes before, the sun is up; three minutes after, it is below
        the sunset threshold. Anything worse than that bracket means the
        equation of time or the hour angle is wrong.
        """
        before = self.elevation(datetime(2026, 6, 21, 20, 11, tzinfo=UTC))
        after = self.elevation(datetime(2026, 6, 21, 20, 24, tzinfo=UTC))
        self.assertGreater(before, fta.SUNSET_ELEVATION)
        self.assertLess(after, fta.SUNSET_ELEVATION)

    def test_naive_and_aware_agree(self):
        """A non-UTC input is converted, not read as though it were UTC."""
        from datetime import timedelta

        utc = datetime(2026, 6, 21, 12, 0, tzinfo=UTC)
        shifted = utc.astimezone(timezone(timedelta(hours=5)))
        self.assertAlmostEqual(self.elevation(utc), self.elevation(shifted), places=9)


class ThemeForElevation(unittest.TestCase):
    def test_above_horizon_is_light(self):
        self.assertIs(fta.theme_for_elevation(10.0), fta.Theme.LIGHT)

    def test_below_horizon_is_dark(self):
        self.assertIs(fta.theme_for_elevation(-10.0), fta.Theme.DARK)

    def test_threshold_is_refraction_corrected_not_zero(self):
        """Between -0.833 and 0 the sun is set by convention but geometrically up."""
        self.assertIs(fta.theme_for_elevation(-0.5), fta.Theme.LIGHT)
        self.assertIs(fta.theme_for_elevation(-1.0), fta.Theme.DARK)

    def test_custom_horizon(self):
        self.assertIs(fta.theme_for_elevation(-3.0, horizon=-6.0), fta.Theme.LIGHT)
        self.assertIs(fta.theme_for_elevation(-8.0, horizon=-6.0), fta.Theme.DARK)


class StateFile(unittest.TestCase):
    def test_round_trip(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "foot" / "theme-state.ini"
            fta.write_state(path, fta.Theme.LIGHT)
            self.assertIs(fta.read_state(path), fta.Theme.LIGHT)
            fta.write_state(path, fta.Theme.DARK)
            self.assertIs(fta.read_state(path), fta.Theme.DARK)

    def test_missing_file_reads_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertIsNone(fta.read_state(Path(tmp) / "absent.ini"))

    def test_unparseable_file_reads_none(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "theme-state.ini"
            path.write_text("[main]\nfont=whatever\n")
            self.assertIsNone(fta.read_state(path))

    def test_rendered_state_carries_its_own_section(self):
        """foot gives an included file its own section scope.

        Without the [main] header, initial-color-theme would land in
        whatever section foot defaults to and be ignored.
        """
        self.assertIn("[main]", fta.render_state(fta.Theme.DARK))

    def test_rendered_state_uses_foot_125_section_numbers(self):
        """foot 1.25 takes 1 or 2, not dark or light.

        Writing the words instead would be silently ignored: foot rejects the
        value and keeps its default, so every window would come up dark.
        """
        self.assertIn("initial-color-theme=1", fta.render_state(fta.Theme.DARK))
        self.assertIn("initial-color-theme=2", fta.render_state(fta.Theme.LIGHT))

    def test_state_ignores_a_theme_written_as_a_word(self):
        """A file left over from a 1.26+ config reads as unset, not as dark."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "theme-state.ini"
            path.write_text("[main]\ninitial-color-theme=dark\n")
            self.assertIsNone(fta.read_state(path))

    def test_write_leaves_no_scratch_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "theme-state.ini"
            fta.write_state(path, fta.Theme.DARK)
            self.assertEqual([p.name for p in Path(tmp).iterdir()], [path.name])


class TimezoneName(unittest.TestCase):
    def test_localtime_symlink_wins_over_timezone_file(self):
        """systemd rewrites the symlink; /etc/timezone is a Debian echo that drifts."""
        with tempfile.TemporaryDirectory() as tmp:
            link = Path(tmp) / "localtime"
            link.symlink_to("/usr/share/zoneinfo/Europe/London")
            stale = Path(tmp) / "timezone"
            stale.write_text("America/New_York\n")
            self.assertEqual(fta.timezone_name(link, stale), "Europe/London")

    def test_falls_back_to_timezone_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            absent = Path(tmp) / "localtime"
            named = Path(tmp) / "timezone"
            named.write_text("Europe/London\n")
            self.assertEqual(fta.timezone_name(absent, named), "Europe/London")

    def test_raises_when_undeterminable(self):
        with (
            tempfile.TemporaryDirectory() as tmp,
            self.assertRaises(LookupError),
        ):
            fta.timezone_name(Path(tmp) / "localtime", Path(tmp) / "timezone")


class FootPids(unittest.TestCase):
    def _proc(self, root, entries):
        for name, comm in entries.items():
            task = Path(root) / name
            task.mkdir()
            if comm is not None:
                (task / "comm").write_text(comm + "\n")

    def test_matches_comm_exactly(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._proc(
                tmp,
                {
                    "101": "foot",
                    "102": "footclient",
                    "103": "bash",
                    "104": "foot",
                    "self": "foot",
                    "cpuinfo": None,
                },
            )
            self.assertEqual(fta.foot_pids(Path(tmp)), [101, 104])

    def test_unreadable_entry_is_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            self._proc(tmp, {"200": None, "201": "foot"})
            self.assertEqual(fta.foot_pids(Path(tmp)), [201])


if __name__ == "__main__":
    unittest.main()
