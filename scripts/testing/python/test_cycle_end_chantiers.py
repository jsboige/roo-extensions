#!/usr/bin/env python3
"""Tests for the D4 anti-dormancy section of test_cycle_end.py.

D4 lists the chantiers (labels epic/approved) open for >= 30 days and flags
those with no dated decision or no substantive activity for > 14 days
(user escalation 19/10, Maintenance#121). Pure classification, no network:
list_chantiers() is exercised with run_gh_json patched.
"""

import importlib.util
import os
import unittest
from datetime import datetime, timezone
from unittest import mock

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "scheduling", "test_cycle_end.py")
_spec = importlib.util.spec_from_file_location("test_cycle_end_mod", _SCRIPT)
tce = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tce)

NOW = datetime(2026, 10, 20, 0, 0, tzinfo=timezone.utc)


def issue(number, created, comments=(), labels=("epic",)):
    return {
        "number": number,
        "title": f"chantier {number}",
        "createdAt": created,
        "labels": [{"name": n} for n in labels],
        "comments": [{"createdAt": ts, "body": body} for ts, body in comments],
    }


class ClassifyChantier(unittest.TestCase):

    def test_younger_than_30_days_is_not_a_chantier(self):
        self.assertIsNone(tce.classify_chantier(issue(1, "2026-10-01T00:00:00Z"), NOW))

    def test_boilerplate_comments_do_not_count_as_activity(self):
        row = tce.classify_chantier(issue(2, "2026-05-15T00:00:00Z", [
            ("2026-09-01T00:00:00Z", "Real progress on the extraction."),
            ("2026-10-18T00:00:00Z", "[CLAIMED] by claude on myia-po-2025 at 2026-10-18"),
            ("2026-10-19T00:00:00Z", "[RESULT] myia-po-2025: PASS — completed (no code changes needed)"),
            ("2026-10-19T01:00:00Z", "[RELEASED] myia-po-2025"),
        ]), NOW)
        self.assertEqual(row["idle_days"], 49)
        self.assertIn("dormant 49 j", row["flags"])
        self.assertIn("sans decision datee", row["flags"])

    def test_dated_decision_and_recent_activity_clear_both_flags(self):
        row = tce.classify_chantier(issue(3, "2026-08-17T00:00:00Z", [
            ("2026-10-20T00:00:00Z", "## [DÉCISION] La Phase D se livre sous #4131 — fin le **03/11**"),
        ]), NOW)
        self.assertEqual(row["flags"], [])
        self.assertEqual(row["last_decision"], "2026-10-20")

    def test_decision_without_any_date_does_not_count(self):
        row = tce.classify_chantier(issue(4, "2026-06-01T00:00:00Z", [
            ("2026-10-15T00:00:00Z", "[DECISION] we will do it soon"),
        ]), NOW)
        self.assertIn("sans decision datee", row["flags"])
        self.assertNotIn("dormant", " ".join(row["flags"]))

    def test_no_comment_falls_back_to_creation_date(self):
        row = tce.classify_chantier(issue(5, "2026-08-01T00:00:00Z"), NOW)
        self.assertEqual(row["idle_days"], row["age_days"])

    def test_gate_label_is_reported_not_hidden(self):
        row = tce.classify_chantier(
            issue(6, "2026-07-01T00:00:00Z", labels=("epic", "frozen")), NOW)
        self.assertEqual(row["gate"], ["frozen"])
        self.assertTrue(row["flags"])


class ListChantiers(unittest.TestCase):

    def test_dedups_across_labels_and_sorts_flagged_first(self):
        quiet = issue(10, "2026-08-01T00:00:00Z",
                      [("2026-10-19T00:00:00Z", "Décision datée : pilote le 22/10")],
                      labels=("epic", "approved"))
        sleeping = issue(11, "2026-05-01T00:00:00Z", labels=("approved",))

        def fake(cmd, repo, timeout=60):
            label = cmd[cmd.index("--label") + 1]
            return {"epic": [quiet], "approved": [quiet, sleeping]}[label]

        with mock.patch.object(tce, "run_gh_json", side_effect=fake):
            rows = tce.list_chantiers(repos=["jsboige/roo-extensions"], now=NOW)
        self.assertEqual([r["number"] for r in rows], [11, 10])
        self.assertTrue(rows[0]["flags"])
        self.assertEqual(rows[1]["flags"], [])

    def test_comments_capped_by_issue_list_are_refetched_in_full(self):
        # `gh issue list` stops at 100 comments: #622 had 694, last read 14/03
        # instead of 14/10 (measured 20/10), so it was reported dormant 219 j.
        capped = issue(622, "2026-03-10T00:00:00Z",
                       [("2026-03-14T00:00:00Z", "old progress")] * 100)
        full = capped["comments"] + [
            {"createdAt": "2026-10-14T00:00:00Z", "body": "Décision datée : AC0 re-mesuré le 21/10"}]
        calls = []

        def fake(cmd, repo, timeout=60):
            calls.append(cmd[:3])
            if cmd[:3] == ["gh", "issue", "view"]:
                self.assertIn("622", cmd)
                return {"comments": full}
            return {"epic": [capped], "approved": []}[cmd[cmd.index("--label") + 1]]

        with mock.patch.object(tce, "run_gh_json", side_effect=fake):
            rows = tce.list_chantiers(repos=["jsboige/roo-extensions"], now=NOW)
        self.assertIn(["gh", "issue", "view"], calls)
        self.assertEqual(rows[0]["idle_days"], 6)
        self.assertEqual(rows[0]["flags"], [])

    def test_line_names_flags_and_decision(self):
        row = tce.classify_chantier(issue(12, "2026-05-15T00:00:00Z"), NOW)
        row["repo"] = "jsboige/roo-extensions"
        line = tce.format_chantier_line(row)
        self.assertTrue(line.startswith("- roo-extensions#12 — 158 j"))
        self.assertIn("decision datee : aucune", line)
        self.assertIn("**[sans decision datee]**", line)


if __name__ == "__main__":
    unittest.main()
