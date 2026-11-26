#!/usr/bin/env python3
"""#4434 G8a corpus scan (read-only, scratch).

Builds the table of PRODUCTION condensation summaries: one row per pass T.
  originals  = messages archived at T            (archive file T)
  summary    = the CONDENSATION-SUMMARY system message posted at T
               (it lives in the feed of a LATER archive of the same key)
  model      = frontmatter of archive T (summaryFallbackModel / summaryCloudFirst)
Output = counters, sizes and section NAMES only (no message or summary text).
"""
import json
import os
import re
import sys
from collections import defaultdict

ARCH = sys.argv[1]
OUT = sys.argv[2]
SINCE = sys.argv[3] if len(sys.argv) > 3 else "2026-11-21T12-00-00"

MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)
FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)
CS_RE = re.compile(r"\*\*CONDENSATION-SUMMARY\*\* - ([0-9T:.Z-]+)")
NOTICE_RE = re.compile(r"(\d+) messages archiv\és? dans `archive/([^`]+)`")
HEAD_RE = re.compile(r"^### (.+)$", re.M)
STATUS_SPLIT_RE = re.compile(r"^## Statut .*?\n", re.M)
FILE_RE = re.compile(r"^(.+)-(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})\.md$")


def parse_frontmatter(text):
    m = FM_RE.match(text)
    fm = {}
    if not m:
        return fm
    for line in m.group(1).split("\n"):
        if ":" in line and not line.startswith(" "):
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip("'\"")
    return fm


def messages(text):
    """[(ts, author, content)] for every `### [ts] author` block."""
    out = []
    hs = list(MSG_HEADER_RE.finditer(text))
    for i, h in enumerate(hs):
        end = hs[i + 1].start() if i + 1 < len(hs) else len(text)
        out.append((h.group(1), h.group(2), text[h.end():end]))
    return out


files = sorted(f for f in os.listdir(ARCH) if f.endswith(".md"))
rows = []
parse_errors = 0
for fn in files:
    m = FILE_RE.match(fn)
    if not m:
        continue
    key, day, hh, mm, ss = m.groups()
    ts = f"{day}T{hh}:{mm}:{ss}"
    if ts < SINCE:
        continue
    with open(os.path.join(ARCH, fn), encoding="utf-8", errors="replace") as f:
        text = f.read()
    fm = parse_frontmatter(text)
    try:
        msgs = messages(text)
    except Exception as e:  # noqa: BLE001
        parse_errors += 1
        rows.append({"file": fn, "error": repr(e)})
        continue
    summaries = []
    for tsx, author, content in msgs:
        c = CS_RE.search(content)
        if not c or author != "system|system":
            continue
        body = content[c.end():]
        heads = HEAD_RE.findall(body)
        fold = body.lower()
        summaries.append({
            "summary_ts": c.group(1),
            "bytes": len(body.strip().encode("utf-8")),
            "lines": body.strip().count("\n") + 1,
            "headings": heads,
            "has_transverse": "etats transverses" in fold.replace("É", "e")
            or "états transverses" in fold,
        })
    rows.append({
        "file": fn, "key": key, "ts": ts,
        "messageCount": fm.get("messageCount"),
        "summaryOutcome": fm.get("summaryOutcome"),
        "summaryModel": fm.get("summaryFallbackModel"),
        "summaryCloudFirst": fm.get("summaryCloudFirst"),
        "statusModel": fm.get("statusFallbackModel"),
        "summaries": summaries,
        "feed_msgs": sum(1 for a in (x[1] for x in msgs) if a != "system|system"),
        "feed_bytes": sum(len(x[2].encode("utf-8")) for x in msgs if x[1] != "system|system"),
    })

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"since": SINCE, "archives": len(rows), "parse_errors": parse_errors, "rows": rows},
              f, ensure_ascii=False, indent=1)

n_sum = sum(len(r.get("summaries", [])) for r in rows)
n_tr = sum(1 for r in rows for s in r.get("summaries", []) if s["has_transverse"])
by_model = defaultdict(lambda: [0, 0])
by_key_tr = defaultdict(lambda: [0, 0])
by_day = defaultdict(lambda: [0, 0])
for r in rows:
    for s in r.get("summaries", []):
        by_model[r.get("summaryModel")][0 if s["has_transverse"] else 1] += 1
        by_key_tr[r["key"]][0 if s["has_transverse"] else 1] += 1
        by_day[r["ts"][:10]][0 if s["has_transverse"] else 1] += 1
print(f"archives={len(rows)} parse_errors={parse_errors} summaries={n_sum} with_transverse={n_tr}")
print("by day  [transverse, without]:")
for d in sorted(by_day):
    print(f"  {d}: {by_day[d][0]} / {by_day[d][1]}")
print("by model  [transverse, without]:")
for k in sorted(by_model, key=lambda x: str(x)):
    print(f"  {k}: {by_model[k][0]} / {by_model[k][1]}")
print("by key  [transverse, without]:")
for k in sorted(by_key_tr):
    print(f"  {k}: {by_key_tr[k][0]} / {by_key_tr[k][1]}")
