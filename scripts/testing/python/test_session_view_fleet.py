#!/usr/bin/env python3
"""Tests for session-view-fleet.py (#3833, step 3).

unittest style so the static CI job (``python3 -m unittest discover -s
scripts/testing/python``) picks it up; the issue criterion runs the same
classes under ``python -m pytest scripts/testing/python/test_session_view_fleet.py``.

Everything runs against a temporary state directory with fabricated machine
files and a frozen clock (``--now``): no shared store is consulted and
nothing is written anywhere but the temp dir.
"""

import importlib.util
import io
import json
import os
import tempfile
import unittest
from contextlib import redirect_stdout, redirect_stderr

_SCRIPT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "..", "diagnostic", "session-view-fleet.py",
)
_SPEC = importlib.util.spec_from_file_location("session_view_fleet", _SCRIPT)
session_view_fleet = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(session_view_fleet)

NOW_ISO = "2026-11-14T21:00:00+00:00"


def _state_payload(generated_at, counts=None, workspaces=("roo-extensions",)):
    """Build a machine state file payload shaped like session-view.py --write."""
    counts = counts or {
        "actif": 1, "repos-recent": 2, "repos-ancien": 3, "mort": 0,
    }
    return {
        "machine": "some-machine",
        "generatedAt": generated_at,
        "restSeconds": 3600,
        "counts": counts,
        "sessions": [
            {
                "file": f"{index}.json", "pid": 1000 + index,
                "workspace": workspace, "status": "repos-recent",
                "ageMs": 1000, "kind": "interactive", "entrypoint": "claude-vscode",
            }
            for index, workspace in enumerate(workspaces)
        ],
    }


class FleetViewTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.state_dir = os.path.join(self.root, "session-view")
        os.makedirs(self.state_dir)
        self.manifest = os.path.join(self.root, "fleet-manifest.json")
        self._write_manifest(["myia-web2", "myia-ai-01"])

    def tearDown(self):
        self._tmp.cleanup()

    # -- helpers ----------------------------------------------------------

    def _write_manifest(self, names):
        with open(self.manifest, "w", encoding="utf-8") as handle:
            json.dump({"machines": {name: {} for name in names}}, handle)

    def _write_state(self, machine, payload):
        with open(os.path.join(self.state_dir, f"{machine}.json"), "w",
                  encoding="utf-8") as handle:
            if isinstance(payload, str):
                handle.write(payload)
            else:
                json.dump(payload, handle)

    def _run(self, *extra):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = session_view_fleet.main([
                "--shared-path", self.root,
                "--manifest", self.manifest,
                "--now", NOW_ISO,
                *extra,
            ])
        return code, out.getvalue(), err.getvalue()

    # -- tests ------------------------------------------------------------

    def test_all_fresh_exit_0(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:58:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 0)
        fresh_rows = [line for line in out.splitlines()
                      if line.startswith("myia-") and "frais" in line]
        self.assertEqual(len(fresh_rows), 2)
        self.assertIn("2 machines: 2 frais, 0 en retard", out)

    def test_late_machine_marked_exit_1(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:00:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 1)
        self.assertIn("en-retard", out)
        ai_line = [line for line in out.splitlines() if line.startswith("myia-ai-01")][0]
        self.assertIn("en-retard", ai_line)

    def test_absent_machine_exit_1(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 1)
        ai_line = [line for line in out.splitlines() if line.startswith("myia-ai-01")][0]
        self.assertIn("absent", ai_line)

    def test_unreadable_file_exit_1(self):
        self._write_state("myia-web2", "{not json")
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 1)
        self.assertIn("illisible", out)

    def test_missing_generated_at_is_unreadable(self):
        payload = _state_payload("2026-11-14T20:59:00+00:00")
        del payload["generatedAt"]
        self._write_state("myia-web2", payload)
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 1)
        self.assertIn("illisible", out)

    def test_boundary_exactly_threshold_is_fresh(self):
        # 15 min threshold: age exactly 15 min stays fresh, 15 min + 1 s is late.
        self._write_state("myia-web2", _state_payload("2026-11-14T20:45:00+00:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        code, _, _ = self._run("--max-age-minutes", "15")
        self.assertEqual(code, 0)
        self._write_state("myia-web2", _state_payload("2026-11-14T20:44:59+00:00"))
        code, _, _ = self._run("--max-age-minutes", "15")
        self.assertEqual(code, 1)

    def test_naive_generated_at_treated_as_utc(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00"))
        code, _, _ = self._run()
        self.assertEqual(code, 0)

    def test_missing_state_dir_exit_2(self):
        code, _, err = self._run("--subdir", "does-not-exist")
        self.assertEqual(code, 2)
        self.assertIn("state directory not found", err)

    def test_no_shared_path_exit_2(self):
        # The seat exports ROOSYNC_SHARED_PATH at User level, which would
        # supply the default and hide this branch: pop it for this test.
        saved = os.environ.pop("ROOSYNC_SHARED_PATH", None)
        try:
            out, err = io.StringIO(), io.StringIO()
            with redirect_stdout(out), redirect_stderr(err):
                code = session_view_fleet.main(["--manifest", self.manifest])
        finally:
            if saved is not None:
                os.environ["ROOSYNC_SHARED_PATH"] = saved
        self.assertEqual(code, 2)
        self.assertIn("ROOSYNC_SHARED_PATH", err.getvalue())

    def test_missing_manifest_no_roster_exit_2(self):
        with self.assertRaises(SystemExit) as raised:
            session_view_fleet.main([
                "--shared-path", self.root,
                "--manifest", os.path.join(self.root, "nope.json"),
                "--now", NOW_ISO,
            ])
        self.assertEqual(raised.exception.code, 2)

    def test_machines_flag_overrides_manifest(self):
        self._write_state("myia-po-2024", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run("--machines", "myia-po-2024")
        self.assertEqual(code, 0)
        self.assertIn("1 machines: 1 frais", out)

    def test_manifest_order_preserved(self):
        self._write_manifest(["myia-ai-01", "myia-web2"])
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        _, out, _ = self._run()
        machine_lines = [line.split()[0] for line in out.splitlines()
                         if line.startswith("myia-")]
        self.assertEqual(machine_lines, ["myia-ai-01", "myia-web2"])

    def test_counts_and_workspaces_rendered(self):
        self._write_state("myia-web2", _state_payload(
            "2026-11-14T20:59:00+00:00",
            counts={"actif": 1, "repos-recent": 2, "repos-ancien": 3, "mort": 4},
            workspaces=("roo-extensions", "CoursIA", "vllm", "IISManagement"),
        ))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        _, out, _ = self._run()
        web2_line = [line for line in out.splitlines() if line.startswith("myia-web2")][0]
        self.assertIn("1/2/3/4", web2_line)
        self.assertIn("CoursIA", web2_line)
        self.assertIn("+1", web2_line)  # 4 workspaces, 3 shown

    def test_bad_counts_value_marks_only_that_machine(self):
        # "actif": "n/a" once raised ValueError above the per-machine loop
        # and killed the whole table (#3833 follow-up): the machine's row
        # must go illisible, the other rows must still print.
        self._write_state("myia-web2", _state_payload(
            "2026-11-14T20:59:00+00:00",
            counts={"actif": "n/a", "repos-recent": 2, "repos-ancien": 3, "mort": 0},
        ))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run()
        self.assertEqual(code, 1)
        web2_line = [line for line in out.splitlines() if line.startswith("myia-web2")][0]
        ai_line = [line for line in out.splitlines() if line.startswith("myia-ai-01")][0]
        self.assertIn("illisible", web2_line)
        self.assertIn("frais", ai_line)  # the other machine still prints
        self.assertIn("1 frais, 1 en retard/absent/illisible", out)
        # The error itself rides the machine-readable output.
        _, json_out, _ = self._run("--json")
        web2 = [m for m in json.loads(json_out)["machines"]
                if m["machine"] == "myia-web2"][0]
        self.assertEqual(web2["state"], "illisible")
        self.assertIn("n/a", web2["error"])

    def test_json_output_shape(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        code, out, _ = self._run("--json")
        self.assertEqual(code, 1)  # ai-01 absent
        payload = json.loads(out)
        self.assertEqual(payload["view"], "session-view-fleet")
        self.assertEqual(payload["summary"]["machines"], 2)
        self.assertEqual(payload["summary"]["frais"], 1)
        self.assertEqual(payload["summary"]["absent"], 1)
        self.assertEqual([m["machine"] for m in payload["machines"]],
                         ["myia-web2", "myia-ai-01"])
        self.assertNotIn("path", payload["machines"][0])

    def test_file_not_in_roster_is_ignored(self):
        self._write_state("myia-web2", _state_payload("2026-11-14T20:59:00+00:00"))
        self._write_state("myia-ai-01", _state_payload("2026-11-14T20:59:00+00:00"))
        self._write_state("ghost-machine", _state_payload("2026-11-14T20:59:00+00:00"))
        _, out, _ = self._run()
        self.assertNotIn("ghost-machine", out)


if __name__ == "__main__":
    unittest.main()