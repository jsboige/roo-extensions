#!/usr/bin/env python3
"""Export the #4801 seed eval to the Memorilla own-data layout.

Reads seed-eval.jsonl (question/answer pairs mined from the workspace memory
fiches, baseline-annotated) plus a corpus directory of .md fiches, and writes
the parquet layout that snap-stanford/memorilla expects under a data repo
(docs/data.md "Using your own data"):

    <output_dir>/data/<task>/test-00000-of-00001.parquet
        columns: collection_id, question, answer, documents

One row per eval question; `documents` is the SAME full corpus (all fiches) for
every row, so the memory module must find the needle itself — the PersonaMem
shape. Only the `test` split is written: this export is for EVALUATION
(evaluate.py --split test), never for training (a train split copied from eval
rows would be leakage).

Usage (on the rented 80 GB GPU box, inside the memorilla venv):
    python export_memorilla_dataset.py \
        --eval seed-eval.jsonl \
        --corpus-dir <workspace memory dir> \
        --output-dir .tmp/memorilla-dataset/my_data

    cd memorilla && python evaluate.py --data_repo ../.tmp/memorilla-dataset/my_data \
        --config roo_memory --split test --scoring generation \
        --checkpoint <path or memorilla/Memorilla-Qwen3-8B:pmv2>

Requires: pandas, pyarrow (present in the memorilla venv).
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(65536), b""):
            h.update(block)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--eval", default=Path(__file__).parent / "seed-eval.jsonl")
    ap.add_argument("--corpus-dir", required=True,
                    help="Directory of .md documents (e.g. the workspace memory fiches)")
    ap.add_argument("--output-dir", required=True,
                    help="Output data-repo root (will contain data/<task>/)")
    ap.add_argument("--task", default="roo_memory")
    # Memorilla's reader does int(collection_id) (EmbeddingStore._position), so
    # the column must be int64: a string id stops the bench before generation.
    ap.add_argument("--collection", type=int, default=0)
    ap.add_argument("--max-chars-per-doc", type=int, default=120_000,
                    help="Hard cap per document; a fiche is ~1-8 KB so this never bites")
    args = ap.parse_args()

    eval_path = Path(args.eval)
    corpus_dir = Path(args.corpus_dir)
    out_root = Path(args.output_dir)

    rows = []
    with eval_path.open(encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    if not rows:
        print(f"ERROR: no rows in {eval_path}", file=sys.stderr)
        return 1

    corpus_files = sorted(p for p in corpus_dir.glob("*.md") if p.is_file())
    if not corpus_files:
        print(f"ERROR: no .md files in {corpus_dir}", file=sys.stderr)
        return 1

    documents = []
    manifest_docs = []
    for p in corpus_files:
        text = p.read_text(encoding="utf-8", errors="replace")[: args.max_chars_per_doc]
        header = f"[{p.name}]\n"
        documents.append(header + text)
        manifest_docs.append({"file": p.name, "sha256": sha256(p), "chars": len(text)})

    try:
        import pandas as pd
    except ImportError:
        print("ERROR: pandas required (present in the memorilla venv)", file=sys.stderr)
        return 1

    task_dir = out_root / "data" / args.task
    task_dir.mkdir(parents=True, exist_ok=True)
    parquet_path = task_dir / "test-00000-of-00001.parquet"
    df = pd.DataFrame({
        "collection_id": pd.Series([args.collection] * len(rows), dtype="int64"),
        "question": [r["question"] for r in rows],
        "answer": [r["gold_answer"] for r in rows],
        "documents": [documents] * len(rows),
    })
    df.to_parquet(parquet_path, index=False)

    manifest = {
        "task": args.task,
        "collection_id": args.collection,
        "split": "test",
        "rows": len(rows),
        "question_ids": [r["id"] for r in rows],
        "corpus_dir": str(corpus_dir),
        "corpus_documents": manifest_docs,
        "parquet": {"path": str(parquet_path), "sha256": sha256(parquet_path)},
        "notes": (
            "Gold answers are condensed from memory fiches; the corpus given to the "
            "memory module is the RAW fiche text. Evaluation only — no train split."
        ),
    }
    (task_dir / "MANIFEST.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"rows={len(rows)} docs={len(documents)} -> {parquet_path}")
    print(f"manifest: {task_dir / 'MANIFEST.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
