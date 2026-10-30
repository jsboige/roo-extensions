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
                     "--env-file", "--margin", "--interval-seconds", "--max-missing"):
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


class G6PassBoundRateResolution(unittest.TestCase):
    """ai-01 CHANGES 29/10: the ceiling belongs to the MEASURED RSM.

    The default used to be float(env) evaluated while building the parser, so a
    nonnumeric EMBEDDING_OPS_PER_MINUTE escaped as a traceback (exit 1 = VIOLATION
    to any caller) and no CLI flag could override it. Resolution is now lazy,
    fail-closed, and always states its provenance.
    """

    def _log(self, body: str) -> str:
        fd, path = tempfile.mkstemp(prefix="g6-rate-", suffix=".log")
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(body)
        self.addCleanup(os.unlink, path)
        return path

    def _env_file(self, body: str) -> str:
        fd, path = tempfile.mkstemp(prefix="g6-env-", suffix=".env")
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(body)
        self.addCleanup(os.unlink, path)
        return path

    def test_nonnumeric_env_is_instrument_not_violation(self):
        proc = _run("--log", os.path.join(tempfile.gettempdir(), "g6-none.log"),
                    env={**os.environ, "EMBEDDING_OPS_PER_MINUTE": "abc"})
        self.assertEqual(proc.returncode, 2, proc.stderr or proc.stdout)
        self.assertIn("EMBEDDING_OPS_PER_MINUTE", proc.stderr)
        self.assertIn("INSTRUMENT", proc.stderr)

    def test_cli_rate_overrides_broken_env(self):
        # with the rate given on the CLI the env value is never consulted: the run
        # proceeds and fails on the (missing) log instead — proving precedence.
        proc = _run("--log", os.path.join(tempfile.gettempdir(), "g6-none.log"),
                    "--ops-per-minute", "10",
                    env={**os.environ, "EMBEDDING_OPS_PER_MINUTE": "abc"})
        self.assertEqual(proc.returncode, 2)
        self.assertNotIn("EMBEDDING_OPS_PER_MINUTE", proc.stderr)

    def test_env_file_wins_over_operator_env_and_states_provenance(self):
        # one pass line, no metrics -> INSTRUMENT "window not closed", but the report
        # still runs and must state where the rate came from.
        path = self._log(
            "2026-10-29T00:10:00.000Z [Qdrant-Worker] pass done: 2 task(s) in 600000ms\n")
        env_file = self._env_file("# seat .env\nEMBEDDING_OPS_PER_MINUTE=2\n")
        proc = _run("--log", path, "--env-file", env_file,
                    env={**os.environ, "EMBEDDING_OPS_PER_MINUTE": "30"})
        self.assertEqual(proc.returncode, 2)
        self.assertIn("env-file", proc.stdout)
        self.assertIn("2/min", proc.stdout)
        self.assertIn("(source:", proc.stdout)

    def test_env_file_without_key_refuses_to_guess(self):
        path = self._log(
            "2026-10-29T00:10:00.000Z [Qdrant-Worker] pass done: 2 task(s) in 600000ms\n")
        env_file = self._env_file("OTHER_KEY=1\n")
        proc = _run("--log", path, "--env-file", env_file)
        self.assertEqual(proc.returncode, 2, proc.stderr or proc.stdout)
        self.assertIn("carries no EMBEDDING_OPS_PER_MINUTE", proc.stderr)

    def test_zero_rate_is_instrument_vacuous_bound(self):
        # EMBEDDING_OPS_PER_MINUTE=0 disables the pacer in the RSM: an unpaced
        # window can produce no allowance. This shape used to PASS at infinity.
        path = self._log(
            "2026-10-29T00:00:00.000Z [EMB-METRICS] called=0 requests=0 rate_limited=0\n"
            "2026-10-29T00:05:00.000Z [EMB-METRICS] called=16 requests=1 rate_limited=0\n"
            "2026-10-29T00:10:00.000Z [EMB-METRICS] called=1744 requests=109 rate_limited=3\n"
            "2026-10-29T00:10:01.000Z [Qdrant-Worker] pass done: 5 task(s) in 600000ms\n")
        proc = _run("--log", path, "--ops-per-minute", "0")
        self.assertEqual(proc.returncode, 2, proc.stdout)
        self.assertIn("pacing disabled", proc.stdout)
        self.assertIn("vacuous", proc.stdout)


if __name__ == "__main__":
    unittest.main()
