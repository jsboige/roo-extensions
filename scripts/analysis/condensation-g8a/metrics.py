#!/usr/bin/env python3
"""#4434 G8a layer 1 — deterministic conservation metrics, full population.

For every PAIRED production summary (pairs.json from pair.py):
  O = non-system messages of the target archive (the originals)
  S = the CONDENSATION-SUMMARY text archived in the carrier
Metrics are LEXICAL (token presence) — proxies, not semantic omission counts:
  id_recall    distinct issue/PR/comment ids of O found verbatim in S
  num_recall   distinct salient numbers of O found verbatim in S
  author_recall distinct authors of O named in S (short machine forms)
  st_recall    cross-cutting-state marker families present in O and found in S
  st_all_kept  1 if every marker family present in O is found in S
Output: per-row metrics (no text) + pooled and within-cell PRE/POST tables.
Arm: POST = S carries the `### États transverses` heading, PRE = it does not.
"""
import json
import os
import re
import sys
from collections import defaultdict

ARCH, PAIRS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]

MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)
CS_RE = re.compile(r"\*\*CONDENSATION-SUMMARY\*\* - ([0-9T:.Z-]+)")

ID_RE = re.compile(r"(?<![A-Za-z0-9])(?:ms#|jsboige-mcp-servers#)?#\d{2,5}(?!\d)|(?<![A-Za-z0-9])issuecomment-\d{6,}|(?<![\w.])c\.\d{8,}")
NUM_RE = re.compile(r"\d+(?:[   ]\d{3})*(?:[.,]\d+)?")
STRIP_RE = re.compile(
    r"\b\d{4}-\d{2}-\d{2}(T[\d:.Z-]+)?\b|\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\b|\b\d{1,2}:\d{2}(?::\d{2})?\s*Z\b"
    r"|\b[0-9a-f]{7,40}\b|#\d{2,5}|issuecomment-\d+|\bc\.\d{8,}|\bmsg-\d{8}T\d{6}-\w+"
    r"|\bv?\d+\.\d+\.\d+(?:\.\d+)?\b")
AUTHOR_SHORT = [
    ("myia-po-2023", "po-2023"), ("myia-po-2024", "po-2024"), ("myia-po-2025", "po-2025"),
    ("myia-po-2026", "po-2026"), ("myia-po-2027", "po-2027"), ("myia-po-2028", "po-2028"),
    ("myia-ai-01", "ai-01"), ("myia-web1", "web1"), ("myia-web2", "web2"),
]
# cross-cutting-state marker families (issue #4434 G7a-1 classes, lexical proxies)
STATE_FAMILIES = [
    ("uac", re.compile(r"\bUAC\b")),
    ("registre", re.compile(r"registre", re.I)),
    ("ask_user", re.compile(r"ASK[-_ ]?USER", re.I)),
    ("exit1", re.compile(r"exit\s*`?1\b", re.I)),
    ("urgent", re.compile(r"\bURGENT\b", re.I)),
    ("pause", re.compile(r"\bpaus(?:e|é|ée|ées|er)\b", re.I)),
    ("handoff", re.compile(r"hand-?off", re.I)),
    ("deny", re.compile(r"\bDENY\b|\bdeny\b", re.I)),
    ("claim", re.compile(r"\bclaims?\b", re.I)),
    ("degraded", re.compile(r"DEGRADED|REPAIRED", re.I)),
    ("question_id", re.compile(r"\bQ-?[A-Za-z]*\d+(-\d+)?\b")),
    ("fenetre_user", re.compile(r"fen[êe]tre (?:user|UAC|d'[ée]l[ée]vation)", re.I)),
]


def messages(text):
    hs = list(MSG_HEADER_RE.finditer(text))
    return [(h.group(1), h.group(2),
             text[h.end(): (hs[i + 1].start() if i + 1 < len(hs) else len(text))])
            for i, h in enumerate(hs)]


def ids(t):
    return {m.group(0) for m in ID_RE.finditer(t)}


def nums(t):
    t = STRIP_RE.sub(" ", t)
    out = set()
    for m in NUM_RE.finditer(t):
        s = m.group(0).replace(" ", "").replace(" ", "").replace(" ", "")
        if len(s.replace(".", "").replace(",", "")) < 2:
            continue
        if re.fullmatch(r"\d{4}", s) and 2020 <= int(s) <= 2030:
            continue  # bare year
        out.add(s.replace(",", "."))
    return out


_cache = {}


def load(fn):
    if fn not in _cache:
        with open(os.path.join(ARCH, fn), encoding="utf-8", errors="replace") as f:
            _cache[fn] = f.read()
    return _cache[fn]


rows = json.load(open(PAIRS, encoding="utf-8"))["rows"]
out = []
for r in rows:
    if "model" not in r:
        continue
    otext = "\n".join(c for _, a, c in messages(load(r["target"])) if a != "system|system")
    oauthors = {a for _, a, _ in messages(load(r["target"])) if a != "system|system"}
    sbody = None
    for _, a, c in messages(load(r["carrier"])):
        m = CS_RE.search(c)
        if a == "system|system" and m and m.group(1) == r["summary_ts"]:
            sbody = c[m.end():]
            break
    if sbody is None:
        continue
    io, iso = ids(otext), ids(sbody)
    no, nso = nums(otext), nums(sbody)
    sa = {short for full, short in AUTHOR_SHORT if any(full in a for a in oauthors)}
    au_hit = sum(1 for s in sa if s in sbody)
    fam_present, fam_hit = [], []
    for name, rx in STATE_FAMILIES:
        if rx.search(otext):
            fam_present.append(name)
            if rx.search(sbody):
                fam_hit.append(name)
    out.append({
        "summary_ts": r["summary_ts"], "target": r["target"],
        "key": r["key"], "model": r["model"], "day": r["target_ts"][:10],
        "arm": "post" if r["has_transverse"] else "pre",
        "msgs": int(r["msg_count"] or 0), "feed_bytes": r["feed_bytes"],
        "sum_bytes": len(sbody.strip().encode("utf-8")),
        "n_ids": len(io), "id_recall": len(io & iso) / len(io) if io else None,
        "n_nums": len(no), "num_recall": len(no & nso) / len(no) if no else None,
        "n_auth": len(sa), "author_recall": au_hit / len(sa) if sa else None,
        "n_fam": len(fam_present), "st_recall": len(fam_hit) / len(fam_present) if fam_present else None,
        "st_all_kept": (len(fam_hit) == len(fam_present)) if fam_present else None,
        "missing_fams": sorted(set(fam_present) - set(fam_hit)),
        "fam_present": fam_present, "fam_hit": fam_hit,
        "n_heads": len(r["headings"]),
    })

json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


def fmt(x):
    return "   —  " if x is None else f"{x:6.3f}"


print(f"paired summaries with metrics: {len(out)}")
for field in ("id_recall", "num_recall", "author_recall", "st_recall", "st_all_kept"):
    pre = [x[field] for x in out if x["arm"] == "pre"]
    post = [x[field] for x in out if x["arm"] == "post"]
    print(f"POOLED   {field:13s} pre={fmt(mean(pre))} (n={len([p for p in pre if p is not None])})  "
          f"post={fmt(mean(post))} (n={len([p for p in post if p is not None])})")
for field in ("sum_bytes", "msgs", "feed_bytes", "n_heads"):
    pre = [x[field] for x in out if x["arm"] == "pre"]
    post = [x[field] for x in out if x["arm"] == "post"]
    print(f"POOLED   {field:13s} pre={mean(pre):9.1f}  post={mean(post):9.1f}")

cells = defaultdict(lambda: {"pre": [], "post": []})
for x in out:
    cells[(x["key"], x["model"])][x["arm"]].append(x)
print()
print("WITHIN-CELL (key, model) PRE vs POST — only cells with both arms")
print(f"{'key':30s} {'model':18s} {'n pre/post':11s} | {'id_recall':17s} | {'num_recall':17s} | {'st_recall':17s} | {'st_all_kept':17s} | {'sum_bytes':15s}")
agg = defaultdict(list)
for k in sorted(cells):
    c = cells[k]
    if not c["pre"] or not c["post"]:
        continue
    a = c["pre"]
    b = c["post"]
    cells_ = []
    for field in ("id_recall", "num_recall", "st_recall", "st_all_kept"):
        pa, pb = mean([x[field] for x in a]), mean([x[field] for x in b])
        cells_.append(f"{fmt(pa)}→{fmt(pb)}".replace("  ", " "))
        agg[field].append((pa, pb, len(a), len(b)))
    ba, bb = mean([x["sum_bytes"] for x in a]), mean([x["sum_bytes"] for x in b])
    agg["sum_bytes"].append((ba, bb, len(a), len(b)))
    print(f"{k[0]:30s} {str(k[1]):18s} {len(a):2d}/{len(b):<8d} | {' | '.join(cells_)} | {ba:6.0f}→{bb:6.0f}")
print()
print("PER-FAMILY lexical carry-over  [present in originals -> found in summary]   pre (n, rate)   post (n, rate)")
for name, rx in STATE_FAMILIES:
    cells_f = []
    for arm in ("pre", "post"):
        sel = [x for x in out if x["arm"] == arm and name in x["fam_present"]]
        cells_f.append((len(sel), sum(1 for x in sel if name in x["fam_hit"]) / len(sel) if sel else None))
    print(f"  {name:12s} pre: {cells_f[0][0]:3d} {fmt(cells_f[0][1])}   post: {cells_f[1][0]:3d} {fmt(cells_f[1][1])}")
print()
print("POST-FIX by day: st_recall / st_all_kept / n / share>=5120B / mean bytes")
for d in sorted({x["day"] for x in out}):
    sel = [x for x in out if x["arm"] == "post" and x["day"] == d]
    if sel:
        print(f"  {d}: {fmt(mean([x['st_recall'] for x in sel]))} / {fmt(mean([x['st_all_kept'] for x in sel]))} / n={len(sel)} / "
              f"{sum(1 for x in sel if x['sum_bytes'] >= 5120)/len(sel):.3f} / {mean([x['sum_bytes'] for x in sel]):.0f}")
for arm in ("pre", "post"):
    sel = [x for x in out if x["arm"] == arm]
    print(f"  {arm}: share>=5120B={sum(1 for x in sel if x['sum_bytes'] >= 5120)/len(sel):.3f}  share>=5000B={sum(1 for x in sel if x['sum_bytes'] >= 5000)/len(sel):.3f}")
print()
for field, vals in agg.items():
    w = [min(va[2], va[3]) for va in vals]
    d = [va[1] - va[0] for va in vals]
    up = sum(1 for x in d if x > 0)
    down = sum(1 for x in d if x < 0)
    wmean = sum(di * wi for di, wi in zip(d, w)) / sum(w) if sum(w) else None
    print(f"WITHIN-CELL {field:13s} cells={len(vals)} post>pre: {up}  post<pre: {down}  tie: {len(vals)-up-down}  "
          f"min(n)-weighted mean delta={fmt(wmean)}  unweighted mean delta={fmt(mean(d))}")
