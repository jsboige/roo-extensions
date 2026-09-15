# ADR 014: Anti-tarissement des lanes — convergence CoursIA (picker 3 urnes, deep-queue, test-resultat)

**Date:** 2026-09-15
**Status:** Accepted
**Issue:** #3675 (Epic #3111 phase 2, candidat #2)
**Related:** #2185 (cap IDLE 3), #2509 (`--limit 15` faux drain), #3111 (Epic convergence),
#3155 (PR audit filesystem CoursIA), #1417 (catalogue idle I1-I8)

## Context

L'observation user n°1 (recurrence 2025-2026) : **les lanes executor roo-extensions se tarissent**.
Le cap IDLE 3 (#2185), le re-arm cron/WAKE et la discipline `gh issue list --limit 100` (PIEGE #2509)
ont amelioré le faux drain mais n'ont pas resolu le tarissement.

L'audit filesystem CoursIA (PR #3155, passe 2) a documente les contre-mesures qui fonctionnent
la-bas : picker 3 urnes ponderees, test de fin de cycle base sur le resultat (pas le vocabulaire),
deep-queue par lane pour les mandates durables.

### Problemes identifies

1. **Monoculture des issues recentes.** `gh issue list` plafonne a `--limit N` retourne les N PLUS
   RECENTES issues. Si les 15/30 dernieres sont toutes `needs-approval` ou meta, l'agent conclut
   faussement « pool draine » alors que des dizaines de grains actionnables existent plus bas.
   Bug local documente : #2509 (`--limit 15` faux drain).

2. **Vocabulaire d'idle contournable.** Le test « idle-honnete » actuel repose sur des labels
   (`needs-approval`, `blocked-on-gate`, etc.). Un agent peut apprendre a les poser pour justifier
   l'idle sans avoir transforme de grain en PR. Le test doit etre sur le RESULTAT, pas le label.

3. **Lane = etiquette de reporting, pas frontiere de travail.** CoursIA R4 (coordinator-discipline)
   l'enonce explicitement : le pool est GLOBAL cross-lane, et le picker tire dedans sans prejudice
   de lane. Le regime « picker-first » du 20/08 cote CoursIA a valide l'approche.

4. **Cap IDLE 3 (#2185) ne suffit pas.** Sans test-resultat, l'agent peut declarer IDLE honnete
   meme quand le pool contient des grains ; le cap penalise la forme mais pas le fond.

## Decision

### 1. Picker 3 urnes ponderees — `scripts/scheduling/pick_idle_grain.py`

Le picker tire dans 3 urnes :

| Urne | Source | Label set | Poids par defaut |
|------|--------|-----------|------------------|
| `grain` | Issues actionnables | `approved`, `bug`, `investigation` | 7 |
| `umbrella` | Issues parentes/epics | `epic` | 2 |
| `delivered` | PRs ouvertes (verrou commentaire) | (n/a) | 1 |

**Parametres :**
- `--limit 300` (defaut) : corrige #2509, echantillonne le backlog reel.
- `--seed 42` (defaut) + `--reroll` : graine deterministe reproductible.
- `--weights "grain:7,umbrella:2,delivered:1"` : override.
- Scan les 2 depots (anti-double-claim #3407) : `jsboige/roo-extensions` + `jsboige/jsboige-mcp-servers`.

**Verdict IDLE-REAL :** declenche UNIQUEMENT si `grain + umbrella + delivered = 0`. Sinon PICK.

### 2. Test de fin de cycle — `scripts/scheduling/test_cycle_end.py`

Remplace « idle-honnete » (vocabulaire) par **test-resultat** (sortie).

```
verdict = PASS  si backlog_actionnable == 0 (REELLEMENT draine)
        |  PASS  si prs_delivered > 0 dans la fenetre
        |  FAIL  sinon (echec de methode)
```

**Sortie :** exit 0 / exit 1, JSON pour CI.

**Integration executor :** Le SKILL.md Phase 2 gagne une etape 9 qui invoque le test avant
de basculer sur le catalogue idle I1-I8. Si FAIL → l'agent doit reprendre Phase 2 (relire le
picker, prendre un grain reel).

### 3. Deep-queue par lane — pattern documente (non code)

Pour les lanes a mandate durable (ex. Vibe, myia-po-2025), la file est PRE-AUTORISEE par le
coordinateur : `outputs/vibe/feeder-queue.json` (gitignored) contient les grains tries par
priorite avec `baseSha`, `finding`, et `contract`. Le picker Vibe lit cette file directement
sans repasser par `gh issue list`.

**Rationale :** le pool global cross-lane (picker 3 urnes) coexiste avec les files locales
deep-queue par lane. La lane Vibe a un domaine precis (markdown table syntax) que le pool
global ne couvre pas.

**Non-but explicite :** ne PAS importer la cadence CoursIA (30 min cron vs 4 h schtask). Les
gardes #2185 (cap IDLE 3) et le re-arm cron/WAKE restent la cadence locale de roo-extensions.

## Consequences

### Positives

- **Anti-tarissement reel.** Le test-resultat bloque la sortie facile « idle honnete ».
- **Anti-monoculture.** `--limit 300` + 3 urnes elargit l'espace de recherche.
- **Reproductibilite.** `--seed` deterministe, `--reroll` pour explorer, `--json` pour CI.
- **Compatibilite ascendante.** Le picker est un outil, pas un remplacement du Phase 2 du SKILL.md.
  Les priorites 1-6 (instructions directes, Machine=*, TODO detaille, bug, in-progress) restent.

### Negatives / trade-offs

- **Cout `gh` API plus eleve.** `--limit 300` x 2 depots = 600 issues + 600 PRs par appel.
  Mitigation : cache local possible (futur), et le picker n'est PAS dans la boucle chaude
  du worker (1 fois par cycle).
- **Verdict FAIL peut surprendre.** Un agent peut se voir refuser IDLE alors qu'il pensait
  avoir respecte Phase 2. C'est le but — forcer la reflexion.

### Non-buts reaffirmes

- Pas de migration cadence CoursIA (30 min cron).
- Pas de modification `#2185` cap IDLE 3 (garde fleche, test-resultat s'y superpose).
- Pas de suppression des priorites 1-6 du Phase 2.

## Implementation

| Fichier | Role |
|---------|------|
| `scripts/scheduling/pick_idle_grain.py` | Picker 3 urnes (grain/umbrella/delivered), --limit 300, --seed, --reroll |
| `scripts/scheduling/test_cycle_end.py` | Test-resultat : PASS si 0 backlog OU >0 livraison dans --since-hours |
| `.claude/skills/executor/SKILL.md` | Phase 2 etape 9 : invoquer `test_cycle_end.py` avant I1-I8 |
| `.claude/commands/executor.md` | Section picker : commande canonique et exemple sortie |
| `.claude/rules/validation.md` | Note : picker et test sont des outils CLI, validation par `python -m py_compile` |

## References

- CoursIA `proactive-coordination.md` (7 regles HARD), `coordinator-discipline.md` R4
- CoursIA `pick_idle_grain.py` (inspiration directe)
- Issue #2509 (bug `--limit 15` faux drain)
- Issue #2185 (cap IDLE 3 — reste en place)
- Issue #3111 (Epic convergence)
- Issue #3675 (candidat #2 de la phase 2, ce document)
- Issue #3676 (candidat #3 — claim sur issue GitHub, livre par po-2026 #3680)
- Issue #3678 (candidat #8 — alertes survivantes, lien cross-pollinisation)
