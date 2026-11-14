#!/usr/bin/env python3
"""Tests for session-view.py (#4694, parent #3833).

unittest style so the static CI job (``python3 -m unittest discover -s
scripts/testing/python``) picks it up; the issue criterion runs the same
classes under ``python -m pytest scripts/testing/python/test_session_view.py``.

Classification is exercised directly (classify()) with a fixed ``now_ms``,
and the CLI surface (dry-run / write / overwrite) end-to-end against a fake
sessions directory with a simulated process probe — no real process is
consulted and nothing real is written.
"""

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

import importlib.util

_SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "..", "diagnostic", "session-view.py"
)
_SPEC = importlib.util.spec_from_file_location("session_view", _SCRIPT)
session_view = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(session_view)

NOW_MS = 1_800_000_000_000  # fixed clock for classify()-level tests
REST_MS = 3600 * 1000
TICKS = 134389778078512215  # plausible win32 FILETIME ticks


def _record(**overrides):
    base = {
        "pid": 400001,
        "procStart": str(TICKS),
        "cwd": "d:\\Dev\\CoursIA-2",
        "kind": "interactive",
        "entrypoint": "claude-vscode",
        "status": "idle",
        "startedAt": NOW_MS - 10 * 3600 * 1000,
        "updatedAt": NOW_MS - 30 * 60 * 1000,
        "statusUpdatedAt": NOW_MS - 30 * 60 * 1000,
        "pidDomain": "win32:myia-po-2024",
    }
    base.update(overrides)
    return base


class ClassifyTest(unittest.TestCase):
    """The four statuses plus pid-reuse, exact-start and tolerance paths."""

    def test_actif_busy_alive(self):
        status, _ = session_view.classify(
            _record(status="busy"), TICKS, NOW_MS, REST_MS
        )
        self.assertEqual(status, "actif")

    def test_repos_recent(self):
        status, age = session_view.classify(
            _record(statusUpdatedAt=NOW_MS - 5 * 60 * 1000), TICKS, NOW_MS, REST_MS
        )
        self.assertEqual(status, "repos-recent")
        self.assertEqual(age, 5 * 60 * 1000)

    def test_repos_ancien(self):
        status, age = session_view.classify(
            _record(statusUpdatedAt=NOW_MS - 3 * 3600 * 1000), TICKS, NOW_MS, REST_MS
        )
        self.assertEqual(status, "repos-ancien")
        self.assertEqual(age, 3 * 3600 * 1000)

    def test_mort_pid_gone(self):
        status, _ = session_view.classify(_record(), None, NOW_MS, REST_MS)
        self.assertEqual(status, "mort")

    def test_mort_pid_reused_with_other_procstart(self):
        # pid 400001 now belongs to a process created at a different time
        status, _ = session_view.classify(_record(), TICKS + 5_000_000, NOW_MS, REST_MS)
        self.assertEqual(status, "mort")

    def test_exact_procstart_match_is_alive(self):
        status, _ = session_view.classify(_record(status="busy"), TICKS, NOW_MS, REST_MS)
        self.assertEqual(status, "actif")

    def test_tolerance_absorbs_small_mismatch(self):
        original = session_view.classify.tolerance_ticks
        session_view.classify.tolerance_ticks = int(2.0 * 1e7)  # --start-tolerance-seconds 2
        try:
            status, _ = session_view.classify(
                _record(status="busy"), TICKS + int(1.0 * 1e7), NOW_MS, REST_MS
            )
            self.assertEqual(status, "actif")
        finally:
            session_view.classify.tolerance_ticks = original

    def test_unverified_start_treated_as_alive(self):
        status, _ = session_view.classify(
            _record(status="busy"), "unverified", NOW_MS, REST_MS
        )
        self.assertEqual(status, "actif")

    def test_missing_procstart_is_alive(self):
        status, _ = session_view.classify(
            _record(status="busy", procStart=None), TICKS, NOW_MS, REST_MS
        )
        self.assertEqual(status, "actif")

    def test_machine_and_workspace_extraction(self):
        self.assertEqual(session_view._machine_of(_record()), "myia-po-2024")
        self.assertEqual(session_view._workspace_of(_record()), "CoursIA-2")
        self.assertEqual(session_view._workspace_of(_record(cwd="/home/x/proj/")), "proj")


class _FakeProbe:
    """Simulated process liveness: answers a fixed pid table."""

    def __init__(self, table):
        self.table = table  # pid -> start ticks | None (gone)

    def __call__(self, pid):
        return self.table.get(pid, None)


class EndToEndTest(unittest.TestCase):
    """CLI surface on a fake registry: dry-run writes nothing, --write
    overwrites the same file."""

    def setUp(self):
        self._old_probe = session_view.probe_process
        tmp = tempfile.mkdtemp(prefix="session-view-test-")
        self.sessions_dir = os.path.join(tmp, "sessions")
        self.shared_path = os.path.join(tmp, "shared")
        os.makedirs(self.sessions_dir)
        self.addCleanup(self._cleanup, tmp)

        self.now_ms = int(sys_time_ms())
        fresh_idle = self.now_ms - 5 * 60 * 1000
        stale_idle = self.now_ms - 3 * 3600 * 1000
        self.records = {
            "400001.json": _record(pid=400001, status="busy"),
            "400002.json": _record(pid=400002, statusUpdatedAt=fresh_idle, updatedAt=fresh_idle),
            "400003.json": _record(pid=400003, statusUpdatedAt=stale_idle, updatedAt=stale_idle),
            "400004.json": _record(pid=400004),  # probe will say: pid gone
        }
        for name, record in self.records.items():
            payload = {k: v for k, v in record.items() if not k.startswith("__")}
            with open(os.path.join(self.sessions_dir, name), "w", encoding="utf-8") as fh:
                json.dump(payload, fh)
        # decoys that must NOT be read
        with open(os.path.join(self.sessions_dir, "readme.txt"), "w", encoding="utf-8") as fh:
            fh.write("not a session")
        nested = os.path.join(self.sessions_dir, "nested")
        os.makedirs(nested)
        with open(os.path.join(nested, "500009.json"), "w", encoding="utf-8") as fh:
            json.dump(_record(pid=500009), fh)

        self.probe = _FakeProbe({
            400001: TICKS,
            400002: TICKS,
            400003: TICKS,
            400004: None,  # gone -> mort
        })
        session_view.probe_process = self.probe

    def _cleanup(self, tmp):
        session_view.probe_process = self._old_probe
        for root, _dirs, files in os.walk(tmp, topdown=False):
            for name in files:
                os.unlink(os.path.join(root, name))
            os.rmdir(root)

    def _run(self, *extra):
        argv = ["--sessions-dir", self.sessions_dir, *extra]
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = session_view.main(argv)
        return code, out.getvalue(), err.getvalue()

    def test_dry_run_one_line_per_json_and_no_write(self):
        code, out, _ = self._run("--dry-run")
        self.assertEqual(code, 0)
        lines = [ln for ln in out.splitlines() if ln.strip()]
        self.assertEqual(len(lines), 4)  # 4 *.json files in the registry dir itself
        statuses = {ln.split()[2] for ln in lines}
        self.assertEqual(statuses, {"actif", "repos-recent", "repos-ancien", "mort"})
        self.assertFalse(os.path.exists(self.shared_path))

    def test_default_mode_is_dry_run(self):
        code, out, _ = self._run()
        self.assertEqual(code, 0)
        self.assertEqual(len([ln for ln in out.splitlines() if ln.strip()]), 4)
        self.assertFalse(os.path.exists(self.shared_path))

    def test_write_creates_and_overwrites_same_file(self):
        subdir = os.path.join(self.shared_path, "session-view")
        code, _, err = self._run("--write", "--shared-path", self.shared_path)
        self.assertEqual(code, 0)
        target = os.path.join(subdir, "myia-po-2024.json")
        self.assertTrue(os.path.exists(target), err)
        self.assertEqual(os.listdir(subdir), ["myia-po-2024.json"])
        with open(target, encoding="utf-8") as fh:
            first = json.load(fh)
        self.assertEqual(first["counts"]["actif"], 1)
        self.assertEqual(first["counts"]["mort"], 1)

        # mutate one session (busy -> idle, stale) and write again
        path_400001 = os.path.join(self.sessions_dir, "400001.json")
        with open(path_400001, encoding="utf-8") as fh:
            payload = json.load(fh)
        payload["status"] = "idle"
        payload["statusUpdatedAt"] = self.now_ms - 5 * 3600 * 1000
        with open(path_400001, "w", encoding="utf-8") as fh:
            json.dump(payload, fh)

        code, _, _ = self._run("--write", "--shared-path", self.shared_path)
        self.assertEqual(code, 0)
        self.assertEqual(os.listdir(subdir), ["myia-po-2024.json"])  # same path, overwritten
        with open(target, encoding="utf-8") as fh:
            second = json.load(fh)
        self.assertEqual(second["counts"].get("actif"), 0)
        self.assertEqual(second["counts"].get("repos-ancien"), 2)
        self.assertNotEqual(first["sessions"], second["sessions"])

    def test_write_without_shared_path_fails(self):
        code, _, err = self._run("--write", "--shared-path", "")
        self.assertEqual(code, 1)
        self.assertIn("shared-path", err)

    def test_dry_run_and_write_are_exclusive(self):
        with self.assertRaises(SystemExit) as ctx:
            self._run("--dry-run", "--write")
        self.assertEqual(ctx.exception.code, 2)

    def test_invalid_json_yields_invalide_line(self):
        with open(os.path.join(self.sessions_dir, "999999.json"), "w", encoding="utf-8") as fh:
            fh.write("{not json")
        code, out, _ = self._run("--dry-run")
        self.assertEqual(code, 0)
        lines = [ln for ln in out.splitlines() if ln.strip()]
        self.assertEqual(len(lines), 5)
        self.assertTrue(any("invalide" in ln for ln in lines), lines)

    def test_missing_sessions_dir_exits_with_message(self):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            with self.assertRaises(SystemExit) as ctx:
                session_view.main(["--sessions-dir", os.path.join(self.sessions_dir, "absent")])
        self.assertIn("cannot read sessions directory", str(ctx.exception))


def sys_time_ms():
    import time
    return time.time() * 1000


if __name__ == "__main__":
    unittest.main()
