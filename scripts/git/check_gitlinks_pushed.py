#!/usr/bin/env python3
"""check_gitlinks_pushed.py — gitlink reachability guard for parent-branch pushes (#4098).

Incident fondateur (po-2026, 03/10) : une branche WORKER du parent poussee avec un
gitlink `mcps/internal` jamais pousse sur le submodule casse `git fetch` sur toute
la flotte (`upload-pack: not our ref`), exactement comme le push direct de
l'incident 2026-05-11 (`67514ec1`). Les gardes existants couvraient le merge/bump
sur main, pas le push d'une branche worker intermediaire.

Ce garde verifie, AVANT `git push origin <branche>`, que chaque gitlink MODIFIE
depuis la base (origin/main par defaut) est atteignable depuis une branche remote
du submodule (origin/*). Un gitlink inchange depuis la base est deja atteignable
par construction — on ne verifie que le delta, sinon chaque push paierait un
fetch par submodule.

Usage (depuis le parent, worktree y compris — le depot du submodule est resolu
via `--git-common-dir`, jamais via `git -C <path>` qui remonte au parent quand le
submodule n'est pas peuple, garde #3454) :

    python scripts/git/check_gitlinks_pushed.py                # HEAD vs origin/main
    python scripts/git/check_gitlinks_pushed.py wt/ma-branche  # ref explicite
    python scripts/git/check_gitlinks_pushed.py --no-fetch ... # offline (refs locales)

Exit codes :
    0  = OK (tous les gitlinks modifies atteignables, ou rien a verifier)
    1  = ORPHAN — au moins un gitlink absent des branches remote : pousser le
         submodule d'abord (branche + PR), sinon NE PAS pousser le parent
    2  = instrument (depot introuvable, fetch impossible, ref inconnue) —
         un garde muet ne valide rien, il arrete
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

ZERO_SHA = "0" * 40


def run_git(args, cwd=None, git_dir=None):
    """git quiet runner ; rend (rc, stdout, stderr). git_dir evite tout `git -C <path>`."""
    cmd = ["git", "--git-dir", git_dir] if git_dir else ["git"]
    cmd += args
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, proc.stdout.strip(), proc.stderr.strip()


def changed_gitlinks(ref_sha, base_sha):
    """Gitlinks (path, new_sha) modifies entre base et ref. Deletion -> omis."""
    rc, out, err = run_git(["diff", "--raw", base_sha, ref_sha])
    if rc != 0:
        print(f"[ERROR] git diff --raw {base_sha}..{ref_sha}: {err}", file=sys.stderr)
        sys.exit(2)
    links = []
    for line in out.splitlines():
        # :160000 160000 <old> <new> M\tpath
        if not line.startswith(":160000"):
            continue
        parts = line[1:].split("\t", 1)
        if len(parts) != 2:
            continue
        fields = parts[0].split()
        new_sha, path = fields[3], parts[1].strip()
        if new_sha != ZERO_SHA:  # 0000.. = suppression du gitlink
            links.append((path, new_sha))
    return links


def submodule_git_dir(parent_common_dir, sub_path):
    """Depot du submodule via <common>/modules/<path> — jamais `git -C <path>` (#3454)."""
    candidate = Path(parent_common_dir) / "modules" / Path(*sub_path.split("/"))
    if not (candidate / "HEAD").exists():
        return None
    return str(candidate)


def main():
    ap = argparse.ArgumentParser(description="Gitlink reachability guard before pushing a parent branch (#4098)")
    ap.add_argument("ref", nargs="?", default="HEAD", help="ref a pousser (defaut: HEAD)")
    ap.add_argument("--base", default="origin/main", help="branche de base du delta (defaut: origin/main)")
    ap.add_argument("--no-fetch", action="store_true", help="ne pas fetch le parent ni les submodules (refs locales)")
    ap.add_argument("--json", action="store_true", help="sortie JSON (CI/agents)")
    args = ap.parse_args()

    rc, ref_sha, err = run_git(["rev-parse", "--verify", f"{args.ref}^{{commit}}"])
    if rc != 0:
        print(f"[ERROR] ref inconnue {args.ref!r}: {err}", file=sys.stderr)
        sys.exit(2)

    if not args.no_fetch:
        rc, _, err = run_git(["fetch", "--quiet", "origin"])
        if rc != 0:
            print(f"[ERROR] fetch parent impossible: {err}", file=sys.stderr)
            sys.exit(2)

    rc, base_sha, err = run_git(["rev-parse", "--verify", f"{args.base}^{{commit}}"])
    if rc != 0:
        print(f"[ERROR] base inconnue {args.base!r}: {err}", file=sys.stderr)
        sys.exit(2)

    # Delta scope : merge-base(ref, base). Sans ancetre commun, on verifie TOUT.
    rc, mb, _ = run_git(["merge-base", ref_sha, base_sha])
    delta_base = mb if rc == 0 and mb else base_sha

    links = changed_gitlinks(ref_sha, delta_base)
    results = []
    if not links:
        verdict = "OK"
    else:
        rc, common_dir, err = run_git(["rev-parse", "--git-common-dir"])
        if rc != 0:
            print(f"[ERROR] --git-common-dir: {err}", file=sys.stderr)
            sys.exit(2)
        common_dir = str(Path(common_dir).resolve())
        for path, sha in links:
            sub_dir = submodule_git_dir(common_dir, path)
            if sub_dir is None:
                results.append({"path": path, "sha": sha, "state": "INSTRUMENT",
                                "detail": f"depot submodule introuvable sous {common_dir}/modules/{path} (non peuple ?)"})
                continue
            if not args.no_fetch:
                rc, _, err = run_git(["fetch", "--quiet"], git_dir=sub_dir)
                if rc != 0:
                    results.append({"path": path, "sha": sha, "state": "INSTRUMENT",
                                    "detail": f"fetch submodule impossible: {err}"})
                    continue
            rc, _, cat_err = run_git(["cat-file", "-e", f"{sha}^{{commit}}"], git_dir=sub_dir)
            if rc != 0:
                results.append({"path": path, "sha": sha, "state": "ORPHAN",
                                "detail": "SHA absente du depot submodule local — pointeur fabrique/stale"})
                continue
            rc, out, _ = run_git(["branch", "-r", "--contains", sha], git_dir=sub_dir)
            carriers = [b for b in out.splitlines() if b.strip()] if rc == 0 else []
            results.append({"path": path, "sha": sha,
                            "state": "OK" if carriers else "ORPHAN",
                            "detail": f"atteignable depuis {', '.join(carriers)}" if carriers
                            else "presente localement mais sur AUCUNE branche remote — pousser le submodule d'abord"})

    states = {r["state"] for r in results}
    verdict = "ORPHAN" if "ORPHAN" in states else ("INSTRUMENT" if "INSTRUMENT" in states else "OK")

    if args.json:
        print(json.dumps({"verdict": verdict, "ref": ref_sha, "base": base_sha, "gitlinks": results}, ensure_ascii=False))
    else:
        if not results:
            print(f"OK — aucun gitlink modifie entre {delta_base[:8]} et {ref_sha[:8]} ({args.ref})")
        for r in results:
            mark = {"OK": "[OK]", "ORPHAN": "[ORPHAN]", "INSTRUMENT": "[INSTRUMENT]"}[r["state"]]
            print(f"{mark} {r['path']} -> {r['sha'][:12]} : {r['detail']}")
        if verdict == "ORPHAN":
            print("STOP — pousser le submodule d'abord (branche + PR), le parent ensuite.", file=sys.stderr)

    sys.exit({"OK": 0, "ORPHAN": 1, "INSTRUMENT": 2}[verdict])


if __name__ == "__main__":
    main()
