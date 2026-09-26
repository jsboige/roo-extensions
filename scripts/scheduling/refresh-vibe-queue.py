#!/usr/bin/env python3
"""Rebuild the Vibe grain queue from fresh detector scans (#15719, #16472, #13410).

Multi-contrat depuis #16472 (GO ai-01 17/09, mandat user « résoudre
définitivement le pb d'approvisionnement ») : la file est l'union des grains
de chaque contrat actif — un détecteur épuisé n'assèche plus la lane.

#13410 (densité pédagogique, dispatch ai-01 18/09 02:02Z) casse le moule
« findings » : son unité est LE NOTEBOOK SOUS LE SEUIL (1200 chars de prose
par cellule code), pas un finding dénombrable. Le contrat porte donc sa
propre règle de taille (`floor`/`max_files` par entrée CONTRACTS) : grain =
1-2 notebooks, conforme au 1,67 fichier/PR mesuré sur les 61 PRs ouvertes.

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


PAYLOAD_DENSITY = """[WAKE-VIBE] {gid} (densite #13410, fournee dimensionnee sur re-scan frais)
baseSha: {base}
targetPath:
{targets}
worktree: {worktree}
branch: {branch}

Mission : relever CHAQUE notebook de targetPath au-dessus du seuil de densite
pedagogique (1200 chars de prose par cellule code ; mesurable par
`python scripts/notebook_tools/pedagogy_density.py <fichier>` : status ok
attendu), en ajoutant 1 a 3 cellules markdown de LECTURE ANCREE.
Convention etablie par les 61 PRs #13410 : une lecture explique le resultat
d'une cellule de code DEMONSTRATION deja executee (output commite, cite tel
quel). Deficit median mesure : 233 chars par notebook.

GARDE-FOUX EDITORIAUX NON NEGOCIABLES (incident 02/09, 30/41 accents
detruits) :
- UTF-8 sans repli ASCII : accents conserves a l'octet pres.
- `source` conserve en forme liste : JAMAIS re-serialise liste -> chaine.
- Markdown-only : cellules code, outputs, execution_count, metadata et IDs
  byte-identiques (aucune re-serialisation generale).
- AUCUNE re-execution du notebook.
- Ne JAMAIS narrer la sortie d'une cellule d'EXERCICE (detect_solution_leaks
  doit rester a 0) : lire les cellules de demonstration, pas celles ou
  l'eleve doit travailler.
- Ne JAMAIS fabriquer un chiffre : une lecture cite la sortie commitee ou
  elle n'existe pas.
- Une lecture fait 1-2 phrases, en francais, et EXPLIQUE ce que la sortie
  montre -- pas ce qu'elle est censee montrer.

INTERDIT : push, PR, gh, catalogue, Lean/lake, backtest, toute commande GPU, tout fichier hors targetPath, toute ecriture dans D:/dev/CoursIA (le seul lieu d'ecriture est le worktree ci-dessus).
N'utilise PAS l'outil fs/read_file pour lire/valider (refuse hors sandbox, brule le budget) : Python io.open uniquement.

CHECKPOINT-COMMIT obligatoire, puis rapport : densite avant/apres par fichier (seuil 1200, ok attendu), lectures ajoutees (nombre + cellule ancre), git status, liste des fichiers touches."""


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


#: Codes reellement traites par le contrat #16472. Les familles H1 (MULTI-H1,
#: H1-DEEP) sont exclues a dessein : hygiene H1 mecanique, pas du travail Vibe
#: (mesure ai-01 18/09). Pin explicite plutot que [A-Z-]+ : la regex generale
#: avalait EN SILENCE les codes a chiffre — 6 notebooks flagges restaient sans
#: aucune ligne resolue, angle mort mesure 18/09 (95 flagges / 89 resolus).
HIERARCHY_CONTRACTED = ("HINT-AS-HEADING", "HEADING-IN-LIST")
HIERARCHY_FINDING = re.compile(
    r"^\s+\[(%s)\] cell (\d+)\s+L(\d+)\s+(.*)$" % "|".join(HIERARCHY_CONTRACTED))
#: Toute ligne finding du census, contrat ou non — sert uniquement a rendre
#: visible (WARN) le tally des exclusions au lieu de l'avaler en silence.
HIERARCHY_ANY_FINDING = re.compile(r"^\s+\[([A-Z0-9-]+)\] cell \d+\s+L\d+")


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
    text = sh([sys.executable, script, "MyIA.AI.Notebooks"], cwd=wt)
    excluded = len(HIERARCHY_ANY_FINDING.findall(text)) - len(HIERARCHY_FINDING.findall(text))
    if excluded:
        print("#16472: %d findings hors contrat (MULTI-H1/H1-DEEP) ignores — "
              "hygiene H1 mecanique, pas du travail Vibe" % excluded)
    return parse_hierarchy_census(text)


def _repo_relative(path, wt):
    """Le scanner densite joint son repo_root absolu (rev-parse) aux chemins :
    ramener au repo-relatif que deconfliction et groupement attendent."""
    rel = path.replace("\\", "/")
    prefix = wt.replace("\\", "/").rstrip("/") + "/"
    if rel.lower().startswith(prefix.lower()):
        rel = rel[len(prefix):]
    return rel


def scan_pedagogy_density(wt):
    """{path: [unite]} ou l'unite du contrat #13410 est le NOTEBOOK sous le
    seuil — pas un finding denombrable. pedagogy_density.py est advisory par
    design : sa sortie JSON below_threshold EST le stock ; les exemptions
    (kinds hors corpus, setup) y sont deja soustraites par le scanner.
    Sans normalisation, la deconfliction ne soustrait RIEN et le groupement
    met toute la file dans la famille "dev" — mesure 18/09 sur le dry-run
    (333 libres, 0 soustrait).
    """
    script = os.path.join(wt, "scripts", "notebook_tools", "pedagogy_density.py")
    if not os.path.isfile(script):
        raise SystemExit("detecteur absent: %s" % script)
    data = json.loads(sh([sys.executable, script, "--json"], cwd=wt))
    return {_repo_relative(v["path"], wt):
            ["density=%s/%s cellules=%s" % (v.get("density"), v.get("threshold"),
                                            v.get("code_cells"))]
            for v in (data.get("below_threshold") or [])}


# Un contrat = un detecteur, son payload de mission et son axe de regroupement
# (index du segment de chemin qui definit le domaine/famille d'une fournee).
# 15719 : md-table, domaine = parts[1] (GenAI, QuantConnect...) ;
# 16472 : hierarchie markdown, famille = parts[2] (Audio, Image...) — le
# contrat exige "une famille/serie par fournee" ;
# 13410 : densite pedagogique, domaine = parts[1] — l'unite est le notebook
# sous le seuil, la regle de taille est PROPRE au contrat (dispatch ai-01
# 18/09 : "ne pas forcer #13410 dans le moule findings — ça produirait des
# grains vides ou monstrueux") : grain = 1-2 notebooks, conforme au
# 1,67 fichier/PR mesure sur les 61 PRs ouvertes.
CONTRACTS = {
    # `branch_prefix` : le prefixe `wt/vibe-` est lu par l'organe de merge
    # automatique de CoursIA -- `FROZEN_BRANCH_PREFIXES = {"wt/vibe-": "13410"}`
    # dans `scripts/coordination/frozen_campaigns.py`, importe par
    # `merge_ready.py` -- et range la PR dans la famille gelee #13410 QUELLE QUE
    # SOIT son issue reelle (le test porte sur `head_ref.startswith(prefix)`, sans
    # exemption). Un grain non-densite
    # nomme `wt/vibe-*` produit donc un livrable que rien ne mergera (mesure
    # 25/09 : grain #16472 g2 parti sur `wt/vibe-g2-residu-petits-domaines`).
    # Le defaut est non-gele pour qu'un contrat ajoute sans prefixe reste
    # mergeable ; seul #13410, qui EST la famille gelee, garde `wt/vibe-`.
    15719: {"scan": scan_md_table, "payload": PAYLOAD, "group": 1,
            "branch_prefix": "wt/mistral-table-"},
    16472: {"scan": scan_md_hierarchy, "payload": PAYLOAD_HINT, "group": 2,
            "branch_prefix": "wt/mistral-hint-"},
    13410: {"scan": scan_pedagogy_density, "payload": PAYLOAD_DENSITY,
            "group": 1, "floor": 1, "max_files": 2,
            # Gele par veto user (#17040, 2026-09-20 ; umbrellas 13410 et
            # 11601 definis dans CoursIA scripts/coordination/frozen_campaigns.py,
            # lus par merge_ready et le gate d'entree). Le feeder re-mesurant
            # la file SANS filtre, ce drapeau est ce qui empeche chaque
            # epuisement de file de rouvrir le dispatch densite. Un --issue
            # 13410 explicite reste possible si le veto est leve.
            "frozen": True,
            "branch_prefix": "wt/vibe-"},
}


def default_issues():
    """Contrats servis quand l'appelant n'en nomme aucun : les NON geles.

    Fail-closed vis-a-vis du veto : le feeder re-mesure la file SANS filtre
    (vibe-feeder.ps1, Invoke-QueueRefresh) des qu'elle est vide — si le
    defaut incluait #13410, chaque epuisement de file rouvrirait
    mecaniquement le dispatch densite sous veto (mesure 25-26/09 : file
    reconstruite a 121 grains dont 120 de #13410, dispatches g4-g7 en une
    nuit). Nommer le contrat explicitement reste la voie operatoire.
    """
    return sorted(i for i, c in CONTRACTS.items() if not c.get("frozen"))


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


def merged_branches(slug, branches):
    """Which of these grain branches carry a MERGED PR -- exact per-branch lookup.

    open_prs() only ever sees `--state open`, so a grain whose work HAS been
    merged falls out of `open_branches` and looks in-flight again: keepable()
    keeps it as long as its worktree carries commits, the feeder SKIPs it on
    the stale baseSha every tick, and the refresh re-keeps it forever. Once
    the worktree is gone the feeder re-seeds the base and REPLAYS it -- a paid
    run on work already merged.

    Measured 2026-09-14 on g1-genai: delivered by #16041 (00:19:53Z) and
    #16067 (03:57:44Z), it SKIP-looped from the first tick after the merge,
    and was replayed at 07:16:01Z as soon as its worktree was removed.

    The lookup is per QUEUED branch with `--head`, not a bulk
    `--state merged --limit N` row window: at the measured CoursIA rate 300
    rows span ~58 h, and a merged grain still queued past the window would
    become invisible -- reopening the exact replay this closes (#3755
    review; reliquat of #3643). One call per queued branch (the queue holds a handful), with no
    dependence on how fast history scrolls.

    check=False: a gh failure must leave the queue as it is, never crash the
    refresh. A failed or unreadable lookup says so on stdout and leaves that
    branch undelivered -- it drops nothing and never widens the drop.
    """
    delivered = set()
    for b in sorted(branches):
        out = sh(["gh", "pr", "list", "--repo", slug, "--state", "merged",
                  "--head", b, "--json", "number", "--limit", "1"], check=False)
        if not out.strip():
            print("WARN: lookup merged sans reponse pour %s — branche traitee non livree" % b)
            continue
        try:
            if json.loads(out):
                delivered.add(b)
        except ValueError:
            print("WARN: lookup merged illisible pour %s — branche traitee non livree" % b)
    return delivered


def split_domain(files, max_files=None):
    """Cut one domain's files into BALANCED chunks of <= max_files.

    A greedy cut of max_files-then-tail leaves an under-floor tail on every
    domain that overflows, and a tail has no same-domain home — it then leaks
    into an unrelated grain, which is how QuantConnect files once ended up in a
    GameTheory fournee. Spreading the heaviest files round-robin across
    ceil(n/max_files) chunks keeps every chunk above the floor instead.
    """
    max_files = MAX_FILES if max_files is None else max_files
    items = sorted(files.items(), key=lambda kv: (-len(kv[1]), kv[0]))
    n_chunks = max(1, -(-len(items) // max_files))
    chunks = [{} for _ in range(n_chunks)]
    for i, (path, fs) in enumerate(items):
        chunks[i % n_chunks][path] = fs
    return chunks


def plan(free, group_idx=1, pour_idx=1, floor=None, max_files=None):
    """Bins that honour the fournee contract, plus the unusable leftover.

    `floor`/`max_files` viennent du contrat (CONTRACTS) : le moule findings
    (FLOOR=10) n'exprime pas #13410, dont l'unite est le notebook sous le
    seuil — grain = 1-2 notebooks.
    """
    floor = FLOOR if floor is None else floor
    max_files = MAX_FILES if max_files is None else max_files
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
        chunks = split_domain(by_domain[dom], max_files)
        for i, ch in enumerate(chunks):
            name = dom if len(chunks) == 1 else "%s-%d" % (dom, i + 1)
            entry = [name, ch, dom, pour_key(next(iter(ch)))]
            (bins if n_findings(ch) >= floor else pockets).append(entry)

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
                    and len(b[1]) + len(ch) <= max_files \
                    and (host is None or n_findings(b[1]) < n_findings(host[1])):
                host = b
        if host is not None:
            host[1].update(ch)
        else:
            residual.update(ch)
    if residual:
        if n_findings(residual) >= floor and len(residual) <= max_files:
            bins.append(["residu-petits-domaines", residual, "residu", "residu"])
        else:
            print("WARN: residu non livrable laisse hors file (%d findings / %d fichiers): %s"
                  % (n_findings(residual), len(residual),
                     ", ".join(sorted(residual)[:8])))
    return [(b[0], b[1]) for b in bins]


def keepable(queue, base, delivered_branches):
    """In-flight grains survive; delivered ones leave the queue.

    `delivered_branches` carries BOTH states on purpose: a branch with an open
    PR has its work staged, one with a merged PR has it landed. In both cases
    there is nothing left for the grain to do -- and a grain kept past its
    merge is not merely idle, it is replayable (see merged_branches).

    A delivered NAME is not proof that this GRAIN is delivered, though: grain
    IDs and branch names are positional, and `wt/vibe-g1-genai` was already
    reused by several merged PRs with diverged tips, which is what happens
    when a deterministic grain ID comes back after a queue drain (#3755
    review; reliquat of #3643). A delivered branch is therefore dropped only when its worktree is
    ABSENT or provably EMPTY (no commits beyond base, nothing dirty); a
    delivered name carrying an ahead/dirty worktree is an in-flight
    generation that merely reuses the name, and the grain stays.
    """
    keep, dropped = [], []
    for g in queue.get("grains") or []:
        wt = g.get("worktree") or ""
        branch = g.get("branch") or ""
        in_flight = False
        if os.path.isdir(wt):
            ahead = sh(["git", "-C", wt, "rev-list", "--count", "%s..HEAD" % base], check=False).strip()
            dirty = sh(["git", "-C", wt, "status", "--porcelain"], check=False).strip()
            in_flight = (ahead.isdigit() and int(ahead) > 0) or bool(dirty)
        if branch in delivered_branches:
            if in_flight:
                print("WARN: branche livree %s reutilisee par un worktree en vol — grain %s conserve (generation en cours)"
                      % (branch, g.get("id")))
                keep.append(g)
            else:
                dropped.append(g.get("id"))
            continue
        if in_flight:
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
                    help="contrat(s) a ravitailler (defaut: les contrats NON geles ; "
                         "un contrat gele ne s'obtient qu'en le nommant explicitement)")
    ap.add_argument("--queue", default="outputs/vibe/feeder-queue.json")
    ap.add_argument("--scan-wt", default="D:/dev/CoursIA-vibe/_scan-queue")
    ap.add_argument("--wt-root", default="D:/dev/CoursIA-vibe")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    issues = args.issue or default_issues()

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
    queue_branches = {g.get("branch") for g in (old.get("grains") or []) if g.get("branch")}
    delivered = open_branches | merged_branches(args.slug, queue_branches)
    print("branches livrees (ouvertes + merged au lookup exact par branche): %d" % len(delivered))
    keep, dropped = keepable(old, base, delivered)
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
        planned = plan(free, contract["group"],
                       floor=contract.get("floor"),
                       max_files=contract.get("max_files"))
        for name, ch in sorted(planned, key=lambda x: x[0]):
            n_planned += 1
            i = len(grains) + 1
            slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:38]
            prefix = contract.get("branch_prefix", "wt/mistral-")
            # Un nom deja porte par une PR ouverte ou livree rend le grain
            # INDISPATCHABLE : Prepare-Worktree rattache la branche existante
            # seulement si elle n'a RIEN d'avance, sinon le tick le SKIP a chaque
            # passage (mesure 25/09 : `g2-residu-petits-domaines` portait la
            # branche d'une PR du 15/09, deja mergee -> grain neuf jamais parti).
            # Le generateur connait deja les noms pris : il decale la generation
            # au lieu d'emettre un nom brule.
            gid = "g%d-%s" % (i, slug)
            branch = "%s%s" % (prefix, gid)
            bump = 2
            while branch in delivered:
                gid = "g%d-%s-%d" % (i, slug, bump)
                branch = "%s%s" % (prefix, gid)
                bump += 1
            delivered.add(branch)
            wt = "%s/%s" % (args.wt_root.rstrip("/"), gid)
            targets = "\n".join("- %s" % p for p, _ in sorted(ch.items()))
            # Discriminant de generation (#3755) : on capture la SHA de tete du
            # worktree au moment ou le grain est pose en file. Le feeder
            # comparera cette valeur au HEAD reel du worktree AVANT chaque
            # repost : si elle diverge, le worktree a ete reutilise pour une
            # nouvelle generation et le grain porte un nom mais pas la bonne
            # tete — eviction sans appel a gh.
            wt_head = ""
            if os.path.isdir(wt):
                wt_head = sh(["git", "-C", wt, "rev-parse", "HEAD"],
                             check=False).strip()
            grains.append({
                "id": gid, "issue": issue, "baseSha": base, "wtHead": wt_head,
                "worktree": wt, "branch": branch,
                "payload": contract["payload"].format(
                    gid=gid, base=base, targets=targets, worktree=wt, branch=branch),
            })
            n, k = n_findings(ch), len(ch)
            ok = (n >= contract.get("floor", FLOOR)
                  and k <= contract.get("max_files", MAX_FILES))
            print("  %-42s findings=%-3d fichiers=%-3d %s"
                  % (gid, n, k, "OK" if ok else "HORS CONTRAT"))
        total += sum(n_findings(ch) for _, ch in planned)
    if n_planned == 0:
        print("aucun finding libre — file inchangee")
        return

    out = {
        "_comment": ("File de travail des grains Mistral Vibe (po-2025). Reconstruite par "
                     "scripts/scheduling/refresh-vibe-queue.py sur re-scan frais de %s : %d unites "
                     "libres mesurees (findings, ou notebooks sous le seuil pour #13410), %d tenues par "
                     "des PR ouvertes et %d claims sans PR (%s), planifiees en %d grain(s) dont la "
                     "taille est propre a chaque contrat. Les grains en vol non livres sont "
                     "conserves tels quels."
                     % (base[:12], total, len(held), len(claims),
                        ", ".join("#%d" % i for i in issues), n_planned)),
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
