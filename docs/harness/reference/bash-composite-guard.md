# Hook `guard-bash-composite` — refuse les Bash composées `cd`+`rm` au lieu de les geler (#4243)

**Script :** [`scripts/hooks/guard-bash-composite.js`](../../../scripts/hooks/guard-bash-composite.js)
**Tests :** [`scripts/hooks/tests/guard-bash-composite.test.js`](../../../scripts/hooks/tests/guard-bash-composite.test.js) (23 assertions, exécutées en CI — job static)
**Origine :** issue #4243, priorité user du 18/10 — 2-3 agents gelés/jour par une attente d'approbation silencieuse.

---

## Ce que ça protège

En mode bypass / auto-approve, certaines commandes `Bash` **composées** déclenchent une attente
d'approbation **silencieuse** : l'agent ne sait pas qu'il attend, le cron suivant ne débloque pas,
le user ne le voit qu'en regardant la fenêtre. Incidents mesurés sur ai-01:CoursIA :

| Date (UTC) | Durée | Forme | Effet |
| --- | --- | --- | --- |
| 15/10 07:37→08:40 | ~1 h | `rm -rf <abs> 2>/dev/null; git worktree add … && cd <autre dossier> && …` | cycle coordinateur gelé |
| 17/10 ~14:40 → 18/10 ~06:40 | **~16 h** | `cd <autre worktree> && rm -f ../<fichier>; git status …` | PR réparant `main` rouge non mergée toute la nuit |

**Facteur commun (supposé, non isolé — repro contrôlé en cours)** : un `cd` hors du répertoire de
travail **et** un `rm` sur un chemin dans la **même** commande composée. Les `rm` seuls, `cd` seuls
et chemins absolus seuls n'ont pas bloqué ailleurs dans les mêmes sessions.

## Ce que fait la garde

Le hook **convertit l'attente silencieuse en refus immédiat et actionnable** : exit 2 + message
donnant la réécriture (`git -C <chemin>`, suppression en commande isolée, `git worktree remove`).
L'agent voit le refus dans le tour et corrige ; la lane ne gèle plus.

**Détection (volontairement conservative — deny-wide)** : commande avec séparateur composite
(`&&`, `||`, `;`, `|`, newline) contenant **à la fois** un `cd <cible>` (cible ≠ `.`) et un `rm`
avec un argument non-option. La conjunction seule suffit, sans résolution de cwd : les faux
positifs (`cd sous-dossier && rm x`) coûtent une réécriture ; les faux négatifs d'une détection
plus fine coûtent des lanes gelées.

**Fail-open** : payload illisible, outil non-Bash, commande simple → exit 0. Un hook cassé ne coupe
jamais l'outil.

**Rollback** : `BASH_COMPOSITE_GUARD=0` dans l'env désactive la garde (défaut : active).

## Câblage

```text
settings harness (~/.claude/settings.json — JAMAIS dans le repo)
  hooks.PreToolUse :
    matcher : "Bash"
    command : node <repo>/scripts/hooks/guard-bash-composite.js
```

Déploiement par siège : le hook vit dans le repo ; l'entrée `hooks` du settings machine se pose à
la main (ou par le script de déploiement du siège) au même titre que `guard-pdf-read` / `log-tool-start`.

## Ligne CLAUDE.md associée (parade immédiate)

La prose réduit la fréquence mais a déjà échoué seule (règle en mémoire locale enfreinte le 17/10
en pleine passe) — elle est déployée **en plus** du hook, pas à sa place : section « Tool Discipline »
du global (`.claude/configs/user-global-claude.md`), ligne « Bash sans attente d'approbation ».

## Reste ouvert sur #4243

- **Repro contrôlée** (point 1 de l'issue) : session jetable en bypass, formes candidates isolées
  une à une — en cours, résultats à verser sur l'issue.
- **Détecteur web1** (volet transcripts, point 3) : session en attente > N minutes — porté par web1.
- Déploiement flotte de la parade : claudish (harmonisation `settings.json`).
