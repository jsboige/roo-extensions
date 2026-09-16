#!/usr/bin/env python3
"""Tests unitaires des scripts anti-tarissement (#3675, ADR 016).

Couvre les exigences des reviews PR #3681 :
  - fail-closed : panne gh (exit non-nul, timeout, JSON invalide) => verdict
    ERROR exit 2, jamais un verdict de fond (IDLE_REAL / PASS) ;
  - encodage : subprocess.run appele avec encoding="utf-8" errors="replace"
    (fix crash cp1252 Windows sur titres accentues, po-2027 16/09) ;
  - --machine supprime : argparse doit rejeter l'option ;
  - verdicts : IDLE_REAL / PICK / PASS / FAIL avec les exit codes associes ;
  - le compteur backlog ne mesure que l'urne grain (approved/bug/investigation).

Stdlib uniquement (unittest + mock) — invoque par
scripts/testing/unit/lane-antitarissement.Tests.ps1 (job CI unit-pester).
"""
import io
import json
import subprocess
import sys
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone, timedelta
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

HERE = Path(__file__).resolve()
SCHEDULING_DIR = HERE.parents[2] / "scheduling"
sys.path.insert(0, str(SCHEDULING_DIR))

import pick_idle_grain as picker  # noqa: E402
import test_cycle_end as tce  # noqa: E402

REPOS = ["jsboige/roo-extensions", "jsboige/jsboige-mcp-servers"]


def ok_result(payload):
    """Fake subprocess.CompletedProcess avec stdout JSON valide."""
    return SimpleNamespace(stdout=json.dumps(payload), stderr="", returncode=0)


def issue(number, labels, title="issue"):
    return {
        "number": number,
        "title": title,
        "labels": [{"name": l} for l in labels],
        "assignees": [],
        "createdAt": "2026-09-01T00:00:00Z",
        "updatedAt": "2026-09-15T00:00:00Z",
    }


def run_main(module, argv):
    """Invoque module.main() avec argv patched, capture stdout, retourne (code, stdout)."""
    out = io.StringIO()
    with mock.patch.object(sys, "argv", ["prog"] + argv), redirect_stdout(out):
        code = module.main()
    return code, out.getvalue()


class PickerFailClosed(unittest.TestCase):
    """Panne instrument => ERROR exit 2, jamais IDLE_REAL/PICK (bloquant 2)."""

    def _run_with(self, side_effect):
        with mock.patch("subprocess.run", side_effect=side_effect):
            return run_main(picker, ["--json"])

    def test_gh_nonzero_exit_yields_error_exit2(self):
        exc = subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 403: rate limit")
        code, out = self._run_with(exc)
        self.assertEqual(code, 2)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "ERROR")
        self.assertIn("rate limit", json.dumps(data))
        self.assertIsNone(data["pick"])

    def test_timeout_yields_error_exit2(self):
        exc = subprocess.TimeoutExpired(cmd=["gh"], timeout=60)
        code, out = self._run_with(exc)
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")

    def test_invalid_json_yields_error_exit2(self):
        code, out = self._run_with([SimpleNamespace(stdout="gh: not json", stderr="", returncode=0)] * 8)
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")

    def test_partial_repo_failure_is_error_not_idle(self):
        # R1 collecte OK, R2 en panne => aucun verdict de fond (fail-closed
        # sur panne PARTIELLE : le pool n'est pas declare vide).
        seq = [
            ok_result([issue(1, ["approved"])]),   # R1 issues
            ok_result([]),                          # R1 prs
            subprocess.CalledProcessError(128, ["gh"], stderr="network"),  # R2 issues
            subprocess.CalledProcessError(128, ["gh"], stderr="network"),  # R2 prs
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")


class PickerVerdicts(unittest.TestCase):
    """Collecte reussie : verdicts de fond uniquement."""

    def test_empty_success_yields_idle_real_exit0(self):
        with mock.patch("subprocess.run", side_effect=[ok_result([])] * 4):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")
        self.assertEqual(data["grain"], 0)

    def test_grain_pick_with_accented_title(self):
        # Titre UTF-8 accentue + fleche : doit traverser sans crash et
        # ressortir intact dans le JSON (classe de defaut cp1252).
        title = "Issue périmée → corriger le pool"
        seq = [
            ok_result([issue(42, ["approved"], title)]),  # R1 issues
            ok_result([]),                                 # R1 prs
            ok_result([]),                                 # R2 issues
            ok_result([]),                                 # R2 prs
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["urn"], "grain")
        self.assertEqual(data["pick"]["title"], title)

    def test_epic_label_goes_to_umbrella_not_grain(self):
        seq = [
            ok_result([issue(7, ["epic"])]),
            ok_result([]),
            ok_result([]),
            ok_result([]),
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["grain"], 0)
        self.assertEqual(data["umbrella"], 1)
        self.assertEqual(data["urn"], "umbrella")

    def test_needs_approval_is_in_no_urn(self):
        seq = [
            ok_result([issue(9, ["needs-approval"])]),
            ok_result([]),
            ok_result([]),
            ok_result([]),
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")

    def test_subprocess_utf8_replacement_kwargs(self):
        # Fix bloquant 1 (po-2027) : sans encoding="utf-8" errors="replace",
        # text=True decode stdout en cp1252 sous Windows => UnicodeDecodeError
        # sur tout titre accentue. Le fix vit dans les kwargs de l'appel.
        with mock.patch("subprocess.run", side_effect=[ok_result([])] * 4) as run:
            run_main(picker, ["--json"])
        self.assertGreaterEqual(len(run.call_args_list), 4)
        for call in run.call_args_list:
            self.assertEqual(call.kwargs.get("encoding"), "utf-8")
            self.assertEqual(call.kwargs.get("errors"), "replace")


class TestCycleEndFailClosed(unittest.TestCase):
    def test_gh_error_yields_error_exit2(self):
        exc = subprocess.CalledProcessError(1, ["gh"], stderr="HTTP 403: rate limit")
        with mock.patch("subprocess.run", side_effect=exc):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 2)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "ERROR")
        self.assertIn("rate limit", json.dumps(data))

    def test_partial_failure_backlog_ok_delivery_panics_is_error(self):
        now = datetime.now(timezone.utc)
        fresh_pr = {"number": 1, "mergedAt": now.isoformat()}
        seq = [
            ok_result([issue(1, ["approved"])]),  # backlog R1
            ok_result([]),                         # backlog R2
            ok_result([]),                         # opened R1
            ok_result([fresh_pr]),                 # merged R1
            subprocess.TimeoutExpired(cmd=["gh"], timeout=60),  # opened R2
            subprocess.TimeoutExpired(cmd=["gh"], timeout=60),  # merged R2
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")


class TestCycleEndVerdicts(unittest.TestCase):
    def _seq(self, issues_r1, issues_r2, opened, merged):
        return [
            ok_result(issues_r1), ok_result(issues_r2),
            ok_result(opened[0]), ok_result(merged[0]),
            ok_result(opened[1]), ok_result(merged[1]),
        ]

    def test_empty_backlog_no_delivery_pass(self):
        with mock.patch("subprocess.run", side_effect=self._seq([], [], ([], []), ([], []))):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PASS")
        self.assertEqual(data["backlog_grain"], 0)

    def test_backlog_and_fleet_delivery_pass(self):
        now = datetime.now(timezone.utc)
        merged_pr = {"number": 5, "mergedAt": now.isoformat()}
        with mock.patch("subprocess.run",
                        side_effect=self._seq([issue(1, ["approved"])], [],
                                              ([], []), ([merged_pr], []))):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PASS")
        self.assertEqual(data["prs_delivered_fleet"], 1)

    def test_backlog_no_delivery_fail_exit1(self):
        old = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
        stale_open = {"number": 2, "createdAt": old}
        with mock.patch("subprocess.run",
                        side_effect=self._seq([issue(1, ["bug"])], [],
                                              ([stale_open], []), ([], []))):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 1)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "FAIL")
        self.assertEqual(data["backlog_grain"], 1)
        self.assertEqual(data["prs_delivered_fleet"], 0)

    def test_backlog_counts_only_grain_labels(self):
        # Le compteur ne mesure QUE l'urne grain : une issue needs-approval
        # ne doit ni gonfler le backlog ni pretendre etre compte (le test
        # ne rapporte que ce qu'il mesure).
        with mock.patch("subprocess.run",
                        side_effect=self._seq([issue(3, ["needs-approval"])], [],
                                              ([], []), ([], []))):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["backlog_grain"], 0)
        self.assertEqual(data["verdict"], "PASS")


class MachineFlagRemoved(unittest.TestCase):
    """--machine supprime (ai-01 CR point 2) : argparse doit rejeter."""

    def _cli(self, script):
        proc = subprocess.run(
            [sys.executable, str(SCHEDULING_DIR / script), "--machine", "myia-po-2025"],
            capture_output=True, timeout=30,
        )
        return proc

    def test_picker_rejects_machine(self):
        proc = self._cli("pick_idle_grain.py")
        self.assertEqual(proc.returncode, 2)
        self.assertIn(b"unrecognized arguments", proc.stderr)

    def test_cycle_end_rejects_machine(self):
        proc = self._cli("test_cycle_end.py")
        self.assertEqual(proc.returncode, 2)
        self.assertIn(b"unrecognized arguments", proc.stderr)


if __name__ == "__main__":
    unittest.main()
