#!/usr/bin/env python3
"""#4434 G8a — pair every production summary with the archive it summarizes.

Pairing key = the `system|system` notice that names `archive/<file>` (measured:
the archive precedes its summary by 0-120 s). Fallback = nearest archive of the
same key with archivedAt <= summary ts within 300 s.
Model / outcome / messageCount are read in the TARGET frontmatter (the pass
that produced the summary), never in the carrier (a later pass).
Output: counters, sizes, heading NAMES only.
"""
import json
import os
import re
import sys
from collections import Counter, defaultdict

ARCH, OUT, SINCE = sys.argv[1], sys.argv[2], sys.argv[3]

MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)
FM_RE = re.compile(r"^---\n(.*?)\n---\n", re.S)
CS_RE = re.compile(r"\*\*CONDENSATION-SUMMARY\*\* - ([0-9T:.Z-]+)")
NOTICE_RE = re.compile(r"(\d+) messages? archiv[ée]s? dans `archive/([^`]+)`")
HEAD_RE = re.compile(r"^### (.+)$", re.M)
FILE_RE = re.compile(r"^(.+)-(\d{4})-(\d{2})-(\d{2})T(\d{2})-(\d{2})-(\d{2})\.md$")


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
    hs = list(MSG_HEADER_RE.finditer(text))
    return [(h.group(1), h.group(2),
             text[h.end(): (hs[i + 1].start() if i + 1 < len(hs) else len(text))])
            for i, h in enumerate(hs)]


def epoch(ts):
    y, mo, d, hh, mi, ss = (int(x) for x in re.match(
        r"(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})", ts).groups())
    return (((((y * 100 + mo) * 100 + d) * 100 + hh) * 100 + mi) * 100 + ss)


def fold(s):
    return s.lower().replace("é", "e").replace("è", "e").replace("ê", "e")


index, texts = {}, {}
for fn in sorted(os.listdir(ARCH)):
    m = FILE_RE.match(fn)
    if not m:
        continue
    key, y, mo, d, hh, mi, ss = m.groups()
    ts = f"{y}-{mo}-{d}T{hh}:{mi}:{ss}"
    if ts < SINCE:
        continue
    try:
        with open(os.path.join(ARCH, fn), encoding="utf-8", errors="replace") as f:
            t = f.read()
    except OSError:
        continue
    texts[fn] = t
    index[fn] = {"fm": parse_frontmatter(t), "ts": ts, "key": key, "e": epoch(ts)}

by_key = defaultdict(list)
for fn, rec in index.items():
    by_key[rec["key"]].append(fn)

rows, unpaired = [], []
for fn, text in texts.items():
    key = index[fn]["key"]
    for i, (tsx, author, content) in enumerate(messages(text)):
        c = CS_RE.search(content)
        if not c or author != "system|system":
            continue
        sbody = content[c.end():].strip()
        sts = c.group(1)
        notice_target = None
        if i + 1 < len(messages(text)) and messages(text)[i + 1][1] == "system|system":
            nm = NOTICE_RE.search(messages(text)[i + 1][2])
            notice_target = nm.group(2) if nm else None
        target = notice_target if notice_target in index else None
        if target is None:
            se = epoch(sts)
            cands = [f for f in by_key[key] if 0 <= se - index[f]["e"] <= 300]
            target = max(cands, key=lambda f: index[f]["e"]) if cands else None
        rec = {"summary_ts": sts, "carrier": fn, "key": key, "target": target,
               "has_transverse": "etats transverses" in fold(sbody),
               "bytes": len(sbody.encode("utf-8")), "lines": sbody.count("\n") + 1,
               "headings": HEAD_RE.findall(sbody)}
        if target:
            tm = index[target]["fm"]
            rec.update({"model": tm.get("summaryFallbackModel"),
                        "outcome": tm.get("summaryOutcome"),
                        "msg_count": tm.get("messageCount"),
                        "target_ts": index[target]["ts"],
                        "feed_bytes": sum(len(x[2].encode("utf-8"))
                                          for x in messages(texts[target]) if x[1] != "system|system")})
        else:
            unpaired.append(rec)
        rows.append(rec)

with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"rows": rows, "unpaired": unpaired}, f, ensure_ascii=False, indent=1)

paired = [r for r in rows if "model" in r]
print(f"summaries={len(rows)} paired={len(paired)} unpaired={len(unpaired)}")
bd, bm, bk = defaultdict(lambda: [0, 0]), defaultdict(lambda: [0, 0]), defaultdict(lambda: [0, 0])
for r in paired:
    tag = 0 if r["has_transverse"] else 1
    bd[r["target_ts"][:10]][tag] += 1
    bm[r["model"]][tag] += 1
    bk[(r["target_ts"][:10], r["key"], r["model"])][tag] += 1
print("by day of ORIGINALS [signature / none]:")
for k in sorted(bd):
    print(f"  {k}: {bd[k][0]} / {bd[k][1]}")
print("by model that SERVED the summary [signature / none]:")
for k in sorted(bm, key=str):
    print(f"  {k}: {bm[k][0]} / {bm[k][1]}")
print()
print("candidate cells with BOTH arms (day, key, model) -> pre / post  [msgs]")
for k in sorted(bk):
    pre, post = bk[k][1], bk[k][0]
    if pre and post:
        print(f"  {k[0]}  {k[1]:26s} {str(k[2]):18s}  {pre:2d} / {post:2d}")
print()
print("unpaired examples:")
for r in unpaired[:10]:
    print(f"  {r['summary_ts']} {r['key']} carrier={r['carrier']}")
