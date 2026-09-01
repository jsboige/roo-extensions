#!/usr/bin/env python3
"""
Cross-tab Hermes reviews vs PR opener, per-author rule compliance.
Fix timestamp: 2026-08-31T07:38:43Z (po-2026 commit), next cron cycle 31/08 08:23Z.
"""
import subprocess
import json
import re
import collections

PRS = [3303, 3304, 3305, 3306, 3307, 3308, 3309, 3310, 3311, 3312, 3313, 3315, 3317, 3318, 3325, 3326, 3327, 3328, 3330, 3331, 3332, 3333, 3334, 3335, 3336, 3337, 3338, 3339, 3340, 3343, 3348, 3349, 3352, 3353, 3354, 3355, 3356, 3357, 3358, 3359]

rows = []
for pr in PRS:
    # Open PR data
    opener_out = subprocess.run(
        ["gh", "api", f"repos/jsboige/roo-extensions/pulls/{pr}", "--jq", ".user.login"],
        capture_output=True, text=True, cwd="D:/dev/roo-extensions"
    )
    opener = opener_out.stdout.strip()
    if not opener:
        continue
    # Get reviews
    rev_out = subprocess.run(
        ["gh", "api", f"repos/jsboige/roo-extensions/pulls/{pr}/reviews"],
        capture_output=True, text=True, cwd="D:/dev/roo-extensions"
    )
    try:
        reviews = json.loads(rev_out.stdout)
    except Exception:
        continue
    for r in reviews:
        # Detect Hermes signature in body
        if not isinstance(r, dict):
            continue
        body = r.get("body", "") or ""
        is_hermes = "[Hermes]" in body
        user_obj = r.get("user") or {}
        rows.append({
            "pr": pr,
            "opener": opener,
            "user": user_obj.get("login", "?"),
            "state": r.get("state", "?"),
            "at": r.get("submitted_at", ""),
            "is_hermes": is_hermes,
            "first_line": body.split("\n")[0][:120] if body else "",
        })

print(f"Total reviews: {len(rows)}")

# Filter Hermes rows
hermes_rows = [r for r in rows if r["is_hermes"]]
print(f"Hermes reviews: {len(hermes_rows)}")

# Per-author compliance
print("\n=== Hermes per-author rule (full window) ===")
print(f"{'PR':<6} {'Opener':<15} {'State':<18} {'At':<22} {'Compliant?':<20}")
compliant = 0
deviations = []
for r in sorted(hermes_rows, key=lambda r: r["at"]):
    compliant_flag = ""
    if r["opener"] == "jsboige" and r["state"] != "COMMENTED":
        compliant_flag = "✗ DEV (opener=jsboige ≠ COMMENTED)"
        deviations.append(r)
    elif r["opener"] != "jsboige" and r["state"] not in ("APPROVED", "CHANGES_REQUESTED"):
        compliant_flag = "⚠ MOU (opener≠jsboige mais non-approve)"
        deviations.append(r)
    elif r["state"] == "DISMISSED":
        compliant_flag = "= DISMISSED"
    else:
        compliant_flag = "✓ OK"
        compliant += 1
    print(f"{r['pr']:<6} {r['opener']:<15} {r['state']:<18} {r['at']:<22} {compliant_flag}")
print(f"\nTotal compliant: {compliant}/{len(hermes_rows)} = {100*compliant/len(hermes_rows):.1f}%")

# Post-fix only (after 2026-08-31T08:23Z)
post_fix = [r for r in hermes_rows if r["at"] >= "2026-08-31T08:23"]
print(f"\n=== Post-fix window (since 2026-08-31T08:23Z): {len(post_fix)} Hermes reviews ===")
for r in sorted(post_fix, key=lambda r: r["at"]):
    flag = "✓ OK"
    if r["opener"] == "jsboige" and r["state"] != "COMMENTED":
        flag = "✗ DEV"
    elif r["opener"] != "jsboige" and r["state"] not in ("APPROVED", "CHANGES_REQUESTED"):
        flag = "⚠ MOU"
    elif r["state"] == "DISMISSED":
        flag = "= DISMISSED"
    print(f"  PR={r['pr']} opener={r['opener']:<14} state={r['state']:<18} at={r['at']}  {flag}")

# Pre-fix baseline (29/08 00:00 → 31/08 08:23)
pre_fix = [r for r in hermes_rows if r["at"] < "2026-08-31T08:23"]
print(f"\n=== Pre-fix window: {len(pre_fix)} Hermes reviews ===")
for r in sorted(pre_fix, key=lambda r: r["at"]):
    flag = "✓ OK"
    if r["opener"] == "jsboige" and r["state"] != "COMMENTED":
        flag = "✗ DEV"
    elif r["opener"] != "jsboige" and r["state"] not in ("APPROVED", "CHANGES_REQUESTED"):
        flag = "⚠ MOU"
    elif r["state"] == "DISMISSED":
        flag = "= DISMISSED"
    print(f"  PR={r['pr']} opener={r['opener']:<14} state={r['state']:<18} at={r['at']}  {flag}")

# NanoClaw register
print("\n=== NanoClaw register (clusterManager-Myia) ===")
nc_rows = [r for r in rows if r["user"] == "clusterManager-Myia"]
for r in sorted(nc_rows, key=lambda r: r["at"]):
    print(f"  PR={r['pr']} opener={r['opener']:<14} state={r['state']:<18} at={r['at']}")
print(f"\nNanoClaw total: {len(nc_rows)}, APPROVED={sum(1 for r in nc_rows if r['state']=='APPROVED')}, COMMENTED={sum(1 for r in nc_rows if r['state']=='COMMENTED')}")
