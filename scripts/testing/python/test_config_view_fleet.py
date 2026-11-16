#!/usr/bin/env python3
"""Tests for config-view-fleet.py (#3833, step 4 / #603 cases 17-18).

unittest style so the static CI job (``python3 -m unittest discover -s
scripts/testing/python``) picks it up.

Everything runs against a temporary state directory with fabricated machine
snapshots and a frozen clock (``--now``): no shared store is consulted and
nothing is written anywhere but the temp dir.

The #3833 acceptance criterion — « une alerte part quand une machine de test
dérive » — is covered at unit level by FleetConfigViewTest.test_divergent_machine_flagged:
a fixture machine holding a divergent value is flagged in the table AND drives
exit 1 (the alert signal consumed by the periodic check, case 19).

Split fleets (no strict majority — review B1 on PR #4764) are covered by
test_split_fleet_no_majority_reported_exit_1, test_two_fresh_disagree_split_reported
(the 2-seat pilot reproduction) and test_four_fresh_two_two_split: the split is
reported SANS MAJORITE, drives exit 1, and surfaces as summary.splitKeys in
--json — never certified healthy.
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
    "..", "..", "diagnostic", "config-view-fleet.py",
)
_SPEC = importlib.util.spec_from_file_location("config_view_fleet", _SCRIPT)
config_view_fleet = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(config_view_fleet)

NOW_ISO = "2026-11-15T21:00:00+00:00"
FRESH_ISO = "2026-11-15T20:59:00+00:00"


def _snapshot(generated_at, env=None, permissions=None, machine="some-machine",
              model="sonnet", output_style="Proactive", flags=None):
    """Build a snapshot payload shaped like config-view.py --write."""
    return {
        "machine": machine,
        "generatedAt": generated_at,
        "schemaVersion": "1.0.0",
        "config": {
            "mcpServers": ["roo-state-manager", "sk-agent"],
            "env": env if env is not None else {
                "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5[1m]",
                "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "230000",
                "ENABLE_TOOL_SEARCH": "true",
                "ANTHROPIC_BASE_URL": "http://127.0.0.1:3000",
            },
            "permissions": permissions if permissions is not None else {
                "mode": "auto-approve",
                "deny": ["AskUserQuestion", "NotebookEdit"],
            },
            "model": model,
            "outputStyle": output_style,
            "flags": flags if flags is not None else {"disableBundledSkills": True},
        },
    }


class FleetConfigViewTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = self._tmp.name
        self.state_dir = os.path.join(self.root, "config-view")
        os.makedirs(self.state_dir)
        self.manifest = os.path.join(self.root, "fleet-manifest.json")
        self._write_manifest(["myia-web1", "myia-web2", "myia-po-2028"])

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
            code = config_view_fleet.main([
                "--shared-path", self.root,
                "--manifest", self.manifest,
                "--now", NOW_ISO,
                *extra,
            ])
        return code, out.getvalue(), err.getvalue()

    def _three_fresh(self):
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state("myia-web2", _snapshot(FRESH_ISO))
        self._write_state("myia-po-2028", _snapshot(FRESH_ISO))

    # -- freshness / states ------------------------------------------------

    def test_all_fresh_no_drift_exit_0(self):
        self._three_fresh()
        code, out, err = self._run()
        self.assertEqual(code, 0)
        self.assertIn("3 frais", out)
        self.assertIn("0 machine(s) en derive", out)

    def test_absent_machine_flagged_exit_1(self):
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state("myia-web2", _snapshot(FRESH_ISO))
        # myia-po-2028: no file
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("absent", out)

    def test_stale_machine_en_retard_does_not_vote(self):
        stale = "2026-11-15T10:00:00+00:00"  # way beyond the 120-min threshold
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state("myia-web2", _snapshot(FRESH_ISO))
        diverging_stale = _snapshot(
            stale, env={"ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-1",
                        "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "99999",
                        "ENABLE_TOOL_SEARCH": "true"}
        )
        self._write_state("myia-po-2028", diverging_stale)
        code, out, err = self._run()
        self.assertEqual(code, 1)  # en-retard alone drives exit 1
        self.assertIn("en-retard", out)
        # the stale divergent values must NOT create drift flags on fresh rows
        self.assertNotIn("env:ANTHROPIC_DEFAULT_OPUS_MODEL", out)

    def test_illisible_snapshot(self):
        self._three_fresh()
        self._write_state("myia-po-2028", "{not json")
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("illisible", out)

    # -- drift consensus (case 18) ------------------------------------------

    def test_divergent_machine_flagged(self):
        """Acceptance criterion: a diverging machine is flagged + exit 1."""
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state("myia-web2", _snapshot(FRESH_ISO))
        self._write_state(
            "myia-po-2028",
            _snapshot(FRESH_ISO, env={
                "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4-1",  # diverges
                "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "99999",         # diverges
                "ENABLE_TOOL_SEARCH": "true",
                "ANTHROPIC_BASE_URL": "http://192.168.0.99:3000",   # observe-only
            }),
        )
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("env:ANTHROPIC_DEFAULT_OPUS_MODEL", out)
        self.assertIn("env:CLAUDE_CODE_AUTO_COMPACT_WINDOW", out)
        self.assertIn("1 machine(s) en derive", out)
        # observe-only key: reported in the snapshot but never drift-judged
        self.assertNotIn("env:ANTHROPIC_BASE_URL", out)

    def test_absent_key_is_drift(self):
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state(
            "myia-web2",
            _snapshot(FRESH_ISO, env={
                "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5[1m]",
                "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "230000",
                # ENABLE_TOOL_SEARCH absent: drift by absence
            }),
        )
        self._write_state("myia-po-2028", _snapshot(FRESH_ISO))
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("env:ENABLE_TOOL_SEARCH", out)

    def test_deny_list_drift(self):
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        self._write_state(
            "myia-web2",
            _snapshot(FRESH_ISO, permissions={
                "mode": "auto-approve",
                "deny": ["AskUserQuestion"],  # missing NotebookEdit
            }),
        )
        self._write_state("myia-po-2028", _snapshot(FRESH_ISO))
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("permissions:deny", out)

    def test_single_witness_no_quorum(self):
        self._write_state("myia-web1", _snapshot(FRESH_ISO))
        # web2 + po-2028 absent
        code, out, err = self._run()
        self.assertEqual(code, 1)  # absent machines still drive exit 1
        self.assertIn("PAS de verdict", out)

    def test_split_fleet_no_majority_reported_exit_1(self):
        """3 machines, 3 different model values: no majority -> the split is
        REPORTED (B1, PR #4764 review) and drives exit 1, not silence."""
        self._write_state("myia-web1", _snapshot(FRESH_ISO, model="sonnet"))
        self._write_state("myia-web2", _snapshot(FRESH_ISO, model="opus"))
        self._write_state("myia-po-2028", _snapshot(FRESH_ISO, model="haiku"))
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("SANS majorite", out)
        self.assertIn("model", out)  # the split key is named
        # no machine is blamed: the disagreement has no majority to contradict
        self.assertIn("0 machine(s) en derive sur les autres cles", out)
        self.assertNotIn("1 machine(s) en derive", out)

    def test_two_fresh_disagree_split_reported(self):
        """B1 reproduction (2-seat pilot): 2 fresh seats disagreeing must NOT
        be certified healthy."""
        self._write_manifest(["myia-web1", "myia-web2"])
        self._write_state("myia-web1", _snapshot(FRESH_ISO, model="sonnet"))
        self._write_state("myia-web2", _snapshot(FRESH_ISO, model="opus"))
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("SANS majorite", out)
        self.assertIn("model", out)
        # the pre-fix bug: consensus line claimed "0 machine(s) en derive" exit 0
        self.assertNotIn("0 machine(s) en derive,", out)
        # --json: the case-19 consumer field
        code, out_json, err = self._run("--json")
        self.assertEqual(code, 1)
        payload = json.loads(out_json)
        self.assertEqual(payload["summary"]["splitKeys"], ["model"])
        self.assertEqual(payload["summary"]["driftingMachines"], 0)
        self.assertEqual(len(payload["splits"]["model"]), 2)

    def test_four_fresh_two_two_split(self):
        """4 fresh seats split 2-2 on one key: reported, no machine blamed."""
        self._write_manifest(["myia-web1", "myia-web2", "myia-po-2023", "myia-po-2028"])
        half = _snapshot(FRESH_ISO, env={
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5[1m]",
            "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "230000",
            "ENABLE_TOOL_SEARCH": "true",
            "ANTHROPIC_BASE_URL": "http://127.0.0.1:3000",
        })
        other = _snapshot(FRESH_ISO, env={
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-5-5[1m]",
            "CLAUDE_CODE_AUTO_COMPACT_WINDOW": "99999",
            "ENABLE_TOOL_SEARCH": "true",
            "ANTHROPIC_BASE_URL": "http://127.0.0.1:3000",
        })
        self._write_state("myia-web1", half)
        self._write_state("myia-web2", half)
        self._write_state("myia-po-2023", other)
        self._write_state("myia-po-2028", other)
        code, out, err = self._run()
        self.assertEqual(code, 1)
        self.assertIn("SANS majorite", out)
        self.assertIn("env:CLAUDE_CODE_AUTO_COMPACT_WINDOW", out)
        self.assertIn("0 machine(s) en derive sur les autres cles", out)

    # -- instrument (exit 2) --------------------------------------------------

    def test_missing_state_dir_exit_2(self):
        os.rmdir(self.state_dir)
        code, out, err = self._run()
        self.assertEqual(code, 2)

    def test_json_output(self):
        self._three_fresh()
        code, out, err = self._run("--json")
        self.assertEqual(code, 0)
        payload = json.loads(out)
        self.assertEqual(payload["view"], "config-view-fleet")
        self.assertEqual(payload["summary"]["frais"], 3)
        self.assertEqual(payload["summary"]["driftQuorum"], True)
        self.assertEqual(payload["summary"]["driftingMachines"], 0)
        self.assertEqual(payload["summary"]["splitKeys"], [])
        self.assertEqual(payload["splits"], {})
        self.assertEqual(payload["machines"][0]["driftKeys"], [])


if __name__ == "__main__":
    unittest.main()
