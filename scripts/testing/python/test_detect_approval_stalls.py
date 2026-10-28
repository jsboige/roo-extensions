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
from datetime import datetime, timedelta, timezone

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "diagnostic", "detect-approval-stalls.py")


def _iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"


def _stalled_session(root, session="dead001", age_hours=3.0):
    """One session whose transcript ends on an unanswered shell tool_use."""
    ts = datetime.now(timezone.utc) - timedelta(hours=age_hours)
    record = {"type": "assistant", "uuid": "a1", "timestamp": _iso(ts),
              "message": {"role": "assistant", "content": [
                  {"type": "tool_use", "id": "t1", "name": "Bash",
                   "input": {"command": "git status --short"}}]}}
    project = os.path.join(root, "proj-a")
    os.makedirs(project, exist_ok=True)
    path = os.path.join(project, session + ".jsonl")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")
    return ts


def _run(root, state_dir, live_processes):
    env = dict(os.environ)
    env["STALL_DETECTOR_STATE_DIR"] = state_dir
    env["STALL_DETECTOR_LIVE_PROCESSES"] = live_processes
    env.pop("MCP_PROXY_BEARER", None)
    return subprocess.run([sys.executable, _SCRIPT, "--root", root, "--json"],
                          capture_output=True, text=True, timeout=120, env=env)


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

    # --- #4243 detector facet: dead session vs live process -------------------
    #
    # The two cases below are the same transcript and differ only by the process
    # table, which is the whole point: a stalled tail is textually identical
    # whether its session is frozen or gone. The table is injected through
    # STALL_DETECTOR_LIVE_PROCESSES so the verdicts are deterministic on any
    # machine (CI has no Claude process at all).

    def test_cli_dead_session_is_reported_once_then_silent(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            stalled = _stalled_session(root)
            # Every process on the host was born AFTER the wait began.
            table = "12@" + f"{stalled.timestamp() + 3600:.0f}"

            first = _run(root, state, table)
            self.assertEqual(first.returncode, 0,
                             f"a dead wait must not trip findings:\n{first.stdout}\n{first.stderr}")
            payload = json.loads(first.stdout)
            self.assertEqual(payload["totals"]["waiting"], 0)
            self.assertEqual(payload["totals"]["abandoned_process"], 1)
            self.assertEqual(payload["totals"]["already_classified"], 0)
            self.assertEqual([s["state"] for s in payload["stalls"]], ["abandoned-process"])
            with open(os.path.join(state, "classified.json"), encoding="utf-8") as fh:
                self.assertEqual(len(json.load(fh)["entries"]), 1)

            second = _run(root, state, table)
            self.assertEqual(second.returncode, 0, second.stdout)
            again = json.loads(second.stdout)
            self.assertEqual(again["totals"]["stalls"], 0, "a dead session must not re-signal")
            self.assertEqual(again["totals"]["already_classified"], 1)
            self.assertEqual(again["stalls"], [])

    def test_cli_live_process_keeps_signalling(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            stalled = _stalled_session(root)
            # A process that existed when the wait began: it could still answer.
            table = "11@" + f"{stalled.timestamp() - 7200:.0f}"

            for attempt in ("first", "second"):
                proc = _run(root, state, table)
                self.assertEqual(proc.returncode, 2,
                                 f"{attempt} run must report a waiting stall:\n"
                                 f"{proc.stdout}\n{proc.stderr}")
                payload = json.loads(proc.stdout)
                self.assertEqual(payload["totals"]["waiting"], 1, payload)
                self.assertEqual(payload["totals"]["abandoned_process"], 0, payload)
                self.assertFalse(os.path.exists(os.path.join(state, "classified.json")),
                                 "a live wait must never be classified as gone")


if __name__ == "__main__":
    unittest.main()
