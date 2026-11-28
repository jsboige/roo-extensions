#!/usr/bin/env python3
"""Unit tests for refresh-vibe-queue.py multi-contract extension (#16472, GO ai-01 17/09).

Covers the pure pieces: hierarchy census parsing, [CLAIMED...] path
extraction (the pre-PR deconfliction gap measured on #16472 fournée 1),
family-level grouping for contract 16472, and payload sanity per contract.
"""

import importlib.util
import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

_SPEC = importlib.util.spec_from_file_location(
    "refresh_vibe_queue",
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "..", "..", "scheduling", "refresh-vibe-queue.py"))
rvq = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(rvq)


CENSUS = (
    "\r\n"
    "## MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb\r\n"
    "  [HINT-AS-HEADING] cell 34  L4  Pistes p\xe9dagogiques\r\n"
    "  [HINT-AS-HEADING] cell 51  L2  Astuce\r\n"
    "\r\n"
    "## MyIA.AI.Notebooks/GenAI/Audio/02-Advanced/02-1-Chatterbox-TTS.ipynb\r\n"
    "  [HEADING-IN-LIST] cell 7  L1  # Indice : cout\r\n"
    "\r\n"
    "## MyIA.AI.Notebooks/GenAI/Audio/02-Advanced/clean.ipynb\r\n"
    "\r\n"
    "=== 2/3 notebooks flagged ===\r\n"
)

#: Familles H1 du scanner : hors contrat #16472. Codes a CHIFFRE — c'est
#: precisement ce que la regex historique [A-Z-]+ avalait en silence (6
#: notebooks flagges sans ligne resolue, mesure 18/09 sur 95 flagges).
#: WHATEVER-XYZ : code tout-alpha inconnu — l'ANCIENNE regex l'aurait pris
#: pour un finding contrat (silence sur un code non contracte) ; le pin le
#: rejette : c'est la difference de comportement que ce test doit pincer.
CENSUS_H1 = (
    "## MyIA.AI.Notebooks/GenAI/Audio/02-Advanced/06-1-AudioLDM.ipynb\r\n"
    "  [MULTI-H1] cell 0  L1  6 H1 across cells [0, 27, 27, 27, 27, 27]\r\n"
    "  [H1-DEEP] cell 27  L1  Indice : r\xe9utilisez timed_generate\r\n"
    "\r\n"
    "## MyIA.AI.Notebooks/GenAI/Audio/03-Future/unknown-code.ipynb\r\n"
    "  [WHATEVER-XYZ] cell 3  L1  future detector kind\r\n"
    "\r\n"
    "## MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb\r\n"
    "  [HINT-AS-HEADING] cell 12  L2  Astuce\r\n"
    "  [H1-DEEP] cell 20  L1  Note p\xe9dagogique\r\n"
)


class TestGrainNameReservations(unittest.TestCase):
    def test_existing_worktree_and_reserved_names_are_not_reused(self):
        with tempfile.TemporaryDirectory() as root:
            os.mkdir(os.path.join(root, 'g1-audio'))
            gid, branch, wt = rvq.available_grain_name(
                1, 'audio', 'wt/vibe-', root,
                {'g1-audio-2'}, {'wt/vibe-g1-audio-3'})
            self.assertEqual(gid, 'g1-audio-4')
            self.assertEqual(branch, 'wt/vibe-g1-audio-4')
            self.assertEqual(wt, root.rstrip('/') + '/g1-audio-4')

    def test_free_name_is_unchanged(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(rvq.available_grain_name(1, 'audio', 'wt/vibe-', root, set(), set())[0],
                             'g1-audio')


class TestHierarchyCensus(unittest.TestCase):
    def test_parses_findings_with_crlf_and_skips_unflagged(self):
        found = rvq.parse_hierarchy_census(CENSUS)
        self.assertEqual(
            sorted(found),
            ["MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb",
             "MyIA.AI.Notebooks/GenAI/Audio/02-Advanced/02-1-Chatterbox-TTS.ipynb"])
        self.assertEqual(len(found["MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb"]), 2)
        self.assertIn("[HEADING-IN-LIST] cell 7",
                      found["MyIA.AI.Notebooks/GenAI/Audio/02-Advanced/02-1-Chatterbox-TTS.ipynb"][0])

    def test_summary_line_and_blanks_are_not_findings(self):
        found = rvq.parse_hierarchy_census("=== 0/3 notebooks flagged ===\r\n")
        self.assertEqual(found, {})

    def test_h1_family_findings_are_excluded_not_swallowed(self):
        """Le pin census (18/09) : MULTI-H1/H1-DEEP hors contrat #16472.

        Un notebook H1-only reste hors file (hygiene mecanique) ; un notebook
        mixte garde SES findings contrat. Avant le pin, la regex [A-Z-]+
        droppait ces lignes SANS les distinguer des vraies pertes.
        """
        found = rvq.parse_hierarchy_census(CENSUS_H1)
        self.assertEqual(sorted(found),
                         ["MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb"])
        self.assertEqual(found["MyIA.AI.Notebooks/GenAI/Audio/01-Foundation/01-4-Whisper-Local.ipynb"],
                         ["[HINT-AS-HEADING] cell 12 L2 Astuce"])
        # le tally des exclusions VOIT les codes a chiffre, la regex contrat non
        self.assertTrue(rvq.HIERARCHY_ANY_FINDING.match("  [MULTI-H1] cell 0  L1  x"))
        self.assertFalse(rvq.HIERARCHY_FINDING.match("  [MULTI-H1] cell 0  L1  x"))


class TestClaimedPaths(unittest.TestCase):
    def test_extracts_ipynb_tokens_with_trailing_period(self):
        body = ("[CLAIMED-AMEND] lane myia-po-2027:CoursIA-2 -- paths: "
                "MyIA.AI.Notebooks/GenAI/Image/01-Foundation/01-2-GPT-5-Image-Generation.ipynb, "
                "MyIA.AI.Notebooks/GenAI/Image/04-Applications/04-3-Production-Integration.ipynb.")
        self.assertEqual(
            rvq.claimed_paths([body]),
            {"MyIA.AI.Notebooks/GenAI/Image/01-Foundation/01-2-GPT-5-Image-Generation.ipynb",
             "MyIA.AI.Notebooks/GenAI/Image/04-Applications/04-3-Production-Integration.ipynb"})

    def test_ignores_comments_without_claim_or_paths(self):
        self.assertEqual(rvq.claimed_paths(["[DISPATCH] fourn\xe9e 1, aucun chemin list\xe9"]), set())
        self.assertEqual(rvq.claimed_paths(["paths: MyIA.AI.Notebooks/x.ipynb sans CLAIMED"]), set())
        self.assertEqual(rvq.claimed_paths([]), set())


class TestPlanGrouping(unittest.TestCase):
    FREE = {
        "MyIA.AI.Notebooks/GenAI/Audio/a.ipynb": ["f1"],
        "MyIA.AI.Notebooks/GenAI/Audio/b.ipynb": ["f2"],
        "MyIA.AI.Notebooks/GenAI/Image/c.ipynb": ["f3"],
    }

    def test_contract_16472_groups_by_family_index_2(self):
        bins = rvq.plan(self.FREE, group_idx=2)
        names = sorted(n for n, _ in bins)
        # 1 finding per family < FLOOR -> pockets -> residu non livrable hors file
        self.assertEqual(names, [])
        # group_idx=1 (contrat 15719) : un seul domaine GenAI, meme sort.

    def test_family_bins_reach_floor_together(self):
        free = {p: ["f%d" % i for i in range(6)] for p in self.FREE}
        bins = rvq.plan(free, group_idx=2)
        # Audio (12 findings) conforme ; Image (6 < FLOOR) se VERSE dans Audio
        # (même domaine GenAI, mécanisme #15719) au lieu de rester résidu.
        self.assertEqual([n for n, _ in bins], ["Audio"])
        poured = dict(bins[0][1])
        self.assertIn("MyIA.AI.Notebooks/GenAI/Image/c.ipynb", poured)

    def test_notebook_directly_under_domain_falls_back_to_domain_family(self):
        free = {
            "MyIA.AI.Notebooks/GameTheory/GameTheory-04b-Lean-NashExistence.ipynb":
                ["f%d" % i for i in range(12)],
        }
        bins = rvq.plan(free, group_idx=2)
        # parts[2] = le nom de fichier : le fallback regroupe sous le domaine
        self.assertEqual([n for n, _ in bins], ["GameTheory"])

    def test_density_contract_sizes_grains_of_one_to_two_notebooks(self):
        """"#13410 : unite = notebook, regle de taille propre (dispatch ai-01
        18/09) — grain 1-2 notebooks, jamais le moule findings FLOOR=10."""
        free = {
            "MyIA.AI.Notebooks/GenAI/Audio/a.ipynb": ["density=900/1200"],
            "MyIA.AI.Notebooks/GenAI/Audio/b.ipynb": ["density=800/1200"],
            "MyIA.AI.Notebooks/GenAI/Audio/c.ipynb": ["density=700/1200"],
            "MyIA.AI.Notebooks/QuantConnect/q.ipynb": ["density=600/1200"],
        }
        bins = rvq.plan(free, group_idx=1, floor=1, max_files=2)
        served = [p for _, ch in bins for p in ch]
        self.assertEqual(sorted(served), sorted(free))  # aucun residu perdu
        for _, ch in bins:
            self.assertGreaterEqual(len(ch), 1)
            self.assertLessEqual(len(ch), 2, "grain densite > 2 notebooks")


class TestPlanFamine(unittest.TestCase):
    """`--famine` (mandat vibe-burn, 16/10) : en famine prouvee, le residu
    sous plancher qui tient dans max_files devient du carburant voie legere
    (FAMINE_BIN) au lieu d'un WARN hors file. Le regime par defaut — celui du
    feeder, qui appelle l'organe SANS flag — ne change PAS d'un bit."""

    FREE_FAMINE = {
        "MyIA.AI.Notebooks/GenAI/Audio/a.ipynb": ["f1", "f2", "f3"],
        "MyIA.AI.Notebooks/GenAI/Audio/b.ipynb": ["f4", "f5"],
    }

    def test_famine_accepts_sub_floor_residual_as_famine_bin(self):
        bins = rvq.plan(self.FREE_FAMINE, group_idx=2, famine=True)
        self.assertEqual([n for n, _ in bins], [rvq.FAMINE_BIN])
        served = {p for _, ch in bins for p in ch}
        self.assertEqual(served, set(self.FREE_FAMINE))

    def test_default_still_drops_sub_floor_residual(self):
        """"Sans flag, le plancher reste une loi : le meme residu qui devient
        grain en famine reste un WARN hors file (comportement feeder inchange)."""
        self.assertEqual(rvq.plan(self.FREE_FAMINE, group_idx=2), [])

    def test_famine_never_exceeds_max_files(self):
        """Le levier famine cede le plancher, PAS la casquette anti-composite :
        un residu plus large que max_files reste hors file meme en famine."""
        free = {
            "MyIA.AI.Notebooks/GenAI/Audio/f%02d.ipynb" % i: ["x"]
            for i in range(16)
        }
        self.assertEqual(rvq.plan(free, group_idx=2, famine=True), [])

    def test_famine_note_is_invisible_to_payload_paths(self):
        """La note famine s'ajoute APRES le bloc targetPath : payload_paths()
        (utilise par la deconfliction au re-scan) doit rendre les memes cibles
        qu'un payload sans note."""
        payload = rvq.PAYLOAD.format(
            gid="g1-x", base="deadbeef", targets="- p1.ipynb\n- p2.ipynb",
            worktree="D:/wt", branch="wt/mistral-g1-x") + rvq.FAMINE_PAYLOAD_NOTE
        self.assertIn("NOTE FAMINE", payload)
        self.assertEqual(rvq.payload_paths({"payload": payload}),
                         {"p1.ipynb", "p2.ipynb"})


class TestDensityScanNormalization(unittest.TestCase):
    """Le scanner densite joint son repo_root ABSOLU : sans strip, la
    deconfliction ne soustrait rien (333 libres / 0, mesure 18/09) et le
    groupement met toute la file dans la famille "dev"."""

    def test_absolute_prefix_is_stripped(self):
        self.assertEqual(
            rvq._repo_relative(
                "D:/dev/CoursIA-vibe/_scan-queue/MyIA.AI.Notebooks/GenAI/A.ipynb",
                "D:/dev/CoursIA-vibe/_scan-queue"),
            "MyIA.AI.Notebooks/GenAI/A.ipynb")

    def test_already_relative_path_is_untouched(self):
        self.assertEqual(
            rvq._repo_relative("MyIA.AI.Notebooks/GenAI/A.ipynb",
                               "D:/dev/CoursIA-vibe/_scan-queue"),
            "MyIA.AI.Notebooks/GenAI/A.ipynb")

    def test_backslash_and_case_variants(self):
        self.assertEqual(
            rvq._repo_relative(
                "D:\\dev\\CoursIA-vibe\\_scan-queue\\MyIA.AI.Notebooks\\B.ipynb",
                "d:/dev/coursia-vibe/_scan-queue/"),
            "MyIA.AI.Notebooks\\B.ipynb".replace("\\", "/"))


class TestContracts(unittest.TestCase):
    def test_registry_has_all_active_contracts(self):
        self.assertEqual(sorted(rvq.CONTRACTS), [13410, 15719, 16472, 17712])

    def test_density_contract_carries_its_own_sizing_rule(self):
        """Moule findings inapplicable (dispatch ai-01 18/09) : 13410 definit
        floor=1 (le notebook est l'unite) et max_files=2 (1,67 fichier/PR)."""
        c = rvq.CONTRACTS[13410]
        self.assertEqual(c["floor"], 1)
        self.assertEqual(c["max_files"], 2)
        for i in (15719, 16472):
            self.assertNotIn("floor", rvq.CONTRACTS[i])
            self.assertNotIn("max_files", rvq.CONTRACTS[i])

    def test_payload_density_carries_editorial_guardrails(self):
        """Incident 02/09 (30/41 accents detruits) : les garde-fous sont du
        payload, pas de la doc peripherique — le run les lit pour s'y tenir."""
        p = rvq.CONTRACTS[13410]["payload"]
        for marker in ("#13410", "pedagogy_density.py", "1200", "LECTURE ANCREE",
                       "UTF-8 sans repli ASCII", "forme liste",
                       "AUCUNE re-execution", "detect_solution_leaks",
                       "JAMAIS fabriquer un chiffre", "CHECKPOINT-COMMIT",
                       "PAS une cible", "AU PLUS UNE cellule"):
            self.assertIn(marker, p, "payload 13410 sans %r" % marker)
        self.assertLessEqual(len(p.encode("utf-8")), 3 * 1024)

    def test_payload_density_never_asks_for_the_threshold(self):
        """#4847 (RX164 a) : le seuil 1200 est classe « PAS une cible » ; le
        payload ne doit plus exiger « ok attendu » (injonction contradictoire
        qui pousse au remplissage)."""
        p = rvq.CONTRACTS[13410]["payload"]
        self.assertNotIn("ok attendu", p.lower())

    def test_payload_hint_carries_contract_essentials(self):
        p = rvq.CONTRACTS[16472]["payload"]
        for marker in ("#16472", "scan_md_hierarchy.py", "demote_md_asides.py",
                       "fix_hint_headings.py", "REASSESSMENT", "update-baseline",
                       "CHECKPOINT-COMMIT"):
            self.assertIn(marker, p, "payload 16472 sans %r" % marker)
        self.assertLessEqual(len(p.encode("utf-8")), 3 * 1024)

    def test_payload_table_keeps_15719_essentials(self):
        p = rvq.CONTRACTS[15719]["payload"]
        for marker in ("#15719", "scan_md_table_syntax.py", "NOOP"):
            self.assertIn(marker, p)

    def test_only_density_contract_uses_the_frozen_branch_prefix(self):
        """Hygiene de prefixe : seul #13410 (famille densite) garde `wt/vibe-`.
        Le prefixe n'a plus de semantique de gel depuis la reouverture 07/10
        (FROZEN_BRANCH_PREFIXES vide dans frozen_campaigns.py) mais reste
        l'identifiant de famille ; un grain non-densite nomme `wt/vibe-*`
        brouille la lecture (mesure 25/09 : grain #16472 parti sur
        `wt/vibe-g2-...`)."""
        self.assertTrue(rvq.CONTRACTS[13410]["branch_prefix"].startswith("wt/vibe-"))
        for i in (15719, 16472):
            self.assertFalse(
                rvq.CONTRACTS[i]["branch_prefix"].startswith("wt/vibe-"),
                "contrat #%d : un prefixe wt/vibe- le gele en #13410" % i)

    def test_default_issue_selection_serves_every_contract(self):
        """#13410 rouvert cote source le 07/10 (frozen_campaigns.py) : le
        drapeau `frozen` du feeder, pose le 25/09 sous le gel #17040, est
        retire le 19/10 — il privait le refresh de la densite 11 jours apres
        la reouverture. Plus aucun contrat n'est gele : le defaut les sert
        tous (mesure 25-26/09, garde d'origine : file reconstruite a 121
        grains dont 120 de #13410 en une nuit — cette garde ne valait que
        sous gel effectif)."""
        self.assertEqual(rvq.default_issues(), [13410, 15719, 16472, 17712])
        for issue, c in rvq.CONTRACTS.items():
            self.assertNotIn("frozen", c, "contrat #%d encore gele" % issue)
        self.assertEqual(sorted(rvq.CONTRACTS), [13410, 15719, 16472, 17712])


class TestTellcContract(unittest.TestCase):
    """#17712, modalites ai-01 26/09 : citations "Tell c." hors .ipynb,
    hors docs/, hors .claude/ — une PR par famille, retrait uniquement en
    commentaire # ou docstring, fixtures/chaines/regex intouchables."""

    def test_tellc_family_classification(self):
        """Chemins mesures sur main 55e867960d : le QC vit sous
        MyIA.AI.Notebooks/QuantConnect/ et fast_lane_registry.py sous
        scripts/ci/ — une classification par segments n'exprime pas ces
        familles metier."""
        cases = {
            "scripts/notebook_tools/detect_morphology.py": "notebook_tools",
            "scripts/tests/test_fast_lane.py": "tests",
            "tests/test_something.py": "tests",
            "scripts/ci/fast_lane_registry.py": "b0-ci-organs",
            "scripts/ci/check_hr_substitution.py": "b0-ci-organs",
            "scripts/ci/tests/test_check_hr_substitution.py": "b0-ci-organs",
            "scripts/check_unaddressed_nits.py": "b0-ci-organs",
            "scripts/livecoding_video_pipeline.py": "b0-ci-organs",
            "scripts/fallacy_detection/regenerate_argumentum_snapshot.py": "b0-ci-organs",
            "MyIA.AI.Notebooks/QuantConnect/projects/FuturesTrend/main_carver13.py": "qc",
            "MyIA.AI.Notebooks/QuantConnect/ML-Training-Pipeline/scripts/tests/test_hmm_regime_vol.py": "qc",
            "MyIA.AI.Notebooks/GameTheory/cooperative_games/assistance_games.py": "notebooks-support",
            "MyIA.AI.Notebooks/IIT/ICT-Series/ict/sae_traces.py": "notebooks-support",
            "MyIA.AI.Notebooks/GenAI/Audio/04-Applications/v4/prosody_lab/bakeoff_large/SETUP.md": "notebooks-support",
        }
        for path, family in cases.items():
            self.assertEqual(rvq.tellc_family(path), family, path)

    def test_scan_tellc_excludes_ipynb_docs_claude(self):
        raw = (
            "scripts/notebook_tools/detect_x.py:12:# Tell c. #123\n"
            "MyIA.AI.Notebooks/GenAI/Audio/a.ipynb:5:Tell c. #9\n"
            "docs/foo.md:3:Tell c. #8\n"
            ".claude/bar.md:2:Tell c. #7\n"
            "MyIA.AI.Notebooks/QuantConnect/q.py:40:s = \"Tell c. #11\"\n"
        )
        orig = rvq.sh
        rvq.sh = lambda cmd, cwd=None, check=True: raw
        try:
            found = rvq.scan_tellc_citations("D:/wt")
        finally:
            rvq.sh = orig
        self.assertEqual(sorted(found),
                         ["MyIA.AI.Notebooks/QuantConnect/q.py",
                          "scripts/notebook_tools/detect_x.py"])
        self.assertEqual(found["scripts/notebook_tools/detect_x.py"],
                         ["L12 # Tell c. #123"])

    def test_tellc_contract_entry(self):
        c = rvq.CONTRACTS[17712]
        self.assertIs(c["scan"], rvq.scan_tellc_citations)
        self.assertIs(c["family_fn"], rvq.tellc_family)
        self.assertEqual(c["floor"], 1)
        self.assertEqual(c["branch_prefix"], "wt/mistral-tellc-")
        self.assertEqual(c["concluded_families"],
                         {"qc", "tests", "notebook_tools", "notebooks-support"})
        self.assertNotIn("frozen", c)
        self.assertFalse(c["branch_prefix"].startswith("wt/vibe-"),
                         "un prefixe wt/vibe- gele #17712 en #13410")

    def test_concluded_families_subtract_only_closed_families(self):
        """End-of-life 08/10 (+ notebooks-support 11/10) : les familles
        conclues sortent de la file, une famille vivante survit. Chemins
        classes par test_tellc_family."""
        free = {
            "scripts/tests/test_a.py": ["f1"],
            "scripts/notebook_tools/detect_b.py": ["f2"],
            "MyIA.AI.Notebooks/QuantConnect/projects/Fut/c.py": ["f3"],
            "MyIA.AI.Notebooks/GameTheory/cooperative_games/assistance_games.py": ["f4"],
            "scripts/ci/fast_lane_registry.py": ["f5"],
        }
        filtered = rvq.subtract_concluded_families(free, rvq.CONTRACTS[17712])
        self.assertEqual(sorted(filtered), ["scripts/ci/fast_lane_registry.py"])

    def test_concluded_families_no_key_leaves_contract_untouched(self):
        """Le non-effet sur un contrat SANS la cle protege #15719/#16472/
        #13410 d'une regression future — rien d'autre que la lecture ne le
        garantit aujourd'hui. Contrat AVEC la cle mais sans family_fn :
        intact aussi (garde du call-site)."""
        free = {"MyIA.AI.Notebooks/GenAI/Audio/a.ipynb": ["f1"]}
        for issue in (15719, 16472, 13410):
            self.assertIs(rvq.subtract_concluded_families(free, rvq.CONTRACTS[issue]), free)
        contract = dict(rvq.CONTRACTS[17712])
        contract.pop("family_fn")
        self.assertIs(rvq.subtract_concluded_families(free, contract), free)

    def test_payload_tellc_carries_contract_essentials(self):
        p = rvq.CONTRACTS[17712]["payload"]
        for marker in ("#17712", "docstring", "fixture", "python -m pytest",
                       "NOOP JUSTIFIE", "CHECKPOINT-COMMIT", "Grain:", "paths:"):
            self.assertIn(marker, p, "payload 17712 sans %r" % marker)
        self.assertLessEqual(len(p.encode("utf-8")), 3 * 1024)

    def test_plan_family_fn_groups_by_family_not_segments(self):
        """La famille qc UNIFIE des fichiers que aucun segment ne rapproche
        (FuturesTrend vs ML-Training-Pipeline) : si grain_key retombait sur
        l'axe par segment, le bin se nommerait QuantConnect — pas qc. La poche
        notebooks-support (2 < floor) reste hors file, jamais versee."""
        free = {
            "scripts/notebook_tools/a.py": ["f%d" % i for i in range(12)],
            "scripts/notebook_tools/b.py": ["g%d" % i for i in range(12)],
            "MyIA.AI.Notebooks/QuantConnect/projects/FuturesTrend/main.py":
                ["h%d" % i for i in range(12)],
            "MyIA.AI.Notebooks/QuantConnect/ML-Training-Pipeline/scripts/tests/test_hmm.py":
                ["i%d" % i for i in range(12)],
            "MyIA.AI.Notebooks/GameTheory/support.py": ["j1", "j2"],
        }
        bins = rvq.plan(free, floor=10, group_fn=rvq.tellc_family)
        self.assertEqual([n for n, _ in bins], ["notebook_tools", "qc"])
        served = {p for _, ch in bins for p in ch}
        self.assertEqual(served, set(free) - {"MyIA.AI.Notebooks/GameTheory/support.py"})

    def test_plan_group_fn_bounds_pour_to_family(self):
        """Le versement suit family_fn : une poche sous plancher ne se verse
        JAMAIS chez une famille voisine, meme quand leurs segments
        coïncident — sinon la PR melangerait deux familles, interdit par les
        modalites #17712. Fixture synthetic : a/x.py et b/x.py partagent le
        segment[1] "x" — c'est precisement la collision que le garde doit
        fermer."""
        def fam(p):
            return "A" if p.startswith("a/") else "B"
        free = {
            "a/x.py": ["f%d" % i for i in range(12)],
            "b/x.py": ["g%d" % i for i in range(2)],
        }
        bins = rvq.plan(free, floor=10, group_fn=fam)
        self.assertEqual([n for n, _ in bins], ["A"])
        self.assertNotIn("b/x.py", {p for _, ch in bins for p in ch})


class TestOpenPrsGraphqlRestFallback(unittest.TestCase):
    """Mesure 17/10 11:10Z : pool GraphQL flotte epuise ~1 h -> `gh pr list
    --json` leve SystemExit -> organ exit 1, file non rafraichie (famine
    artificielle pendant la fenetre). La bascule GraphQL->REST est livree en
    secours ici ; lot 7b (#4150) : REST devient le chemin UNIQUE — ces tests
    gardent le contrat (meme collecte) et la fail-closed."""

    def _fake_sh_factory(self, calls):
        def fake_sh(cmd, cwd=None, check=True):
            calls.append(" ".join(cmd))
            if cmd[1] == "pr":
                raise SystemExit("commande echouee: gh pr list\nGraphQL: rate limit")
            if "/pulls?" in cmd[-1]:
                # 1 page courte : 2 PRs ouvertes, une seule matche #15719.
                return json.dumps([
                    {"number": 11, "title": "fix(x,#15719): table", "head": {"ref": "wt/keep"}},
                    {"number": 12, "title": "chore: hors contrat", "head": {"ref": "wt/other"}},
                ])
            if "/files" in cmd[-1]:
                assert "/pulls/11/" in cmd[-1], "fichiers requis pour la PR contrat seule"
                # Shape REELLE de GET /pulls/{n}/files : cle "filename" (pas
                # "path" — forme GraphQL). Le mock initial fabulait "path" et
                # verrouillait la fantaisie (KeyError prouve en live, #4239).
                return json.dumps([{
                    "additions": 3, "changes": 3, "deletions": 0,
                    "filename": "MyIA.AI.Notebooks\\GenAI\\Audio\\a.ipynb",
                    "sha": "abc", "status": "modified"}])
            raise AssertionError("appel inattendu: %s" % cmd)
        return fake_sh

    def test_malformed_pr_listing_fails_closed(self):
        for response in ('{}', '[{}]', '[null]', '[{"number":1,"title":"x","head":{}}]'):
            with self.subTest(response=response), mock.patch.object(rvq, 'sh', return_value=response):
                with self.assertRaises(ValueError):
                    rvq.open_prs('example/repo', [123])

    def test_malformed_pr_files_refuse_partial_deconfliction(self):
        listing = json.dumps([{'number': 1, 'title': 'fix #123', 'head': {'ref': 'wt/g'}}])
        for response in ('{}', '[null]', '[{}]', '[{"filename":""}]'):
            with self.subTest(response=response), mock.patch.object(rvq, 'sh', side_effect=[listing, response]):
                with self.assertRaises(ValueError):
                    rvq.open_prs('example/repo', [123])

    def test_graphql_pool_exhausted_falls_back_to_rest(self):
        """REST unique (lot 7b) : la collecte rend les memes tuples que
        l'ancien chemin GraphQL — fichiers de la PR contrat seule, branches
        de TOUTES les PRs ouvertes."""
        calls = []
        with mock.patch.object(rvq, "sh", self._fake_sh_factory(calls)):
            held, branches = rvq.open_prs("jsboige/CoursIA", [15719])
        self.assertEqual(held, {"MyIA.AI.Notebooks/GenAI/Audio/a.ipynb": 11})
        self.assertEqual(branches, {"wt/keep", "wt/other"})
        self.assertTrue(any("/pulls?" in c for c in calls), "liste REST attendue")
        self.assertTrue(any("/pulls/11/" in c and "/files" in c for c in calls),
                        "fichiers de la PR contrat attendus")
        self.assertFalse(any("/pulls/12/" in c for c in calls),
                          "pas de requete fichiers pour une PR hors contrat")

    def test_graphql_healthy_path_unchanged(self):
        """Chemin REST healthy (lot 7b : le GraphQL n'est PLUS jamais appele)
        — le mock repond la forme REST (head.ref, filename via /files)."""
        def rest(cmd, cwd=None, check=True):
            if "/pulls?" in cmd[-1]:
                return json.dumps([
                    {"number": 21, "title": "fix(#16472)", "head": {"ref": "wt/g"}},
                ])
            if "/files" in cmd[-1]:
                return json.dumps([{"filename": "n/b.ipynb"}])
            raise AssertionError("appel inattendu: %s" % cmd)
        with mock.patch.object(rvq, "sh", rest):
            held, branches = rvq.open_prs("jsboige/CoursIA", [16472])
        self.assertEqual(held, {"n/b.ipynb": 21})
        self.assertEqual(branches, {"wt/g"})

    def test_rest_failure_still_raises_fail_closed(self):
        def boom(cmd, cwd=None, check=True):
            raise SystemExit("commande echouee: %s" % cmd[0])
        with mock.patch.object(rvq, "sh", boom):
            with self.assertRaises(SystemExit):
                rvq.open_prs("jsboige/CoursIA", [15719])


class TestDefaultQueueAnchoring(unittest.TestCase):
    """Friction c.150/c.151 : le default --queue etait relatif au cwd — un run
    depuis D:/dev/CoursIA ecrivait la file au mauvais repo pendant que le
    feeder (repoRoot derive de $PSScriptRoot) lisait l'ancienne. Le default
    doit suivre le meme ancrage que le feeder : le repo qui porte LE SCRIPT."""

    def test_default_queue_is_absolute_and_script_anchored(self):
        # Ancrage calcule INDEPENDAMMENT depuis ce fichier de test :
        # scripts/testing/python -> scripts -> repo root.
        repo_root = os.path.dirname(os.path.dirname(os.path.dirname(
            os.path.dirname(os.path.abspath(__file__)))))
        expected = os.path.join(repo_root, "outputs", "vibe", "feeder-queue.json")
        self.assertTrue(os.path.isabs(rvq.DEFAULT_QUEUE),
                        "le default doit etre absolu, pas relatif au cwd")
        self.assertEqual(rvq.DEFAULT_QUEUE, expected)

    def test_default_queue_survives_a_cwd_change(self):
        """Le defaut ne doit rien au cwd : chdir vers un tempdir distinct ne
        change pas la valeur (le bug historique : la valeur ETAIT le cwd)."""
        before = rvq.DEFAULT_QUEUE
        original = os.getcwd()
        tmp = tempfile.mkdtemp(prefix="rvq-cwd-")
        try:
            os.chdir(tmp)
            # Recalcule la derivation comme le ferait un import dans ce cwd :
            # le chemin du script ne bouge pas, le default non plus.
            recomputed = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(
                    os.path.abspath(rvq.__file__)))),
                "outputs", "vibe", "feeder-queue.json")
            self.assertEqual(before, recomputed)
            self.assertNotIn(tmp, before)
        finally:
            os.chdir(original)
            os.rmdir(tmp)


class TestPrintConflicts(unittest.TestCase):
    """--print-conflicts : le conflict set des semis voie legere (17/10).

    Le semis #19241 du 16/10 listait les PRs tenues A LA MAIN -> g1 a
    duplique #21032 (1 run paye sur du deja tenu). Le mode exporte
    held/claims/branches en JSON et sort AVANT le scan : un numero hors
    CONTRACTS doit passer sans KeyError, sans scan-wt, sans ecriture de
    file. Toute commande non-gh seen = le mode a continue trop loin.
    """

    def _fake_sh(self, seen):
        def fake_sh(cmd, cwd=None, check=True):
            line = " ".join(cmd)
            seen.append(line)
            # Lot 7b (#4150) : open_prs est REST unique — liste paginee (1
            # page courte), puis /files des PRs dont le titre cite l'umbrella.
            if line.startswith("gh pr list"):
                raise AssertionError("la jambe GraphQL ne doit plus exister (lot 7b)")
            if "/pulls?" in line:
                return json.dumps([
                    {"number": 21032,
                     "title": "chore(translations,#19241): mlnet re-cle",
                     "head": {"ref": "wt/mistral-trad-g1"}},
                    {"number": 21155,
                     "title": "chore(translations,#19241): lot search",
                     "head": {"ref": "wt/mistral-trad-g2-trad-search"}},
                ])
            if "/pulls/21032/files" in line:
                return json.dumps([{"filename": "translations\\mlnet\\mlnet.csv"}])
            if "/pulls/21155/files" in line:
                return json.dumps([{"filename": "translations/search/search.csv"}])
            if "/comments?" in line:
                return json.dumps([
                    {"body": "[CLAIMED-AMEND] fournee\npaths:\n"
                             "MyIA.AI.Notebooks/GenAI/Audio/a.ipynb."}])
            raise AssertionError(
                "commande inattendue sous --print-conflicts "
                "(le mode doit sortir avant le scan): %s" % line)
        return fake_sh

    def test_exports_union_conflict_set_and_exits_before_scan(self):
        seen = []
        old_sh, old_argv = rvq.sh, sys.argv
        rvq.sh = self._fake_sh(seen)
        sys.argv = ["refresh-vibe-queue.py", "--print-conflicts",
                    "--issue", "19241"]
        buf = io.StringIO()
        try:
            with redirect_stdout(buf):
                rvq.main()
        finally:
            rvq.sh, sys.argv = old_sh, old_argv
        out = json.loads(buf.getvalue().strip())
        # Les deux PRs citant l'umbrella tiennent leurs fichiers (anti-#21032)
        self.assertEqual(out["held"]["translations/mlnet/mlnet.csv"], 21032)
        self.assertEqual(out["held"]["translations/search/search.csv"], 21155)
        # Le claim sans PR est exporte au meme titre que les PRs ouvertes
        self.assertIn("MyIA.AI.Notebooks/GenAI/Audio/a.ipynb", out["claims"])
        # Les branches ouvertes aussi : un semis ne doit pas bruler un nom vif
        self.assertIn("wt/mistral-trad-g1", out["branches"])
        # Union d'office : 1 liste REST + 1 fetch comments par contrat actif
        # (le /files des PRs de contrat vient en sus, par PR matchee).
        expected_issues = sorted(set([19241]) | set(rvq.default_issues()))
        self.assertEqual(sum(1 for c in seen if "/pulls?" in c), 1)
        self.assertEqual(
            sum(1 for c in seen if "/comments?" in c),
            len(expected_issues))


class TestIssueClaimsFailures(unittest.TestCase):
    def test_unreadable_comments_refuse_deconfliction(self):
        for response in ("", "not json", "{}", '[null]', '[{}]', '[{"body": 123}]'):
            with self.subTest(response=response), mock.patch.object(
                    rvq, "sh", return_value=response):
                with self.assertRaises(ValueError):
                    rvq.issue_claims("example/repo", [123])

    def test_empty_list_is_a_valid_absence(self):
        with mock.patch.object(rvq, "sh", return_value="[]"):
            self.assertEqual(rvq.issue_claims("example/repo", [123]), set())

    def test_failed_command_with_valid_json_is_not_accepted(self):
        result = mock.Mock(returncode=1, stdout='[]', stderr='failed')
        with mock.patch.object(rvq.subprocess, 'run', return_value=result):
            with self.assertRaises(SystemExit):
                rvq.issue_claims("example/repo", [123])

    def test_failed_second_page_does_not_return_partial_claims(self):
        first = json.dumps([{"body": "[CLAIMED] paths: held.md"}] * 100)
        with mock.patch.object(rvq, "sh", side_effect=[first, ""]):
            with self.assertRaises(ValueError):
                rvq.issue_claims("example/repo", [123])


class TestMergedBranchesRest(unittest.TestCase):
    """Lot 7b (#4150) : merged_branches passe en REST — `state=merged`
    n'existe pas côté REST : state=closed + filtre merged_at. Une PR fermée
    NON mergée ne livre pas la branche (elle serait re-semee, #3755)."""

    def _fake(self, rows):
        def fake(cmd, cwd=None, check=True):
            self.assertIn("state=closed", cmd[-1])
            self.assertIn("head=wt/g&per_page=100", cmd[-1])
            return json.dumps(rows)
        return fake

    def test_merged_at_present_delivers_branch(self):
        with mock.patch.object(rvq, "sh", self._fake(
                [{"number": 1, "merged_at": "2026-11-01T00:00:00Z"}])):
            self.assertEqual(rvq.merged_branches("jsboige/CoursIA", ["wt/g"]),
                             {"wt/g"})

    def test_closed_not_merged_does_not_deliver(self):
        with mock.patch.object(rvq, "sh", self._fake(
                [{"number": 1, "merged_at": None}])):
            self.assertEqual(rvq.merged_branches("jsboige/CoursIA", ["wt/g"]),
                             set())

    def test_newer_closed_pr_does_not_hide_older_merge(self):
        with mock.patch.object(rvq, "sh", self._fake([
                {"number": 2, "merged_at": None},
                {"number": 1, "merged_at": "2026-10-01T00:00:00Z"}])):
            self.assertEqual(rvq.merged_branches("jsboige/CoursIA", ["wt/g"]),
                             {"wt/g"})

    def test_empty_answer_is_warn_not_deliver(self):
        with mock.patch.object(rvq, "sh", self._fake([])):
            self.assertEqual(rvq.merged_branches("jsboige/CoursIA", ["wt/g"]),
                             set())

    def test_unreadable_answer_refuses_refresh(self):
        with mock.patch.object(rvq, "sh", return_value="not json"):
            with self.assertRaises(ValueError):
                rvq.merged_branches("jsboige/CoursIA", ["wt/g"])
    def test_merge_on_a_later_page_delivers_branch(self):
        """100 PR fermées non mergées ne doivent pas masquer un merge ancien."""
        calls = []

        def pages(cmd, cwd=None, check=True):
            calls.append(cmd[-1])
            if "page=2" in cmd[-1]:
                return json.dumps([{"number": 1, "merged_at": "2026-10-01T00:00:00Z"}])
            return json.dumps([
                {"number": i, "merged_at": None} for i in range(2, 102)])

        with mock.patch.object(rvq, "sh", pages):
            self.assertEqual(rvq.merged_branches("jsboige/CoursIA", ["wt/g"]),
                             {"wt/g"})
        self.assertEqual(len(calls), 2)
        self.assertIn("page=1", calls[0])
        self.assertIn("page=2", calls[1])

    def test_invalid_json_shape_refuses_refresh(self):
        for response in ('', '{}', '[null]', '[{}]'):
            with self.subTest(response=response), mock.patch.object(rvq, 'sh', return_value=response):
                with self.assertRaises(ValueError):
                    rvq.merged_branches('jsboige/CoursIA', ['wt/g'])

    def test_failed_second_page_refuses_partial_lookup(self):
        first = json.dumps([{"number": i, "merged_at": None} for i in range(100)])
        with mock.patch.object(rvq, 'sh', side_effect=[first, '']):
            with self.assertRaises(ValueError):
                rvq.merged_branches('jsboige/CoursIA', ['wt/g'])

    def test_failed_command_cannot_masquerade_as_empty_list(self):
        failure = mock.Mock(returncode=1, stdout='[]', stderr='lookup failed')
        with mock.patch.object(rvq.subprocess, 'run', return_value=failure):
            with self.assertRaises(SystemExit):
                rvq.merged_branches('jsboige/CoursIA', ['wt/g'])


class TestQueueBootstrap(unittest.TestCase):
    """Reject invalid queues without destroying the last preserved backup.

    Recovery requires reconciling stored reservations before rebuilding: an
    invalid queue cannot safely be interpreted as an empty queue.
    """

    def setUp(self):
        self.dir = tempfile.mkdtemp()
        self.path = os.path.join(self.dir, "feeder-queue.json")

    def tearDown(self):
        for name in os.listdir(self.dir):
            os.unlink(os.path.join(self.dir, name))
        os.rmdir(self.dir)

    def _write(self, text):
        with io.open(self.path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)

    def test_failed_worktree_list_does_not_create_or_checkout(self):
        failure = mock.Mock(returncode=1, stdout='', stderr='worktree list failed')
        with mock.patch.object(rvq.subprocess, 'run', return_value=failure) as run:
            with self.assertRaises(SystemExit):
                rvq.ensure_scan_wt('repo', 'base', os.path.join(self.dir, 'scan'))
        self.assertEqual(run.call_count, 1)
        self.assertEqual(run.call_args.args[0], ['git', '-C', 'repo', 'worktree', 'list'])
        self.assertEqual(os.listdir(self.dir), [])

    def test_absent_queue_fails_closed(self):
        with self.assertRaises(OSError):
            rvq.load_queue(self.path)

    def test_fresh_seat_without_queue_or_backup_starts_empty(self):
        self.assertEqual(rvq.load_or_bootstrap_queue(self.path), {"grains": []})
        self.assertEqual(os.listdir(self.dir), [])

    def test_absent_queue_beside_backup_refuses(self):
        backup = b'{"grains":[{"id":"reserved","branch":"wt/reserved"}]}'
        with open(self.path + ".bak", "wb") as fh:
            fh.write(backup)
        with self.assertRaises(FileNotFoundError):
            rvq.load_or_bootstrap_queue(self.path)
        with open(self.path + ".bak", "rb") as fh:
            self.assertEqual(fh.read(), backup)
        self.assertFalse(os.path.exists(self.path))

    def test_blank_queue_without_backup_still_refuses(self):
        for text in ('', '  \r\n', '{}'):
            with self.subTest(text=text):
                self._write(text)
                with self.assertRaises(ValueError):
                    rvq.load_or_bootstrap_queue(self.path)
                self.assertFalse(os.path.exists(self.path + ".bak"))

    def test_main_on_fresh_seat_reaches_the_scan(self):
        class Reached(Exception):
            pass
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path]), \
             mock.patch.object(rvq, 'fresh_base', side_effect=Reached) as fresh_base:
            with self.assertRaises(Reached):
                rvq.main()
            fresh_base.assert_called_once()
        self.assertEqual(os.listdir(self.dir), [])

    def test_main_on_fresh_seat_publishes_without_backup(self):
        contract = {'scan': lambda _: {'free.ipynb': ['x']}, 'branch_prefix': 'wt/',
                    'payload': 'targetPath:\n{targets}\nworktree: {worktree}\nbranch: {branch}\n'}
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--issue', '1', '--wt-root', os.path.join(self.dir, 'wt')]), \
             mock.patch.object(rvq, 'CONTRACTS', {1: contract}), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'merged_branches', return_value=set()), \
             mock.patch.object(rvq, 'plan', return_value=[('x', {'free.ipynb': ['x']})]), \
             redirect_stdout(io.StringIO()):
            rvq.main()
        self.assertEqual(sorted(os.listdir(self.dir)), ['feeder-queue.json'])
        self.assertEqual(len(rvq.load_queue(self.path)['grains']), 1)

    def test_main_refuses_absent_queue_beside_backup_before_scan(self):
        backup = b'{"grains":[{"id":"reserved","branch":"wt/reserved"}]}'
        with open(self.path + '.bak', 'wb') as fh:
            fh.write(backup)
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path]), \
             mock.patch.object(rvq, 'fresh_base') as fresh_base:
            with self.assertRaises(FileNotFoundError):
                rvq.main()
            fresh_base.assert_not_called()
        with open(self.path + '.bak', 'rb') as fh:
            self.assertEqual(fh.read(), backup)

    def test_invalid_queues_fail_closed_preserving_backup(self):
        backup = b'{"grains":[{"id":"reserved","branch":"wt/reserved"}]}'
        with open(self.path + ".bak", "wb") as fh:
            fh.write(backup)
        for text in ('', '  \r\n', '{"grains":[', '[1,2]', '{}',
                     '{"grains":[null]}', '{"grains":["invalid"]}'):
            with self.subTest(text=text):
                self._write(text)
                with self.assertRaises(ValueError):
                    rvq.load_queue(self.path)
                self.assertFalse(rvq.preserve_previous(self.path, text))
                with open(self.path + ".bak", "rb") as fh:
                    self.assertEqual(fh.read(), backup)

    def test_main_refuses_corrupt_queue_before_scan_and_preserves_backup(self):
        backup = b'{"grains":[{"id":"reserved","branch":"wt/reserved"}]}'
        with open(self.path + '.bak', 'wb') as fh:
            fh.write(backup)
        self._write('{"grains":[')
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path]), \
             mock.patch.object(rvq, 'fresh_base') as fresh_base:
            with self.assertRaises(ValueError):
                rvq.main()
            fresh_base.assert_not_called()
        with open(self.path + '.bak', 'rb') as fh:
            self.assertEqual(fh.read(), backup)
        with io.open(self.path, encoding='utf-8') as fh:
            self.assertEqual(fh.read(), '{"grains":[')

    def test_main_rejects_unreadable_recovery_manifest_before_scan(self):
        self._write('{"grains":[]}')
        manifest = os.path.join(self.dir, 'quarantine.json')
        with open(manifest, 'w', encoding='utf-8') as fh:
            fh.write('{broken')
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--recovery-manifest', manifest, '--dry-run']), \
             mock.patch.object(rvq, 'fresh_base') as fresh_base:
            with self.assertRaises(ValueError):
                rvq.main()
            fresh_base.assert_not_called()

    def test_inspect_backup_never_scans_or_writes(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        with open(self.path + '.bak', 'w', encoding='utf-8') as fh:
            json.dump({'grains': [grain]}, fh)
        output = io.StringIO()
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--inspect-backup']), \
             mock.patch.object(rvq, 'fresh_base') as base, \
             mock.patch.object(rvq, 'ensure_scan_wt') as scan, \
             mock.patch.object(rvq, 'sh') as command, \
             mock.patch.object(rvq, 'publish_text') as publish, redirect_stdout(output):
            rvq.main()
            base.assert_not_called()
            scan.assert_not_called()
            command.assert_not_called()
            publish.assert_not_called()
        self.assertEqual(json.loads(output.getvalue()), {'grains': 1, 'paths': 1})
        self.assertFalse(os.path.exists(self.path))

    def test_simulated_backup_load_fails_closed_when_backup_invalid(self):
        self._write('')
        with open(self.path + '.bak', 'w', encoding='utf-8') as fh:
            fh.write('{broken')
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--simulate-backup', '--dry-run']), \
             mock.patch.object(rvq, 'fresh_base') as fresh_base:
            with self.assertRaises(ValueError):
                rvq.main()
            fresh_base.assert_not_called()

    def test_simulated_backup_reserves_targets_without_writing_queue(self):
        self._write('')
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- Folder/Held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        with open(self.path + '.bak', 'w', encoding='utf-8') as fh:
            json.dump({'grains': [grain]}, fh)
        contract = {'scan': lambda _: {'folder\\held.ipynb': ['x'], 'free.ipynb': ['y']}}
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--simulate-backup', '--dry-run', '--issue', '1']), \
             mock.patch.object(rvq, 'CONTRACTS', {1: contract}), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'merged_branches', return_value=set()) as merged, \
             mock.patch.object(rvq, 'keepable', return_value=([], [])) as keepable, \
             mock.patch.object(rvq, 'plan', return_value=[]) as plan, \
             mock.patch.object(rvq, 'publish_text') as publish:
            rvq.main()
            self.assertEqual(merged.call_args.args[1], {'wt/g1'})
            self.assertEqual(merged.call_count, 1)
            self.assertEqual(keepable.call_args.args[0]['grains'], [grain])
            self.assertEqual(plan.call_args.args[0], {'free.ipynb': ['y']})
            publish.assert_not_called()
        with open(self.path, 'rb') as fh:
            self.assertEqual(fh.read(), b'')

    def test_recovery_manifest_cannot_be_used_for_publication(self):
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--recovery-manifest', 'missing.json']), \
             mock.patch.object(rvq, 'fresh_base') as fresh_base:
            with self.assertRaisesRegex(ValueError, 'dry-run only'):
                rvq.main()
            fresh_base.assert_not_called()

    def test_dry_run_main_excludes_reserved_targets_from_plan(self):
        self._write('{"grains":[]}')
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- Folder/Held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        manifest = os.path.join(self.dir, 'quarantine.json')
        rvq.create_recovery_manifest(manifest, {'grains': [grain]})
        contract = {'scan': lambda _: {'folder\\held.ipynb': ['x'], 'free.ipynb': ['y']}}
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--recovery-manifest', manifest, '--dry-run', '--issue', '1']), \
             mock.patch.object(rvq, 'CONTRACTS', {1: contract}), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'merged_branches', return_value=set()), \
             mock.patch.object(rvq, 'plan', return_value=[]) as plan, \
             mock.patch.object(rvq, 'publish_text') as publish:
            rvq.main()
            self.assertEqual(plan.call_args.args[0], {'free.ipynb': ['y']})
            publish.assert_not_called()

    def test_dry_run_main_passes_reserved_names_to_allocator(self):
        self._write('{"grains":[]}')
        grain = {'id': 'g1-x', 'branch': 'wt/g1-x', 'worktree': 'D:/vibe/g1-x',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1-x\nbranch: wt/g1-x\n'}
        manifest = os.path.join(self.dir, 'quarantine.json')
        rvq.create_recovery_manifest(manifest, {'grains': [grain]})
        contract = {'scan': lambda _: {'free.ipynb': ['x']}, 'branch_prefix': 'wt/',
                    'payload': 'targetPath:\n{targets}\nworktree: {worktree}\nbranch: {branch}\n'}
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--recovery-manifest', manifest, '--dry-run', '--issue', '1']), \
             mock.patch.object(rvq, 'CONTRACTS', {1: contract}), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'merged_branches', return_value=set()), \
             mock.patch.object(rvq, 'plan', return_value=[('x', {'free.ipynb': ['x']})]), \
             mock.patch.object(rvq, 'available_grain_name', wraps=rvq.available_grain_name) as allocator, \
             mock.patch.object(rvq, 'publish_text') as publish:
            rvq.main()
            args = allocator.call_args.args
            self.assertIn('g1-x', args[4])
            self.assertIn('wt/g1-x', args[5])
            self.assertIn('D:/vibe/g1-x', args[6])
            publish.assert_not_called()

    def test_main_refuses_unreadable_claims_without_publishing(self):
        original = b'{"grains":[]}'
        backup = b'{"grains":[{"id":"reserved"}]}'
        with open(self.path, 'wb') as fh:
            fh.write(original)
        with open(self.path + '.bak', 'wb') as fh:
            fh.write(backup)
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path]), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'sh', return_value=''), \
             mock.patch.object(rvq, 'publish_text') as publish:
            with self.assertRaises(ValueError):
                rvq.main()
            publish.assert_not_called()
        with open(self.path, 'rb') as fh:
            self.assertEqual(fh.read(), original)
        with open(self.path + '.bak', 'rb') as fh:
            self.assertEqual(fh.read(), backup)

    def test_main_refuses_unreadable_merged_lookup_without_publishing(self):
        original = b'{"grains":[{"id":"g1","branch":"wt/g1"}]}'
        backup = b'{"grains":[{"id":"reserved"}]}'
        with open(self.path, 'wb') as fh:
            fh.write(original)
        with open(self.path + '.bak', 'wb') as fh:
            fh.write(backup)
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path]), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'sh', return_value=''), \
             mock.patch.object(rvq, 'publish_text') as publish:
            with self.assertRaises(ValueError):
                rvq.main()
            publish.assert_not_called()
        with open(self.path, 'rb') as fh:
            self.assertEqual(fh.read(), original)
        with open(self.path + '.bak', 'rb') as fh:
            self.assertEqual(fh.read(), backup)

    def test_recovery_conflicts_cover_identity_and_windows_path_aliases(self):
        original = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                    'payload': 'targetPath:\n- Folder/Held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        manifest = rvq.recovery_reservations({'grains': [original]})
        def candidate(gid='g2', branch='wt/g2', worktree='D:/vibe/g2', target='Other.ipynb'):
            return {'id': gid, 'branch': branch, 'worktree': worktree,
                    'payload': 'targetPath:\n- %s\nworktree: %s\nbranch: %s\n' % (target, worktree, branch)}
        self.assertFalse(rvq.recovery_conflicts(candidate(), manifest))
        for grain in (candidate(gid='g1'), candidate(branch='wt/g1'),
                      candidate(worktree='d:\\VIBE\\g1'), candidate(target='folder\\held.ipynb')):
            with self.subTest(grain=grain):
                self.assertTrue(rvq.recovery_conflicts(grain, manifest))

    def test_reserved_targets_are_excluded_case_insensitively(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- Folder/Held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        manifest = rvq.recovery_reservations({'grains': [grain]})
        free = {'folder\\held.ipynb': ['x'], 'folder/free.ipynb': ['y']}
        self.assertEqual(rvq.exclude_recovery_targets(free, manifest),
                         {'folder/free.ipynb': ['y']})

    def test_reserved_worktree_alias_cannot_be_reissued(self):
        gid, branch, wt = rvq.available_grain_name(
            1, 'x', 'wt/', 'D:/vibe', set(), set(), {'d:\\VIBE\\g1-x'})
        self.assertEqual((gid, branch, wt), ('g1-x-2', 'wt/g1-x-2', 'D:/vibe/g1-x-2'))

    def test_recovery_manifest_round_trips_all_reservations(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        path = os.path.join(self.dir, 'quarantine.json')
        rvq.create_recovery_manifest(path, {'grains': [grain]})
        self.assertEqual(rvq.read_recovery_manifest(path), rvq.recovery_reservations({'grains': [grain]}))

    def test_recovery_manifest_reader_rejects_truncated_or_inconsistent_data(self):
        path = os.path.join(self.dir, 'quarantine.json')
        for data in ('', '{"version":1', '{"version":1,"grains":[],"paths":["missing"]}',
                     '{"version":2,"grains":[],"paths":[]}'):
            with self.subTest(data=data):
                with open(path, 'w', encoding='utf-8') as fh:
                    fh.write(data)
                with self.assertRaises(ValueError):
                    rvq.read_recovery_manifest(path)

    def test_recovery_manifest_is_created_once_without_overwrite(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        path = os.path.join(self.dir, 'quarantine.json')
        rvq.create_recovery_manifest(path, {'grains': [grain]})
        with open(path, 'rb') as fh:
            before = fh.read()
        with self.assertRaises(FileExistsError):
            rvq.create_recovery_manifest(path, {'grains': [grain]})
        with open(path, 'rb') as fh:
            self.assertEqual(fh.read(), before)
        self.assertEqual(json.loads(before)['paths'], ['held.ipynb'])

    def test_failed_manifest_publication_leaves_no_partial_final_file(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        path = os.path.join(self.dir, 'quarantine.json')
        with mock.patch.object(rvq.os, 'link', side_effect=OSError('publication failed')):
            with self.assertRaises(OSError):
                rvq.create_recovery_manifest(path, {'grains': [grain]})
        self.assertFalse(os.path.exists(path))
        self.assertFalse(any(name.endswith('.tmp') for name in os.listdir(self.dir)))

    def test_recovery_reserves_every_backup_grain_and_its_targets(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        manifest = rvq.recovery_reservations({'grains': [grain]})
        self.assertEqual(manifest['grains'], [grain])
        self.assertEqual(manifest['paths'], ['held.ipynb'])
        self.assertEqual(manifest['version'], 1)

    def test_recovery_rejects_payload_identity_mismatch(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1'}
        for worktree, branch in [('D:/vibe/other', 'wt/g1'),
                                 ('D:/vibe/g1', 'wt/other')]:
            payload = 'targetPath:\n- held.ipynb\nworktree: %s\nbranch: %s\n' % (worktree, branch)
            with self.subTest(worktree=worktree, branch=branch), self.assertRaises(ValueError):
                rvq.recovery_reservations({'grains': [{**grain, 'payload': payload}]})

    def test_recovery_refuses_unidentifiable_grain(self):
        valid = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        for field in ('id', 'branch', 'worktree', 'payload'):
            broken = dict(valid)
            broken[field] = ''
            with self.subTest(field=field), self.assertRaises(ValueError):
                rvq.recovery_reservations({'grains': [broken]})

    def test_recovery_rejects_targets_outside_repository(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1'}
        for target in ('../outside.ipynb', 'dir/../../outside.ipynb',
                       'D:/outside.ipynb', '/outside.ipynb', 'C:relative.ipynb'):
            payload = 'targetPath:\n- %s\nworktree: D:/vibe/g1\nbranch: wt/g1\n' % target
            with self.subTest(target=target), self.assertRaisesRegex(ValueError, 'invalid target path'):
                rvq.recovery_reservations({'grains': [{**grain, 'payload': payload}]})

    def test_recovery_rejects_empty_target_alongside_valid_target(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\n- \nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        with self.assertRaisesRegex(ValueError, 'invalid target block'):
            rvq.recovery_reservations({'grains': [grain]})

    def test_recovery_rejects_duplicate_reservation_identities(self):
        first = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1',
                 'payload': 'targetPath:\n- held.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'}
        for gid, branch, worktree in [('g1', 'wt/g2', 'D:/vibe/g2'),
                                      ('g2', 'wt/g1', 'D:/vibe/g2'),
                                      ('g2', 'wt/g2', 'd:\\VIBE\\g1')]:
            second = {'id': gid, 'branch': branch, 'worktree': worktree,
                      'payload': 'targetPath:\n- other.ipynb\nworktree: %s\nbranch: %s\n' % (worktree, branch)}
            with self.subTest(second=second), self.assertRaisesRegex(ValueError, 'Duplicate recovery'):
                rvq.recovery_reservations({'grains': [first, second]})

    def test_recovery_rejects_ambiguous_target_blocks(self):
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': 'D:/vibe/g1'}
        for payload in ('targetPath note:\n- fake.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n',
                        'worktree: D:/vibe/g1\nbranch: wt/g1\ntargetPath:\n- held.ipynb\n',
                        'targetPath:\n- held.ipynb\nother: surprise\nworktree: D:/vibe/g1\nbranch: wt/g1\n',
                        'targetPath:\n- held.ipynb\ntargetPath:\n- other.ipynb\nworktree: D:/vibe/g1\nbranch: wt/g1\n'):
            with self.subTest(payload=payload), self.assertRaisesRegex(ValueError, 'target block'):
                rvq.recovery_reservations({'grains': [{**grain, 'payload': payload}]})

    def test_inflight_backup_target_is_excluded_from_new_candidates(self):
        grain = {"id": "reserved", "branch": "wt/reserved", "worktree": self.dir,
                 "payload": "targetPath:\n- held.ipynb\nworktree: x\n"}
        with open(self.path + '.bak', 'w', encoding='utf-8') as fh:
            json.dump({"grains": [grain]}, fh)
        old = rvq.load_queue(self.path + '.bak')
        with mock.patch.object(rvq, 'sh', side_effect=['1', '']):
            keep, _ = rvq.keepable(old, 'base', set())
        kept_paths = set().union(*(rvq.payload_paths(g) for g in keep))
        candidates = {'held.ipynb': ['finding'], 'free.ipynb': ['finding']}
        free = {p: f for p, f in candidates.items() if p not in kept_paths}
        self.assertEqual(keep, [grain])
        self.assertEqual(set(free), {'free.ipynb'})

    def test_simulated_backup_inflight_grain_stays_quarantined(self):
        self._write('')
        grain = {'id': 'g1', 'branch': 'wt/g1', 'worktree': self.dir,
                 'payload': 'targetPath:\n- held.ipynb\nworktree: %s\nbranch: wt/g1\n' % self.dir}
        with open(self.path + '.bak', 'w', encoding='utf-8') as fh:
            json.dump({'grains': [grain]}, fh)
        contract = {'scan': lambda _: {'held.ipynb': ['x']}}
        output = io.StringIO()
        with mock.patch.object(sys, 'argv', ['refresh-vibe-queue', '--queue', self.path,
                                            '--simulate-backup', '--dry-run', '--issue', '1']), \
             mock.patch.object(rvq, 'CONTRACTS', {1: contract}), \
             mock.patch.object(rvq, 'fresh_base', return_value='base'), \
             mock.patch.object(rvq, 'ensure_scan_wt', return_value='scan'), \
             mock.patch.object(rvq, 'open_prs', return_value=({}, set())), \
             mock.patch.object(rvq, 'issue_claims', return_value=set()), \
             mock.patch.object(rvq, 'merged_branches', return_value=set()), \
             mock.patch.object(rvq, 'sh', side_effect=['1', '']), \
             mock.patch.object(rvq, 'publish_text') as publish, redirect_stdout(output):
            rvq.main()
            publish.assert_not_called()
        self.assertIn('aucun finding libre', output.getvalue())
        with open(self.path, 'rb') as fh:
            self.assertEqual(fh.read(), b'')

    def test_unreadable_worktree_is_not_classified_as_empty(self):
        grain = {"id": "reserved", "branch": "wt/reserved", "worktree": self.dir}
        with mock.patch.object(rvq, 'sh', side_effect=['', '']):
            with self.assertRaises(ValueError):
                rvq.keepable({"grains": [grain]}, 'base', {'wt/reserved'})

    def test_failed_git_status_cannot_release_a_reservation(self):
        grain = {"id": "reserved", "branch": "wt/reserved", "worktree": self.dir}
        success = mock.Mock(returncode=0, stdout='0\n', stderr='')
        failure = mock.Mock(returncode=1, stdout='', stderr='git status failed')
        with mock.patch.object(rvq.subprocess, 'run', side_effect=[success, failure]):
            with self.assertRaises(SystemExit):
                rvq.keepable({"grains": [grain]}, 'base', {'wt/reserved'})

    def test_valid_queue_is_returned_unchanged(self):
        payload = {"_comment": "x", "grains": [{"id": "g1"}]}
        self._write(json.dumps(payload))
        self.assertEqual(rvq.load_queue(self.path), payload)

    def test_blank_previous_never_erases_a_good_backup(self):
        """A 0-byte queue must not rotate nothing over the last known-good .bak."""
        with io.open(self.path + ".bak", "w", encoding="utf-8", newline="\n") as fh:
            fh.write("KEEP-ME")
        self.assertFalse(rvq.preserve_previous(self.path, ""))
        with io.open(self.path + ".bak", encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "KEEP-ME")

    def test_non_blank_previous_rotates_into_bak(self):
        self._write("OLD")
        self.assertTrue(rvq.preserve_previous(self.path, '{"grains":[]}'))
        with io.open(self.path + ".bak", encoding="utf-8") as fh:
            self.assertEqual(fh.read(), '{"grains":[]}')

    def test_rotation_preserves_crlf_and_utf8_bytes(self):
        original = '{\r\n  "_comment": "réservé",\r\n  "grains": []\r\n}\r\n'.encode('utf-8')
        with open(self.path, 'wb') as fh:
            fh.write(original)
        with io.open(self.path, encoding='utf-8', newline='') as fh:
            previous = fh.read()
        self.assertTrue(rvq.preserve_previous(self.path, previous))
        with open(self.path + '.bak', 'rb') as fh:
            self.assertEqual(fh.read(), original)

    def test_publish_text_leaves_no_temporary_behind(self):
        rvq.publish_text(self.path, "NEW")
        with io.open(self.path, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "NEW")
        self.assertEqual(sorted(os.listdir(self.dir)), ["feeder-queue.json"])

    def test_publish_text_replaces_atomically_not_truncating(self):
        self._write("OLD")
        rvq.publish_text(self.path, "NEW")
        self.assertEqual(sorted(os.listdir(self.dir)), ["feeder-queue.json"])
        with io.open(self.path, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), "NEW")


if __name__ == "__main__":
    unittest.main()

