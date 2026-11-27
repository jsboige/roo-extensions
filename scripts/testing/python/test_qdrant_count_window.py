#!/usr/bin/env python3
"""CI wrapper for qdrant-count-window.py (#4928).

The organ carries its own fixture selftest (`--selftest`, argparse style, not
discoverable); this wrapper pins it to the unittest discovery the static CI job
runs (`python3 -m unittest discover -s scripts/testing/python`), plus a CLI
surface smoke and the exit-code contract.

No bare CLI run on the real seat here on purpose: it would read this machine's
live build and RSM journals, so CI would be red for an environment reason, not
a code reason. The exit-2 checks use a throwaway directory instead, and each
names its cause: a failed build pointer and an absent journal are two different
instrument errors, and one assertion cannot stand for both (review of #4932).
"""

import datetime
import os
import subprocess
import sys
import tempfile
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "qdrant-count-window.py")


class QdrantCountWindowSelftest(unittest.TestCase):

    def test_selftest_passes(self):
        proc = subprocess.run([sys.executable, _SCRIPT, "--selftest"],
                              capture_output=True, text=True, timeout=180)
        self.assertEqual(proc.returncode, 0,
                         f"selftest failed:\n{proc.stdout}\n{proc.stderr}")
        self.assertIn("[SELFTEST] PASS", proc.stdout)

    def test_cli_help_smoke(self):
        # The protocol replays this exact command before and after the fix:
        # argparse must exist and document the flags the measurement relies on.
        proc = subprocess.run([sys.executable, _SCRIPT, "--help"],
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(proc.returncode, 0)
        for flag in ("--rsm-root", "--log-dir", "--since", "--until",
                     "--no-hosts", "--json", "--selftest"):
            self.assertIn(flag, proc.stdout)

    def test_instrument_error_exit_2(self):
        # A silent reader must never render a value: no build pointer -> exit 2.
        with tempfile.TemporaryDirectory() as empty:
            proc = subprocess.run(
                [sys.executable, _SCRIPT, "--rsm-root", empty,
                 "--log-dir", os.path.join(empty, "logs"), "--no-hosts"],
                capture_output=True, text=True, timeout=60)
        self.assertEqual(proc.returncode, 2, proc.stderr)
        self.assertIn("INSTRUMENT ERROR", proc.stderr)
        # Name the cause: this run must fail on the BUILD, not on the journal.
        self.assertIn("build-current absent", proc.stderr)

    def _fake_rsm(self):
        """A throwaway RSM root: pointer + compiled file, no live build read."""
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = tmp.name
        vintage = "build-0123456789abcdef"
        build = os.path.join(root, vintage, "services", "task-indexer")
        os.makedirs(build)
        with open(os.path.join(root, "build-current"), "w") as handle:
            handle.write(vintage)
        with open(os.path.join(build, "VectorIndexer.js"), "w") as handle:
            handle.write("export async function countPointsByHostOs(h) {\n"
                         "  return qdrant.count(C, { exact: false });\n}\n")
        return root

    def _run(self, root, log_dir, *extra):
        return subprocess.run(
            [sys.executable, _SCRIPT, "--rsm-root", root,
             "--log-dir", log_dir, "--no-hosts", *extra],
            capture_output=True, text=True, timeout=60)

    def test_absent_log_dir_is_an_instrument_error(self):
        # An ABSENT journal is not a journal with zero lines. With a valid
        # build pointer, the exit 2 must come from the journal and say so.
        root = self._fake_rsm()
        proc = self._run(root, os.path.join(root, "no-such-dir"))
        self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
        self.assertIn("INSTRUMENT ERROR", proc.stderr)
        self.assertIn("dossier de journaux absent", proc.stderr)

    def test_journal_without_dated_line_is_an_instrument_error(self):
        # Same silent zero, one step further: a directory that exists but
        # carries no dated line in the window renders `aucun` on every series.
        root = self._fake_rsm()
        empty = os.path.join(root, "empty")
        os.mkdir(empty)
        proc = self._run(root, empty)
        self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
        self.assertIn("aucune ligne datee", proc.stderr)
        self.assertNotIn("dossier de journaux absent", proc.stderr)

    def test_read_journal_still_renders(self):
        # The two guards above must not refuse a journal that IS readable:
        # one dated line in the window is enough for the series to be a value.
        root = self._fake_rsm()
        logs = os.path.join(root, "logs")
        os.mkdir(logs)
        day = datetime.datetime.now(datetime.timezone.utc).date().isoformat()
        with open(os.path.join(logs, "roosync-1.log"), "w") as handle:
            handle.write("[%s 04:00:00] Server started\n" % day)
        proc = self._run(root, logs)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("demarrages serveur/jour: %s:1" % day[5:], proc.stdout)
        self.assertIn("qdrant_upsert_failed/jour: aucun", proc.stdout)


if __name__ == "__main__":
    unittest.main()
