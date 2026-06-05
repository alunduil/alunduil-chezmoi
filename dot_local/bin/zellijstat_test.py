"""Function-layer tests for the zellijstat /proc sampler.

Loads the chezmoi-managed executable (no .py suffix) by path and exercises its
pure parsers against synthetic /proc and `ss` fixtures. These cover only
zellijstat's own logic — session extraction, ss aggregation, stat/status
parsing, thread grouping, and exposition rendering — not stdlib behaviour.
"""

import importlib.util
import os
import sys
import tempfile
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

# Don't drop a __pycache__ beside the chezmoi-managed source when importing it.
sys.dont_write_bytecode = True

_SRC = Path(__file__).resolve().parent / "executable_zellijstat"
# The deployed file has no .py suffix, so name the loader explicitly rather
# than letting importlib infer it from the extension. Register it in
# sys.modules before exec so @dataclass can resolve its own module.
_loader = SourceFileLoader("zellijstat", str(_SRC))
_spec = importlib.util.spec_from_loader("zellijstat", _loader)
assert _spec is not None  # spec_from_loader always returns a spec for a loader
zs = importlib.util.module_from_spec(_spec)
sys.modules["zellijstat"] = zs
_loader.exec_module(zs)


class SessionFromCmdline(unittest.TestCase):
    def test_server_cmdline_yields_session(self):
        cmd = b"/home/u/.local/bin/zellij\x00--server\x00/run/user/1000/zellij/0.43.1/mellifluous-muskrat\x00"
        self.assertEqual(zs.session_from_cmdline(cmd), "mellifluous-muskrat")

    def test_client_cmdline_has_no_server(self):
        self.assertIsNone(zs.session_from_cmdline(b"zellij\x00"))

    def test_server_flag_without_value(self):
        self.assertIsNone(zs.session_from_cmdline(b"zellij\x00--server\x00"))


class ReadRssBytes(unittest.TestCase):
    def test_vmrss_kb_to_bytes(self):
        status = "Name:\tzellij\nVmRSS:\t   167488 kB\nThreads:\t54\n"
        self.assertEqual(zs.read_rss_bytes(status), 167488 * 1024)

    def test_missing_vmrss(self):
        self.assertEqual(zs.read_rss_bytes("Name:\tzellij\n"), 0)


class ReadCpuSeconds(unittest.TestCase):
    def test_utime_plus_stime(self):
        # comm contains a ')' to prove the rfind-based split is robust.
        stat = "42 (weird)name) S 1 1 1 0 -1 0 0 0 0 0 10 20 0 0 20 0 1 0 999"
        self.assertAlmostEqual(zs.read_cpu_seconds(stat), 30 / zs.CLK_TCK)

    def test_malformed_returns_zero(self):
        self.assertEqual(zs.read_cpu_seconds("no parens here"), 0.0)


class ParseSsUnix(unittest.TestCase):
    def test_aggregates_per_pid_with_queues(self):
        text = (
            "Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port Process\n"
            'u_str ESTAB 5 0 * 100 * 200 users:(("zellij",pid=18533,fd=9))\n'
            'u_str ESTAB 0 7 * 101 * 201 users:(("zellij",pid=18533,fd=10))\n'
            'u_str ESTAB 0 0 * 102 * 202 users:(("other",pid=999,fd=3))\n'
        )
        out = zs.parse_ss_unix(text)
        self.assertEqual(out[18533], (2, 5, 7))
        self.assertEqual(out[999], (1, 0, 0))

    def test_lines_without_pid_are_ignored(self):
        text = "u_str ESTAB 0 0 /run/systemd/journal/stdout 304 * 0\n"
        self.assertEqual(zs.parse_ss_unix(text), {})


class CollectThreads(unittest.TestCase):
    def _make_task(self, root, threads):
        task = root / "task"
        for tid, (comm, wchan) in threads.items():
            d = task / str(tid)
            d.mkdir(parents=True)
            (d / "comm").write_text(comm + "\n")
            (d / "wchan").write_text(wchan)
        return task

    def test_groups_by_comm_and_wchan(self):

        with tempfile.TemporaryDirectory() as tmp:
            task = self._make_task(
                Path(tmp),
                {
                    1: ("zellij", "futex_wait"),
                    2: ("server_router", "futex_wait"),
                    3: ("server_router", "0"),
                },
            )
            total, by_comm, by_wchan = zs.collect_threads(task)
            self.assertEqual(total, 3)
            self.assertEqual(by_comm["server_router"], 2)
            self.assertEqual(by_wchan["futex_wait"], 2)
            # wchan "0" is reported as the running bucket.
            self.assertEqual(by_wchan["running"], 1)


class CollectAndIter(unittest.TestCase):
    def test_only_servers_sampled(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            root.joinpath("uptime").write_text("100000.00 50000.00\n")
            # A server process. Field 22 (starttime) is the last stat field here.
            srv = root / "18533"
            (srv / "task" / "18533").mkdir(parents=True)
            (srv / "task" / "18533" / "comm").write_text("zellij\n")
            (srv / "task" / "18533" / "wchan").write_text("futex_wait")
            srv.joinpath("comm").write_text("zellij\n")
            srv.joinpath("cmdline").write_bytes(
                b"zellij\x00--server\x00/run/user/1000/zellij/0.43.1/sess-a\x00"
            )
            srv.joinpath("status").write_text("VmRSS:\t1024 kB\n")
            srv.joinpath("stat").write_text(
                "18533 (zellij) S 1 1 1 0 -1 0 0 0 0 0 5 5 0 0 20 0 1 0 8610872"
            )
            fd = srv / "fd"
            fd.mkdir()
            os.symlink("socket:[12345]", fd / "0")
            os.symlink("pipe:[999]", fd / "1")
            os.symlink("/dev/pts/3", fd / "2")
            # A pane child of the server, picked up by the ppid walk.
            child = root / "18600"
            child.mkdir()
            child.joinpath("comm").write_text("bash\n")
            child.joinpath("stat").write_text("18600 (bash) S 18533 18600 18600 0 -1")
            # A client process (no --server) must be skipped.
            cli = root / "18530"
            cli.mkdir()
            cli.joinpath("comm").write_text("zellij\n")
            cli.joinpath("cmdline").write_bytes(b"zellij\x00")

            ss_text = 'u_str ESTAB 3 4 * 1 * 2 users:(("zellij",pid=18533,fd=9))\n'
            samples = zs.collect(proc_root=root, ss_text=ss_text)

            self.assertEqual(len(samples), 1)
            s = samples[0]
            self.assertEqual(s.session, "sess-a")
            self.assertEqual(s.rss_bytes, 1024 * 1024)
            self.assertEqual((s.connections, s.recvq_bytes, s.sendq_bytes), (1, 3, 4))
            self.assertEqual(s.open_fds, 3)
            self.assertEqual(s.fds_by_type, {"socket": 1, "pipe": 1, "pty": 1})
            self.assertEqual(s.panes_by_class, {"shell": 1})
            self.assertEqual(s.state, "S")
            self.assertAlmostEqual(s.uptime_seconds, 100000.0 - 8610872 / zs.CLK_TCK)


class ClassifyFd(unittest.TestCase):
    def test_buckets_by_readlink_prefix(self):
        self.assertEqual(zs.classify_fd("socket:[12345]"), "socket")
        self.assertEqual(zs.classify_fd("pipe:[999]"), "pipe")
        self.assertEqual(zs.classify_fd("anon_inode:[eventpoll]"), "anon")
        self.assertEqual(zs.classify_fd("/dev/pts/3"), "pty")
        self.assertEqual(zs.classify_fd("/dev/ptmx"), "pty")
        self.assertEqual(zs.classify_fd("/tmp/zellij-1000/zellij.log"), "file")


class CollectFds(unittest.TestCase):
    def test_counts_and_groups_symlinks(self):
        with tempfile.TemporaryDirectory() as tmp:
            fd = Path(tmp) / "fd"
            fd.mkdir()
            os.symlink("socket:[1]", fd / "0")
            os.symlink("socket:[2]", fd / "1")
            os.symlink("pipe:[3]", fd / "2")
            os.symlink("/dev/pts/4", fd / "3")
            total, by_type = zs.collect_fds(fd)
            # Total equals the sum of buckets, not the raw entry count.
            self.assertEqual(total, 4)
            self.assertEqual(by_type, {"socket": 2, "pipe": 1, "pty": 1})

    def test_missing_dir_is_empty(self):
        self.assertEqual(zs.collect_fds(Path("/nonexistent/fd")), (0, {}))


class ClassifyChildren(unittest.TestCase):
    def test_shell_claude_other(self):
        self.assertEqual(zs.classify_child("bash"), "shell")
        self.assertEqual(zs.classify_child("zsh"), "shell")
        self.assertEqual(zs.classify_child("claude"), "claude")
        self.assertEqual(zs.classify_child("lazygit"), "other")

    def test_counts_by_class(self):
        out = zs.classify_children(["bash", "claude", "bash", "lazygit"])
        self.assertEqual(out, {"shell": 2, "claude": 1, "other": 1})


class StatFields(unittest.TestCase):
    # comm holds a ')' to prove the rfind split stays robust for every reader.
    _STAT = "42 (we)ird) R 7 1 1 0 -1 0 0 0 0 0 10 20 0 0 20 0 1 0 8610872"

    def test_state(self):
        self.assertEqual(zs.read_state(self._STAT), "R")
        self.assertEqual(zs.read_state("garbage"), "")

    def test_starttime_ticks(self):
        self.assertEqual(zs.read_starttime_ticks(self._STAT), 8610872)
        # Truncated stat (no field 22) yields 0 rather than raising.
        self.assertEqual(zs.read_starttime_ticks("42 (x) S 1 1"), 0)


class ReadUptimeSeconds(unittest.TestCase):
    def test_first_field(self):
        with tempfile.TemporaryDirectory() as tmp:
            Path(tmp, "uptime").write_text("100000.50 50000.00\n")
            self.assertAlmostEqual(zs.read_uptime_seconds(Path(tmp)), 100000.50)

    def test_missing_returns_zero(self):
        self.assertEqual(zs.read_uptime_seconds(Path("/nonexistent")), 0.0)


class ScanProc(unittest.TestCase):
    def test_servers_and_child_map(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            srv = root / "100"
            srv.mkdir()
            srv.joinpath("comm").write_text("zellij\n")
            srv.joinpath("stat").write_text("100 (zellij) S 1 1")
            srv.joinpath("cmdline").write_bytes(
                b"zellij\x00--server\x00/run/user/1000/zellij/0.43.1/sess\x00"
            )
            kid = root / "200"
            kid.mkdir()
            kid.joinpath("comm").write_text("claude\n")
            kid.joinpath("stat").write_text("200 (claude) S 100 200")
            servers, children = zs.scan_proc(root)
            self.assertEqual(servers, [(100, "sess")])
            self.assertEqual(children[100], ["claude"])


class Render(unittest.TestCase):
    def test_exposition_shape_and_escaping(self):
        s = zs.ServerSample(
            pid=1,
            session='we"ird',
            threads=2,
            threads_by_wchan={"futex_wait": 2},
        )
        out = zs.render([s])
        self.assertIn("# TYPE zellijstat_server_threads gauge", out)
        self.assertIn('session="we\\"ird"', out)
        self.assertIn("zellijstat_servers 1", out)
        self.assertTrue(out.endswith("\n"))

    def test_renders_census_metrics(self):
        s = zs.ServerSample(
            pid=7,
            session="sess",
            open_fds=4,
            fds_by_type={"socket": 3, "pty": 1},
            panes_by_class={"shell": 2, "claude": 1},
            uptime_seconds=1234.5,
            state="S",
        )
        out = zs.render([s])
        self.assertIn(
            'zellijstat_server_open_fds_by_type{session="sess",pid="7",type="socket"} 3',
            out,
        )
        self.assertIn('zellijstat_server_panes{session="sess",pid="7"} 3', out)
        self.assertIn(
            'zellijstat_server_panes_by_class{session="sess",pid="7",class="claude"} 1',
            out,
        )
        self.assertIn(
            'zellijstat_server_uptime_seconds{session="sess",pid="7"} 1234.5', out
        )
        self.assertIn(
            'zellijstat_server_state{session="sess",pid="7",state="S"} 1', out
        )


if __name__ == "__main__":
    unittest.main()
