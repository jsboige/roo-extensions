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


class TestContracts(unittest.TestCase):
    def test_registry_has_both_active_contracts(self):
        self.assertEqual(sorted(rvq.CONTRACTS), [15719, 16472])

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


if __name__ == "__main__":
    unittest.main()
