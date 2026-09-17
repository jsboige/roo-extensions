#!/usr/bin/env python3
"""Rebuild the Vibe grain queue from fresh detector scans (#15719, #16472).

Multi-contrat depuis #16472 (GO ai-01 17/09, mandat user « résoudre
définitivement le pb d'approvisionnement ») : la file est l'union des grains
de chaque contrat actif — un détecteur épuisé n'assèche plus la lane.

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
`python scripts/notebook_tools/scan_md_table_syntax.py --check <fichier>`,
ou a un NOOP justifie (voir plus bas). Un NOOP justifie est une REUSSITE,
pas un echec de grain.
Recettes par pathologie (n'appliquer que celle detectee sur la ligne visee) :
- ORPHAN_TABLE_ROW : re-declarer le header + separateur REELS avant la ligne pipe orpheline (ne deplacer aucune ligne, ne pas inventer de colonne).
- COL_MISMATCH ou CODE_SPAN_PIPE : echapper le `|` nu en `\\|` dans la cellule -- UNIQUEMENT si la ligne est une vraie rangee de tableau (bloc sous un separateur `|---|`). Dans un code span inline sur une ligne de PROSE, le `|` est deja litteral : ne pas y toucher (FP 5).
- MATH_SPAN_PIPE : remplacer le `|` par `\\mid` (condition / such-that, ex. p(a|s)) ou `\\vert` (valeur absolue). TOUJOURS espacer l'operateur : `a \\mid b`, `\\vert x \\vert`. Ne jamais coller une commande LaTeX a la lettre suivante : elle l'absorbe et la commande devient non definie.
- NO_BLANK_BEFORE / NO_BLANK_AFTER : inserer UNE ligne vide avant / apres la table.

FAUX POSITIFS connus, mesures : (1) span mathematique `$...$` pontant le `|`
separateur de cellules (ex. `Input ($/1M tokens) | Output ($/1M tokens)`) ;
(2) `||` logique JavaScript dans une fence de code ; (3) `|` en prose
(ex. `pi*(y|x)`, navigation `[Precedent](...) | [Suivant](...)`, metadonnees
`**Duree estimee** : ... | **Prerequis** : ...`) ; (4) boites ASCII a traits
verticaux, manifests et archives ; (5) `|` dans un code span inline sur des
lignes de PROSE consecutives, lues comme un pseudo-tableau -- signature : le
finding porte une ligne SANS AUCUN pipe (ex. `**Objectif** -- ...`). Ces cas
NE SONT PAS du travail : ne rien reecrire, les citer en une ligne dans le
rapport et passer.

ATTENTION FP 5 : l'echappement y est une MUTATION, pas un fix. Dans un code
span, l'antislash est LITTERAL et devient visible : `float\\|None` s'affiche
avec l'antislash devant l'etudiant. Mesure les 13-14/09 sur 10e_LLamaSharp --
deux vecteurs distincts de la meme mutation : lignes vides inserees au milieu
d'une phrase, puis echappements de pipes en prose. Le NOOP justifie est la
seule issue correcte pour cette famille.

NOOP JUSTIFIE : fichier INCHANGE, finding cite (pathologie + ligne), motif en
une ligne. C'est une REUSSITE, pas un echec de grain. La liste ci-dessus n'est
pas exhaustive -- c'est le NOOP qui protege, elle ne fait qu'epargner des cycles.

PRIORITE EN CAS DE CONFLIT : si respecter "aucune prose reecrite, aucun mot
change" empeche d'atteindre 0 finding, c'est "aucun mot change" qui GAGNE.

Notebooks : modifier UNIQUEMENT la source markdown des cellules concernees. Cellules code, outputs, execution_count et metadata byte-identiques (aucune re-serialisation generale). Aucune prose reecrite, aucun mot change. Ne jamais couper dans un chemin, lien markdown ou jeton.

INTERDIT : push, PR, gh, catalogue, Lean/lake, backtest, toute commande GPU, tout fichier hors targetPath, toute ecriture dans D:/dev/CoursIA (le seul lieu d'ecriture est le worktree ci-dessus).
N'utilise PAS l'outil fs/read_file pour lire/valider (refuse hors sandbox, brule le budget) : Python io.open uniquement.

CHECKPOINT-COMMIT obligatoire, puis rapport : scan avant/apres par fichier (0 attendu), NOOP justifies (fichier + finding + motif), git status, liste des fichiers touches."""


PAYLOAD_HINT = """[WAKE-VIBE] {gid} (sweep #16472, fournee dimensionnee sur re-scan frais)
baseSha: {base}
targetPath:
{targets}
worktree: {worktree}
branch: {branch}

Mission : faire passer CHAQUE fichier de targetPath a 0 finding de
`python scripts/notebook_tools/scan_md_hierarchy.py <fichier>`
(pathologies HINT-AS-HEADING et HEADING-IN-LIST), ou a un FP documente.
REASSESSMENT OBLIGATOIRE avant tout fix (contrat #16472) : un heading qui est
une VRAIE section intentionnelle (structure pedagogique voulue, ex. un
### Solution : de section d'exercice referencee par la nav) ne se demote PAS —
FP documente dans le rapport (heading + motif). Un finding = une decision
citee, jamais un fix aveugle.
Recettes (convention d'autorite CoursIA, precedents #8647/#8654/#8630) :
- Famille curatoriee (Indices, Etapes, Astuces, Notes, Conseils, Remarques...)
  ou variante parenthese/apostrophe/prefixe long : outil
  `scripts/notebook_tools/demote_md_asides.py` depuis le worktree — demotion
  en callout blockquote : `### Indices` devient `> **Indices :**` (texte
  identique, deux-points attaches au gras).
- HEADING-IN-LIST : `scripts/notebook_tools/fix_hint_headings.py` (couvre
  exactement cette pathologie, invariant round-trip verifie par l'outil).
- Hors liste curatee : demotion MANUELLE au format `> **<texte> :**` — MEME
  transformation, jugement par contenu ; citer before/after dans le rapport.
INTERDITS : renommer le texte, changer de niveau, supprimer du contenu, ajouter
des headings artificiels, remplir le quota avec des fichiers sans defaut.
Proteges anti-regression : cellules `# Solution` / `# Exemple resolu` =
contenu pedagogique protege — au doute, NE PAS traiter, citer en FP douteux.
Markdown-only byte-surgical : cellules code, outputs, execution_count,
metadata et IDs byte-identiques. LF-only, ecriture binaire
json.dumps().encode('utf-8'), JAMAIS nbformat.write, aucun scrubbing d'output.
Rebaseline : `scan_md_hierarchy.py --update-baseline` dans la MEME PR que la
fournee, jamais en avance.
INTERDIT : push, PR, gh, catalogue, Lean/lake, backtest, toute commande GPU, tout fichier hors targetPath, toute ecriture dans D:/dev/CoursIA (le seul lieu d'ecriture est le worktree ci-dessus).
N'utilise PAS l'outil fs/read_file pour lire/valider (refuse hors sandbox, brule le budget) : Python io.open uniquement.

CHECKPOINT-COMMIT obligatoire, puis rapport : scan avant/apres par fichier (0 attendu), FPs documentes (heading + motif), before/after des demotions hors liste curatee, git status, liste des fichiers touches."""


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


def scan_md_table(wt):
    script = os.path.join(wt, "scripts", "notebook_tools", "scan_md_table_syntax.py")
    if not os.path.isfile(script):
        raise SystemExit("detecteur absent: %s" % script)
    data = json.loads(sh([sys.executable, script, "--json", "MyIA.AI.Notebooks"], cwd=wt))
    return {e["path"].replace("\\", "/"): e["findings"]
            for e in (data.get("files") or []) if e.get("findings")}


HIERARCHY_FINDING = re.compile(r"^\s+\[([A-Z-]+)\] cell (\d+)\s+L(\d+)\s+(.*)$")


def parse_hierarchy_census(text):
    """{path: [finding, ...]} from scan_md_hierarchy census output (no --json mode).

    Format mesure (CRLF inclus) :
        ## MyIA.AI.Notebooks/.../SL-7.ipynb
          [HINT-AS-HEADING] cell 34  L4  Pistes pedagogiques
        === 100/1317 notebooks flagged ===
    """
    found, path = {}, None
    for line in (text or "").splitlines():
        line = line.rstrip("\r")
        if line.startswith("## "):
            path = line[3:].strip().replace("\\", "/")
            found.setdefault(path, [])
        elif path is not None:
            m = HIERARCHY_FINDING.match(line)
            if m:
                found[path].append("[%s] cell %s L%s %s" % m.groups())
    return {p: f for p, f in found.items() if f}


def scan_md_hierarchy(wt):
    script = os.path.join(wt, "scripts", "notebook_tools", "scan_md_hierarchy.py")
    if not os.path.isfile(script):
        raise SystemExit("detecteur absent: %s" % script)
    return parse_hierarchy_census(
        sh([sys.executable, script, "MyIA.AI.Notebooks"], cwd=wt))


# Un contrat = un detecteur, son payload de mission et son axe de regroupement
# (index du segment de chemin qui definit le domaine/famille d'une fournee).
# 15719 : md-table, domaine = parts[1] (GenAI, QuantConnect...) ;
# 16472 : hierarchie markdown, famille = parts[2] (Audio, Image...) — le
# contrat exige "une famille/serie par fournee".
CONTRACTS = {
    15719: {"scan": scan_md_table, "payload": PAYLOAD, "group": 1},
    16472: {"scan": scan_md_hierarchy, "payload": PAYLOAD_HINT, "group": 2},
}


def open_prs(slug, issues):
    """(files held by an open PR claiming ANY active contract, open branches).

    Cross-contract: un fichier tenu par une PR reclamant n'importe quel
    contrat actif est soustrait pour tous — deux PRs sur un meme fichier
    entrent en conflit quel que soit le contrat qui les a engendrees.
    """
    pats = [re.compile(r"#%d([^0-9]|$)" % i) for i in issues]
    held, branches = {}, set()
    out = sh(["gh", "pr", "list", "--repo", slug, "--state", "open", "--limit", "300",
              "--json", "number,title,headRefName,files"])
    for pr in json.loads(out):
        branches.add(pr.get("headRefName") or "")
        if any(p.search(pr.get("title") or "") for p in pats):
            for f in pr.get("files") or []:
                held[f["path"].replace("\\", "/")] = pr["number"]
    return held, branches


CLAIM_TOKEN = re.compile(r"^[\w ./\\-]+\.(?:ipynb|md)$")


def claimed_paths(bodies):
    """Paths cites par des commentaires [CLAIMED...] sans PR encore ouverte.

    Le 17/09 sur #16472, la fournée 1 a ete claimée par commentaires
    [CLAIMED-AMEND] (4 posts, ~25 fichiers, aucune PR) : invisible pour une
    deconfliction basee sur les PRs seules — exactement la classe de boucle
    de re-dispatch fermee sur #15719.
    """
    out = set()
    for body in bodies or []:
        if "[CLAIMED" not in body or "paths:" not in body:
            continue
        tail = body.split("paths:", 1)[1]
        for tok in re.split(r"[,\n]", tail):
            tok = tok.strip().rstrip(".").strip()
            if CLAIM_TOKEN.match(tok):
                out.add(tok.replace("\\", "/"))
    return out


def issue_claims(slug, issues):
    paths = set()
    for issue in issues:
        out = sh(["gh", "issue", "view", str(issue), "--repo", slug,
                  "--json", "comments"], check=False)
        try:
            comments = (json.loads(out) or {}).get("comments") or []
        except ValueError:
            continue
        for c in comments:
            paths |= claimed_paths([c.get("body") or ""])
    return paths


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


def plan(free, group_idx=1, pour_idx=1):
    """Bins that honour the fournee contract, plus the unusable leftover."""
    def grain_key(p):
        parts = p.split("/")
        # parts[group_idx] n'est une famille que s'il existe un segment PLUS
        # PROFOND (le fichier) : un notebook pose directement sous le domaine
        # (GameTheory/GameTheory-04b.ipynb) aurait sinon le NOM DE FICHIER
        # pour famille — une famille singleton sous le plancher, mesuré 17/09.
        if len(parts) > group_idx + 1:
            return parts[group_idx]
        return parts[1] if len(parts) > 1 else "divers"

    def pour_key(p):
        parts = p.split("/")
        return parts[pour_idx] if len(parts) > pour_idx else "divers"

    by_domain = collections.defaultdict(dict)
    pour_of = {}
    for p, f in free.items():
        by_domain[grain_key(p)][p] = f
        pour_of[p] = pour_key(p)

    bins, pockets = [], []
    for dom in sorted(by_domain, key=lambda d: -n_findings(by_domain[d])):
        chunks = split_domain(by_domain[dom])
        for i, ch in enumerate(chunks):
            name = dom if len(chunks) == 1 else "%s-%d" % (dom, i + 1)
            entry = [name, ch, dom, pour_key(next(iter(ch)))]
            (bins if n_findings(ch) >= FLOOR else pockets).append(entry)

    # Une poche se verse d'abord chez un grain CONFORME de sa FAMILLE, puis —
    # meme mecanisme qu'#15719 au niveau domaine — chez un grain conforme de
    # son DOMAINE qui a de la place : agrandir une fournee de son propre
    # domaine reste une fournee. Passer la frontiere du domaine n'est tolere
    # que comme residu explicite.
    residual = {}
    for name, ch, family, pour in pockets:
        host = None
        for b in bins:
            if (b[2] == family or b[3] == pour) \
                    and len(b[1]) + len(ch) <= MAX_FILES \
                    and (host is None or n_findings(b[1]) < n_findings(host[1])):
                host = b
        if host is not None:
            host[1].update(ch)
        else:
            residual.update(ch)
    if residual:
        if n_findings(residual) >= FLOOR and len(residual) <= MAX_FILES:
            bins.append(["residu-petits-domaines", residual, "residu", "residu"])
        else:
            print("WARN: residu non livrable laisse hors file (%d findings / %d fichiers): %s"
                  % (n_findings(residual), len(residual),
                     ", ".join(sorted(residual)[:8])))
    return [(b[0], b[1]) for b in bins]


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
    ap.add_argument("--issue", type=int, action="append", default=None,
                    help="contrat(s) a ravitailler (defaut: tous les contrats actifs)")
    ap.add_argument("--queue", default="outputs/vibe/feeder-queue.json")
    ap.add_argument("--scan-wt", default="D:/dev/CoursIA-vibe/_scan-queue")
    ap.add_argument("--wt-root", default="D:/dev/CoursIA-vibe")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    issues = args.issue or sorted(CONTRACTS)

    base = fresh_base(args.repo, args.base)
    print("base: %s | contrats: %s" % (base, ", ".join("#%d" % i for i in issues)))

    scan_wt = ensure_scan_wt(args.repo, base, args.scan_wt)
    held, open_branches = open_prs(args.slug, issues)
    claims = issue_claims(args.slug, issues)
    print("deconfliction: %d tenus par une PR ouverte (%s) | %d claims sans PR"
          % (len(held), ", ".join("#%d" % i for i in issues), len(claims)))

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

    grains = list(keep)
    total, n_planned = 0, 0
    for issue in issues:
        contract = CONTRACTS[issue]
        found = contract["scan"](scan_wt)
        free = {p: f for p, f in found.items()
                if p not in held and p not in kept_paths and p not in claims}
        print("#%d: scan %d fichiers avec findings | %d libres apres deconfliction"
              % (issue, len(found), len(free)))
        if not free:
            continue
        planned = plan(free, contract["group"])
        for name, ch in sorted(planned, key=lambda x: x[0]):
            n_planned += 1
            i = len(grains) + 1
            gid = "g%d-%s" % (i, re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:38])
            wt = "%s/%s" % (args.wt_root.rstrip("/"), gid)
            branch = "wt/vibe-%s" % gid
            targets = "\n".join("- %s" % p for p, _ in sorted(ch.items()))
            grains.append({
                "id": gid, "issue": issue, "baseSha": base, "worktree": wt,
                "branch": branch,
                "payload": contract["payload"].format(
                    gid=gid, base=base, targets=targets, worktree=wt, branch=branch),
            })
            n, k = n_findings(ch), len(ch)
            print("  %-42s findings=%-3d fichiers=%-3d %s"
                  % (gid, n, k, "OK" if (n >= FLOOR and k <= MAX_FILES) else "HORS CONTRAT"))
        total += sum(n_findings(ch) for _, ch in planned)
    if n_planned == 0:
        print("aucun finding libre — file inchangee")
        return

    out = {
        "_comment": ("File de travail des grains Mistral Vibe (po-2025). Reconstruite par "
                     "scripts/scheduling/refresh-vibe-queue.py sur re-scan frais de %s : %d findings "
                     "libres mesures, %d tenus par des PR ouvertes et %d claims sans PR (%s), "
                     "planifies en %d grain(s) de >= %d findings et <= %d fichiers. Les grains en "
                     "vol non livres sont conserves tels quels."
                     % (base[:12], total, len(held), len(claims),
                        ", ".join("#%d" % i for i in issues), n_planned, FLOOR, MAX_FILES)),
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
