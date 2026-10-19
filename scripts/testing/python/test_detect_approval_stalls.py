#!/usr/bin/env python3
"""CI wrapper for detect-approval-stalls.py (#4243, volet 3).

The detector carries its own fixture selftest (`--selftest`, argparse style —
not discoverable); this wrapper pins it to the unittest discovery the static
CI job runs (`python3 -m unittest discover -s scripts/testing/python`), plus a
smoke of the CLI surface on an empty root. Guards the import-by-path contract
with scan-approval-waits.py: if its helpers (parse_ts, redact, load_hook_log)
move or change signature, the selftest breaks here before any seat runs the
tool for real.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "detect-approval-stalls.py")


class DetectApprovalStallsSelftest(unittest.TestCase):

    def test_selftest_passes(self):
        proc = subprocess.run([sys.executable, _SCRIPT, "--selftest"],
                              capture_output=True, text=True, timeout=120)
        self.assertEqual(proc.returncode, 0,
                         f"selftest failed:\n{proc.stdout}\n{proc.stderr}")
        self.assertIn("selftest OK", proc.stdout)

    def test_cli_json_smoke_on_empty_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            proc = subprocess.run(
                [sys.executable, _SCRIPT, "--root", tmp, "--json"],
                capture_output=True, text=True, timeout=60)
            self.assertEqual(proc.returncode, 0,
                             f"empty root must exit clean:\n{proc.stdout}\n{proc.stderr}")
            payload = json.loads(proc.stdout)
            self.assertEqual(payload["totals"]["files"], 0)
            self.assertEqual(payload["totals"]["stalls"], 0)

    def test_cli_dashboard_without_bearer_is_best_effort(self):
        # --dashboard with no bearer (arg or env) must degrade to a warning and
        # leave the exit code to the detection result alone (#4243 volet 3).
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if k != "MCP_PROXY_BEARER"}
            proc = subprocess.run(
                [sys.executable, _SCRIPT, "--root", tmp, "--dashboard"],
                capture_output=True, text=True, timeout=60, env=env)
            self.assertEqual(proc.returncode, 0,
                             f"no-bearer must exit clean:\n{proc.stdout}\n{proc.stderr}")
            self.assertIn("without bearer", proc.stderr)

    def test_cli_accepts_dashboard_timeout(self):
        # The scheduled launcher passes --dashboard-timeout (run-approval-stall-detector.ps1).
        with tempfile.TemporaryDirectory() as tmp:
            env = {k: v for k, v in os.environ.items() if k != "MCP_PROXY_BEARER"}
            proc = subprocess.run(
                [sys.executable, _SCRIPT, "--root", tmp, "--dashboard",
                 "--dashboard-timeout", "60"],
                capture_output=True, text=True, timeout=60, env=env)
            self.assertEqual(proc.returncode, 0,
                             f"--dashboard-timeout must parse:\n{proc.stdout}\n{proc.stderr}")


if __name__ == "__main__":
    unittest.main()
