#!/usr/bin/env python3
"""#4434 — Condensation corpus scan (read-only).

Scans the RooSync shared-state dashboard archives and emits one JSONL row per
archive with: frontmatter fields (incl. statusOutcome/statusFallbackModel when
present), the outcome announced by the pass's CONDENSATION system message
(status size/mode, summary size, duration), and — for archives that embed
"## Statut avant condensation" (#3962, since 2026-10-04) — structural metrics
of that snapshot (byte size, presence of the 8 expected status sections).

Metadata only: no dashboard content is copied into the output. Section NAMES
are recorded (they come from the prompt template), not section bodies.

Usage:
    python scripts/analysis/condensation_corpus_scan.py \
        [--shared-state "G:/Mon Drive/Synchronisation/RooSync/.shared-state"] \
        [--keys global,workspace-roo-extensions] [--since 2026-05-01] \
        [--out corpus_index.jsonl]
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

STATUS_SECTIONS = [
    "Résumé",
    "État des systèmes",
    "Décisions actées",
    "Blocages structurels",
    "Livrables récents",
    "En cours",
    "Métriques de référence",
    "Patterns appris",
]

FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)
COND_MSG_RE = re.compile(r"\*\*CONDENSATION\*\* - (\S+)\n(.*?)(?=\n\n---|\n### |\Z)", re.S)
STATUS_KB_RE = re.compile(r"Statut mis à jour(?: via fallback cloud| \(déterministe\))? \(([\d.]+)KB\)")
STATUS_MODE_RE = re.compile(r"Statut mis à jour( via fallback cloud| \(déterministe\))? \(")
SUMMARY_KB_RE = re.compile(r"résumé LLM généré \(([\d.]+)KB\)")
DUR_RE = re.compile(r"Durée: (\d+)s")
ARCHIVED_N_RE = re.compile(r"(\d+) messages archivés")
KEPT_N_RE = re.compile(r"(\d+) messages conservés")
STATUS_BEFORE_RE = re.compile(
    r"## Statut avant condensation \(#3962\)\n(.*?)(?=\n### \[|\n## (?!#)|\Z)", re.S
)
FALLBACK_MARKER = "lastCondense: fallback-truncated"


def sha256_of(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_frontmatter(text: str) -> dict:
    m = FM_RE.match(text)
    fm = {}
    if m:
        for line in m.group(1).split("\n"):
            if ":" in line:
                k, v = line.split(":", 1)
                fm[k.strip()] = v.strip().strip("'\"")
    return fm


def section_metrics(status: str) -> dict:
    present = [s for s in STATUS_SECTIONS if re.search(r"#+\s*[^\n]*" + re.escape(s), status)]
    return {
        "sections_present": len(present),
        "section_names": present,
        "has_title_header": bool(re.search(r"^## \[", status, re.M)),
        "fallback_marker": FALLBACK_MARKER in status,
    }


def scan(archive_dir: str, keys: list, since: datetime, out_path: str) -> int:
    rows = []
    for fn in sorted(os.listdir(archive_dir)):
        key = next((k for k in keys if fn.startswith(k + "-")), None)
        if not key:
            continue
        m = re.match(r".*-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})(?:-\d+Z)?\.md$", fn)
        if not m:
            continue
        try:
            ts = datetime.fromisoformat(
                m.group(1) + "T" + m.group(2) + ":" + m.group(3) + ":" + m.group(4) + "+00:00"
            )
        except ValueError:
            continue
        if ts < since:
            continue
        path = os.path.join(archive_dir, fn)
        text = open(path, encoding="utf-8", errors="replace").read()
        row = {
            "file": fn,
            "key": key,
            "ts": ts.isoformat(),
            "bytes": os.path.getsize(path),
            "sha256": sha256_of(path),
        }
        row.update(parse_frontmatter(text))

        cm = COND_MSG_RE.search(text)
        if cm:
            body = cm.group(2)
            sm = STATUS_MODE_RE.search(body)
            if sm:
                row["status_mode"] = (sm.group(1) or "").strip() or "llm"
            kb = STATUS_KB_RE.search(body)
            if kb:
                row["status_kb"] = float(kb.group(1))
            skb = SUMMARY_KB_RE.search(body)
            if skb:
                row["summary_kb"] = float(skb.group(1))
            d = DUR_RE.search(body)
            if d:
                row["dur_s"] = int(d.group(1))
            an = ARCHIVED_N_RE.search(body)
            if an:
                row["archived_n"] = int(an.group(1))
            kn = KEPT_N_RE.search(body)
            if kn:
                row["kept_n"] = int(kn.group(1))

        sb = STATUS_BEFORE_RE.search(text)
        if sb:
            status = sb.group(1).strip()
            if len(status) >= 50:
                row["before_bytes"] = len(status.encode("utf-8"))
                row.update(section_metrics(status))

        rows.append(row)

    with open(out_path, "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    return len(rows)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    default_state = os.environ.get(
        "ROOSYNC_SHARED_PATH", "G:/Mon Drive/Synchronisation/RooSync/.shared-state"
    )
    ap.add_argument("--shared-state", default=default_state)
    ap.add_argument("--keys", default="global,workspace-roo-extensions")
    ap.add_argument("--since", default="2026-05-01")
    ap.add_argument("--out", default="condensation_corpus.jsonl")
    args = ap.parse_args()

    archive_dir = os.path.join(args.shared_state, "dashboards", "archive")
    if not os.path.isdir(archive_dir):
        print(f"error: archive dir not found: {archive_dir}", file=sys.stderr)
        return 2
    since = datetime.fromisoformat(args.since).replace(tzinfo=timezone.utc)
    n = scan(archive_dir, args.keys.split(","), since, args.out)
    print(f"scanned={n} -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
