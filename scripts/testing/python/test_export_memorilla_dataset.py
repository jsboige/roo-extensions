"""Contract tests for scripts/analysis/memorilla-pilot/export_memorilla_dataset.py (#4802).

Memorilla's reader converts the collection id with int() (EmbeddingStore._position)
before torch.searchsorted, so the exported `collection_id` column must be int64.
A string id made the bench stop before the first generation (review on #4802).
"""

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "scripts" / "analysis" / "memorilla-pilot" / "export_memorilla_dataset.py"

try:
    import pandas  # noqa: F401
    import pyarrow.parquet as pq
    import pyarrow as pa
    HAVE_PARQUET = True
except ImportError:
    HAVE_PARQUET = False


def _fixture(tmp: Path) -> tuple[Path, Path]:
    seed = tmp / "seed.jsonl"
    seed.write_text(
        "\n".join(json.dumps({"id": f"Q0{i}", "question": f"q{i}", "gold_answer": f"a{i}"})
                  for i in (1, 2)) + "\n",
        encoding="utf-8",
    )
    corpus = tmp / "corpus"
    corpus.mkdir()
    (corpus / "a.md").write_text("fiche a", encoding="utf-8")
    (corpus / "b.md").write_text("fiche b", encoding="utf-8")
    return seed, corpus


def _run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, timeout=120)


class CollectionIdContract(unittest.TestCase):
    def test_string_collection_id_is_refused_at_parse_time(self):
        # Runs without pandas: argparse rejects the value before any import.
        with tempfile.TemporaryDirectory() as d:
            seed, corpus = _fixture(Path(d))
            r = _run("--eval", str(seed), "--corpus-dir", str(corpus),
                     "--output-dir", str(Path(d) / "out"),
                     "--collection", "roo-memory-fiches-v1")
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn("--collection", r.stderr)

    @unittest.skipUnless(HAVE_PARQUET, "pandas/pyarrow absent")
    def test_exported_collection_id_is_int64(self):
        with tempfile.TemporaryDirectory() as d:
            seed, corpus = _fixture(Path(d))
            out = Path(d) / "out"
            r = _run("--eval", str(seed), "--corpus-dir", str(corpus),
                     "--output-dir", str(out))
            self.assertEqual(r.returncode, 0, r.stderr)
            task_dir = out / "data" / "roo_memory"
            table = pq.read_table(task_dir / "test-00000-of-00001.parquet")
            self.assertEqual(table.schema.field("collection_id").type, pa.int64())
            ids = table.column("collection_id").to_pylist()
            self.assertEqual(ids, [0, 0])
            # The reader's own conversion must succeed on the exported value.
            self.assertEqual(int(ids[0]), 0)
            manifest = json.loads((task_dir / "MANIFEST.json").read_text(encoding="utf-8"))
            self.assertEqual(manifest["collection_id"], 0)


if __name__ == "__main__":
    unittest.main()
