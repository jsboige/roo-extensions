#!/usr/bin/env python3
"""Unit tests for refresh-vibe-queue.py multi-contract extension (#16472, GO ai-01 17/09).

Covers the pure pieces: hierarchy census parsing, [CLAIMED...] path
extraction (the pre-PR deconfliction gap measured on #16472 fournée 1),
family-level grouping for contract 16472, and payload sanity per contract.
"""

import importlib.util
import os
import tempfile
import unittest

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
                       "JAMAIS fabriquer un chiffre", "CHECKPOINT-COMMIT"):
            self.assertIn(marker, p, "payload 13410 sans %r" % marker)
        self.assertLessEqual(len(p.encode("utf-8")), 3 * 1024)

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
        """L'organe de merge CoursIA (FROZEN_BRANCH_PREFIXES, defini dans
        scripts/coordination/frozen_campaigns.py et importe par merge_ready.py)
        range tout `wt/vibe-*` dans la famille gelee #13410, quelle que soit son
        issue reelle. Un grain
        non-densite nomme ainsi produit donc un livrable que rien ne mergera
        (mesure 25/09 : grain #16472 parti sur `wt/vibe-g2-...`). Seul #13410,
        qui EST cette famille, garde le prefixe."""
        self.assertTrue(rvq.CONTRACTS[13410]["branch_prefix"].startswith("wt/vibe-"))
        for i in (15719, 16472):
            self.assertFalse(
                rvq.CONTRACTS[i]["branch_prefix"].startswith("wt/vibe-"),
                "contrat #%d : un prefixe wt/vibe- le gele en #13410" % i)

    def test_default_issue_selection_excludes_the_frozen_contract(self):
        """Le feeder re-mesure la file SANS filtre des qu'elle est vide. Si le
        defaut incluait le contrat gele, chaque epuisement de file rouvrirait
        mecaniquement le dispatch densite sous veto #17040 (mesure 25-26/09 :
        file reconstruite a 121 grains dont 120 de #13410 en une nuit). Le
        defaut doit donc ne servir QUE le non-gele ; un --issue 13410
        explicite reste la voie operatoire pour lever la garde."""
        self.assertEqual(rvq.default_issues(), [15719, 16472, 17712])
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


if __name__ == "__main__":
    unittest.main()
