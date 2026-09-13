#!/usr/bin/env python3
"""Rebuild the Vibe grain queue from a fresh detector scan (#15719).

`outputs/vibe/feeder-queue.json` is a gitignored runtime file consumed by the
Vibe-Feeder schtask, one grain per fire. Its grains were scoped by hand from a
PARTIAL inventory: the header declared 65 files / 83 findings while a full scan
of the same base measures 179 findings / 2098 files. Whole domains were
therefore under-scoped — `Probas` carried 4 findings in the queue's inventory
and 28 in the fresh one — and the fournee floor (>=10 confirmed findings per
PR) was unreachable for the grains as scoped.

This organ re-measures instead of trusting a stored list:

  1. scan the fresh base with `scan_md_table_syntax.py --json`;
  2. subtract every file already held by an OPEN PR on the issue
     (deconfliction — a grain must not re-fix what a review is looking at);
  3. group the free findings into contract-sized grains: one domain,
     >= FLOOR findings, <= MAX_FILES files;
  4. keep grains that already carry work and are NOT yet delivered, then
     rewrite the queue and keep the previous one as `.bak`.

The scan is the expensive step and it costs ~45 s on the full corpus, so
re-measuring every time is cheap enough to be the default: the queue stops
being a document that rots and becomes a view over the current tree.
"""

import argparse
import collections
import io
import json
import os
import re
import subprocess
import sys

FLOOR = 10          # fournee floor: confirmed findings per grain (contract #15719)
MAX_FILES = 15      # anti-composite cap: files per PR

PAYLOAD = """[WAKE-VIBE] {gid} (sweep #15719, fournee dimensionnee sur re-scan frais)
baseSha: {base}
targetPath:
{targets}
worktree: {worktree}
branch: {branch}

Mission : faire passer CHAQUE fichier de targetPath a 0 finding de
`python scripts/notebook_tools/scan_md_table_syntax.py --check <fichier>`.
Recettes par pathologie (n'appliquer que celle detectee sur la ligne visee) :
- ORPHAN_TABLE_ROW : re-declarer le header + separateur REELS avant la ligne pipe orpheline (ne deplacer aucune ligne, ne pas inventer de colonne).
- COL_MISMATCH ou CODE_SPAN_PIPE : echapper le `|` nu en `\\|` dans la cellule (dans un code span inline : `\\|` aussi).
- MATH_SPAN_PIPE : remplacer le `|` par `\\mid` (condition / such-that, ex. p(a|s)) ou `\\vert` (valeur absolue). TOUJOURS espacer l'operateur : `a \\mid b`, `\\vert x \\vert`. Ne jamais coller une commande LaTeX a la lettre suivante : elle l'absorbe et la commande devient non definie.
- NO_BLANK_BEFORE / NO_BLANK_AFTER : inserer UNE ligne vide avant / apres la table.

FAUX POSITIFS connus : navigation `[Precedent](...) | [Suivant](...)`, metadonnees
`**Duree estimee** : ... | **Prerequis** : ...`, manifests et archives. NE PAS
fabriquer de header pour ces cas : les signaler dans le rapport et passer.

Notebooks : modifier UNIQUEMENT la source markdown des cellules concernees. Cellules code, outputs, execution_count et metadata byte-identiques (aucune re-serialisation generale). Aucune prose reecrite, aucun mot change. Ne jamais couper dans un chemin, lien markdown ou jeton.

INTERDIT : push, PR, gh, catalogue, Lean/lake, backtest, toute commande GPU, tout fichier hors targetPath, toute ecriture dans D:/dev/CoursIA (le seul lieu d'ecriture est le worktree ci-dessus).
N'utilise PAS l'outil fs/read_file pour lire/valider (refuse hors sandbox, brule le budget) : Python io.open uniquement.

CHECKPOINT-COMMIT obligatoire, puis rapport : scan avant/apres par fichier (0 attendu), git status, liste des fichiers touches."""


def sh(cmd, cwd=None, check=True):
    r = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    if check and r.returncode != 0:
        raise SystemExit("commande echouee: %s\n%s%s" % (" ".join(cmd), r.stdout, r.stderr))
    return r.stdout


def n_findings(chunk):
    return sum(len(f) for f in chunk.values())


def fresh_base(repo, base):
    sh(["git", "-C", repo, "fetch", "origin", "main"], check=False)
    return sh(["git", "-C", repo, "rev-parse", base]).strip()


def ensure_scan_wt(repo, base, path):
    out = sh(["git", "-C", repo, "worktree", "list"], check=False)
    known = {os.path.normcase(os.path.normpath(l.split()[0]))
             for l in out.splitlines() if l.strip()}
    target = os.path.normcase(os.path.normpath(path))
    if target in known:
        sh(["git", "-C", path, "checkout", "--detach", base])
    else:
        parent = os.path.dirname(path)
        if parent and not os.path.isdir(parent):
            os.makedirs(parent, exist_ok=True)
        sh(["git", "-C", repo, "worktree", "add", "--detach", path, base])
    return path


def scan(wt):
    script = os.path.join(wt, "scripts", "notebook_tools", "scan_md_table_syntax.py")
    if not os.path.isfile(script):
        raise SystemExit("detecteur absent: %s" % script)
    data = json.loads(sh([sys.executable, script, "--json", "MyIA.AI.Notebooks"], cwd=wt))
    return {e["path"].replace("\\", "/"): e["findings"]
            for e in (data.get("files") or []) if e.get("findings")}


def open_prs(slug, issue):
    """(files held by an open PR claiming the issue, branches with an open PR)."""
    pat = re.compile(r"#%d([^0-9]|$)" % issue)
    held, branches = {}, set()
    out = sh(["gh", "pr", "list", "--repo", slug, "--state", "open", "--limit", "200",
              "--json", "number,title,headRefName,files"])
    for pr in json.loads(out):
        branches.add(pr.get("headRefName") or "")
        if pat.search(pr.get("title") or ""):
            for f in pr.get("files") or []:
                held[f["path"].replace("\\", "/")] = pr["number"]
    return held, branches


def split_domain(files):
    """Cut one domain's files into BALANCED chunks of <= MAX_FILES.

    A greedy cut of MAX_FILES-then-tail leaves an under-floor tail on every
    domain that overflows, and a tail has no same-domain home — it then leaks
    into an unrelated grain, which is how QuantConnect files once ended up in a
    GameTheory fournee. Spreading the heaviest files round-robin across
    ceil(n/MAX_FILES) chunks keeps every chunk above the floor instead.
    """
    items = sorted(files.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    n_chunks = max(1, -(-len(items) // MAX_FILES))
    chunks = [{} for _ in range(n_chunks)]
    for i, (path, fs) in enumerate(items):
        chunks[i % n_chunks][path] = fs
    return chunks


def plan(free):
    """Bins that honour the fournee contract, plus the unusable leftover."""
    by_domain = collections.defaultdict(dict)
    for p, f in free.items():
        parts = p.split("/")
        by_domain[parts[1] if len(parts) > 1 else "divers"][p] = f

    bins, pockets = [], []
    for dom in sorted(by_domain, key=lambda d: -n_findings(by_domain[d])):
        chunks = split_domain(by_domain[dom])
        for i, ch in enumerate(chunks):
            name = dom if len(chunks) == 1 else "%s-%d" % (dom, i + 1)
            (bins if n_findings(ch) >= FLOOR else pockets).append([name, ch, dom])

    # Une poche se verse d'abord chez un grain CONFORME DU MEME DOMAINE qui a la
    # place : agrandir une fournee de son propre domaine reste une fournee.
    # Passer la frontiere du domaine n'est tolere que comme residu explicite.
    residual = {}
    for name, ch, dom in pockets:
        host = None
        for b in bins:
            if b[2] == dom and len(b[1]) + len(ch) <= MAX_FILES \
                    and (host is None or n_findings(b[1]) < n_findings(host[1])):
                host = b
        if host is not None:
            host[1].update(ch)
        else:
            residual.update(ch)
    if residual:
        if n_findings(residual) >= FLOOR and len(residual) <= MAX_FILES:
            bins.append(["residu-petits-domaines", residual, "residu"])
        else:
            print("WARN: residu non livrable laisse hors file (%d findings / %d fichiers): %s"
                  % (n_findings(residual), len(residual),
                     ", ".join(sorted(residual)[:8])))
    return [(n, c) for n, c, _ in bins]


def keepable(queue, base, open_branches):
    """In-flight grains survive; delivered ones (open PR) leave the queue."""
    keep, dropped = [], []
    for g in queue.get("grains") or []:
        wt = g.get("worktree") or ""
        branch = g.get("branch") or ""
        if branch in open_branches:
            dropped.append(g.get("id"))
            continue
        if not os.path.isdir(wt):
            continue
        ahead = sh(["git", "-C", wt, "rev-list", "--count", "%s..HEAD" % base], check=False).strip()
        dirty = sh(["git", "-C", wt, "status", "--porcelain"], check=False).strip()
        if (ahead.isdigit() and int(ahead) > 0) or dirty:
            keep.append(g)
    return keep, dropped


def payload_paths(g):
    """Only the targetPath block — the recipe bullets also start with '- '."""
    inside, out = False, set()
    for line in (g.get("payload") or "").splitlines():
        s = line.strip()
        if s.startswith("targetPath"):
            inside = True
            continue
        if inside and (s.startswith("worktree:") or s.startswith("branch:")):
            break
        if inside and s.startswith("- "):
            out.add(s[2:].strip())
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default="D:/dev/CoursIA", help="clone CoursIA (jamais le cwd de session)")
    ap.add_argument("--base", default="origin/main")
    ap.add_argument("--slug", default="jsboige/CoursIA")
    ap.add_argument("--issue", type=int, default=15719)
    ap.add_argument("--queue", default="outputs/vibe/feeder-queue.json")
    ap.add_argument("--scan-wt", default="D:/dev/CoursIA-vibe/_scan-queue")
    ap.add_argument("--wt-root", default="D:/dev/CoursIA-vibe")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    base = fresh_base(args.repo, args.base)
    print("base: %s" % base)

    found = scan(ensure_scan_wt(args.repo, base, args.scan_wt))
    held, open_branches = open_prs(args.slug, args.issue)
    print("scan: %d fichiers avec findings | deconfliction: %d tenus par une PR ouverte sur #%d"
          % (len(found), len(held), args.issue))

    queue_path = os.path.join(os.getcwd(), args.queue)
    old = {}
    if os.path.isfile(queue_path):
        with io.open(queue_path, encoding="utf-8") as fh:
            old = json.load(fh)
    keep, dropped = keepable(old, base, open_branches)
    if dropped:
        print("livres -> retires de la file: %s" % ", ".join(dropped))
    kept_paths = set()
    for g in keep:
        kept_paths |= payload_paths(g)

    free = {p: f for p, f in found.items() if p not in held and p not in kept_paths}
    if not free:
        print("aucun finding libre — file inchangee")
        return

    planned = plan(free)
    grains = list(keep)
    for i, (name, ch) in enumerate(sorted(planned, key=lambda x: x[0]), start=len(grains) + 1):
        gid = "g%d-%s" % (i, re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:38])
        wt = "%s/%s" % (args.wt_root.rstrip("/"), gid)
        branch = "wt/vibe-%s" % gid
        targets = "\n".join("- %s" % p for p, _ in sorted(ch.items()))
        grains.append({
            "id": gid, "baseSha": base, "worktree": wt, "branch": branch,
            "payload": PAYLOAD.format(gid=gid, base=base, targets=targets, worktree=wt, branch=branch),
        })
        n, k = n_findings(ch), len(ch)
        print("  %-42s findings=%-3d fichiers=%-3d %s"
              % (gid, n, k, "OK" if (n >= FLOOR and k <= MAX_FILES) else "HORS CONTRAT"))

    total = sum(n_findings(ch) for _, ch in planned)
    out = {
        "_comment": ("File de travail des grains Mistral Vibe (po-2025). Reconstruite par "
                     "scripts/scheduling/refresh-vibe-queue.py sur re-scan frais de %s : %d findings "
                     "libres mesures, %d tenus par des PR ouvertes sur #%d, planifies en %d grain(s) "
                     "de >= %d findings et <= %d fichiers (contrat de fournee #15719). Les grains en "
                     "vol non livres sont conserves tels quels."
                     % (base[:12], total, len(held), args.issue, len(planned), FLOOR, MAX_FILES)),
        "grains": grains,
    }

    if args.dry_run:
        print("\n[DRY-RUN] %d grain(s) au total, %d findings planifies — file non ecrite"
              % (len(grains), total))
        return
    if os.path.isfile(queue_path):
        with io.open(queue_path, encoding="utf-8") as fh:
            previous = fh.read()
        with io.open(queue_path + ".bak", "w", encoding="utf-8", newline="\n") as fh:
            fh.write(previous)
    with io.open(queue_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(json.dumps(out, ensure_ascii=False, indent=2) + "\n")
    print("\nfile ecrite: %s (%d grains, %d findings, precedent conserve en .bak)"
          % (queue_path, len(grains), total))


if __name__ == "__main__":
    main()
