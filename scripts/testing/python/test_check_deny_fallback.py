#!/usr/bin/env python3
"""CI wrapper for check-deny-fallback.py (#4340).

The probe carries its own fixture selftest (`--selftest`, argparse style —
not discoverable); this wrapper pins it to the unittest discovery the static
CI job runs (`python3 -m unittest discover -s scripts/testing/python`), plus
a CLI surface smoke. No bare CLI run here on purpose: without overrides the
probe reads the REAL ~/.claude/settings.json of whoever runs it — a live
finding on a deny seat (po-2024 today) would make CI red for an environment
reason, not a code reason. The selftest itself performs a REAL stdio
handshake against an in-process fake MCP server: it covers ok / flag-inert /
missing-config / spec-form-deny / disabled-seat / inert / deaf.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "check-deny-fallback.py")


class CheckDenyFallbackSelftest(unittest.TestCase):

    def test_selftest_passes(self):
        proc = subprocess.run([sys.executable, _SCRIPT, "--selftest"],
                              capture_output=True, text=True, timeout=180)
        self.assertEqual(proc.returncode, 0,
                         f"selftest failed:\n{proc.stdout}\n{proc.stderr}")
        self.assertIn("[SELFTEST] PASS", proc.stdout)

    def test_cli_help_smoke(self):
        # The pre-flight invokes `python check-deny-fallback.py --workspace ...`:
        # argparse must exist and document the flags the wiring relies on.
        proc = subprocess.run([sys.executable, _SCRIPT, "--help"],
                              capture_output=True, text=True, timeout=60)
        self.assertEqual(proc.returncode, 0)
        for flag in ("--workspace", "--timeout", "--json", "--selftest"):
            self.assertIn(flag, proc.stdout)


if __name__ == "__main__":
    unittest.main()
