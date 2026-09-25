#!/usr/bin/env python3
"""Unit tests for refresh-vibe-queue.py multi-contract extension (#16472, GO ai-01 17/09).

Covers the pure pieces: hierarchy census parsing, [CLAIMED...] path
extraction (the pre-PR deconfliction gap measured on #16472 fournée 1),
family-level grouping for contract 16472, and payload sanity per contract.
"""

import importlib.util
import os
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
        self.assertEqual(sorted(rvq.CONTRACTS), [13410, 15719, 16472])

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
        """L'organe de merge CoursIA (scripts/coordination/merge_ready.py:119,
        FROZEN_BRANCH_PREFIXES = {"wt/vibe-": "13410"}) range tout `wt/vibe-*`
        dans la famille gelee #13410, quelle que soit son issue reelle. Un grain
        non-densite nomme ainsi produit donc un livrable que rien ne mergera
        (mesure 25/09 : grain #16472 parti sur `wt/vibe-g2-...`). Seul #13410,
        qui EST cette famille, garde le prefixe."""
        self.assertTrue(rvq.CONTRACTS[13410]["branch_prefix"].startswith("wt/vibe-"))
        for i in (15719, 16472):
            self.assertFalse(
                rvq.CONTRACTS[i]["branch_prefix"].startswith("wt/vibe-"),
                "contrat #%d : un prefixe wt/vibe- le gele en #13410" % i)


if __name__ == "__main__":
    unittest.main()
