#!/usr/bin/env python3
"""test_check_issue_claim.py — tests unitaires pour #3676 (ADR 017).

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
    DEFAULT_REPO,
    SUBMODULE_REPO,
    classify,
    classify_number,
    extract_machine,
    main,
    parse_iso_utc,
    reduce_claims,
    resolve_repo,
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

    def test_result_releases_claim(self):
        # le protocole worker livre "[CLAIMED] by ..." puis "[RESULT] ..." --
        # si RESULT ne ferme pas, la machine garde un faux verrou 24h
        # (reproduit sur le stock live #3626, review #3680 bloquant 1)
        comments = [
            comment("[CLAIMED] myia-po-2023 -- start", T0),
            comment("[RESULT] myia-po-2023 -- PR #1 delivered, SHA abc123", T0 + timedelta(hours=2)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2023"]["state"], "released")

    def test_result_releases_only_own_machine(self):
        comments = [
            comment("[CLAIMED] myia-po-2023 -- a", T0),
            comment("[CLAIMED] myia-web1 -- b", T0 + timedelta(minutes=5)),
            comment("[RESULT] myia-po-2023 -- a shipped", T0 + timedelta(hours=2)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2023"]["state"], "released")
        self.assertEqual(state["myia-web1"]["state"], "active")

    def test_result_scanned_as_event_and_decoration_tolerant(self):
        for body in (
            "[RESULT] myia-po-2023 -- shipped",
            "**[RESULT] myia-po-2023 -- shipped**",
            "## [RESULT] myia-po-2023 -- shipped",
        ):
            events = list(scan_comment_events(body))
            self.assertEqual([e[0] for e in events], ["RESULT"], body)
            self.assertEqual(events[0][1], "myia-po-2023", body)

    def test_result_mentioned_in_prose_is_not_event(self):
        body = (
            "[CLAIMED] myia-po-2023 -- start\n"
            "Delivered, see the `[RESULT]` convention in the rules.\n"  # prose
        )
        events = [e[0] for e in scan_comment_events(body)]
        self.assertEqual(events, ["CLAIMED"])


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
                rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 1)

    def test_clear_exit_0(self):
        issue = self._issue([])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)

    def test_resuming_exit_0(self):
        issue = self._issue([comment("[CLAIMED] myia-po-2026 -- mine", T0)])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            with patch("check_issue_claim.now_utc", return_value=T0 + timedelta(hours=1)):
                rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)

    def test_result_releases_block_end_to_end(self):
        # reproduction #3626 : une AUTRE machine a livre via [RESULT] --
        # le check doit rendre la voie libre (exit 0), pas bloquer 24h
        issue = self._issue([
            comment("[CLAIMED] myia-po-2025 -- on it", T0),
            comment("[RESULT] myia-po-2025 -- delivered PR #99", T0 + timedelta(hours=1)),
        ])
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            with patch("check_issue_claim.now_utc", return_value=T0 + timedelta(hours=2)):
                rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)

    def test_closed_issue_blocked_exit_1(self):
        issue = self._issue([], state="CLOSED")
        with patch("check_issue_claim.fetch_issue", return_value=issue):
            rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 1)

    def test_gh_failure_exit_2(self):
        with patch(
            "check_issue_claim.fetch_issue",
            side_effect=RuntimeError("gh failed: no network"),
        ):
            rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 2)


def gh_stub(per_repo):
    """Fake `_gh_exec` driven by a {repo: (returncode, stdout, stderr)} table.

    Patching the single gh seam keeps these tests OFF the network. The previous
    revision of this suite patched `fetch_issue` only, so the repo resolution
    added for #3768 reached out to GitHub for real -- green locally with an
    authenticated gh, red in CI, and 1000x slower either way.
    """

    def _exec(args):
        for repo, outcome in per_repo.items():
            if any(f"repos/{repo}/issues/" in a for a in args):
                return outcome
        raise AssertionError(f"unexpected gh call: {args}")

    return _exec


OK_ISSUE = (0, "issue\n", "")
OK_PR = (0, "pr\n", "")
NOT_FOUND = (1, "", "gh: Not Found (HTTP 404)")
RATE_LIMITED = (1, "", "gh: API rate limit exceeded for user ID 3159389 (HTTP 403)")


class TestClassifyNumber(unittest.TestCase):
    """A failed lookup must never be reported as an absence (#3768 follow-up)."""

    def _kind(self, outcome):
        with patch("check_issue_claim._gh_exec", gh_stub({DEFAULT_REPO: outcome})):
            return classify_number("123", DEFAULT_REPO)

    def test_issue(self):
        self.assertEqual(self._kind(OK_ISSUE), "issue")

    def test_pull_request(self):
        self.assertEqual(self._kind(OK_PR), "pr")

    def test_real_404_is_absent(self):
        self.assertEqual(self._kind(NOT_FOUND), "absent")

    def test_rate_limit_is_error_not_absent(self):
        # Le coeur du correctif : un 403 de limite secondaire n'est PAS un 404.
        self.assertEqual(self._kind(RATE_LIMITED), "error")

    def test_empty_stdout_is_error_not_absent(self):
        self.assertEqual(self._kind((0, "   \n", "")), "error")


class TestResolveRepo(unittest.TestCase):
    def _resolve(self, parent, submod):
        stub = gh_stub({DEFAULT_REPO: parent, SUBMODULE_REPO: submod})
        with patch("check_issue_claim._gh_exec", stub):
            return resolve_repo("123")

    def test_issue_in_parent_only(self):
        repo, note, code = self._resolve(OK_ISSUE, NOT_FOUND)
        self.assertEqual((repo, code), (DEFAULT_REPO, 0))
        self.assertEqual(note, "")

    def test_pr_in_parent_issue_in_submodule_is_the_3768_trap(self):
        repo, note, code = self._resolve(OK_PR, OK_ISSUE)
        self.assertEqual((repo, code), (SUBMODULE_REPO, 0))
        self.assertIn("PULL REQUEST", note)

    def test_issue_in_both_is_ambiguous_exit_3(self):
        repo, message, code = self._resolve(OK_ISSUE, OK_ISSUE)
        self.assertIsNone(repo)
        self.assertEqual(code, 3)
        self.assertIn("AMBIGUOUS", message)

    def test_absent_from_both_is_exit_2(self):
        repo, message, code = self._resolve(NOT_FOUND, NOT_FOUND)
        self.assertIsNone(repo)
        self.assertEqual(code, 2)

    def test_partial_failure_refuses_instead_of_guessing(self):
        # La regression que cette suite existe pour empecher : le parent repond
        # "issue", le submodule est en 403. Resoudre vers le parent ferait ecrire
        # le verrou sur le mauvais ticket -- exactement le degat de #3768.
        repo, message, code = self._resolve(OK_ISSUE, RATE_LIMITED)
        self.assertIsNone(repo)
        self.assertEqual(code, 2)
        self.assertIn(SUBMODULE_REPO, message)
        self.assertIn("not an absence", message)

    def test_partial_failure_on_the_other_side_too(self):
        repo, _message, code = self._resolve(RATE_LIMITED, OK_ISSUE)
        self.assertIsNone(repo)
        self.assertEqual(code, 2)


class TestMainRepoResolution(unittest.TestCase):
    """main() must surface resolve_repo's exit code, not a fixed one."""

    def test_ambiguous_number_exits_3(self):
        stub = gh_stub({DEFAULT_REPO: OK_ISSUE, SUBMODULE_REPO: OK_ISSUE})
        with patch("check_issue_claim._gh_exec", stub):
            self.assertEqual(main(["123", "--agent", "myia-po-2026"]), 3)

    def test_unreadable_repo_exits_2_not_3(self):
        # Une panne gh rapportee en "3" enverrait l'operateur chercher une
        # collision de numerotation qui n'existe pas.
        stub = gh_stub({DEFAULT_REPO: OK_ISSUE, SUBMODULE_REPO: RATE_LIMITED})
        with patch("check_issue_claim._gh_exec", stub):
            self.assertEqual(main(["123", "--agent", "myia-po-2026"]), 2)

    def test_explicit_repo_makes_no_lookup_at_all(self):
        def explode(args):
            raise AssertionError("--repo was given; no resolution call expected")

        issue = {"number": 123, "state": "OPEN", "comments": []}
        with patch("check_issue_claim._gh_exec", explode):
            with patch("check_issue_claim.fetch_issue", return_value=issue):
                rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
