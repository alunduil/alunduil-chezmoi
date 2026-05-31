"""Function-layer tests for the zellijstat /proc sampler.

Loads the chezmoi-managed executable (no .py suffix) by path and exercises its
pure parsers against synthetic /proc and `ss` fixtures. These cover only
zellijstat's own logic — session extraction, ss aggregation, stat/status
parsing, thread grouping, and exposition rendering — not stdlib behaviour.
"""

import importlib.util
import sys
import unittest
from importlib.machinery import SourceFileLoader
from pathlib import Path

# Don't drop a __pycache__ beside the chezmoi-managed source when importing it.
sys.dont_write_bytecode = True

_SRC = Path(__file__).resolve().parent.parent / "dot_local" / "bin" / "executable_zellijstat"
# The deployed file has no .py suffix, so name the loader explicitly rather
# than letting importlib infer it from the extension. Register it in
# sys.modules before exec so @dataclass can resolve its own module.
_loader = SourceFileLoader("zellijstat", str(_SRC))
_spec = importlib.util.spec_from_loader("zellijstat", _loader)
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
        import tempfile

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
        import tempfile

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # A server process.
            srv = root / "18533"
            (srv / "task" / "18533").mkdir(parents=True)
            (srv / "task" / "18533" / "comm").write_text("zellij\n")
            (srv / "task" / "18533" / "wchan").write_text("futex_wait")
            srv.joinpath("comm").write_text("zellij\n")
            srv.joinpath("cmdline").write_bytes(
                b"zellij\x00--server\x00/run/user/1000/zellij/0.43.1/sess-a\x00"
            )
            srv.joinpath("status").write_text("VmRSS:\t1024 kB\n")
            srv.joinpath("stat").write_text("18533 (zellij) S 1 1 1 0 -1 0 0 0 0 0 5 5 0 0")
            (srv / "fd").mkdir()
            (srv / "fd" / "0").write_text("")
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
            self.assertEqual(s.open_fds, 1)


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


if __name__ == "__main__":
    unittest.main()
