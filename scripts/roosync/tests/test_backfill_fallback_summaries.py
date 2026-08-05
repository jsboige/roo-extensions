#!/usr/bin/env python3
"""test_backfill_fallback_summaries.py — tests unitaires pour #8889 backfill.

Couverture :
  - parse_frontmatter : frontmatter valide, absent, mal forme
  - is_fallback_candidate : detection via fallbackTruncation (pas le nom de fichier)
  - is_already_backfilled : idempotence
  - within_age_window : frontiere 30j
  - heuristic_summary : produit un resume non-vide a partir de messages
  - build_backfilled_content : preservation verbatim des messages
  - backfill_one dry-run vs apply
  - Round-trip idempotent (2 passes)
"""

import os
import re
import shutil
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

# Permet l'import depuis le repertoire parent
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from backfill_fallback_summaries import (
    ArchiveFile,
    backfill_one,
    build_backfilled_content,
    heuristic_summary,
    is_already_backfilled,
    is_fallback_candidate,
    load_archive,
    parse_frontmatter,
    within_age_window,
)


def make_archive(text: str) -> ArchiveFile:
    """Helper : wrap un text comme ArchiveFile minimal."""
    fm, body_start = parse_frontmatter(text)
    archived_at = None
    if isinstance(fm.get("archivedAt"), str):
        try:
            archived_at = datetime.fromisoformat(
                fm["archivedAt"].replace("Z", "+00:00")
            )
        except ValueError:
            pass
    return ArchiveFile(
        path=Path("/fake/archive.md"),
        frontmatter=fm,
        raw_text=text,
        body_start=body_start,
        archived_at=archived_at,
    )


SAMPLE_FALLBACK = """---
type: archive
originalKey: workspace-Test-2026-05-15T05-08-22
archivedAt: '2026-05-15T05:08:22.460Z'
messageCount: 3
llmGenerated: false
fallbackTruncation: true
circuitBreakerOpen: true
---

# Archive (fallback): workspace-Test-2026-05-15T05-08-22

Archived: 2026-05-15T05:08:22.460Z
Messages: 3
Method: Truncation fallback (LLM unavailable)

[FALLBACK TRUNCATION] Le condenseur a renvoyé un circuit breaker ouvert. Les messages ci-dessous sont préservés intacts.

---

### [2026-05-15T04:30:00.000Z] myia-ai-01:workspace-CoursIA

**Sujet**: Test message 1

Premier message du test.

### [2026-05-15T04:35:00.000Z] myia-po-2023:workspace-CoursIA-2

**Sujet**: Reponse 1

Reponse au premier message.

### [2026-05-15T04:40:00.000Z] myia-ai-01:workspace-CoursIA

**Sujet**: Suite

Suite du premier message.
"""


SAMPLE_NORMAL_NO_FALLBACK = """---
type: archive
originalKey: workspace-Test-2026-05-15T05-08-22
archivedAt: '2026-05-15T05:08:22.460Z'
messageCount: 3
llmGenerated: true
---

# Archive: workspace-Test-2026-05-15T05-08-22

Archives normales.

---

### [2026-05-15T04:30:00.000Z] myia-ai-01:workspace-CoursIA

Message.
"""


SAMPLE_ALREADY_BACKFILLED = """---
type: archive
originalKey: workspace-Test
archivedAt: '2026-05-15T05:08:22.460Z'
messageCount: 1
llmGenerated: true
fallbackTruncation: false
backfilledAt: '2026-05-20T10:00:00.000Z'
backfillMode: heuristic
---

Archive deja backfillede.
"""


class TestParseFrontmatter(unittest.TestCase):
    def test_valid_frontmatter(self):
        text = "---\nkey: value\n---\nbody"
        fm, offset = parse_frontmatter(text)
        self.assertEqual(fm, {"key": "value"})
        self.assertEqual(text[offset:].strip(), "body")

    def test_no_frontmatter(self):
        text = "no frontmatter here"
        fm, offset = parse_frontmatter(text)
        self.assertEqual(fm, {})
        self.assertEqual(offset, 0)

    def test_invalid_yaml(self):
        text = "---\nkey: [unclosed\n---\nbody"
        fm, offset = parse_frontmatter(text)
        self.assertEqual(fm, {})
        self.assertGreater(offset, 0)


class TestCandidateDetection(unittest.TestCase):
    def test_fallback_candidate_true(self):
        arch = make_archive(SAMPLE_FALLBACK)
        self.assertTrue(is_fallback_candidate(arch))

    def test_fallback_candidate_false_normal(self):
        arch = make_archive(SAMPLE_NORMAL_NO_FALLBACK)
        self.assertFalse(is_fallback_candidate(arch))

    def test_already_backfilled(self):
        arch = make_archive(SAMPLE_ALREADY_BACKFILLED)
        self.assertTrue(is_already_backfilled(arch))

    def test_not_backfilled(self):
        arch = make_archive(SAMPLE_FALLBACK)
        self.assertFalse(is_already_backfilled(arch))


class TestAgeWindow(unittest.TestCase):
    def test_within_window(self):
        # Date archive = aujourd'hui - 5 jours, max = 30j -> in
        arch = make_archive(SAMPLE_FALLBACK)
        arch.archived_at = datetime.now(timezone.utc) - timedelta(days=5)
        self.assertTrue(within_age_window(arch, 30))

    def test_outside_window(self):
        # Date archive = aujourd'hui - 60 jours, max = 30j -> out
        arch = make_archive(SAMPLE_FALLBACK)
        arch.archived_at = datetime.now(timezone.utc) - timedelta(days=60)
        self.assertFalse(within_age_window(arch, 30))

    def test_no_date(self):
        arch = make_archive(SAMPLE_FALLBACK)
        arch.archived_at = None
        self.assertFalse(within_age_window(arch, 30))


class TestHeuristicSummary(unittest.TestCase):
    def test_produces_non_empty_summary(self):
        # Extrait une partie representative du sample
        messages = """
### [2026-05-15T04:30:00.000Z] myia-ai-01:workspace-CoursIA

**Sujet**: Test message 1

Premier message du test.

### [2026-05-15T04:35:00.000Z] myia-po-2023:workspace-CoursIA-2

**Sujet**: Reponse

Une reponse.

### [2026-05-15T04:40:00.000Z] myia-ai-01:workspace-CoursIA

**Sujet**: Suite

Suite.
"""
        summary = heuristic_summary(messages, 3)
        self.assertIn("3 messages", summary)
        self.assertIn("Resume", summary)


class TestVerbatimPreservation(unittest.TestCase):
    def test_message_count_preserved(self):
        """Le contenu verbatim des messages doit etre preserve (AC #2 #8889)."""
        arch = make_archive(SAMPLE_FALLBACK)
        # Pas de LLM -> mode heuristique
        # Calcule un resume manuellement
        summary = "RESUME TEST 12345"
        new_raw = build_backfilled_content(arch, summary, "heuristic", None)

        # Compte les blocs de message
        old_count = len(re.findall(r"^###\s+\[[^\]]+\]", arch.raw_text, re.MULTILINE))
        new_count = len(re.findall(r"^###\s+\[[^\]]+\]", new_raw, re.MULTILINE))
        self.assertEqual(old_count, new_count,
                         f"Message count changed: {old_count} -> {new_count}")

        # Le resume doit etre dans le nouveau contenu
        self.assertIn("RESUME TEST 12345", new_raw)
        # L'ancien fallback doit avoir disparu
        self.assertNotIn("[FALLBACK TRUNCATION]", new_raw)
        # llmGenerated doit etre true maintenant
        self.assertIn("llmGenerated: true", new_raw)
        self.assertIn("backfilledAt:", new_raw)


class TestApplyDryRun(unittest.TestCase):
    def test_dry_run_does_not_modify_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = Path(tmpdir) / "test-fallback.md"
            archive_path.write_bytes(SAMPLE_FALLBACK.encode("utf-8"))

            # Force archived_at recent
            text = SAMPLE_FALLBACK.replace(
                "'2026-05-15T05:08:22.460Z'",
                f"'{datetime.now(timezone.utc).isoformat()}'"
            )
            archive_path.write_bytes(text.encode("utf-8"))

            arch = load_archive(archive_path)
            self.assertIsNone(arch.skipped_reason,
                              f"Archive mal classee: {arch.skipped_reason}")

            # Dry-run
            result = backfill_one(arch, llm_config=None, dry_run=True)
            self.assertEqual(result.status, "backfilled")

            # Le fichier NE doit PAS etre modifie
            new_content = archive_path.read_text("utf-8")
            self.assertIn("[FALLBACK TRUNCATION]", new_content,
                          "Dry-run aurait du laisser le fichier inchange")

    def test_apply_modifies_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = Path(tmpdir) / "test-fallback.md"
            recent = f"'{datetime.now(timezone.utc).isoformat()}'"
            text = SAMPLE_FALLBACK.replace("'2026-05-15T05:08:22.460Z'", recent)
            archive_path.write_bytes(text.encode("utf-8"))

            arch = load_archive(archive_path)
            self.assertIsNone(arch.skipped_reason)

            # Apply
            result = backfill_one(arch, llm_config=None, dry_run=False)
            self.assertEqual(result.status, "backfilled")
            self.assertEqual(result.mode, "heuristic")

            # Le fichier DOIT etre modifie
            new_content = archive_path.read_text("utf-8")
            self.assertNotIn("[FALLBACK TRUNCATION]", new_content)
            self.assertIn("backfilledAt:", new_content)

            # L'ecriture passe par un tmp + os.replace (atomicite sur un
            # partage GDrive). Le tmp ne doit rien laisser derriere lui :
            # un residu .tmp dans le repertoire partage serait un defaut
            # introduit par l'atomicite elle-meme.
            self.assertEqual(list(Path(tmpdir).glob("*.tmp")), [])

    def test_interrupted_write_leaves_archive_intact(self):
        """Une ecriture coupee en cours ne doit pas tronquer l'archive.

        C'est la raison d'etre du tmp + os.replace : ces archives sont du
        patrimoine partage, sur un repertoire GDrive synchronise par six
        machines. Process tue, G: qui decroche, disque plein -> l'archive
        d'origine doit rester lisible, et aucun .tmp ne doit subsister.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = Path(tmpdir) / "test-fallback.md"
            recent = f"'{datetime.now(timezone.utc).isoformat()}'"
            text = SAMPLE_FALLBACK.replace("'2026-05-15T05:08:22.460Z'", recent)
            archive_path.write_bytes(text.encode("utf-8"))
            original = archive_path.read_bytes()

            arch = load_archive(archive_path)
            real_write_bytes = Path.write_bytes

            def interrupted_write(self, data):
                # Coupe l'ecriture a mi-parcours, QUELLE QUE SOIT sa cible :
                # l'archive elle-meme (ecriture en place) ou un tmp. Les deux
                # implementations subissent donc exactement le meme incident,
                # et c'est l'etat de l'archive apres coup qui les departage.
                real_write_bytes(self, data[: len(data) // 2])
                raise OSError("ecriture interrompue")

            with patch.object(Path, "write_bytes", interrupted_write):
                with self.assertRaises(OSError):
                    backfill_one(arch, llm_config=None, dry_run=False)

            self.assertEqual(archive_path.read_bytes(), original)
            self.assertEqual(list(Path(tmpdir).glob("*.tmp")), [])


class TestIdempotence(unittest.TestCase):
    def test_second_pass_skips_via_fallback_flag(self):
        """Une archive deja backfillede a fallbackTruncation:false -> non-candidate.

        AC #3 (#8889 idempotence) est garantie par DEUX mecanismes :
        - fallbackTruncation:false post-backfill -> is_fallback_candidate retourne False
        - backfilledAt present -> is_already_backfilled retourne True (defense in depth)

        Ce test verifie le premier mecanisme (canonique) ; le second est teste
        dans TestCandidateDetection.test_already_backfilled.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = Path(tmpdir) / "test-fallback.md"
            archive_path.write_bytes(SAMPLE_ALREADY_BACKFILLED.encode("utf-8"))
            loaded = load_archive(archive_path)
            # Mecanisme 1 : fallbackTruncation:false -> non-candidate
            self.assertEqual(loaded.skipped_reason, "not-fallback")

            result = backfill_one(loaded, llm_config=None, dry_run=False)
            self.assertEqual(result.status, "skipped")
            self.assertEqual(result.reason, "not-fallback")

    def test_idempotence_marker_works_if_fallback_flag_missing(self):
        """Defense in depth : si jamais fallbackTruncation n'est pas mis a false,
        backfilledAt doit quand meme empecher le re-traitement."""
        # Construit une archive avec fallbackTruncation:true MAIS backfilledAt present
        # (cas pathologique : un backfill interrompu avant la mise a jour du flag)
        text = SAMPLE_FALLBACK.replace(
            "circuitBreakerOpen: true",
            "circuitBreakerOpen: true\nbackfilledAt: '2026-05-20T10:00:00.000Z'"
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            archive_path = Path(tmpdir) / "test-fallback.md"
            archive_path.write_bytes(text.encode("utf-8"))
            loaded = load_archive(archive_path)
            self.assertEqual(loaded.skipped_reason, "already-backfilled")

            result = backfill_one(loaded, llm_config=None, dry_run=False)
            self.assertEqual(result.status, "skipped")
            self.assertEqual(result.reason, "already-backfilled")


class TestLoadArchiveFiltering(unittest.TestCase):
    """Verifie la classification au chargement (skip reasons)."""

    def test_normal_archive_loads_as_skipped(self):
        """Une archive non-fallback est classee 'skipped' des le load."""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "normal.md"
            path.write_bytes(SAMPLE_NORMAL_NO_FALLBACK.encode("utf-8"))
            arch = load_archive(path)
            self.assertEqual(arch.skipped_reason, "not-fallback")

    def test_fallback_archive_loads_clean(self):
        """Une archive fallback eligible est classee sans skip."""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "test-fallback.md"
            recent = f"'{datetime.now(timezone.utc).isoformat()}'"
            text = SAMPLE_FALLBACK.replace("'2026-05-15T05:08:22.460Z'", recent)
            path.write_bytes(text.encode("utf-8"))
            arch = load_archive(path)
            # archived_at est recent -> pas skip
            self.assertIsNone(arch.skipped_reason)


if __name__ == "__main__":
    unittest.main(verbosity=2)
