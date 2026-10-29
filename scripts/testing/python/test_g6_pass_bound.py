#!/usr/bin/env python3
"""CI wrapper for g6-pass-bound.py (#4352 g6, ai-01 review 29/10).

The probe carries its own fixture selftest (`--selftest`, argparse style — not
discoverable); this wrapper pins it to the unittest discovery the static CI job
runs (`python3 -m unittest discover -s scripts/testing/python`), plus the CLI
surface and the two exit-code contracts callers rely on.

The selftest needs no network, no log from a live seat, and no env: it composes
its own logs. That is deliberate — the first version of the probe bounded the
pass on `called` (sub-chunks) instead of `requests` (HTTP calls) and was up to
16x too generous, so the guard that must not rot is the fixture that reproduces
that defect.
"""

import os
import subprocess
import sys
import tempfile
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "g6-pass-bound.py")


def _run(*args, **kwargs):
    return subprocess.run([sys.executable, _SCRIPT, *args],
                          capture_output=True, text=True, timeout=120, **kwargs)


class G6PassBoundSelftest(unittest.TestCase):

    def test_selftest_passes(self):
        proc = _run("--selftest")
        self.assertEqual(proc.returncode, 0,
                         f"selftest failed:\n{proc.stdout}\n{proc.stderr}")
        self.assertIn("[selftest] PASS", proc.stdout)
        # the chunk-delta defect must be one of the covered cases, by name
        self.assertIn("stall hidden behind the chunk delta", proc.stdout)
        self.assertIn("log without requests=", proc.stdout)

    def test_cli_help_smoke(self):
        proc = _run("--help")
        self.assertEqual(proc.returncode, 0)
        for flag in ("--log", "--json", "--selftest", "--ops-per-minute",
                     "--margin", "--interval-seconds", "--max-missing"):
            self.assertIn(flag, proc.stdout)


class G6PassBoundExitCodes(unittest.TestCase):
    """Exit 2 is the INSTRUMENT contract: never a PASS by silence, never a 1."""

    def _log(self, body: str) -> str:
        fd, path = tempfile.mkstemp(prefix="g6-ci-", suffix=".log")
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(body)
        self.addCleanup(os.unlink, path)
        return path

    def test_malformed_timestamp_is_instrument_not_violation(self):
        # ai-01 review: an unparseable date used to escape as a traceback, i.e. exit 1,
        # which any caller reads as VIOLATION. It must be exit 2.
        path = self._log(
            "2026-13-45T00:00:00.000Z [EMB-METRICS] called=0 requests=0\n"
            "2026-13-45T00:10:00.000Z [Qdrant-Worker] pass done: 2 task(s) in 600000ms\n")
        proc = _run("--log", path)
        self.assertEqual(proc.returncode, 2, proc.stderr or proc.stdout)
        self.assertIn("INSTRUMENT", proc.stderr)

    def test_missing_log_is_instrument(self):
        proc = _run("--log", os.path.join(tempfile.gettempdir(), "g6-does-not-exist.log"))
        self.assertEqual(proc.returncode, 2)

    def test_log_without_pass_done_is_instrument(self):
        path = self._log(
            "2026-10-29T00:00:00.000Z [EMB-METRICS] called=0 requests=0\n"
            "2026-10-29T00:05:00.000Z [EMB-METRICS] called=16 requests=1\n")
        proc = _run("--log", path)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("no 'pass done'", proc.stderr)


if __name__ == "__main__":
    unittest.main()
