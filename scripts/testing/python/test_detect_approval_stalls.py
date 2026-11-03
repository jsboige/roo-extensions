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


def _stalled_session(root, session="dead001", age_hours=3.0, cwd=None):
    """One session whose transcript ends on an unanswered shell tool_use."""
    ts = datetime.now(timezone.utc) - timedelta(hours=age_hours)
    record = {"type": "assistant", "uuid": "a1", "timestamp": _iso(ts),
              "message": {"role": "assistant", "content": [
                  {"type": "tool_use", "id": "t1", "name": "Bash",
                   "input": {"command": "git status --short"}}]}}
    if cwd:
        record["cwd"] = cwd
    project = os.path.join(root, "proj-a")
    os.makedirs(project, exist_ok=True)
    path = os.path.join(project, session + ".jsonl")
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(json.dumps(record) + "\n")
    return ts


def _load_module():
    """Import the detector by path -- same contract the wrapper pins for
    scan-approval-waits helpers; safe here: everything lives under functions
    and the CLI is guarded by __main__."""
    import importlib.util
    spec = importlib.util.spec_from_file_location("detect_approval_stalls", _SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


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

    def test_cli_malformed_seam_degrades_to_unknown(self):
        # #4397 review (non-blocking): a malformed STALL_DETECTOR_LIVE_PROCESSES
        # used to crash every tick with exit 1. It must degrade the table to
        # unknown instead: the wait keeps signalling (exit 2), never silent.
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            _stalled_session(root)
            proc = _run(root, state, "12@notanumber")
            self.assertEqual(proc.returncode, 2,
                             f"a malformed seam must degrade, not crash:\n"
                             f"{proc.stdout}\n{proc.stderr}")
            payload = json.loads(proc.stdout)
            self.assertEqual(payload["totals"]["waiting"], 1, payload)
            self.assertEqual(payload["totals"]["abandoned_process"], 0, payload)
            self.assertIn("STALL_DETECTOR_LIVE_PROCESSES", proc.stderr)


class StallNoteIdAndRouting(unittest.TestCase):
    """#4243 volet 3 fix: daily id bucket + routing to the stalled session's
    workspace. Measured regression this pins: the 15-min bucket re-posted the
    same note on every tick (po-2024: CoursIA stalls re-noted hourly to the
    roo-extensions dashboard all day)."""

    def setUp(self):
        self.mod = _load_module()

    def test_note_id_stable_within_a_day(self):
        stalls = [{"session": "s1", "since": "2026-11-02T10:00:00.000Z"}]
        t0 = 1_800_000_000  # fixed epoch: 2027-01-15, well inside no DST on UTC
        self.assertEqual(self.mod.build_note_id(stalls, now=t0),
                         self.mod.build_note_id(stalls, now=t0 + 3600),
                         "same set, same day: one id (server-side dedup per tick)")

    def test_note_id_rolls_over_next_day(self):
        stalls = [{"session": "s1", "since": "2026-11-02T10:00:00.000Z"}]
        t0 = 1_800_000_000
        self.assertNotEqual(self.mod.build_note_id(stalls, now=t0),
                            self.mod.build_note_id(stalls, now=t0 + 90_000),
                            "next day: a new id -- the at-most-24h reminder")

    def test_note_id_tracks_the_stall_set(self):
        t0 = 1_800_000_000
        one = [{"session": "s1", "since": "2026-11-02T10:00:00.000Z"}]
        two = one + [{"session": "s2", "since": "2026-11-02T11:00:00.000Z"}]
        self.assertNotEqual(self.mod.build_note_id(one, now=t0),
                            self.mod.build_note_id(two, now=t0),
                            "a new stall must earn a fresh note immediately")

    def test_note_routes_to_each_session_workspace(self):
        mod = self.mod
        calls = []
        stalls = [
            {"state": "waiting-suspected", "session": "a", "workspace": "CoursIA"},
            {"state": "waiting-suspected", "session": "b", "workspace": None},
            {"state": "waiting-suspected", "session": "c", "workspace": "roo-extensions"},
        ]
        real_publish = mod.publish_dashboard_note

        def fake_publish(group, target, *_a, **_k):
            calls.append((target, sorted(s["session"] for s in group)))
            return True
        mod.publish_dashboard_note = fake_publish
        try:
            self.assertTrue(mod.maybe_publish_dashboard_note(
                {"waiting": 3}, stalls, "roo-extensions", "http://x", "tok"))
        finally:
            mod.publish_dashboard_note = real_publish
        # No-cwd stall falls back to the detector's workspace; one append per
        # target dashboard, in a deterministic (sorted) order.
        self.assertEqual(calls, [("CoursIA", ["a"]),
                                 ("roo-extensions", ["b", "c"])])

    def test_note_routing_failure_of_all_targets_is_false(self):
        mod = self.mod
        stalls = [{"state": "waiting-suspected", "session": "a", "workspace": "CoursIA"}]
        real_publish = mod.publish_dashboard_note
        mod.publish_dashboard_note = lambda *_a, **_k: False
        try:
            self.assertFalse(mod.maybe_publish_dashboard_note(
                {"waiting": 1}, stalls, "roo-extensions", "http://x", "tok"))
        finally:
            mod.publish_dashboard_note = real_publish

    def test_cli_reports_stall_workspace_from_transcript_cwd(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            ts = _stalled_session(root, session="wscase",
                                  cwd="D:\\Dev\\CoursIA")
            table = "11@" + f"{ts.timestamp() - 7200:.0f}"
            proc = _run(root, state, table)
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            payload = json.loads(proc.stdout)
            self.assertEqual(payload["totals"]["waiting"], 1)
            stall = payload["stalls"][0]
            self.assertEqual(stall["workspace"], "CoursIA",
                             "the stall must carry its session's workspace, "
                             "parsed from the transcript cwd")

    def test_workspace_from_cwd_uses_the_main_checkout_for_worktrees(self):
        # #4243 volet 3: PR work happens in worktrees (that is the doctrine),
        # so the common cwd carries a .claude/worktrees/<name> tail. Verbatim
        # last-segment would route the note to a dashboard nobody reads.
        mod = self.mod
        self.assertEqual(
            mod._workspace_from_cwd(r"D:\dev\roo-extensions\.claude\worktrees\wt-4243-note"),
            "roo-extensions")
        self.assertEqual(
            mod._workspace_from_cwd("/home/jesse/ws/.claude/worktrees/fix-x"),
            "ws")
        self.assertEqual(
            mod._workspace_from_cwd(r"D:\dev\roo-extensions\.claude\worktrees\wt-x\scripts"),
            "roo-extensions")
        # Non-worktree paths keep their final segment, both separators.
        self.assertEqual(mod._workspace_from_cwd(r"D:\Dev\CoursIA"), "CoursIA")
        self.assertEqual(mod._workspace_from_cwd("/opt/data/workspace/CoursIA"), "CoursIA")
        self.assertEqual(mod._workspace_from_cwd("D:\\"), "D:")
        self.assertIsNone(mod._workspace_from_cwd(None))
        self.assertIsNone(mod._workspace_from_cwd(""))

    def test_cli_reports_stall_workspace_from_posix_cwd(self):
        # #4243 review: the workspace split must be host-independent. A POSIX
        # cwd must yield its final segment wherever the detector runs, so the
        # Windows-path case above (red under os.path.basename on the ubuntu
        # CI) never stands alone as the only guard.
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            ts = _stalled_session(root, session="posixcase",
                                  cwd="/opt/data/workspace/CoursIA")
            table = "11@" + f"{ts.timestamp() - 7200:.0f}"
            proc = _run(root, state, table)
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            stall = json.loads(proc.stdout)["stalls"][0]
            self.assertEqual(stall["workspace"], "CoursIA")

    def test_cli_stall_without_cwd_keeps_null_workspace(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = os.path.join(tmp, "projects")
            state = os.path.join(tmp, "state")
            ts = _stalled_session(root, session="nocwd")
            table = "11@" + f"{ts.timestamp() - 7200:.0f}"
            proc = _run(root, state, table)
            self.assertEqual(proc.returncode, 2, proc.stdout + proc.stderr)
            stall = json.loads(proc.stdout)["stalls"][0]
            self.assertIsNone(stall["workspace"])


if __name__ == "__main__":
    unittest.main()
