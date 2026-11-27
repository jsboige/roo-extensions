#!/usr/bin/env python3
"""Tests for scripts/diagnostic/audit-stale-mcp-disables.py (#4937, #4195).

unittest style on purpose: the CI static job runs
`python3 -m unittest discover -s scripts/testing/python`, which collects nothing
from plain pytest functions; pytest also runs these classes. Fixtures live in a
temp dir, never the real ~/.claude.json.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "audit-stale-mcp-disables.py")


def _run(*args):
    return subprocess.run([sys.executable, _SCRIPT, *args],
                          capture_output=True, text=True, encoding="utf-8")


class AuditStaleMcpDisables(unittest.TestCase):

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory(prefix="audit-stale-mcp-test-")
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.live = self.tmp / "live-ws"
        self.live.mkdir()
        self.ghost = str(self.tmp / "moved-away" / "ws")

    def _config(self, data):
        path = self.tmp / "claude.json"
        path.write_text(data if isinstance(data, str) else json.dumps(data),
                        encoding="utf-8")
        return str(path)

    def test_ghost_path_is_stale_exit_2(self):
        cfg = self._config({"projects": {self.ghost: {"disabledMcpServers": ["google-workspace"]}}})
        r = _run("--config", cfg)
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        self.assertIn("[STALE-GHOST]", r.stdout)

    def test_existing_path_is_active_exit_0(self):
        cfg = self._config({"projects": {str(self.live): {"disabledMcpServers": ["sk-agent"]}}})
        r = _run("--config", cfg)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("[ACTIVE]", r.stdout)
        self.assertNotIn("[STALE-GHOST]", r.stdout)

    def test_no_projects_or_no_disable_exit_0(self):
        for data in ({}, {"projects": {str(self.live): {"other": 1}}},
                     {"projects": {self.ghost: {"disabledMcpServers": []}}}):
            with self.subTest(data=data):
                r = _run("--config", self._config(data))
                self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_unreadable_json_exit_1(self):
        r = _run("--config", self._config("{not json"))
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_missing_file_exit_1(self):
        r = _run("--config", str(self.tmp / "absent.json"))
        self.assertEqual(r.returncode, 1, r.stdout + r.stderr)

    def test_json_output_names_ghost_keys(self):
        cfg = self._config({"projects": {
            self.ghost: {"disabledMcpServers": ["google-workspace"]},
            str(self.live): {"disabledMcpServers": ["sk-agent"]}}})
        r = _run("--config", cfg, "--json")
        self.assertEqual(r.returncode, 2, r.stdout + r.stderr)
        out = json.loads(r.stdout.split("[FINDINGS]")[0])
        self.assertEqual([s["key"] for s in out["stale"]], [self.ghost])
        self.assertEqual([a["key"] for a in out["active"]], [str(self.live)])

    def test_selftest_exit_0(self):
        r = _run("--selftest")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)


if __name__ == "__main__":
    unittest.main()
