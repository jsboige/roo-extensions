#!/usr/bin/env python3
"""#4434 G8a layer 2 — final aggregation with the two corrections.

Correction 1 (mechanism, dashboard.ts:8066-8076): the summary is posted back into
intercom as a `system|system` message. A LATER pass archives it and feeds it to
the next summary. So a line a reader calls "unsupported by the originals" is
legitimate when its ids live in the archive's own system blocks. This script
downloads nothing: it re-reads the same archive the reader read.

Correction 2: adjudication.json (over-counted omission claims) and the
messageCount convention (n vs n+2).

Usage: aggregate.py <samples> <findings> <archive_dir> <adjudication> <truncation> <out>
"""
import json
import os
import re
import sys

SAMPLES, FINDINGS, ARCH, ADJ, TRUNC, OUT = sys.argv[1:7]

MSG_HEADER_RE = re.compile(r"^### \[([0-9T:.Z-]+)\] (.+)$", re.M)


def norm(s):
    return re.sub(r"\s+", " ", s or "").strip()


def fold(s):
    """Same folding as verify_quotes.fold: whitespace-normalised, lower-case,
    accent-insensitive over the full Latin-1 vowel set."""
    s = norm(s).lower()
    for a, b in (("é", "e"), ("è", "e"), ("ê", "e"), ("ë", "e"),
                 ("à", "a"), ("â", "a"), ("ä", "a"),
                 ("î", "i"), ("ï", "i"), ("ô", "o"), ("ö", "o"),
                 ("ù", "u"), ("û", "u"), ("ü", "u"), ("ç", "c"),
                 ("œ", "oe"), ("’", "'")):
        s = s.replace(a, b)
    return s


index = {x["id"]: x for x in json.load(open(os.path.join(SAMPLES, "index.json"), encoding="utf-8"))}
trunc = {x["id"]: x for x in json.load(open(TRUNC, encoding="utf-8"))}
adj = json.load(open(ADJ, encoding="utf-8"))
over = [(o["sample"], o["class"], fold(o["label_head"])) for o in adj["overcounted"]]

findings = []
for fn in sorted(os.listdir(FINDINGS)):
    if fn.endswith(".json"):
        data = json.load(open(os.path.join(FINDINGS, fn), encoding="utf-8"))
        for obj in (data if isinstance(data, list) else [data]):
            obj["_reader"] = fn            # one file = one reader
            findings.append(obj)


def system_blocks(target):
    """The `system|system` message blocks of the archive: prior summaries/notices,
    i.e. messages the pass legitimately had in its input."""
    t = open(os.path.join(ARCH, target), encoding="utf-8", errors="replace").read()
    hs = list(MSG_HEADER_RE.finditer(t))
    out = []
    for i, h in enumerate(hs):
        if h.group(2).startswith("system|system"):
            end = hs[i + 1].start() if i + 1 < len(hs) else len(t)
            out.append(t[h.end():end])
    return out


def msgcount_artifact(text):
    t = (text or "").replace("\\", "")
    return bool(re.search(r"(?:r[ée]sum[ée] des\s+)?\d+\s+messages", t, re.I))


rows = []
for obj in findings:
    sid = obj["sample"]
    x = index[sid]
    prior = system_blocks(x["target"])
    prior_txt = fold("\n".join(prior))
    om = list(obj.get("omitted") or [])
    ca = list(obj.get("carried") or [])
    reclass = 0
    keep_om = []
    for o in om:
        lab = fold(o.get("label") or "")
        hit = any(s == sid and c == o.get("class") and (lab.startswith(h[:25]) or h.startswith(lab[:25]))
                  for s, c, h in over)
        if hit:
            reclass += 1
            ca.append({"class": o.get("class"), "summary_line": "(adjudicated as carried)"})
        else:
            keep_om.append(o)
    om = keep_om
    prior_words = set(re.findall(r"[a-z0-9_]{5,}", prior_txt))

    def trace(line):
        """Share of the line's content words (>=5 chars, folded) found in the
        archive's own prior-summary blocks. None = too short to test."""
        w = re.findall(r"[a-z0-9_]{5,}", fold(line))
        if len(w) < 3:
            return None
        return sum(1 for x in w if x in prior_words) / len(w)

    def verdict(line):
        r = trace(line)
        if r is None:
            return "untested"
        return "prior" if r >= 0.8 else ("partial" if r >= 0.5 else "unsourced")

    fs_prior, fs_partial, fs_art, fs_kept, fs_untested = [], [], [], [], []
    for f in obj.get("false_or_unsupported") or []:
        sl = f.get("summary_line") or ""
        if msgcount_artifact(sl):
            fs_art.append(f)
            continue
        v = verdict(sl)
        {"prior": fs_prior, "partial": fs_partial, "unsourced": fs_kept, "untested": fs_untested}[v].append(f)
    nm_kept, nm_prior, nm_partial, nm_untested = [], 0, 0, 0
    prior_flat = re.sub(r"[\s  ]+", " ", "\n".join(prior))
    for n in obj.get("number_mismatches") or []:
        sv = str(n.get("summary_value") or "")
        if msgcount_artifact(sv):
            continue
        if re.fullmatch(r"\d+", sv.strip()) and int(sv) == x["msgs"] + 2:
            continue                      # the n+2 convention, not a defect
        toks = re.findall(r"\d[\d\s .,]*\d|\d", re.sub(r"[\s  ]+", " ", sv))
        toks = [t.strip(" .,") for t in toks if len(t.strip(" .,")) >= 2]
        if toks and all(t in prior_flat for t in toks):
            nm_prior += 1
            continue
        v = verdict(sv)
        if v == "prior":
            nm_prior += 1
        elif v == "partial":
            nm_partial += 1
        elif v == "untested":
            nm_untested += 1
            nm_kept.append(n)
        else:
            nm_kept.append(n)
    tot = len(om) + len(ca)
    rows.append({
        "id": sid, "arm": x["arm"], "key": x["key"], "model": x["model"], "reader": obj.get("_reader"),
        "states": obj.get("states_identified"), "omitted": len(om), "carried": len(ca),
        "share": (len(ca) / tot) if tot else None,
        "overcounted": reclass,
        "classes_omitted": [o.get("class") for o in om if o.get("class")],
        "classes_carried": [o.get("class") for o in ca if o.get("class")],
        "false": sum(1 for f in fs_kept if f.get("type") == "false"),
        "unsupported": sum(1 for f in fs_kept if f.get("type") != "false"),
        "false_prior": sum(1 for f in fs_prior if f.get("type") == "false"),
        "unsupported_prior": sum(1 for f in fs_prior if f.get("type") != "false"),
        "unsupported_partial": len(fs_partial), "unsupported_untested": len(fs_untested), "msgcount_art": len(fs_art),
        "contradictions": len(obj.get("unflagged_contradictions") or []),
        "num_kept": len(nm_kept), "num_prior": nm_prior, "num_partial": nm_partial, "num_untested": nm_untested, "numbers_checked": obj.get("numbers_checked"),
        "links": obj.get("clickable_links"),
        "prior_blocks": len(prior), "prior_bytes": len("\n".join(prior).encode("utf-8")),
        "truncated": bool(trunc.get(sid, {}).get("truncated")),
        "lines_removed": int(trunc.get(sid, {}).get("removed", 0)),
        "sum_bytes": x["sum_bytes"],
    })

json.dump(rows, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


print(f"samples={len(rows)}/{len(index)}")
print(f"{'id':4s} {'arm':4s} {'T':1s} {'pri':3s} {'states':6s} {'omit':4s} {'carr':4s} {'share':5s} {'oc':2s} {'false':5s} {'unsup':5s} {'->pri':5s} {'part':4s} {'art':3s} {'contr':5s} {'num':4s} {'numpri':6s}")
for r in sorted(rows, key=lambda r: r["id"]):
    share = "  —  " if r["share"] is None else f"{r['share']:.2f}"
    print(f"{r['id']:4s} {r['arm']:4s} {'T' if r['truncated'] else '-':1s} {r['prior_blocks']:3d} {str(r['states']):6s} "
          f"{r['omitted']:4d} {r['carried']:4d} {share:5s} "
          f"{r['overcounted']:2d} {r['false']:5d} {r['unsupported']:5d} {r['unsupported_prior']:5d} {r['unsupported_partial']:4d} {r['msgcount_art']:3d} {r['contradictions']:5d} {r['num_kept']:4d} {r['num_prior']:6d}")
print()
for arm in ("pre", "post"):
    s = [r for r in rows if r["arm"] == arm]
    o, c = sum(r["omitted"] for r in s), sum(r["carried"] for r in s)
    print(f"{arm:4s} n={len(s):2d} states={sum(r['states'] or 0 for r in s):3d} omitted={o:3d} carried={c:3d} "
          f"pooled_omission_share={o/(o+c):.3f} mean_sample_carried={mean([r['share'] for r in s]):.3f} "
          f"overcounted={sum(r['overcounted'] for r in s)} false={sum(r['false'] for r in s)} "
          f"unsupported_kept={sum(r['unsupported'] for r in s)} reclassified_prior={sum(r['unsupported_prior'] for r in s)} "
          f"false_prior={sum(r['false_prior'] for r in s)} partial_prior={sum(r['unsupported_partial'] for r in s)} "
          f"untested={sum(r['unsupported_untested'] for r in s)} "
          f"artifacts={sum(r['msgcount_art'] for r in s)} contradictions={sum(r['contradictions'] for r in s)} "
          f"num_mismatch={sum(r['num_kept'] for r in s)}/{sum(r['numbers_checked'] or 0 for r in s)} "
          f"num_prior={sum(r['num_prior'] for r in s)} num_partial={sum(r['num_partial'] for r in s)} "
          f"links={sum(r['links'] or 0 for r in s)} truncated={sum(1 for r in s if r['truncated'])} "
          f"bytes={mean([r['sum_bytes'] for r in s]):.0f} prior_bytes={mean([r['prior_bytes'] for r in s]):.0f}")
print()
print("PER CLASS omitted/carried (after adjudication)   pre        post")
for cls in range(1, 9):
    po = sum(r["classes_omitted"].count(cls) for r in rows if r["arm"] == "pre")
    pc = sum(r["classes_carried"].count(cls) for r in rows if r["arm"] == "pre")
    qo = sum(r["classes_omitted"].count(cls) for r in rows if r["arm"] == "post")
    qc = sum(r["classes_carried"].count(cls) for r in rows if r["arm"] == "post")
    f = lambda o, c: "  —  " if o + c == 0 else f"{o/(o+c):.2f}"
    print(f"  class {cls}: pre {po:2d}/{pc:2d} {f(po,pc)}   post {qo:2d}/{qc:2d} {f(qo,qc)}")
print()
print("PAIRED (same key+model, consecutive summaries)")
deltas = []
for key in sorted({(r["key"], r["model"]) for r in rows}):
    pre = sorted([r for r in rows if r["arm"] == "pre" and (r["key"], r["model"]) == key], key=lambda r: index[r["id"]]["summary_ts"])
    post = sorted([r for r in rows if r["arm"] == "post" and (r["key"], r["model"]) == key], key=lambda r: index[r["id"]]["summary_ts"])
    for a, b in zip(pre, post):
        if a["share"] is None or b["share"] is None:
            continue
        d = a["share"] - b["share"]
        deltas.append(d)
        print(f"  {key[0][:30]:30s} {a['id']}({a['omitted']}/{a['omitted']+a['carried']}) {a['share']:.2f} -> "
              f"{b['id']}({b['omitted']}/{b['omitted']+b['carried']}) {b['share']:.2f}  d={d:+.2f}")
if deltas:
    print(f"  pairs={len(deltas)} post_better(d<0)={sum(1 for d in deltas if d<0)} post_worse(d>0)={sum(1 for d in deltas if d>0)} "
          f"ties={sum(1 for d in deltas if d==0)} mean_d={mean(deltas):+.3f}")
print()
print(f"prior-summary blocks present: {sum(1 for r in rows if r['prior_blocks'])}/{len(rows)}  "
      f"mean prior bytes {mean([r['prior_bytes'] for r in rows]):.0f}")
print()
print("PER READER (one findings file = one reader; readers are not calibrated)")
by_reader = {}
for r in rows:
    by_reader.setdefault(r["reader"], []).append(r)
within = []
for rd in sorted(by_reader):
    s = by_reader[rd]
    o, c = sum(r["omitted"] for r in s), sum(r["carried"] for r in s)
    arms = "/".join(r["arm"][:2] for r in s)
    print(f"  {rd:14s} arms {arms:9s} n={len(s)} omitted {o:2d}/{o+c:2d} = {o/(o+c) if o+c else float('nan'):.2f}  "
          + " ".join(f"{r['id']}({r['omitted']}/{r['omitted']+r['carried']})" for r in s))
    pre_s = [r for r in s if r["arm"] == "pre" and r["share"] is not None]
    post_s = [r for r in s if r["arm"] == "post" and r["share"] is not None]
    if pre_s and post_s:
        within.append((rd, pre_s[0]["share"] - post_s[0]["share"], pre_s[0], post_s[0]))
if within:
    print("WITHIN-READER (readers that read one PRE and one POST; the two summaries are not the same cell)")
    for rd, d, a, b in within:
        print(f"  {rd:14s} {a['id']} {a['share']:.2f} -> {b['id']} {b['share']:.2f}  d={d:+.3f}")
    o_pre = sum(a["omitted"] for _, _, a, _ in within)
    t_pre = sum(a["omitted"] + a["carried"] for _, _, a, _ in within)
    o_post = sum(b["omitted"] for _, _, _, b in within)
    t_post = sum(b["omitted"] + b["carried"] for _, _, _, b in within)
    print(f"  readers={len(within)} post_better(d<0)={sum(1 for _, d, _, _ in within if d < 0)} "
          f"post_worse(d>0)={sum(1 for _, d, _, _ in within if d > 0)} mean_d={mean([d for _, d, _, _ in within]):+.3f}")
    print(f"  pooled on these readers only: pre {o_pre}/{t_pre} = {o_pre/t_pre:.3f}   post {o_post}/{t_post} = {o_post/t_post:.3f}")
