#!/usr/bin/env python3
"""Genere un pack Vibe profond a partir d'une issue GitHub (depot via VIBE_REPO).

Le pack impose trois choses que les 12 runs d'aujourd'hui ont montrees necessaires :
 - un budget de commandes REPARTI, avec ecriture obligatoire des la commande 6 ;
 - une consigne de citer la GRANDEUR et son fichier quand l'issue cite un seuil
   (sans quoi l'agent prend l'unite la plus accessible -- incident #13410, 29/08) ;
 - une separation explicite etabli / non-etabli, et un doute renforce sur toute
   refutation TOTALE de la premisse de l'issue.
"""
import json, os, re, subprocess, sys, pathlib

REPO = os.environ.get("VIBE_REPO", "jsboige/CoursIA")

def gh(n):
    out = subprocess.run(
        ["gh", "issue", "view", str(n), "--repo", REPO,
         "--json", "number,title,body,labels"],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode:
        raise SystemExit(f"#{n}: {out.stderr.strip()[:200]}")
    return json.loads(out.stdout)

TPL = """Tu travailles dans le depot {repo}. AUDIT APPROFONDI en LECTURE SEULE, issue #{n}.

## L'issue, telle qu'elle est ecrite
**{title}**

{body}

## Mission
Verifier ce que cette issue affirme, **par la lecture du code et des fichiers**, jamais par la
citation de l'issue elle-meme. Pour chaque affirmation factuelle qu'elle contient :
1. localise ce dont elle parle (fichier, ligne, cellule) ;
2. lis-le reellement ;
3. rends un verdict **VERIFIE / PARTIELLEMENT VERIFIE / REFUTE / NON MESURABLE ICI**, porte par une
   citation.

**Si l'issue cite un seuil ou un chiffre, commence par etablir la GRANDEUR qu'il mesure et le fichier
qui la definit.** Un plancher peut porter sur un ratio, pas sur ce qui est le plus facile a compter.
Ne choisis jamais l'unite la plus accessible par defaut.

**Si ta mesure REFUTE totalement l'issue, arrete-toi et verifie l'unite avant d'ecrire.** Un ecart
partiel se discute ; un ecart TOTAL signale presque toujours un desaccord de definition, pas une
erreur de l'auteur.

## Budget
{cmds} commandes Bash, reparties ainsi :
- 1-5 : reperage
- **6 : ECRIRE une premiere version de `outputs/vibe/{slug}.md`, meme tres incomplete**
- 7-{last} : lire en profondeur (`cat`, pas seulement `grep`/`wc`) et reecrire le fichier a chaque progres
- dernieres : reserve

Un fichier imparfait vaut infiniment mieux qu'un run sans produit. N'attends jamais d'avoir tout
compris pour ecrire.

## Livrable
`outputs/vibe/{slug}.md` : une section par affirmation verifiee, chacune avec sa citation et son
verdict ; puis une section **Constat** disant ce que la mesure etablit, **ce qu'elle n'etablit PAS**,
et ce qu'il faudrait pour trancher le reste.

## Interdits
Aucun commit, aucune PR, aucune modification hors `outputs/vibe/`. Aucun chiffre que tu n'as pas
mesure toi-meme dans ce run — ecris "non mesure" plutot qu'une estimation presentee comme un fait.
"""

def slugify(n, title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return f"i{n}-{s[:44].rstrip('-')}"

def main():
    out = pathlib.Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
    cmds = 40
    made = []
    for n in sys.argv[2:]:
        d = gh(n)
        body = (d.get("body") or "").strip()
        if len(body) > 6000:
            body = body[:6000] + "\n\n[... corps tronque ...]"
        slug = slugify(d["number"], d["title"])
        p = out / f"{slug}.txt"
        p.write_text(TPL.format(n=d["number"], title=d["title"], body=body or "(corps vide)",
                                slug=slug, cmds=cmds, last=cmds - 3, repo=REPO),
                     encoding="utf-8", newline="\n")
        made.append((slug, p.stat().st_size))
    for s, sz in made:
        print(f"{sz:6d}  {s}")

main()
