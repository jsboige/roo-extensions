#!/usr/bin/env python3
"""Tests for the REST surface of test_cycle_end.py (#4150 lot 4b, doctrine #4604).

`gh issue list` / `gh pr list` / `gh issue view` (GraphQL, fleet-shared quota)
fell to ERROR fail-closed under contention (measured po-204 c.371/372). The
collectors now go through `gh api repos/...` (core quota, never exhausted).
Pure unit tests, no network: run_gh_text and fetchers are patched.
"""

import importlib.util
import json
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest import mock

_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "..", "scheduling", "test_cycle_end.py")
_spec = importlib.util.spec_from_file_location("test_cycle_end_mod", _SCRIPT)
tce = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tce)

NOW = datetime(2026, 11, 9, 21, 0, tzinfo=timezone.utc)


def _lines(items):
    return "".join(json.dumps(i) + "\n" for i in items)


class ParseJsonLines(unittest.TestCase):

    def test_one_compact_object_per_line(self):
        out = tce._parse_json_lines('{"a": 1}\n{"a": 2}\n', "r")
        self.assertEqual([o["a"] for o in out], [1, 2])

    def test_garbage_line_is_instrument_failure_not_empty_pool(self):
        with self.assertRaises(tce.GhCommandError):
            tce._parse_json_lines('{"a": 1}\nnot json\n', "r")


class SplitOpenItems(unittest.TestCase):
    """Un PR porte la cle `pull_request` dans la reponse /issues (picker #4103)."""

    def test_prs_and_issues_split_and_normalized_camelCase(self):
        raw = [
            {"number": 1, "title": "issue", "created_at": "2026-01-01T00:00:00Z",
             "labels": [{"name": "bug"}]},
            {"number": 2, "title": "pr", "created_at": "2026-02-01T00:00:00Z",
             "labels": [], "pull_request": {"url": "x"}},
        ]
        issues, prs = tce.split_open_items(raw)
        self.assertEqual(len(issues), 1)
        self.assertEqual(len(prs), 1)
        self.assertEqual(issues[0]["createdAt"], "2026-01-01T00:00:00Z")
        self.assertEqual(issues[0]["labels"], [{"name": "bug"}])
        self.assertIn("pull_request", prs[0])


class FetchMergedPrsSince(unittest.TestCase):

    def test_keeps_window_merges_drops_rejected(self):
        cutoff = NOW - timedelta(hours=24)
        page1 = _lines([
            # fusion dans la fenetre -> comptee
            {"number": 100, "merged_at": "2026-11-09T10:00:00Z",
             "updated_at": "2026-11-09T10:00:00Z"},
            # fermee sans merge (rejetee) -> ignoree
            {"number": 101, "merged_at": None, "updated_at": "2026-11-09T09:00:00Z"},
            # fusion ancienne -> hors fenetre, ignoree
            {"number": 102, "merged_at": "2026-10-01T10:00:00Z",
             "updated_at": "2026-11-01T10:00:00Z"},
        ])
        calls = []

        def fake(cmd, repo, timeout=60):
            calls.append(cmd[-1])
            return page1 if len(calls) == 1 else ""

        with mock.patch.object(tce, "run_gh_text", side_effect=fake):
            merged = tce.fetch_merged_prs_since("jsboige/roo-extensions", cutoff)
        self.assertEqual([p["number"] for p in merged], [100])
        # page 1 melange frais et ancien -> pas d'arret tot, page 2 vide -> arret
        self.assertEqual(len(calls), 2)

    def test_stops_without_second_page_when_whole_page_precedes_window(self):
        cutoff = NOW - timedelta(hours=24)
        stale_page = _lines([
            {"number": 900 + i, "merged_at": "2026-09-01T00:00:00Z",
             "updated_at": "2026-09-01T00:00:00Z"} for i in range(3)
        ])
        calls = []

        def fake(cmd, repo, timeout=60):
            calls.append(cmd[-1])
            return stale_page

        with mock.patch.object(tce, "run_gh_text", side_effect=fake):
            merged = tce.fetch_merged_prs_since("jsboige/roo-extensions", cutoff)
        self.assertEqual(merged, [])
        # TOUTE la page precede la fenetre -> arret tot, une seule requete
        self.assertEqual(len(calls), 1)

    def test_pages_until_a_page_precedes_the_window(self):
        cutoff = NOW - timedelta(hours=24)
        fresh = [{"number": i, "merged_at": "2026-11-09T11:00:00Z",
                  "updated_at": "2026-11-09T11:00:00Z"} for i in range(3)]
        stale = [{"number": 900 + i, "merged_at": "2026-09-01T00:00:00Z",
                  "updated_at": "2026-09-01T00:00:00Z"} for i in range(3)]
        pages = {1: _lines(fresh), 2: _lines(stale)}
        calls = []

        def fake(cmd, repo, timeout=60):
            calls.append(cmd[-1])
            return pages.get(len(calls), "")

        with mock.patch.object(tce, "run_gh_text", side_effect=fake):
            merged = tce.fetch_merged_prs_since("jsboige/roo-extensions", cutoff)
        self.assertEqual(len(merged), 3)
        self.assertEqual(len(calls), 2)


class CountPrsDeliveredSince(unittest.TestCase):

    def test_opened_in_window_plus_merged_counted(self):
        # Bornes relatives a l'horloge reelle : le test ne pourrit pas au fil
        # des jours (pas de mock de datetime — _parse_ts en depend).
        now = datetime.now(timezone.utc)
        prs_by_repo = {
            "jsboige/roo-extensions": [
                {"number": 1, "created_at": (now - timedelta(hours=2)).isoformat()},
                {"number": 2, "created_at": (now - timedelta(hours=48)).isoformat()},
            ],
            "jsboige/jsboige-mcp-servers": [],
        }
        with mock.patch.object(
                tce, "fetch_merged_prs_since",
                side_effect=lambda repo, cutoff: (
                    [{"number": 9}] if repo == "jsboige/roo-extensions" else [])):
            delivered = tce.count_prs_delivered_since(24, prs_by_repo)
        self.assertEqual(delivered, 2)  # 1 ouverte dans la fenetre + 1 mergee


class ListApprovedWithoutPr(unittest.TestCase):

    def test_word_boundary_and_repo_scoping(self):
        issues = {"jsboige/roo-extensions": [
            tce._normalize_issue({"number": 101, "title": "grain 101",
                                  "labels": [{"name": "approved"}]}),
            tce._normalize_issue({"number": 10, "title": "grain 10",
                                  "labels": [{"name": "approved"}]}),
        ]}
        prs = {"jsboige/roo-extensions": [{"title": "fix: see #101 (suite)"}],
               "jsboige/jsboige-mcp-servers": [{"title": "refactor: couvre #10"}]}
        out = tce.list_approved_without_pr(issues, prs)
        # #101 couvert (frontiere de mot) ; #10 NON couvert : la PR vit dans
        # l'AUTRE depot — un numero seul n'identifie rien (#4103).
        self.assertEqual([i["number"] for i in out], [10])


class SentinelleGraphQL(unittest.TestCase):
    """#4150 lot 4b : aucune jambe GraphQL ne subsiste dans l'instrument."""

    def test_no_gh_issue_or_pr_list_legs(self):
        with open(_SCRIPT, encoding="utf-8") as fh:
            src = fh.read()
        for banned in ('"gh", "issue", "list"', '"gh", "issue", "view"',
                       '"gh", "pr", "list"'):
            self.assertNotIn(banned, src, f"jambe GraphQL restante: {banned}")
        self.assertIn('"gh", "api"', src)


if __name__ == "__main__":
    unittest.main()
