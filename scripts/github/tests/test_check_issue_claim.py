#!/usr/bin/env python3
"""test_check_issue_claim.py — tests unitaires pour #3676 (ADR 014).

Couverture :
  - parse_iso_utc : stamps serveur Z et +00:00
  - extract_machine : token machine sur la ligne, absent, casse
  - scan_comment_events : line-anchored (prose = non-événement, #10228),
    tolérance décoration (**, ##, liste), multi-marqueurs multi-lignes,
    insensible à la casse
  - reduce_claims : dernier marqueur gagne, tri par createdAt serveur
    (pas l'ordre d'entrée), close sans open = no-op, sentinel unowned
  - classify : blocage autre machine, STALE au-delà du seuil, propre claim
    = reprise, claim sans propriétaire = fail-closed
  - main : end-to-end bloqué / clear / reprise, issue fermée
"""

import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

# Permet l'import depuis le repertoire parent
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from check_issue_claim import (
    classify,
    extract_machine,
    main,
    parse_iso_utc,
    reduce_claims,
    scan_comment_events,
)

T0 = datetime(2026, 9, 15, 12, 0, 0, tzinfo=timezone.utc)


def iso(dt):
    return dt.isoformat().replace("+00:00", "Z")


def comment(body, created_at):
    return {"body": body, "createdAt": iso(created_at)}


class TestParseIsoUtc(unittest.TestCase):
    def test_z_suffix(self):
        self.assertEqual(parse_iso_utc("2026-09-15T12:00:00Z"), T0)

    def test_offset(self):
        self.assertEqual(parse_iso_utc("2026-09-15T14:00:00+02:00"), T0)

    def test_naive_defensive(self):
        parsed = parse_iso_utc("2026-09-15T12:00:00")
        self.assertEqual(parsed.tzinfo, timezone.utc)


class TestExtractMachine(unittest.TestCase):
    def test_fleet_tokens(self):
        for token in ("myia-ai-01", "myia-po-2026", "myia-web1"):
            self.assertEqual(
                extract_machine(f"[CLAIMED] {token} -- work"), token
            )

    def test_case_insensitive(self):
        self.assertEqual(extract_machine("[CLAIMED] MYIA-PO-2026 -- work"), "myia-po-2026")

    def test_absent(self):
        self.assertIsNone(extract_machine("[CLAIMED] starting work now"))

    def test_machine_on_other_line_not_attributed(self):
        # la machine citée sur une AUTRE ligne que le marqueur n'est pas
        # attribuée à ce marqueur : le claim devient unowned -> fail-closed
        events = list(
            scan_comment_events("[CLAIMED] commencing\ncontext: myia-po-2025 did X before")
        )
        marker, machine, _line = events[0]
        self.assertEqual(marker, "CLAIMED")
        self.assertIsNone(machine)
        # une machine citée en prose sans marqueur = pas d'événement du tout
        self.assertEqual(
            list(scan_comment_events("cc myia-po-2025 who claimed earlier")), []
        )


class TestScanCommentEvents(unittest.TestCase):
    def test_line_anchored_mid_prose_is_not_event(self):
        body = (
            "[CLAIMED] myia-po-2023 -- start\n"
            "Release with `[RELEASED]` when your PR lands.\n"  # prose (#10228)
        )
        events = [e[0] for e in scan_comment_events(body)]
        self.assertEqual(events, ["CLAIMED"])

    def test_decoration_tolerance(self):
        for decorated in (
            "**[CLAIMED] myia-po-2023 -- x**",
            "## [CLAIMED] myia-po-2023 -- x",
            "- [CLAIMED] myia-po-2023 -- x",
            "[claimed] myia-po-2023 -- x",
        ):
            events = list(scan_comment_events(decorated))
            self.assertEqual(len(events), 1, decorated)
            self.assertEqual(events[0][0], "CLAIMED", decorated)

    def test_multi_marker_across_lines_last_wins(self):
        body = "[CLAIMED] myia-po-2023 -- take\n[DONE] myia-po-2023 -- delivered"
        events = list(scan_comment_events(body))
        self.assertEqual([e[0] for e in events], ["CLAIMED", "DONE"])

    def test_marker_at_line_start_only(self):
        # un marqueur précédé de texte sur la même ligne = prose
        self.assertEqual(
            list(scan_comment_events("fixed per [CLAIMED] myia-po-2023 earlier")), []
        )


class TestReduceClaims(unittest.TestCase):
    def test_last_marker_wins_per_machine(self):
        comments = [
            comment("[CLAIMED] myia-po-2023 -- start", T0),
            comment("[RELEASED] myia-po-2023 -- pivot", T0 + timedelta(hours=1)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2023"]["state"], "released")

    def test_server_created_at_orders_not_input(self):
        # entrées dans le désordre : le claim T0+1h doit être l'état final
        comments = [
            comment("[CLAIMED] myia-po-2024 -- second", T0 + timedelta(hours=1)),
            comment("[CLAIMED] myia-po-2024 -- first", T0),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2024"]["since"], T0 + timedelta(hours=1))

    def test_close_without_open_is_noop(self):
        state = reduce_claims([comment("[DONE] myia-po-2025 -- report", T0)])
        self.assertNotIn("myia-po-2025", state)

    def test_unowned_claim_is_sentinel(self):
        state = reduce_claims([comment("[CLAIMED] starting now", T0)])
        self.assertIn(None, state)
        self.assertEqual(state[None]["state"], "active")

    def test_unowned_release_closes_unowned_claim(self):
        comments = [
            comment("[CLAIMED] starting now", T0),
            comment("[RELEASED] done here", T0 + timedelta(hours=2)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state[None]["state"], "released")

    def test_machines_independent(self):
        comments = [
            comment("[CLAIMED] myia-po-2023 -- a", T0),
            comment("[CLAIMED] myia-web1 -- b", T0 + timedelta(minutes=5)),
            comment("[DONE] myia-po-2023 -- a shipped", T0 + timedelta(hours=3)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2023"]["state"], "released")
        self.assertEqual(state["myia-web1"]["state"], "active")


class TestClassify(unittest.TestCase):
    def _state(self, machine, since):
        return {machine: {"state": "active", "since": since, "line": "[CLAIMED] x"}}

    def test_other_machine_within_threshold_blocks(self):
        blocking, warnings, notes = classify(
            self._state("myia-po-2025", T0), "myia-po-2026", 24.0, now=T0 + timedelta(hours=2)
        )
        self.assertEqual(len(blocking), 1)
        self.assertEqual(blocking[0][0], "myia-po-2025")
        self.assertEqual((warnings, notes), ([], []))

    def test_other_machine_stale_warns_not_blocks(self):
        blocking, warnings, notes = classify(
            self._state("myia-po-2025", T0), "myia-po-2026", 24.0, now=T0 + timedelta(hours=30)
        )
        self.assertEqual(blocking, [])
        self.assertEqual(len(warnings), 1)
        self.assertIn("STALE_CLAIM myia-po-2025", warnings[0])
        self.assertEqual(notes, [])

    def test_own_claim_is_resume(self):
        blocking, warnings, notes = classify(
            self._state("myia-po-2026", T0), "myia-po-2026", 24.0, now=T0 + timedelta(hours=2)
        )
        self.assertEqual((blocking, warnings), ([], []))
        self.assertEqual(len(notes), 1)
        self.assertIn("resuming", notes[0])

    def test_unowned_claim_blocks_fail_closed(self):
        blocking, _w, _n = classify(
            self._state(None, T0), "myia-po-2026", 24.0, now=T0 + timedelta(minutes=10)
        )
        self.assertEqual(len(blocking), 1)
        self.assertIn("UNOWNED", blocking[0][0])

    def test_released_claim_never_blocks(self):
        state = {"myia-po-2025": {"state": "released", "since": T0, "line": "x"}}
        blocking, warnings, notes = classify(
            state, "myia-po-2026", 24.0, now=T0 + timedelta(hours=1)
        )
        self.assertEqual((blocking, warnings, notes), ([], [], []))


class TestMain(unittest.TestCase):
    def _issue(self, comments, state="OPEN"):
        return {"number": 123, "state": state, "comments": comments}

    def test_blocked_exit_1(self):
        issue = self._issue([comment("[CLAIMED] myia-po-2025 -- on it", T0)])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            with patch("check_issue_claim.now_utc", return_value=T0 + timedelta(hours=1)):
                rc = main(["123", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 1)

    def test_clear_exit_0(self):
        issue = self._issue([])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            rc = main(["123", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)

    def test_resuming_exit_0(self):
        issue = self._issue([comment("[CLAIMED] myia-po-2026 -- mine", T0)])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            with patch("check_issue_claim.now_utc", return_value=T0 + timedelta(hours=1)):
                rc = main(["123", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)

    def test_closed_issue_blocked_exit_1(self):
        issue = self._issue([], state="CLOSED")
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            rc = main(["123", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 1)

    def test_gh_failure_exit_2(self):
        with patch(
            "check_issue_claim.fetch_issue",
            side_effect=RuntimeError("gh failed: no network"),
        ):
            rc = main(["123", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 2)


if __name__ == "__main__":
    unittest.main()
