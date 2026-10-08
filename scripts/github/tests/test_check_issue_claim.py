#!/usr/bin/env python3
"""test_check_issue_claim.py — tests unitaires pour #3676 (ADR 017) + #4114.

Couverture :
  - parse_iso_utc : stamps serveur Z et +00:00
  - extract_lane : identité lane machine[:workspace] (#4114), token machine
    seul, absent, casse, workspace case-preserved
  - scan_comment_events : line-anchored (prose = non-événement, #10228),
    tolérance décoration (**, ##, liste), multi-marqueurs multi-lignes,
    insensible à la casse
  - reduce_claims : dernier marqueur gagne, tri par createdAt serveur
    (pas l'ordre d'entrée), close sans open = no-op, sentinel unowned,
    release legacy ne ferme pas un verrou lane (#4114 fail-closed)
  - classify : blocage autre lane, STALE au-delà du seuil, propre claim
    = reprise, claim sans propriétaire = fail-closed, sémantique
    machine:workspace (#4114) : même machine+même workspace = self, même
    machine+workspace différent = foreign, legacy sans workspace = foreign
    + LEGACY_CLAIM (fail-closed)
  - default_agent / detect_workspace : composition lane, walk-up toplevel,
    dégradation machine seule hors dépôt
  - main : end-to-end bloqué / clear / reprise, issue fermée, composition
    --workspace depuis COMPUTERNAME
"""

import contextlib
import io
import json
import os
import sys
import tempfile
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
    default_agent,
    detect_workspace,
    extract_lane,
    fetch_issue,
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


class TestExtractLane(unittest.TestCase):
    def test_fleet_tokens(self):
        for token in ("myia-ai-01", "myia-po-2026", "myia-web1"):
            self.assertEqual(
                extract_lane(f"[CLAIMED] {token} -- work"), token
            )

    def test_case_insensitive(self):
        self.assertEqual(extract_lane("[CLAIMED] MYIA-PO-2026 -- work"), "myia-po-2026")

    def test_absent(self):
        self.assertIsNone(extract_lane("[CLAIMED] starting work now"))

    def test_machine_workspace_suffix(self):
        # #4114 : l'identité de claim est la lane machine:workspace
        self.assertEqual(
            extract_lane("[CLAIMED] myia-po-2026:roo-extensions -- work"),
            "myia-po-2026:roo-extensions",
        )

    def test_workspace_case_preserved_machine_lowered(self):
        # La casse du workspace est conservée (affichage) ; seule la machine
        # est normalisée -- les COMPARAISONS sont insensibles à la casse.
        self.assertEqual(
            extract_lane("[CLAIMED] MYIA-PO-2026:CoursIA-2 -- work"),
            "myia-po-2026:CoursIA-2",
        )

    def test_colon_without_workspace_token_is_machine_only(self):
        # "myia-po-2026: 12:00" (horodatage en prose) : le ':' non suivi d'un
        # token workspace ne fabrique pas une lane fantôme.
        self.assertEqual(
            extract_lane("[CLAIMED] myia-po-2026: pending review"), "myia-po-2026"
        )

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
            "`[CLAIMED] myia-po-2023 -- x`",  # inline-code decoration (#3826)
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

    def test_backticked_done_releases_claim(self):
        # #3826: un commentaire de libération dont le marqueur est décoré de
        # backticks — "`[DONE] myia-po-XXXX …`" — doit fermer le claim. Rouge sur
        # la regex pré-fix (marqueur non détecté, verrou fantôme jusqu'à --release).
        comments = [
            comment("[CLAIMED] myia-po-2023 -- start", T0),
            comment("`[DONE] myia-po-2023 -- shipped`", T0 + timedelta(hours=2)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2023"]["state"], "released")

    def test_worker_hold_line_keeps_claim_after_result(self):
        # #4000 (02/10): the worker's "do not redispatch" verdicts (rescue branch,
        # BLOCKED, FAIL with artifacts) start with [RESULT], which releases. The
        # worker now re-opens on a LATER line of the same comment: last marker wins.
        body = (
            "[RESULT] myia-po-2025: PASS — completed, but submodule work was PRESERVED "
            "on a rescue branch — review required, do not redispatch\n\n"
            "[RESCUE_BRANCH] #3944 phantom-pointer guard preserved real submodule work.\n"
            "- `worker-rescue/github-4000-x`@143ea41d in mcps/internal\n\n"
            "[CLAIMED] myia-po-2025 -- held: work above awaits recovery/review; "
            "do not re-take without asking myia-po-2025 or the coordinator"
        )
        comments = [
            comment("[CLAIMED] by claude on myia-po-2025 at 2026-10-02T04:40", T0),
            comment(body, T0 + timedelta(minutes=22)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2025"]["state"], "active")
        blocking, _, _ = classify(state, "myia-web2", 24, now=T0 + timedelta(minutes=40))
        self.assertEqual([b[0] for b in blocking], ["myia-po-2025"])

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
            "`[RESULT] myia-po-2023 -- shipped`",  # #3826
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

    def test_lane_scoped_claim_release_roundtrip(self):
        # #4114 : pose et levée sous la MÊME identité lane se suivent.
        comments = [
            comment("[CLAIMED] myia-po-2026:roo-extensions -- start", T0),
            comment("[RELEASED] myia-po-2026:roo-extensions -- shipped", T0 + timedelta(hours=1)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2026:roo-extensions"]["state"], "released")

    def test_legacy_release_does_not_close_lane_claim(self):
        # #4114 fail-closed : une levée au format historique (machine seule)
        # ne libère PAS un verrou posé sous identité lane -- le releaser sans
        # suffixe n'est pas prouvé être la lane qui a posé le verrou.
        comments = [
            comment("[CLAIMED] myia-po-2026:roo-extensions -- start", T0),
            comment("[DONE] myia-po-2026 -- shipped", T0 + timedelta(hours=1)),
        ]
        state = reduce_claims(comments)
        self.assertEqual(state["myia-po-2026:roo-extensions"]["state"], "active")
        # ... et la clé legacy, distincte, n'existe pas (close sans open = no-op)
        self.assertNotIn("myia-po-2026", state)


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


class TestClassifyLaneIdentity(unittest.TestCase):
    """#4114 : l'identité de claim est la lane machine[:workspace].

    AC de l'issue : même machine + même workspace = self ; même machine +
    workspace différent = foreign ; machine différente = foreign ; claim
    legacy sans workspace vu d'une lane de sa machine = foreign +
    avertissement (fail-closed).
    """

    def _state(self, lane, since=T0):
        return {lane: {"state": "active", "since": since, "line": "[CLAIMED] x"}}

    def test_same_machine_same_workspace_is_self(self):
        blocking, warnings, notes = classify(
            self._state("myia-po-2026:roo-extensions"),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual((blocking, warnings), ([], []))
        self.assertEqual(len(notes), 1)
        self.assertIn("resuming", notes[0])

    def test_same_machine_different_workspace_is_foreign(self):
        # Deux lanes partagent une machine : seul le workspace les distingue.
        blocking, warnings, notes = classify(
            self._state("myia-po-2026:CoursIA-2"),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual(len(blocking), 1)
        self.assertEqual(blocking[0][0], "myia-po-2026:CoursIA-2")
        self.assertEqual(notes, [])
        # foreign "simple" : pas de warning LEGACY (le claim porte un workspace)
        self.assertEqual([w for w in warnings if "LEGACY" in w], [])

    def test_different_machine_is_foreign(self):
        blocking, _w, notes = classify(
            self._state("myia-po-2025:roo-extensions"),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual(len(blocking), 1)
        self.assertEqual(notes, [])

    def test_legacy_claim_without_workspace_is_foreign_fail_closed(self):
        # AC #4114 : un claim pré-#4114 (machine seule) vu d'une lane de SA
        # machine est un TIERS -- on ne sait pas quelle lane l'a posé.
        blocking, warnings, notes = classify(
            self._state("myia-po-2026"),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual(len(blocking), 1)
        self.assertEqual(blocking[0][0], "myia-po-2026")
        self.assertEqual(notes, [])
        legacy = [w for w in warnings if w.startswith("LEGACY_CLAIM")]
        self.assertEqual(len(legacy), 1)
        self.assertIn("myia-po-2026", legacy[0])

    def test_legacy_agent_seeing_workspace_claim_is_foreign_too(self):
        # Converse : l'agent sans workspace (machine seule) face à un claim
        # lane de sa machine -- même fail-closed.
        blocking, warnings, _n = classify(
            self._state("myia-po-2026:roo-extensions"),
            "myia-po-2026",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual(len(blocking), 1)
        self.assertEqual(len([w for w in warnings if w.startswith("LEGACY_CLAIM")]), 1)

    def test_both_legacy_same_machine_is_self(self):
        # Compat : agent ET claim au format historique machine seule -- le
        # guard d'origine (pré-#4114) doit garder sa sémantique de reprise.
        blocking, warnings, notes = classify(
            self._state("myia-po-2026"),
            "myia-po-2026",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual((blocking, warnings), ([], []))
        self.assertEqual(len(notes), 1)
        self.assertIn("resuming", notes[0])

    def test_legacy_claim_past_threshold_is_stale_not_blocking(self):
        # La péremption domine le fail-closed : un claim legacy de 30 h ne
        # bloque plus (STALE), le claimant pose son propre [CLAIMED].
        blocking, warnings, _n = classify(
            self._state("myia-po-2026", since=T0 - timedelta(hours=30)),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0,
        )
        self.assertEqual(blocking, [])
        self.assertEqual(len([w for w in warnings if w.startswith("STALE_CLAIM")]), 1)
        self.assertEqual(len([w for w in warnings if w.startswith("LEGACY_CLAIM")]), 1)

    def test_lane_comparison_is_case_insensitive(self):
        # Le workspace en casse différente désigne la MÊME lane (la casse y
        # est de l'affichage, pas de l'identité).
        blocking, _w, notes = classify(
            self._state("myia-po-2026:Roo-Extensions"),
            "myia-po-2026:roo-extensions",
            24.0,
            now=T0 + timedelta(hours=2),
        )
        self.assertEqual(blocking, [])
        self.assertEqual(len(notes), 1)
        self.assertIn("resuming", notes[0])


class TestLaneIdentityHelpers(unittest.TestCase):
    """default_agent / detect_workspace (#4114) : composition de la lane."""

    def test_detect_workspace_walks_up_to_git_toplevel(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "my-repo"
            (root / "sub" / "dir").mkdir(parents=True)
            (root / ".git").mkdir()
            with patch("check_issue_claim.Path.cwd", return_value=root / "sub" / "dir"):
                self.assertEqual(detect_workspace(), "my-repo")

    def test_detect_workspace_empty_outside_any_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("check_issue_claim.Path.cwd", return_value=Path(tmp)):
                self.assertEqual(detect_workspace(), "")

    def test_detect_workspace_resolves_linked_worktree_gitfile(self):
        # #4122 review : dans un worktree lié, `.git` est un FICHIER (pointeur
        # gitdir). L'identité doit rester celle du checkout principal -- sinon
        # le re-check pré-livraison depuis le worktree voit « un autre
        # workspace » et bloque sur son PROPRE claim.
        with tempfile.TemporaryDirectory() as tmp:
            main = Path(tmp) / "roo-extensions"
            wt = main / ".claude" / "worktrees" / "wt-4114-claim-lane-id"
            wt.mkdir(parents=True)
            (main / ".git").mkdir()
            (wt / ".git").write_text(
                f"gitdir: {main / '.git' / 'worktrees' / 'wt-4114-claim-lane-id'}",
                encoding="utf-8",
            )
            with patch("check_issue_claim.Path.cwd", return_value=wt):
                self.assertEqual(detect_workspace(), "roo-extensions")

    def test_detect_workspace_submodule_pointer_falls_through(self):
        # Pointeur sans segment worktrees (submodule `.git/modules/<name>`)
        # : non résolu vers un toplevel, la remontée continue et atteint le
        # dépôt parent.
        with tempfile.TemporaryDirectory() as tmp:
            main = Path(tmp) / "roo-extensions"
            sub = main / "mcps" / "internal"
            sub.mkdir(parents=True)
            (main / ".git").mkdir()
            (sub / ".git").write_text(
                f"gitdir: {main / '.git' / 'modules' / 'internal'}",
                encoding="utf-8",
            )
            with patch("check_issue_claim.Path.cwd", return_value=sub):
                self.assertEqual(detect_workspace(), "roo-extensions")

    def test_detect_workspace_unparseable_gitfile_falls_through(self):
        with tempfile.TemporaryDirectory() as tmp:
            main = Path(tmp) / "roo-extensions"
            stray = main / "tools"
            stray.mkdir(parents=True)
            (main / ".git").mkdir()
            (stray / ".git").write_text("garbage", encoding="utf-8")
            with patch("check_issue_claim.Path.cwd", return_value=stray):
                self.assertEqual(detect_workspace(), "roo-extensions")

    def test_default_agent_composes_machine_and_workspace(self):
        with patch.dict(os.environ, {"COMPUTERNAME": "MYIA-WEB2"}):
            # workspace case-preserved : tel que passé/détecté
            self.assertEqual(default_agent("roo-extensions"), "myia-web2:roo-extensions")

    def test_default_agent_empty_workspace_degrades_to_machine(self):
        with patch.dict(os.environ, {"COMPUTERNAME": "MYIA-WEB2"}):
            self.assertEqual(default_agent(""), "myia-web2")

    def test_default_agent_none_off_fleet(self):
        with patch.dict(os.environ, {"COMPUTERNAME": "WIN-QM11U56L393"}):
            self.assertIsNone(default_agent("roo-extensions"))


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

    def test_workspace_flag_composes_agent_and_resumes_own_lane(self):
        # #4114 : sans --agent, l'identité se compose COMPUTERNAME + --workspace ;
        # le claim de SA propre lane est une reprise (exit 0), pas un blocage.
        issue = self._issue([
            comment("[CLAIMED] myia-web2:roo-extensions -- mine", T0)
        ])
        with patch.dict("os.environ", {"COMPUTERNAME": "MYIA-WEB2"}):
            with patch("check_issue_claim.fetch_issue", return_value=issue):
                with patch(
                    "check_issue_claim.now_utc",
                    return_value=T0 + timedelta(hours=1),
                ):
                    rc = main(
                        ["123", "--repo", DEFAULT_REPO, "--workspace", "roo-extensions"]
                    )
        self.assertEqual(rc, 0)

    def test_workspace_flag_same_machine_other_workspace_blocks(self):
        # Miroir : même machine, autre workspace -> claim étranger, exit 1.
        issue = self._issue([
            comment("[CLAIMED] myia-web2:CoursIA-2 -- other lane", T0)
        ])
        with patch.dict("os.environ", {"COMPUTERNAME": "MYIA-WEB2"}):
            with patch("check_issue_claim.fetch_issue", return_value=issue):
                with patch(
                    "check_issue_claim.now_utc",
                    return_value=T0 + timedelta(hours=1),
                ):
                    rc = main(
                        ["123", "--repo", DEFAULT_REPO, "--workspace", "roo-extensions"]
                    )
        self.assertEqual(rc, 1)


def gh_router(graphql, issue_state, comments):
    """Fake `_gh_exec` routing on the CALL SHAPE (#3899), unlike gh_stub which
    routes on the repo: the fallback fires several different gh invocations in
    one fetch, each with its own outcome.

    graphql     : (returncode, stdout, stderr) for `gh issue view --json ...`
    issue_state : outcome for `gh api repos/<repo>/issues/<n>`
    comments    : outcome for `gh api repos/<repo>/issues/<n>/comments`

    Records every call in `calls` so a test can prove the REST leg ran (or
    provably did NOT, for the non-quota error contract).
    """

    def _exec(args):
        _exec.calls.append(list(args))
        if args and args[0] == "issue":
            return graphql
        if any(a.endswith("/comments") for a in args):
            return comments
        return issue_state

    _exec.calls = []
    return _exec


GRAPHQL_LIMITED = (
    1,
    "",
    "gh: GraphQL: API rate limit exceeded (HTTP 403)",
)
GRAPHQL_SECONDARY_LIMITED = (
    1,
    "",
    "gh: You have exceeded a secondary rate limit "
    "and will be blocked from receiving content (HTTP 403)",
)
GRAPHQL_OTHER_ERROR = (1, "", "gh: connection reset by peer (HTTP 500)")


class TestFetchIssueRestFallback(unittest.TestCase):
    """#3899: REST fallback ONLY on an explicitly recognised quota error."""

    def _rest_ok(self, bodies=(), state="open"):  # real REST shape (#3909)
        lines = "".join(
            '{"createdAt":"%s","body":%s}\n'
            % (iso(T0 + timedelta(hours=i)), json.dumps(body))
            for i, body in enumerate(bodies)
        )
        return (0, '{"state":"%s"}' % state, ""), (0, lines, "")

    def test_rate_limit_falls_back_to_rest(self):
        state_out, comments_out = self._rest_ok(["[CLAIMED] myia-po-2025 -- on it"])
        stub = gh_router(GRAPHQL_LIMITED, state_out, comments_out)
        with patch("check_issue_claim._gh_exec", stub):
            issue = fetch_issue("123", DEFAULT_REPO)
        self.assertEqual(issue["state"], "OPEN")
        self.assertEqual(len(issue["comments"]), 1)
        self.assertEqual(issue["comments"][0]["body"], "[CLAIMED] myia-po-2025 -- on it")
        self.assertIn("createdAt", issue["comments"][0])  # GraphQL shape preserved
        # both REST legs actually ran
        self.assertTrue(any(a[0] == "api" for a in stub.calls))
        self.assertEqual(sum(1 for a in stub.calls if a and a[0] == "issue"), 1)

    def test_secondary_rate_limit_also_falls_back(self):
        state_out, comments_out = self._rest_ok([])
        stub = gh_router(GRAPHQL_SECONDARY_LIMITED, state_out, comments_out)
        with patch("check_issue_claim._gh_exec", stub):
            issue = fetch_issue("123", DEFAULT_REPO)
        self.assertEqual(issue["state"], "OPEN")
        self.assertEqual(issue["comments"], [])

    def test_non_quota_error_propagates_without_rest_calls(self):
        # A network/5xx error is NOT a quota condition: no second API is tried,
        # the failure surfaces as before (fail-closed, exit 2 upstream).
        stub = gh_router(GRAPHQL_OTHER_ERROR, (0, "{}", ""), (0, "", ""))
        with patch("check_issue_claim._gh_exec", stub):
            with self.assertRaises(RuntimeError):
                fetch_issue("123", DEFAULT_REPO)
        self.assertEqual(len(stub.calls), 1)  # GraphQL leg only, no REST leg

    def test_rest_also_limited_stays_fail_closed(self):
        stub = gh_router(GRAPHQL_LIMITED, (1, "", "gh: API rate limit exceeded (HTTP 403)"), (0, "", ""))
        with patch("check_issue_claim._gh_exec", stub):
            with self.assertRaises(RuntimeError):
                fetch_issue("123", DEFAULT_REPO)


class TestRestFallbackEndToEnd(unittest.TestCase):
    """main() must reach a MEASURED verdict through the REST leg."""

    def _run(self, bodies, state="open"):  # real REST shape (#3909)
        lines = "".join(
            '{"createdAt":"%s","body":%s}\n'
            % (iso(T0 + timedelta(hours=i)), json.dumps(body))
            for i, body in enumerate(bodies)
        )
        stub = gh_router(
            GRAPHQL_LIMITED,
            (0, '{"state":"%s"}' % state, ""),
            (0, lines, ""),
        )
        with patch("check_issue_claim._gh_exec", stub):
            with patch(
                "check_issue_claim.now_utc", return_value=T0 + timedelta(hours=1)
            ):
                rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        return rc

    def test_blocked_via_rest_data(self):
        rc = self._run(["[CLAIMED] myia-po-2025 -- on it"])
        self.assertEqual(rc, 1)

    def test_clear_via_rest_data(self):
        rc = self._run([])
        self.assertEqual(rc, 0)


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

    def test_non_404_mentioning_not_found_is_not_absent(self):
        # Regression : la regex matchait la PROSE en insensible a la casse, donc
        # n'importe quel message contenant "not found" -- y compris celui que ce
        # module produit lui-meme quand gh n'est pas lancable -- passait pour un
        # 404. Le code HTTP seul fait foi.
        self.assertEqual(
            self._kind((1, "", "gh: repository index not found (HTTP 500)")), "error"
        )

    def test_404_is_recognised_by_status_code_only(self):
        self.assertEqual(self._kind((1, "", "gh: quelque chose (HTTP 404)")), "absent")


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


class TestUnrunnableGh(unittest.TestCase):
    """An environment failure must never borrow a measured verdict's exit code.

    `gh` absent from PATH used to raise OSError out of _gh_exec: traceback, and
    exit 1 -- which this tool's contract defines as "another machine holds the
    claim". A cron worker would read a broken PATH as a concurrent lock.
    """

    def test_classify_number_reports_error_not_absent(self):
        with patch("check_issue_claim.subprocess.run", side_effect=OSError(2, "not found")):
            self.assertEqual(classify_number("123", DEFAULT_REPO), "error")

    def test_resolution_path_exits_2(self):
        with patch("check_issue_claim.subprocess.run", side_effect=OSError(2, "not found")):
            self.assertEqual(main(["123", "--agent", "myia-po-2026"]), 2)

    def test_explicit_repo_path_also_exits_2(self):
        with patch("check_issue_claim.subprocess.run", side_effect=OSError(2, "not found")):
            rc = main(["123", "--repo", DEFAULT_REPO, "--agent", "myia-po-2026"])
        self.assertEqual(rc, 2)


class TestMainRepoResolution(unittest.TestCase):
    """main() must surface resolve_repo's exit code, not a fixed one."""

    def test_mutation_under_auto_repo_says_which_ticket_it_targets(self):
        stub = gh_stub({DEFAULT_REPO: OK_PR, SUBMODULE_REPO: OK_ISSUE})
        err = io.StringIO()
        with patch("check_issue_claim._gh_exec", stub):
            with patch("check_issue_claim.post_comment") as post:
                with contextlib.redirect_stderr(err):
                    rc = main(["980", "--claim", "on it", "--agent", "myia-po-2026"])
        self.assertEqual(rc, 0)
        self.assertIn("this MUTATION targets", err.getvalue())
        self.assertIn(SUBMODULE_REPO, err.getvalue())
        self.assertEqual(post.call_args.args[1], SUBMODULE_REPO)

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
