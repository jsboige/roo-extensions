#!/usr/bin/env python3
"""Unit tests for the 3-urn picker — an open PR is never a free candidate.

Measured on po-2024 (cycle c.309): ms#1538 (an open PR) came out of the draw
as a candidate and was treated as a work item — a claim was heading for a PR.
`delivered` used to be "never skipped", so a PR was the one urn that could
only ever produce a LIBRE verdict.

Contract under test:
  - an item carrying `pull_request` (REST key -> `is_pr`) is ECARTE with an
    explicit reason, whatever urn it came from, and without any API call;
  - a real issue still goes through the claim checks (the exclusion must not
    become a blanket skip);
  - PRs stay COLLECTED: `delivered` feeds `cited_issues_by_open_prs`, which
    is how an issue already carried by an open PR is excluded (decision
    ai-01 25/10). Filtering them out at collection would silently kill that.
"""

import importlib.util
import os
import random
import unittest
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "pick_idle_grain",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "..", "scheduling", "pick_idle_grain.py"))
pick = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(pick)


def _item(number, *, is_pr=False, labels=(), repo="jsboige/roo-extensions",
          title=None):
    return {
        "number": number,
        "title": f"item {number}" if title is None else title,
        "body": "",
        "labels": [{"name": n} for n in labels],
        "assignees": [],
        "createdAt": "2026-10-28T00:00:00Z",
        "updatedAt": "2026-10-28T00:00:00Z",
        "is_pr": is_pr,
        "repo": repo,
    }


class OpenPrIsNeverFree(unittest.TestCase):
    def test_delivered_pr_candidate_is_discarded_without_any_api_call(self):
        pr = _item(1538, is_pr=True)
        with mock.patch.object(pick.check_issue_claim, "fetch_issue",
                               side_effect=AssertionError("no claim lookup on a PR")):
            skip, reason = pick.check_candidate("delivered", pr, "myia-po-2024",
                                                "myia-po-2024:roo-extensions")
        self.assertTrue(skip)
        self.assertIn("open PR", reason)

    def test_a_pr_reached_through_another_urn_is_discarded_too(self):
        # Defensive: nothing forbids a future collection change from letting a
        # PR into grain/umbrella. The guard reads the ITEM, not the urn name.
        pr = _item(1539, is_pr=True, labels=("approved",))
        skip, reason = pick.check_candidate("grain", pr, "myia-po-2024",
                                            "myia-po-2024:roo-extensions")
        self.assertTrue(skip)
        self.assertIn("open PR", reason)

    def test_a_drawn_pr_is_served_as_candidate_then_skipped(self):
        # The measured shape: the draw hands the PR out as a candidate.
        pr = _item(1538, is_pr=True)
        buckets = {"grain": [], "umbrella": [], "delivered": [pr]}
        drawn = pick.draw_candidates(buckets, pick.DEFAULT_WEIGHTS,
                                     random.Random(42), 1)
        self.assertEqual([(urn, item["number"]) for urn, item in drawn],
                         [("delivered", 1538)])
        skip, reason = pick.check_candidate(drawn[0][0], drawn[0][1],
                                            "myia-po-2024",
                                            "myia-po-2024:roo-extensions")
        self.assertTrue(skip)
        self.assertIn("open PR", reason)

    def test_a_real_issue_still_goes_through_the_claim_checks(self):
        issue = _item(4400, labels=("approved",))
        with mock.patch.object(pick.check_issue_claim, "fetch_issue",
                               return_value={"comments": []}) as fetch:
            skip, reason = pick.check_candidate("grain", issue, "myia-po-2024",
                                                "myia-po-2024:roo-extensions")
        self.assertFalse(skip, reason)
        self.assertEqual(reason, "")
        fetch.assert_called_once()

    def test_prs_are_still_collected_for_the_cited_by_exclusion(self):
        # Keeping PRs in `delivered` is what makes "issue already carried by an
        # open PR" detectable. This test fails if someone "filters at
        # collection" without moving that exclusion.
        pr = {"number": 1549, "title": "feat: x", "body": "Closes #4151",
              "labels": [], "is_pr": True, "repo": "jsboige/jsboige-mcp-servers"}
        issue = _item(4151)
        buckets, unlabelled_open, open_issues = pick.bucketize_items([pr, issue])
        self.assertEqual(len(buckets["delivered"]), 1)
        self.assertEqual(buckets["grain"], [])
        self.assertEqual(unlabelled_open, 1)
        self.assertEqual(open_issues, 1)  # the PR is not an open ISSUE
        cited = pick.cited_issues_by_open_prs(buckets["delivered"])
        self.assertEqual(cited.get(("jsboige/jsboige-mcp-servers", 4151)), 1549)


class EpicByTitleIsUmbrella(unittest.TestCase):
    """An epic carried by its TITLE marker (no `epic` label) is umbrella, not grain.

    Measured on web2 (cycle c.91, 30/10): #3151 ("[#2191] RooSync canal sous
    PostgreSQL - messagerie + dashboards hors GDrive (épic)", labels
    approved/claude-only, NO `epic` label) was drawn from the GRAIN urn three
    cycles in a row - umbrella classification was label-only. The net reads a
    bounded title marker (prefix "[EPIC]"/"Epic:"/"Epic -" or a parenthesized
    suffix at end of title), never the bare word: "epicenter" stays a grain.
    """

    # The exact measured shape of #3151 (accented suffix, actionable labels).
    EPIC_SUFFIX_TITLE = (
        "[#2191] RooSync canal sous PostgreSQL — messagerie + dashboards "
        "hors GDrive (épic)")

    def test_measured_epic_suffix_lands_in_umbrella_not_grain(self):
        issue = _item(3151, labels=("approved", "claude-only"),
                      title=self.EPIC_SUFFIX_TITLE)
        buckets, unlabelled_open, open_issues = pick.bucketize_items([issue])
        self.assertEqual([i["number"] for i in buckets["umbrella"]], [3151])
        self.assertEqual(buckets["grain"], [])
        self.assertEqual(unlabelled_open, 0)
        self.assertEqual(open_issues, 1)

    def test_epic_prefix_variants_land_in_umbrella(self):
        for title in ("Epic: Optimisation consommation crédits",
                      "[EPIC] Fleet hardening", "[ÉPIC] Mixed accents",
                      "Epic - Fleet hardening"):
            with self.subTest(title=title):
                issue = _item(1, labels=("approved",), title=title)
                buckets, _, _ = pick.bucketize_items([issue])
                self.assertEqual([i["number"] for i in buckets["umbrella"]], [1])
                self.assertEqual(buckets["grain"], [])

    def test_bare_epic_word_inside_a_sentence_stays_grain(self):
        # No false positives: the marker must be a bounded prefix/suffix, the
        # bare word anywhere else is ordinary vocabulary ("epicenter").
        for title in ("Fix the epicenter of the search failure",
                      "Add epic mode to the picker",
                      "item 4400"):
            with self.subTest(title=title):
                issue = _item(4400, labels=("approved",), title=title)
                buckets, unlabelled_open, _ = pick.bucketize_items([issue])
                self.assertEqual([i["number"] for i in buckets["grain"]], [4400])
                self.assertEqual(buckets["umbrella"], [])
                self.assertEqual(unlabelled_open, 0)

    def test_unlabelled_epic_by_title_counts_as_umbrella_not_hole(self):
        # An epic-shaped title with NO urn label must join umbrella, not the
        # unlabelled hole counter (that hole is the coordinator's signal).
        issue = _item(3151, labels=(), title=self.EPIC_SUFFIX_TITLE)
        buckets, unlabelled_open, open_issues = pick.bucketize_items([issue])
        self.assertEqual(len(buckets["umbrella"]), 1)
        self.assertEqual(unlabelled_open, 0)
        self.assertEqual(open_issues, 1)

    def test_looks_like_epic_title_direct_cases(self):
        cases = {
            "…hors GDrive (épic)": True,      # accented suffix (measured #3151)
            "[ÉPIC] upper accented": True,     # NFKD + lower
            "Epic: prefix": True,
            "epicenter of the failure": False,  # word boundary, not a marker
            "Add epic mode": False,
            "": False,
            None: False,
        }
        for title, expected in cases.items():
            with self.subTest(title=title):
                self.assertEqual(pick._looks_like_epic_title(title), expected)

    def test_epic_label_alone_still_lands_in_umbrella(self):
        # The label path is unchanged - the title net only widens it.
        issue = _item(3111, labels=("epic", "approved"))
        buckets, _, _ = pick.bucketize_items([issue])
        self.assertEqual([i["number"] for i in buckets["umbrella"]], [3111])
        self.assertEqual(buckets["grain"], [])


if __name__ == "__main__":
    unittest.main()
