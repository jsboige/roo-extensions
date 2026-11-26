#!/usr/bin/env python3
"""CI wrapper for qdrant-count-window.py (#4928).

The organ carries its own fixture selftest (`--selftest`, argparse style, not
discoverable); this wrapper pins it to the unittest discovery the static CI job
runs (`python3 -m unittest discover -s scripts/testing/python`), plus a CLI
surface smoke and the exit-code contract.

No bare CLI run on the real seat here on purpose: it would read this machine's
live build and RSM journals, so CI would be red for an environment reason, not
a code reason. The exit-2 check uses a throwaway directory instead.
"""

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


if __name__ == "__main__":
    unittest.main()
