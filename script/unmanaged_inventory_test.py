import pathlib
import runpy
import unittest
from types import SimpleNamespace
from typing import Any

ui = SimpleNamespace(
    **runpy.run_path(str(pathlib.Path(__file__).with_name("unmanaged-inventory")))
)


def package(
    name: str, priority: str = "optional", provides: str = "", depends: str = ""
) -> str:
    """One dpkg-query line in the script's field order."""
    return f"{name}\tinstalled\t{priority}\t{provides}\t\t{depends}\t"


def packages(*lines: str) -> Any:
    return ui.parse_packages("\n".join(lines))


class ParsePackagesTest(unittest.TestCase):
    def test_strips_versions_and_architectures(self) -> None:
        parsed = packages(package("a", depends="b (>= 1.0), c:any, d | e"))
        self.assertEqual(
            parsed["a"].dependencies,
            (frozenset({"b"}), frozenset({"c"}), frozenset({"d", "e"})),
        )

    def test_skips_packages_not_installed(self) -> None:
        parsed = ui.parse_packages("gone\tconfig-files\toptional\t\t\t\t")
        self.assertEqual(parsed, {})


class KeptPackagesTest(unittest.TestCase):
    def test_follows_dependencies_transitively(self) -> None:
        installed = packages(
            package("a", depends="b"), package("b", depends="c"), package("c")
        )
        self.assertEqual(ui.kept_packages({"a"}, installed), {"a", "b", "c"})

    def test_resolves_virtual_packages_to_installed_providers(self) -> None:
        installed = packages(
            package("a", depends="mail-transport-agent"),
            package("postfix", provides="mail-transport-agent"),
        )
        self.assertEqual(ui.kept_packages({"a"}, installed), {"a", "postfix"})

    def test_keeps_every_installed_alternative(self) -> None:
        installed = packages(package("a", depends="b | c"), package("b"), package("c"))
        self.assertEqual(ui.kept_packages({"a"}, installed), {"a", "b", "c"})

    def test_roots_at_base_priorities(self) -> None:
        installed = packages(
            package("base", priority="required", depends="lib"), package("lib")
        )
        self.assertEqual(ui.kept_packages(set(), installed), {"base", "lib"})

    def test_leaves_out_unreached_packages(self) -> None:
        installed = packages(package("a"), package("stray"))
        self.assertEqual(ui.kept_packages({"a"}, installed), {"a"})

    def test_ignores_declared_packages_not_installed(self) -> None:
        self.assertEqual(ui.kept_packages({"missing"}, packages()), set())


class ParseOwnersTest(unittest.TestCase):
    def test_maps_unit_names_to_packages(self) -> None:
        output = (
            "openssh-server: /lib/systemd/system/ssh.service\n"
            "a:amd64, b: /usr/lib/systemd/user/x@.service\n"
            "diversion by foo from: /lib/systemd/system/y.service\n"
        )
        self.assertEqual(
            ui.parse_owners(output),
            {"ssh.service": {"openssh-server"}, "x@.service": {"a", "b"}},
        )


class UnmanagedUnitsTest(unittest.TestCase):
    def test_reports_only_units_neither_deployed_nor_kept(self) -> None:
        units = ui.unmanaged_units(
            enabled={
                "deployed.timer",
                "kept.service",
                "stray.service",
                "loose.service",
            },
            deployed={"deployed.timer"},
            owners={"kept.service": {"pkg"}, "stray.service": {"other"}},
            kept={"pkg"},
        )
        self.assertEqual(units, {"stray.service", "loose.service"})


class UndroppedTest(unittest.TestCase):
    dropped = ui.parse_dropped(
        """
        [[dropped]]
        kind = "file"
        pattern = ".config/*.bak*"
        reason = "backups"
        """
    )

    def test_filters_matching_items_of_the_same_kind(self) -> None:
        items = {".config/zellij/config.kdl.bak.1", ".config/foo"}
        self.assertEqual(ui.undropped("file", items, self.dropped), {".config/foo"})

    def test_leaves_other_kinds_alone(self) -> None:
        items = {".config/x.bak"}
        self.assertEqual(ui.undropped("package", items, self.dropped), items)


class DroppedListTest(unittest.TestCase):
    def test_every_entry_has_a_known_kind_and_a_reason(self) -> None:
        for entry in ui.parse_dropped(ui.DROPPED.read_text()):
            self.assertIn(entry.kind, {"file", "package", "unit"})
            self.assertTrue(entry.reason.strip(), entry.pattern)


if __name__ == "__main__":
    unittest.main()
