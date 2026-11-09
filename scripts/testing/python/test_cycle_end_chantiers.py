#!/usr/bin/env python3
"""Tests for the D4 anti-dormancy section of test_cycle_end.py.

D4 lists the chantiers (labels epic/approved) open for >= 30 days and flags
those with no dated decision or no substantive activity for > 14 days
(user escalation 19/10, Maintenance#121). Pure classification, no network:
list_chantiers() is exercised with run_gh_json patched.
"""

import importlib.util
import json
import os
import re
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

    def test_own_d4_line_counts_as_the_dated_line_it_asks_for(self):
        # The line D4 requires (GO, named obstacle or proposed abandon) is posted
        # with the D4 marker; an obstacle line is not a "[DÉCISION]" but must clear the flag.
        row = tce.classify_chantier(issue(7, "2026-06-01T00:00:00Z", [
            ("2026-10-19T23:30:00Z", "**[D4 — ligne datée 19/10, ai-01 coord]**\n\n"
                                     "Obstacle nommé : po-2026 en réparation. Réexamen le 03/11."),
        ]), NOW)
        self.assertEqual(row["flags"], [])
        self.assertEqual(row["last_decision"], "2026-10-19")

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
    """Formes REST (#4150 lot 4b) : requetes par label puis commentaires
    page par page, run_gh_text rend une ligne JSON compacte par item."""

    @staticmethod
    def _raw(number, created, labels):
        return {"number": number, "title": f"chantier {number}",
                "created_at": created,
                "labels": [{"name": n} for n in labels]}

    @staticmethod
    def _lines(items):
        return "".join(json.dumps(i) + "\n" for i in items)

    def test_dedups_across_labels_and_sorts_flagged_first(self):
        quiet = self._raw(10, "2026-08-01T00:00:00Z", ("epic", "approved"))
        quiet_comments = [{"body": "Décision datée : pilote le 22/10",
                           "created_at": "2026-10-19T00:00:00Z"}]
        sleeping = self._raw(11, "2026-05-01T00:00:00Z", ("approved",))

        def fake(cmd, repo, timeout=60):
            url = cmd[-1]
            if "/comments" in url:
                if "issues/10/comments" in url:
                    return self._lines(quiet_comments)
                return ""  # #11 : aucun commentaire -> retombe sur createdAt
            label = "epic" if "labels=epic" in url else "approved"
            return self._lines({("epic",): [quiet], ("approved",): [quiet, sleeping]}[(label,)])

        with mock.patch.object(tce, "run_gh_text", side_effect=fake):
            rows = tce.list_chantiers(repos=["jsboige/roo-extensions"], now=NOW)
        self.assertEqual([r["number"] for r in rows], [11, 10])
        self.assertTrue(rows[0]["flags"])
        self.assertEqual(rows[1]["flags"], [])

    def test_comments_are_fetched_full_via_rest_paging(self):
        # #622 avait 694 commentaires : `gh issue list --json comments` cappait
        # a 100 (dernier lu 14/03 au lieu du 14/10, mesure 20/10). La pagination
        # REST rend tout — page 1 pleine (100 anciens), page 2 courte (1 décision
        # récente) : les deux pages doivent être lues.
        pages = {
            1: [{"body": "old progress", "created_at": "2026-03-14T00:00:00Z"}] * 100,
            2: [{"body": "Décision datée : AC0 re-mesuré le 21/10",
                 "created_at": "2026-10-14T00:00:00Z"}],
        }
        seen_pages = []

        def fake(cmd, repo, timeout=60):
            url = cmd[-1]
            if "/comments" in url:
                page = int(re.search(r"[?&]page=(\d+)", url).group(1))
                seen_pages.append(page)
                return self._lines(pages.get(page, []))
            return self._lines([self._raw(622, "2026-03-10T00:00:00Z", ("epic",))]
                               if "labels=epic" in url else [])

        with mock.patch.object(tce, "run_gh_text", side_effect=fake):
            rows = tce.list_chantiers(repos=["jsboige/roo-extensions"], now=NOW)
        self.assertEqual(seen_pages, [1, 2])  # page 2 courte -> arrêt
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
