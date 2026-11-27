#!/usr/bin/env python3
"""#4434 G8a layer 2 — build the semantic re-read sample (blind, deterministic).

Rule (fixed on TIMESTAMPS ONLY, before any content was read): per cell
(key, model) among the six largest cells holding both arms, take the 2 pre-fix
and the 2 post-fix summaries whose best pairing minimises the summed time gap
(some cells have two seats on different builds, so the arms interleave).
Sample ids are neutral (S01..S24) and shuffled with a fixed seed so a reader
is not told which arm a pair belongs to.
Writes <dir>/Sxx_originals.md and <dir>/Sxx_summary.md + index.json.
"""
import itertools
import json
import os
import random
import re
import sys
from datetime import datetime

ARCH, PAIRS, OUTDIR = sys.argv[1], sys.argv[2], sys.argv[3]
MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)
CS_RE = re.compile(r"\*\*CONDENSATION-SUMMARY\*\* - ([0-9T:.Z-]+)")
CELLS = [
    ("global", "glm-4.7"),
    ("workspace-cluster-coordination", "glm-4.7"),
    ("workspace-CoursIA-2", "deepseek-v4-flash"),
    ("workspace-CoursIA-3", "deepseek-v4-flash"),
    ("workspace-claudish", "deepseek-v4-flash"),
    ("workspace-CoursIA", "deepseek-v4-flash"),
]


def messages(text):
    hs = list(MSG_HEADER_RE.finditer(text))
    return [(h.group(1), h.group(2),
             text[h.end(): (hs[i + 1].start() if i + 1 < len(hs) else len(text))])
            for i, h in enumerate(hs)]


def load(fn):
    with open(os.path.join(ARCH, fn), encoding="utf-8", errors="replace") as f:
        return f.read()


def ts(t):
    return datetime.strptime(t[:19], "%Y-%m-%dT%H:%M:%S").timestamp()


def closest_pairs(cell, k=2):
    pre = [r for r in cell if not r["has_transverse"]]
    post = [r for r in cell if r["has_transverse"]]
    best = None
    for ps in itertools.combinations(pre, k):
        for qs in itertools.combinations(post, k):
            for perm in itertools.permutations(qs):
                gap = sum(abs(ts(p["summary_ts"]) - ts(q["summary_ts"])) for p, q in zip(ps, perm))
                if best is None or gap < best[0]:
                    best = (gap, list(zip(ps, perm)))
    return best[1], best[0] / 3600


rows = [r for r in json.load(open(PAIRS, encoding="utf-8"))["rows"] if "model" in r]
os.makedirs(OUTDIR, exist_ok=True)
for stale in os.listdir(OUTDIR):
    if re.match(r"S\d\d_(originals|summary)\.md$", stale):
        os.remove(os.path.join(OUTDIR, stale))
picked = []
for key, model in CELLS:
    cell = sorted((r for r in rows if r["key"] == key and r["model"] == model),
                  key=lambda r: r["summary_ts"])
    pairs, gap = closest_pairs(cell)
    print(f"cell {key}/{model}: pairs=" + " ".join(
        f"[{p['summary_ts'][5:16]} -> {q['summary_ts'][5:16]}]" for p, q in pairs) + f"  summed gap {gap:.1f} h")
    for p, q in pairs:
        picked.append({"key": key, "model": model, "arm": "pre", "row": p})
        picked.append({"key": key, "model": model, "arm": "post", "row": q})
random.Random(4434).shuffle(picked)
index = []
for i, p in enumerate(picked, 1):
    sid = f"S{i:02d}"
    r = p["row"]
    omsgs = [(t, a, c) for t, a, c in messages(load(r["target"])) if a != "system|system"]
    sbody = None
    for _, a, c in messages(load(r["carrier"])):
        m = CS_RE.search(c)
        if a == "system|system" and m and m.group(1) == r["summary_ts"]:
            sbody = c[m.end():].strip()
            break
    with open(os.path.join(OUTDIR, f"{sid}_originals.md"), "w", encoding="utf-8") as f:
        f.write(f"# {len(omsgs)} messages (dashboard '{p['key']}', archived {r['target_ts']}Z)\n\n")
        for t, a, c in omsgs:
            f.write(f"### [{t}] {a}\n\n{c.strip()}\n\n---\n\n")
    with open(os.path.join(OUTDIR, f"{sid}_summary.md"), "w", encoding="utf-8") as f:
        f.write(sbody + "\n")
    index.append({
        "id": sid, "key": p["key"], "model": p["model"], "arm": p["arm"],
        "summary_ts": r["summary_ts"], "target": r["target"], "carrier": r["carrier"],
        "msgs": len(omsgs),
        "orig_bytes": sum(len(c.encode("utf-8")) for _, _, c in omsgs),
        "sum_bytes": len(sbody.encode("utf-8")),
        "has_transverse": r["has_transverse"],
    })
json.dump(index, open(os.path.join(OUTDIR, "index.json"), "w", encoding="utf-8"),
          ensure_ascii=False, indent=1)
print(f"samples={len(index)}")
for x in index:
    print(f"{x['id']} {x['key']:30s} {x['model']:18s} {x['arm']:4s} ts={x['summary_ts']} msgs={x['msgs']:2d} "
          f"orig={x['orig_bytes']:6d}B sum={x['sum_bytes']:5d}B tr={x['has_transverse']}")
