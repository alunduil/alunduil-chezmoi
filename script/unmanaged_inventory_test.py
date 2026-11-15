import pathlib
import runpy
import subprocess
import tempfile
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
        patterns = [".config/*.bak*"]
        reason = "backups"
        """
    )

    def test_filters_matching_items_of_the_same_kind(self) -> None:
        items = {".config/zellij/config.kdl.bak.1", ".config/foo"}
        self.assertEqual(ui.undropped("file", items, self.dropped), {".config/foo"})

    def test_leaves_other_kinds_alone(self) -> None:
        items = {".config/x.bak"}
        self.assertEqual(ui.undropped("package", items, self.dropped), items)


class UnmanagedFilesTest(unittest.TestCase):
    """Checkouts are marked by a .git entry; the stub recoverable accepts any
    checkout whose name starts with "clean"."""

    def setUp(self) -> None:
        self.home = pathlib.Path(self.enterContext(tempfile.TemporaryDirectory()))

    def checkout(self, path: str) -> None:
        self.file(f"{path}/.git/HEAD")

    def file(self, path: str) -> None:
        (self.home / path).parent.mkdir(parents=True, exist_ok=True)
        (self.home / path).touch()

    def found(self, *items: str) -> set[str]:
        found: set[str] = ui.unmanaged_files(
            items, self.home, lambda p: p.name.startswith("clean")
        )
        return found

    def test_leaves_out_empty_directory_trees(self) -> None:
        (self.home / "empty/nested").mkdir(parents=True)
        self.assertEqual(self.found("empty"), set())

    def test_leaves_out_recoverable_checkouts(self) -> None:
        self.checkout("clean-repo")
        self.assertEqual(self.found("clean-repo"), set())

    def test_reports_unrecoverable_checkouts(self) -> None:
        self.checkout("dirty-repo")
        self.assertEqual(self.found("dirty-repo"), {"dirty-repo"})

    def test_narrows_a_directory_of_checkouts_to_the_unrecoverable(self) -> None:
        self.checkout("worktrees/org/repo/clean-pet")
        self.checkout("worktrees/org/repo/dirty-pet")
        (self.home / "worktrees/org/emptied").mkdir()
        self.assertEqual(self.found("worktrees"), {"worktrees/org/repo/dirty-pet"})

    def test_reports_a_directory_holding_anything_besides_checkouts(self) -> None:
        self.checkout("org/clean-repo")
        self.file("org/notes.md")
        self.assertEqual(self.found("org"), {"org"})

    def test_reports_checkouts_nested_deeper_than_the_limit(self) -> None:
        self.checkout("a/b/c/d/clean-repo")
        self.assertEqual(self.found("a"), {"a"})

    def test_reports_plain_files(self) -> None:
        self.file("notes.md")
        self.assertEqual(self.found("notes.md"), {"notes.md"})


class RecoverableTest(unittest.TestCase):
    def setUp(self) -> None:
        self.repo = pathlib.Path(self.enterContext(tempfile.TemporaryDirectory()))
        self.git("init", "--quiet")
        self.git("remote", "add", "origin", "git@github.com:owner/repo.git")
        self.git("commit", "--quiet", "--allow-empty", "-m", "first")
        self.git("update-ref", "refs/remotes/origin/main", "HEAD")

    def git(self, *args: str) -> None:
        subprocess.run(
            ("git", "-C", str(self.repo), "-c", "user.name=t", "-c", "user.email=t@t")
            + args,
            check=True,
        )

    def test_accepts_a_clean_pushed_github_checkout(self) -> None:
        self.assertTrue(ui.is_recoverable(self.repo))

    def test_rejects_untracked_files(self) -> None:
        (self.repo / "new").touch()
        self.assertFalse(ui.is_recoverable(self.repo))

    def test_rejects_a_head_on_no_remote(self) -> None:
        self.git("commit", "--quiet", "--allow-empty", "-m", "local")
        self.assertFalse(ui.is_recoverable(self.repo))

    def test_rejects_an_origin_off_github(self) -> None:
        self.git("remote", "set-url", "origin", "https://example.com/repo.git")
        self.assertFalse(ui.is_recoverable(self.repo))

    def test_rejects_a_checkout_without_origin(self) -> None:
        self.git("remote", "remove", "origin")
        self.assertFalse(ui.is_recoverable(self.repo))


def dropped_entry(
    kind: str = "file", patterns: str = '["x"]', reason: str = "why"
) -> str:
    return f'[[dropped]]\nkind = "{kind}"\npatterns = {patterns}\nreason = "{reason}"\n'


class ParseDroppedTest(unittest.TestCase):
    def test_rejects_an_entry_without_patterns(self) -> None:
        with self.assertRaisesRegex(ValueError, "no patterns"):
            ui.parse_dropped(dropped_entry(patterns="[]"))

    def test_rejects_an_unknown_kind(self) -> None:
        with self.assertRaisesRegex(ValueError, "unknown kind"):
            ui.parse_dropped(dropped_entry(kind="pacakge"))

    def test_rejects_a_blank_reason(self) -> None:
        with self.assertRaisesRegex(ValueError, "no reason"):
            ui.parse_dropped(dropped_entry(reason=" "))

    def test_accepts_the_committed_list(self) -> None:
        ui.parse_dropped(ui.DROPPED.read_text())


if __name__ == "__main__":
    unittest.main()
