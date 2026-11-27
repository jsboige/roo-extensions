#!/usr/bin/env python3
"""#4434 G8a layer 2 — verify the blind readers' findings against the SOURCE.

Inputs:
  samples dir  (Sxx_originals.md / Sxx_summary.md / index.json from sample.py)
  findings dir (F01.json .. F12.json, each: a JSON array of 2 objects or 1 object)

Checks per finding (producer != verifier: the readers never see this script):
  excerpt      must be a whitespace-normalised substring of the originals
  summary_line must be a whitespace-normalised substring of the summary
  tokens       all must occur in the excerpt; an omission whose token IS in the
               summary is flagged (either a bad token or a false omission claim)
Prints per-sample and per-arm totals; writes findings-checked.json. No text dump.
"""
import json
import os
import re
import sys

SAMPLES, FINDINGS, OUT = sys.argv[1], sys.argv[2], sys.argv[3]


def norm(s):
    return re.sub(r"\s+", " ", s or "").strip()


def fold(s):
    """Whitespace-normalised, lower-case, accent-insensitive. The full Latin-1
    vowel set, not a hand-picked subset: a reader retyping 'brûle' against a
    dashboard line typed 'brule' is the same words (S02, 26/11)."""
    s = norm(s).lower()
    for a, b in (("é", "e"), ("è", "e"), ("ê", "e"), ("ë", "e"),
                 ("à", "a"), ("â", "a"), ("ä", "a"),
                 ("î", "i"), ("ï", "i"), ("ô", "o"), ("ö", "o"),
                 ("ù", "u"), ("û", "u"), ("ü", "u"), ("ç", "c"),
                 ("œ", "oe"), ("’", "'")):
        s = s.replace(a, b)
    return s


index = {x["id"]: x for x in json.load(open(os.path.join(SAMPLES, "index.json"), encoding="utf-8"))}
TRUNC_PATH = os.path.join(SAMPLES, "truncation.json")
trunc = {}
if os.path.exists(TRUNC_PATH):
    trunc = {x["id"]: x for x in json.load(open(TRUNC_PATH, encoding="utf-8"))}
findings = []
for fn in sorted(os.listdir(FINDINGS)):
    if not fn.endswith(".json"):
        continue
    data = json.load(open(os.path.join(FINDINGS, fn), encoding="utf-8"))
    if isinstance(data, dict):
        data = [data]
    for obj in data:
        findings.append(obj)

rows, problems = [], []


def _msgcount_artifact(text):
    """The sample header counts NON-SYSTEM messages; the archive frontmatter
    `messageCount` (and the summary's own 'Resume des N messages') counts them
    plus the 2 system condensation notices — verified equal to n+2 on 24/24
    samples. A claim about that count is an artefact of the two conventions,
    not a summary defect."""
    t = (text or "").replace("\\", "")
    return bool(re.search(r"(?:r[ée]sum[ée] des\s+)?\d+\s+messages", t, re.I))


for obj in findings:
    sid = obj.get("sample")
    if sid not in index:
        problems.append({"file": "?", "problem": f"unknown sample {sid}"})
        continue
    orig = norm(open(os.path.join(SAMPLES, f"{sid}_originals.md"), encoding="utf-8").read())
    summ = norm(open(os.path.join(SAMPLES, f"{sid}_summary.md"), encoding="utf-8").read())
    suf, n_ex_bad, tok_bad, tok_in_sum, n_sum_bad = fold(summ), 0, 0, 0, 0
    for o in obj.get("omitted") or []:
        ex = fold(o.get("excerpt"))
        if ex and ex not in fold(orig):
            n_ex_bad += 1
            problems.append({"sample": sid, "problem": "excerpt not in originals", "excerpt": (o.get("excerpt") or "")[:90]})
        toks = [t for t in (o.get("tokens") or []) if t]
        if not toks:
            tok_bad += 1
        for t in toks:
            if fold(t) not in ex:
                tok_bad += 1
                problems.append({"sample": sid, "problem": "token not in excerpt", "token": t})
            elif fold(t) in suf:
                tok_in_sum += 1
                problems.append({"sample": sid, "problem": "token found in summary (omission claim?)", "token": t})
    for c in obj.get("carried") or []:
        sl = fold(c.get("summary_line"))
        if sl and sl not in suf:
            n_sum_bad += 1
            problems.append({"sample": sid, "problem": "summary_line not in summary", "summary_line": (c.get("summary_line") or "")[:90]})
    for fs in obj.get("false_or_unsupported") or []:
        sl = fold(fs.get("summary_line"))
        if sl and sl not in suf:
            n_sum_bad += 1
            problems.append({"sample": sid, "problem": "false/unsupported summary_line not in summary", "summary_line": (fs.get("summary_line") or "")[:90]})
    for cp in obj.get("unflagged_contradictions") or []:
        sl = fold(cp.get("summary_line"))
        if sl and sl not in suf:
            n_sum_bad += 1
            problems.append({"sample": sid, "problem": "contradiction summary_line not in summary", "summary_line": (cp.get("summary_line") or "")[:90]})
    om = obj.get("omitted") or []
    ca = obj.get("carried") or []
    x = index[sid]
    fs_all = obj.get("false_or_unsupported") or []
    nm_all = obj.get("number_mismatches") or []

    def _is_artifact(n):
        sv = str(n.get("summary_value") or "").strip()
        if _msgcount_artifact(sv):
            return True
        return bool(re.fullmatch(r"\d+", sv)) and int(sv) == x["msgs"] + 2

    fs_art = [f for f in fs_all if _msgcount_artifact(f.get("summary_line"))]
    fs_kept = [f for f in fs_all if f not in fs_art]
    nm_art = [n for n in nm_all if _is_artifact(n)]
    rows.append({
        "id": sid, "key": x["key"], "model": x["model"], "arm": x["arm"],
        "has_transverse": x["has_transverse"], "sum_bytes": x["sum_bytes"],
        "truncated": bool(trunc.get(sid, {}).get("truncated")),
        "lines_removed": int(trunc.get(sid, {}).get("removed", 0)),
        "states": obj.get("states_identified"),
        "omitted": len(om), "carried": len(ca),
        "carried_share": (len(ca) / (len(om) + len(ca))) if (len(om) + len(ca)) else None,
        "classes_omitted": [o.get("class") for o in om if o.get("class")],
        "classes_carried": [o.get("class") for o in ca if o.get("class")],
        "false_or_unsupported": len(fs_kept),
        "false": sum(1 for f in fs_kept if f.get("type") == "false"),
        "msgcount_artifacts": len(fs_art) + len(nm_art),
        "unflagged_contradictions": len(obj.get("unflagged_contradictions") or []),
        "number_mismatches": len(nm_all) - len(nm_art),
        "numbers_checked": obj.get("numbers_checked"),
        "ids_checked": obj.get("ids_checked"),
        "clickable_links": obj.get("clickable_links"),
        "quote_defects": n_ex_bad + n_sum_bad,
        "token_defects": tok_bad,
        "tokens_in_summary": tok_in_sum,
        "notes": (obj.get("notes") or "")[:160],
    })

json.dump({"rows": rows, "problems": problems}, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=1)

print(f"samples with findings: {len(rows)}/{len(index)}")
print(f"{'id':4s} {'arm':4s} {'T':1s} {'key':26s} {'states':6s} {'omit':4s} {'carr':4s} {'share':5s} {'false':5s} {'unsup':5s} {'contr':5s} {'nummm':5s} {'art':3s} qd td")
for r in sorted(rows, key=lambda r: r["id"]):
    sh = "  —  " if r["carried_share"] is None else f"{r['carried_share']:.2f}"
    print(f"{r['id']:4s} {r['arm']:4s} {'T' if r['truncated'] else '-':1s} {r['key'][:26]:26s} {str(r['states']):6s} {r['omitted']:4d} {r['carried']:4d} {sh:5s} "
          f"{r['false']:5d} {r['false_or_unsupported'] - r['false']:5d} {r['unflagged_contradictions']:5d} {r['number_mismatches']:5d} {r['msgcount_artifacts']:3d} {r['quote_defects']:2d} {r['token_defects']:2d}")


def mean(xs):
    xs = [x for x in xs if x is not None]
    return sum(xs) / len(xs) if xs else None


print()
for arm in ("pre", "post"):
    sel = [r for r in rows if r["arm"] == arm]
    if not sel:
        continue
    o, c = sum(r["omitted"] for r in sel), sum(r["carried"] for r in sel)
    print(f"{arm:4s} n={len(sel):2d}  states={sum(r['states'] or 0 for r in sel):3d}  omitted={o:3d}  carried={c:3d}  "
          f"pooled omission share={o/(o+c):.3f}  mean per-sample carried_share={mean([r['carried_share'] for r in sel]):.3f}  "
          f"false={sum(r['false'] for r in sel):2d}  unsupported={sum(r['false_or_unsupported'] - r['false'] for r in sel):2d}  "
          f"contradictions={sum(r['unflagged_contradictions'] for r in sel):2d}  number_mismatches={sum(r['number_mismatches'] for r in sel):2d}/{sum(r['numbers_checked'] or 0 for r in sel):3d}  "
          f"links={sum(r['clickable_links'] or 0 for r in sel):3d}  truncated={sum(1 for r in sel if r['truncated']):2d}  "
          f"mean_bytes={round(mean([r['sum_bytes'] for r in sel]) or 0)}")

print()
print("PER CLASS  omitted/carried   pre   post   (pooled, class 1..8)")
for cls in range(1, 9):
    po, pc = sum(r["classes_omitted"].count(cls) for r in rows if r["arm"] == "pre"), sum(r["classes_carried"].count(cls) for r in rows if r["arm"] == "pre")
    qo, qc = sum(r["classes_omitted"].count(cls) for r in rows if r["arm"] == "post"), sum(r["classes_carried"].count(cls) for r in rows if r["arm"] == "post")
    f = lambda o, c: "   —  " if o + c == 0 else f"{o/(o+c):.2f}"
    print(f"  class {cls}:  pre {po:2d}/{pc:2d} {f(po,pc)}    post {qo:2d}/{qc:2d} {f(qo,qc)}")

print()
print("PAIRED by cell (pre vs post, ordered by summary_ts): delta omission share = pre - post")
deltas = []
for key in sorted({(index[i]["key"], index[i]["model"]) for i in index}):
    pre = sorted([r for r in rows if r["arm"] == "pre" and (r["key"], r["model"]) == key], key=lambda r: index[r["id"]]["summary_ts"])
    post = sorted([r for r in rows if r["arm"] == "post" and (r["key"], r["model"]) == key], key=lambda r: index[r["id"]]["summary_ts"])
    for a, b in zip(pre, post):
        if a["carried_share"] is None or b["carried_share"] is None:
            continue
        d = a["carried_share"] - b["carried_share"]   # negative = post better
        deltas.append(d)
        print(f"  {key[0][:26]:26s} {a['id']}({a['omitted']}/{a['omitted']+a['carried']}) vs {b['id']}({b['omitted']}/{b['omitted']+b['carried']})  "
              f"share {a['carried_share']:.2f} -> {b['carried_share']:.2f}  d={d:+.2f}")
if deltas:
    pos, neg = sum(1 for d in deltas if d < 0), sum(1 for d in deltas if d > 0)
    print(f"  pairs={len(deltas)}  post better (d<0): {pos}   post worse (d>0): {neg}   ties: {len(deltas)-pos-neg}   mean d={mean(deltas):+.3f}")
print()
print(f"quote defects: {sum(r['quote_defects'] for r in rows)}  token defects: {sum(r['token_defects'] for r in rows)}  "
      f"tokens found in summary: {sum(r['tokens_in_summary'] for r in rows)}  msgcount artifacts reclassified: {sum(r['msgcount_artifacts'] for r in rows)}  problems listed: {len(problems)}")
for p in problems[:25]:
    print("  ", p)
