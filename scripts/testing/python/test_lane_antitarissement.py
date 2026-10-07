#!/usr/bin/env python3
"""Tests unitaires des scripts anti-tarissement (#3675, ADR 016, rework #4103).

Couvre les exigences des reviews PR #3681 et le rework #4103 :
  - fail-closed : panne gh (exit non-nul, timeout, JSON invalide — collecte OU
    verification de claim) => verdict ERROR exit 2, jamais un verdict de fond
    (IDLE_REAL / PASS / grain libre) ;
  - encodage : subprocess.run appele avec encoding="utf-8" errors="replace"
    (fix crash cp1252 Windows sur titres accentues, po-2027 16/09) ;
  - filtre machine par flag : SUPPRIME (ADR 016), argparse doit rejeter ;
  - verdicts : IDLE_REAL / PICK / ALL_CLAIMED / PASS / FAIL, exit codes associes ;
  - le compteur backlog ne mesure que l'urne grain (approved/bug/investigation) ;
  - #4103 : graine par lane et creneau (sha256, jamais hash()), liste ordonnee
    sans remise, saut des claims etrangers (reutilise check_issue_claim) et des
    etiquettes de lane myia-*, elargissement ALL_CLAIMED, unlabelled_open.

Stdlib uniquement (unittest + mock) — invoque par
scripts/testing/unit/lane-antitarissement.Tests.ps1 (job CI unit-pester).
"""
import hashlib
import io
import json
import os
import random
import subprocess
import sys
import unittest
from contextlib import contextmanager, redirect_stdout
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
    """Fake subprocess.CompletedProcess avec stdout JSON valide (test_cycle_end)."""
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


# --- fixtures REST du picker (#4103 : une collecte par depot) -----------------


def rest_page(items):
    """Fake `gh api --paginate --jq '.[]'` : un objet JSON compact par ligne."""
    return SimpleNamespace(
        stdout="\n".join(json.dumps(i) for i in items), stderr="", returncode=0
    )


def rest_issue(number, labels, title="issue"):
    """Item REST brut (snake_case) tel que repos/{repo}/issues le sert."""
    return {
        "number": number,
        "title": title,
        "labels": [{"name": l} for l in labels],
        "assignees": [],
        "created_at": "2026-09-01T00:00:00Z",
        "updated_at": "2026-09-15T00:00:00Z",
    }


def rest_pr(number, title="pr", labels=()):
    """Item REST brut d'une PR : la cle `pull_request` la distingue d'une issue."""
    return {**rest_issue(number, list(labels), title),
            "pull_request": {"url": f"https://api.github.com/repos/x/pulls/{number}"}}


def claim_comment(machine, hours=1.0):
    """Commentaire [CLAIMED] horodate serveur, age de `hours` heures."""
    return {
        "createdAt": (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat(),
        "body": f"[CLAIMED] {machine} -- work in progress",
    }


NO_CLAIM = {"state": "OPEN", "comments": []}


@contextmanager
def no_claims():
    """Aucun claim actif sur les candidats parcourus (fetch issue borde)."""
    with mock.patch.object(
        picker.check_issue_claim, "fetch_issue", return_value=NO_CLAIM
    ):
        yield


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
        code, out = self._run_with(
            [SimpleNamespace(stdout="gh: not json", stderr="", returncode=0)] * 2
        )
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")

    def test_partial_repo_failure_is_error_not_idle(self):
        # R1 collecte OK, R2 en panne => aucun verdict de fond (fail-closed
        # sur panne PARTIELLE : le pool n'est pas declare vide).
        seq = [
            rest_page([rest_issue(1, ["approved"])]),  # R1
            subprocess.CalledProcessError(128, ["gh"], stderr="network"),  # R2
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")

    def test_claim_check_failure_is_error_not_free(self):
        # #4103 : un claim ILLISIBLE est une panne d'instrument, jamais un
        # grain libre - sinon le picker recommanderait une collision certaine.
        seq = [rest_page([rest_issue(31, ["approved"])]), rest_page([])]

        def boom(number, repo):
            raise RuntimeError("gh issue view failed (exit 1): rate limit")

        with mock.patch("subprocess.run", side_effect=seq), \
                mock.patch.object(picker.check_issue_claim, "fetch_issue", side_effect=boom):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out)["verdict"], "ERROR")


class PickerVerdicts(unittest.TestCase):
    """Collecte reussie : verdicts de fond uniquement."""

    def test_empty_success_yields_idle_real_exit0(self):
        with mock.patch("subprocess.run", side_effect=[rest_page([])] * 2):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")
        self.assertEqual(data["grain"], 0)

    def test_unlabelled_open_counts_open_issues_without_urn_label(self):
        # #4103 : le trou du pool rendu visible. Une issue `harness` (pas un
        # label d'urne), non gatee, non epic -> comptee. Une issue gatee ne
        # gonfle pas le compteur ; une PR n'est pas une issue ouverte.
        page = [
            rest_issue(1, ["harness"]),
            rest_issue(2, ["needs-approval"]),
            rest_issue(3, ["approved"]),
            rest_pr(9, "fix"),
        ]
        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), no_claims():
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["unlabelled_open"], 1)

    def test_grain_pick_with_accented_title(self):
        # Titre UTF-8 accentue + fleche : doit traverser sans crash et
        # ressortir intact dans le JSON (classe de defaut cp1252).
        title = "Issue périmée → corriger le pool"
        seq = [rest_page([rest_issue(42, ["approved"], title)]), rest_page([])]
        with mock.patch("subprocess.run", side_effect=seq), no_claims():
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["urn"], "grain")
        self.assertEqual(data["pick"]["title"], title)

    def test_epic_label_goes_to_umbrella_not_grain(self):
        seq = [rest_page([rest_issue(7, ["epic"])]), rest_page([])]
        with mock.patch("subprocess.run", side_effect=seq), no_claims():
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["grain"], 0)
        self.assertEqual(data["umbrella"], 1)
        self.assertEqual(data["urn"], "umbrella")

    def test_needs_approval_is_in_no_urn(self):
        seq = [rest_page([rest_issue(9, ["needs-approval"])]), rest_page([])]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")

    def test_frozen_is_in_no_urn_even_with_a_grain_label(self):
        # #3381 : `frozen` gele l'issue par decision ; un label actionnable
        # porte en meme temps ne doit pas la remettre dans l'urne grain.
        seq = [rest_page([rest_issue(11, ["approved", "frozen"]),
                          rest_issue(12, ["epic", "frozen"])]), rest_page([])]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")

    def test_gated_labels_are_in_no_urn_even_with_a_grain_label(self):
        # Mesure 03/10 (po-204) : #4038 (bug + needs-approval) a ete pickee
        # au 1er tirage alors que le contrat du module met les labels
        # d'attente hors de toute urne. Le cas label-seul etait couvert ;
        # la CO-OCCURRENCE ne l'etait pas (symetrique du cas frozen).
        seq = [rest_page([
            rest_issue(21, ["bug", "needs-approval"]),
            rest_issue(22, ["investigation", "deferred"]),
            rest_issue(23, ["approved", "blocked-on-gate"]),
            rest_issue(24, ["epic", "needs-approval"]),
        ]), rest_page([])]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "IDLE_REAL")

    def test_pick_reports_which_repo_it_came_from(self):
        # Mesure po-2026 03/10 ([FRICTION] c.72) : #608 existe dans les DEUX
        # depots avec des contenus differents - un pick sans champ repo envoie
        # l'agent faire son grounding sur la mauvaise issue (reflexe gh issue
        # view sur le depot parent).
        seq = [rest_page([]),
               rest_page([rest_issue(608, ["bug"], "fix(infrastructure): Move qdrant-snapshots")])]
        with mock.patch("subprocess.run", side_effect=seq), no_claims():
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["urn"], "grain")
        self.assertEqual(data["pick"]["repo"], "jsboige/jsboige-mcp-servers")
        self.assertEqual(data["pick"]["number"], 608)

    def test_delivered_pick_carries_repo_too(self):
        # Miroir du cas grain pour l'urne delivered : les PRs submod vivent
        # dans le depot fils - un pick delivered sans champ repo envoie
        # l'agent reviewer la PR au mauvais depot (suite #4047, snippet
        # promis en review par web2). #4103 : la PR arrive dans la MEME
        # reponse REST (cle `pull_request`), pas d'appel pr list.
        seq = [rest_page([]), rest_page([rest_pr(77, "fix(server): condensation guard")])]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["urn"], "delivered")
        self.assertEqual(data["pick"]["repo"], "jsboige/jsboige-mcp-servers")
        self.assertEqual(data["pick"]["number"], 77)

    def test_subprocess_utf8_replacement_kwargs(self):
        # Fix bloquant 1 (po-2027) : sans encoding="utf-8" errors="replace",
        # text=True decode stdout en cp1252 sous Windows => UnicodeDecodeError
        # sur tout titre accentue. Le fix vit dans les kwargs de l'appel.
        with mock.patch("subprocess.run", side_effect=[rest_page([])] * 2) as run:
            run_main(picker, ["--json"])
        self.assertGreaterEqual(len(run.call_args_list), 2)
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
        # Ordre des appels gh de test_cycle_end : issues r1/r2, PR-listes r1/r2
        # (#3381 D3 : approved-sans-PR), puis delivered (opened/merged par repo).
        return [
            ok_result(issues_r1), ok_result(issues_r2),
            ok_result([]), ok_result([]),
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

    def test_backlog_skips_gated_or_frozen_issues_carrying_a_grain_label(self):
        # Co-occurrence (mesure 03/10, #4038) : un label d'attente ou de gel
        # porte AVEC un label actionnable ne doit ni gonfler le backlog ni
        # contredire le picker (ADR 016) - sinon le test presse la lane vers
        # des grains non actionnables. frozen inclus : parite #3381/#3809.
        gated = [issue(3, ["bug", "needs-approval"]),
                 issue(4, ["investigation", "deferred"]),
                 issue(5, ["approved", "blocked-on-gate"]),
                 issue(6, ["approved", "frozen"])]
        with mock.patch("subprocess.run",
                        side_effect=self._seq(gated, [],
                                              ([], []), ([], []))):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["backlog_grain"], 0)
        self.assertEqual(data["verdict"], "PASS")

    def test_approved_no_pr_word_boundary_coverage(self):
        # #3381 D3 : couverture = frontiere de mot sur le numero dans le titre
        # de la PR. "#71" ne couvre PAS l'issue 7 (mesure 05/09 : le flou
        # --search GitHub, ici remplace par un scan regex local des titres).
        now = datetime.now(timezone.utc)
        merged_pr = {"number": 5, "mergedAt": now.isoformat()}

        def pr(n, title):
            return {"number": n, "title": title}

        seq = [
            ok_result([issue(7, ["approved"]), issue(8, ["approved"])]),
            ok_result([]),
            # PR-listes r1/r2 : "#8 fix" couvre 8 ; "#71" ne couvre PAS 7.
            ok_result([pr(101, "fix(#8): covered"), pr(102, "ref #71 for other")]),
            ok_result([]),
            ok_result([]), ok_result([merged_pr]),   # delivered r1
            ok_result([]), ok_result([]),            # delivered r2
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PASS")
        nos = [(i["repo"], i["number"]) for i in data["approved_no_pr"]]
        self.assertIn(("jsboige/roo-extensions", 7), nos)
        self.assertNotIn(("jsboige/roo-extensions", 8), nos)

    def test_approved_no_pr_gated_excluded(self):
        # Une approved portant un label de gel ne doit pas apparaitre dans la
        # vue D3 (meme filtre que le backlog).
        gated_and_clean = [issue(3, ["approved", "needs-approval"]),
                           issue(9, ["approved"])]
        now = datetime.now(timezone.utc)
        merged_pr = {"number": 5, "mergedAt": now.isoformat()}
        seq = [
            ok_result(gated_and_clean), ok_result([]),
            ok_result([]), ok_result([]),
            ok_result([]), ok_result([merged_pr]),
            ok_result([]), ok_result([]),
        ]
        with mock.patch("subprocess.run", side_effect=seq):
            code, out = run_main(tce, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["backlog_grain"], 1)
        self.assertEqual([i["number"] for i in data["approved_no_pr"]], [9])


class GatedLabelDriftGuard(unittest.TestCase):
    """Dispatch c2300 item 3 (po-204) : la liste des labels bloquants vit a
    4 endroits (picker, garde worker, requete Zoo, test_cycle_end). Le picker
    retire un grain gated du vivier ; le worker autonome ne doit JAMAIS
    pouvoir prendre ce que le picker a ecarte — sinon la porte que le label
    pose est tenue d'un cote et ouverte de l'autre. Chaque label exclu par
    le picker (GATED | FROZEN) doit donc etre exclu par
    start-claude-worker.ps1 : requete serveur `-label:X` OU garde aval
    `$LabelNames -contains "X"`."""

    def _worker_covers(self, label, worker_src):
        server_side = f"-label:{label}" in worker_src
        guard_side = f'$LabelNames -contains "{label}"' in worker_src
        return server_side or guard_side

    def test_every_picker_excluded_label_is_excluded_by_the_worker(self):
        worker_path = SCHEDULING_DIR / "start-claude-worker.ps1"
        worker_src = worker_path.read_text(encoding="utf-8")
        excluded = picker.GATED_LABELS | picker.FROZEN_LABELS
        # Un ensemble vide rendrait le garde muet (toujours vert) : l'assert
        # echoue plutot que de certifier une couverture vide.
        self.assertTrue(excluded, "GATED|FROZEN vides : le garde ne testerait rien")
        uncovered = sorted(
            lbl for lbl in excluded if not self._worker_covers(lbl, worker_src)
        )
        self.assertEqual(
            uncovered, [],
            f"labels exclus par le picker mais prenables par le worker: {uncovered}",
        )


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


class PickerConsoleEncoding(unittest.TestCase):
    """Sortie texte sur console Windows cp1252 (mesure web2 04/10, cycle c.24).

    #3675/#3681 a corrige la LECTURE de stdout gh (decodage UTF-8
    errors='replace'). L'ECRITURE du mode texte restait sur l'encodage de la
    console : un titre portant '→' (U+2192, absent de cp1252) tuait le
    -dry-run, precisement le mode qui sert a choisir quand le tirage rend un
    candidat deja pris (mesure du cycle : deux candidats ecartes d'affilee
    sans pouvoir lire la liste des autres).
    """

    def _cp1252_console(self):
        """Vraie console cp1252 stricte (pas un mock) : BytesIO + TextIOWrapper."""
        raw = io.BytesIO()
        return raw, io.TextIOWrapper(raw, encoding="cp1252", errors="strict")

    def test_dry_run_text_output_survives_cp1252_console(self):
        title = "Stack audio OWUI : 2e panne post-reboot → restart-policy"
        seq = [rest_page([rest_issue(3896, ["bug"], title)]), rest_page([])]
        raw, console = self._cp1252_console()
        # Pas de redirect_stdout ici : il masquerait l'encodage reel derriere
        # un StringIO, qui accepte tout et rendrait le test faussement vert.
        with mock.patch("subprocess.run", side_effect=seq), no_claims(), \
                mock.patch.object(sys, "argv", ["prog", "--dry-run"]), \
                mock.patch.object(sys, "stdout", console):
            code = picker.main()
            console.flush()
        self.assertEqual(code, 0)
        self.assertIn("3896", raw.getvalue().decode("cp1252", "replace"))


class CandidateSkipRules(unittest.TestCase):
    """#4103 : la lane parcourt la liste ordonnee jusqu'au premier grain libre.

    Claims etrangers actifs (ADR 017, reutilises via check_issue_claim) et
    etiquettes de lane myia-* ecartent un candidat ; la liste rend la raison.
    """

    def test_foreign_claim_is_skipped_and_next_candidate_returned(self):
        # Fixture sans reseau : 51 claimed par myia-po-2025 (1 h, actif),
        # 52 libre -> pick = 52 quelle que soit l'ordre du tirage, et l'entree
        # de 51 porte la raison des qu'elle est parcourue.
        page = [rest_issue(51, ["approved"]), rest_issue(52, ["approved"])]
        claimed = {"state": "OPEN", "comments": [claim_comment("myia-po-2025", hours=1.0)]}

        def fetch(number, repo):
            return claimed if int(number) == 51 else NO_CLAIM

        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                mock.patch.object(picker.check_issue_claim, "fetch_issue", side_effect=fetch), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}):
            code, out = run_main(picker, ["--json", "--top", "2", "--seed", "7"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["pick"]["number"], 52)
        c51 = next(c for c in data["candidates"] if c["number"] == 51)
        self.assertTrue(c51["skipped"])
        self.assertIn("myia-po-2025", c51["reason"])

    def test_stale_claim_does_not_skip(self):
        # > 24 h : STALE au sens du guard (ADR 017), pas bloquant - le nouveau
        # claimant pose son propre [CLAIMED], il ne doit pas etre prive du grain.
        page = [rest_issue(53, ["approved"])]
        stale = {"state": "OPEN", "comments": [claim_comment("myia-po-2025", hours=30.0)]}
        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                mock.patch.object(picker.check_issue_claim, "fetch_issue", return_value=stale), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}):
            code, out = run_main(picker, ["--json", "--seed", "3"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertFalse(data["candidates"][0]["skipped"])

    def test_machine_labelled_issue_is_skipped(self):
        # Etiquette de lane etrangere : ecarte SANS lecture de claim (donnee
        # locale, pas d'appel API). 62 est l'unique grain libre -> pick = 62.
        page = [rest_issue(61, ["approved", "myia-po-2026"]), rest_issue(62, ["approved"])]

        def fetch(number, repo):
            # 62 (libre, sans etiquette de lane) a droit a sa lecture de claim ;
            # 61 doit etre ecarte AVANT toute lecture.
            self.assertNotEqual(number, "61", "61 doit etre ecarte sans lecture de claim")
            return NO_CLAIM

        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                mock.patch.object(picker.check_issue_claim, "fetch_issue", side_effect=fetch), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}):
            # seed 1 verifie deterministiquement que 61 est PARCOURU avant 62 :
            # l'ecart doit se produire, pas seulement etre possible.
            code, out = run_main(picker, ["--json", "--top", "2", "--seed", "1"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["pick"]["number"], 62)
        c61 = next(c for c in data["candidates"] if c["number"] == 61)
        self.assertTrue(c61["skipped"])
        self.assertIn("myia-po-2026", c61["reason"])

    def test_all_claimed_verdict_when_pool_fully_taken(self):
        # Les K candidats pris -> elargissement au pool entier dans l'ordre du
        # tirage ; rien de libre -> ALL_CLAIMED exit 0 (ni IDLE_REAL ni ERROR),
        # chaque ecart rendu avec sa raison. --top 1 force l'elargissement.
        page = [rest_issue(71, ["approved"]), rest_issue(72, ["approved"])]
        claimed = {"state": "OPEN", "comments": [claim_comment("myia-po-2024", hours=2.0)]}
        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                mock.patch.object(picker.check_issue_claim, "fetch_issue", return_value=claimed), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}):
            code, out = run_main(picker, ["--json", "--top", "1", "--seed", "5"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "ALL_CLAIMED")
        self.assertIsNone(data["pick"])
        self.assertEqual(len(data["candidates"]), 2)
        self.assertTrue(all(c["skipped"] for c in data["candidates"]))
        self.assertTrue(all("claim" in (c["reason"] or "") for c in data["candidates"]))

    def test_delivered_pr_is_never_skipped_by_machine_label(self):
        # Urne delivered : pas de verrou ni d'etiquette de lane ecartee (ADR
        # 016) - la review cross-lane EST le but de cette urne. Une PR portant
        # l'etiquette d'une autre lane reste prenable.
        page = [rest_pr(91, "fix(#x): lane po-2026 work", labels=["myia-po-2026"])]
        with mock.patch("subprocess.run", side_effect=[rest_page([]), rest_page(page)]), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}):
            code, out = run_main(picker, ["--json", "--seed", "13"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["verdict"], "PICK")
        self.assertEqual(data["urn"], "delivered")
        self.assertFalse(data["candidates"][0]["skipped"])

    def test_same_machine_other_workspace_claim_skips(self):
        # AC #4114 : le claim de l'AUTRE workspace de SA machine ecarte le
        # grain -- le picker classifie sur l'identite LANE, pas la machine.
        item = picker.normalize_rest_item(rest_issue(63, ["approved"]), REPOS[0])
        claimed = {"state": "OPEN",
                   "comments": [claim_comment("myia-po-2027:CoursIA-2", hours=1.0)]}
        with mock.patch.object(picker.check_issue_claim, "fetch_issue", return_value=claimed):
            skip, reason = picker.check_candidate(
                "grain", item, "myia-po-2027", "myia-po-2027:roo-extensions"
            )
        self.assertTrue(skip)
        self.assertIn("myia-po-2027:CoursIA-2", reason)

    def test_own_lane_claim_same_workspace_is_resumable(self):
        # Miroir : le claim de SA lane (meme machine, meme workspace) n'ecarte
        # pas le grain -- reprise, pas collision.
        item = picker.normalize_rest_item(rest_issue(64, ["approved"]), REPOS[0])
        claimed = {"state": "OPEN",
                   "comments": [claim_comment("myia-po-2027:roo-extensions", hours=1.0)]}
        with mock.patch.object(picker.check_issue_claim, "fetch_issue", return_value=claimed):
            skip, _reason = picker.check_candidate(
                "grain", item, "myia-po-2027", "myia-po-2027:roo-extensions"
            )
        self.assertFalse(skip)

    def test_own_lane_id_composes_machine_and_workspace(self):
        # #4114 : l'identite de lecture de claims est la lane, workspace par
        # walk-up toplevel ; degrade en machine seule hors depot.
        with mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}), \
                mock.patch.object(picker.check_issue_claim, "detect_workspace",
                                  return_value="roo-extensions"):
            self.assertEqual(picker.own_lane_id(), "myia-po-2027:roo-extensions")
        with mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}), \
                mock.patch.object(picker.check_issue_claim, "detect_workspace",
                                  return_value=""):
            self.assertEqual(picker.own_lane_id(), "myia-po-2027")


class LaneSeedDivergence(unittest.TestCase):
    """#4103 : deux machines tirent des listes differentes sur le meme pool."""

    @classmethod
    def setUpClass(cls):
        items = [picker.normalize_rest_item(rest_issue(n, ["approved"]), "jsboige/roo-extensions")
                 for n in (101, 102, 103, 104)]
        items.append(picker.normalize_rest_item(rest_issue(201, ["epic"]), "jsboige/roo-extensions"))
        items.append(picker.normalize_rest_item(rest_pr(301, "fix"), "jsboige/roo-extensions"))
        cls.buckets, _unlabelled, _total = picker.bucketize_items(items)

    def test_derive_seed_is_stable_sha256_not_hash(self):
        # Precisation analyst #4103 : le condense doit etre la formule sha256
        # documentee (stable d'un processus a l'autre), JAMAIS hash() - le
        # hash Python d'une chaine est sale par processus (PYTHONHASHSEED).
        digest = hashlib.sha256(b"myia-po-2027").digest()
        expected = int.from_bytes(digest[:8], "big") ^ 512034
        self.assertEqual(picker.derive_seed("myia-po-2027", 512034), expected)
        self.assertNotEqual(
            picker.derive_seed("myia-po-2025", 100),
            picker.derive_seed("myia-po-2026", 100),
        )

    def test_two_machines_diverge_over_slots(self):
        # AC #4103 : sur un pool fixe, deux machines donnent des premiers
        # tirages differents au moins une fois sur un echantillon >= 20
        # creneaux. Deterministe : seeds fixes (sha256 + slot), rng fixe.
        diverged = False
        for slot in range(5000, 5024):
            picks = {}
            for machine in ("myia-po-2025", "myia-po-2026"):
                rng = random.Random(picker.derive_seed(machine, slot))
                order = picker.draw_candidates(self.buckets, picker.DEFAULT_WEIGHTS, rng, 1)
                picks[machine] = order[0][1]["number"]
            if picks["myia-po-2025"] != picks["myia-po-2026"]:
                diverged = True
                break
        self.assertTrue(diverged, "deux lanes n'ont jamais diverge sur 24 creneaux")

    def test_json_output_carries_seed_and_slot(self):
        # Tracabilite #4103 : la sortie rend la graine effective et le creneau
        # pour rejouer un tirage a partir des logs.
        page = [rest_issue(81, ["approved"])]
        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                no_claims(), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}), \
                mock.patch.object(picker, "current_slot", return_value=424242):
            code, out = run_main(picker, ["--json"])
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertEqual(data["machine"], "myia-po-2027")
        self.assertEqual(data["slot"], 424242)
        self.assertEqual(data["seed"], picker.derive_seed("myia-po-2027", 424242))

    def test_explicit_seed_overrides_derivation(self):
        # Reproductibilite : --seed N court-circuite machine+creneau (tests).
        page = [rest_issue(82, ["approved"])]
        with mock.patch("subprocess.run", side_effect=[rest_page(page), rest_page([])]), \
                no_claims(), \
                mock.patch.dict(os.environ, {"COMPUTERNAME": "MYIA-PO-2027"}), \
                mock.patch.object(picker, "current_slot", return_value=424242):
            code, out = run_main(picker, ["--json", "--seed", "99"])
        data = json.loads(out)
        self.assertEqual(data["seed"], 99)


if __name__ == "__main__":
    unittest.main()
