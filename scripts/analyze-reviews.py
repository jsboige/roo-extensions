#!/usr/bin/env python3
"""
Analyse des reviews du dataset /tmp/pr-reviews-3219-v3.txt
Fenêtre : 40 PRs (#3303 → #3359), 29/08 → 01/09
"""
import re
import collections
import json

INPUT = r"C:\Users\jsboi\AppData\Local\Temp\pr-reviews-3219-v3.txt"

records = []
with open(INPUT, "r", encoding="utf-8") as fh:
    for raw in fh:
        # Skip errors and PR=3325 which 404'd
        if raw.startswith("PR=") is False:
            continue
        # PR=3359 user=jsboige state=APPROVED at=2026-09-01T07:25:31Z sha=8bfc750 first=...
        m = re.match(r'PR=(\d+) user=(\S+) state=(\S+) at=([\dT:Z\-]+) sha=(\S+) first=(.*)$', raw.strip())
        if not m:
            # Try a JSON error line
            try:
                obj = json.loads(raw.strip())
                if obj.get("status") == "404":
                    continue
            except Exception:
                pass
            continue
        pr, user, state, at, sha, first = m.groups()
        records.append({
            "pr": int(pr), "user": user, "state": state, "at": at, "sha": sha, "first": first[:160]
        })

print(f"Total reviews: {len(records)}")
print(f"Total PRs: {len(set(r['pr'] for r in records))}")
print()

# Per-user state tally
by_user_state = collections.Counter()
for r in records:
    by_user_state[(r["user"], r["state"])] += 1
print("=== Reviews par utilisateur × state ===")
for (u, s), n in sorted(by_user_state.items(), key=lambda kv: (-kv[1], kv[0])):
    print(f"  {u:25s} {s:18s} {n}")
print()

# Hermes = user jsboige with first line containing "[Hermes]"
def is_hermes(r):
    return "[Hermes]" in r["first"]

def is_nanoclaw(r):
    return r["user"] == "clusterManager-Myia"

def is_ai01(r):
    return r["user"] == "myia-ai-01"

def is_web1(r):
    return r["user"] == "MyIA-Web1"

def is_po2023(r):
    return r["user"] == "myia-po-2023"

hermes = [r for r in records if is_hermes(r)]
nanoclaw = [r for r in records if is_nanoclaw(r)]
print(f"=== Hermes (signé [Hermes]) ===")
print(f"Total : {len(hermes)}")
print(f"  APPROVED : {sum(1 for r in hermes if r['state']=='APPROVED')}")
print(f"  COMMENTED : {sum(1 for r in hermes if r['state']=='COMMENTED')}")
print(f"  DISMISSED : {sum(1 for r in hermes if r['state']=='DISMISSED')}")
print(f"  CHANGES_REQUESTED : {sum(1 for r in hermes if r['state']=='CHANGES_REQUESTED')}")
# Opener field
for r in hermes:
    opener_match = re.search(r"opener=([^\s]+)", r["first"])
    r["opener"] = opener_match.group(1) if opener_match else None
dev_per_author = [r for r in hermes if r["opener"] and r["opener"] != "jsboige"]
dev_jsboige = [r for r in hermes if r["opener"] == "jsboige"]
unknown = [r for r in hermes if r["opener"] is None]
print(f"  opener field present: {sum(1 for r in hermes if r['opener'])}/{len(hermes)}")
print(f"  opener != jsboige: {len(dev_per_author)}")
print(f"  opener == jsboige: {len(dev_jsboige)}")
print(f"  no opener field in first line: {len(unknown)}")
print()
print("=== NanoClaw (clusterManager-Myia) ===")
print(f"Total : {len(nanoclaw)}")
print(f"  APPROVED : {sum(1 for r in nanoclaw if r['state']=='APPROVED')}")
print(f"  COMMENTED : {sum(1 for r in nanoclaw if r['state']=='COMMENTED')}")
print()

# Hermes per-author rule check
print("=== Hermes per-author rule check (post-fix po-2026 31/08) ===")
print("Window = post-fix cycles: Hermes reviews at >= 2026-08-31T08:23Z (next cron after fix)")
post_fix_hermes = [r for r in hermes if r["at"] >= "2026-08-31T08:23"]
print(f"Post-fix Hermes reviews: {len(post_fix_hermes)}")
for r in post_fix_hermes:
    flag = ""
    if r["opener"] is None and r["state"] == "APPROVED":
        flag = "  ⚠ APPROVED without opener= in first line"
    elif r["opener"] == "jsboige" and r["state"] == "APPROVED":
        flag = "  ⚠ APPROVED but opener=jsboige (deviation)"
    elif r["opener"] and r["opener"] != "jsboige" and r["state"] == "COMMENTED":
        flag = "  ⚠ COMMENTED but opener!=jsboige (deviation mou)"
    print(f"  PR={r['pr']} state={r['state']:18s} opener={str(r['opener']):20s} at={r['at']}{flag}")

# Other machine-claude signals
print()
print("=== Other machines Claude (ai-01, web1, po-2023) ===")
for u, label in [("myia-ai-01","ai-01"), ("MyIA-Web1","web1"), ("myia-po-2023","po-2023")]:
    recs = [r for r in records if r["user"] == u]
    print(f"  {label:8s} : {len(recs)} reviews (APPROVED={sum(1 for r in recs if r['state']=='APPROVED')}, COMMENTED={sum(1 for r in recs if r['state']=='COMMENTED')}, CHANGES_REQUESTED={sum(1 for r in recs if r['state']=='CHANGES_REQUESTED')})")
