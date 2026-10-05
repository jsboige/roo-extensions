# Commands ↔ Skills — allowlist explicite de parité

**Version:** 1.0.0
**Issue :** #3381 (mission D9 — prescription ai-01 03/09, dispatch 05/10)
**MAJ :** 2026-10-05

---

## Pourquoi ce fichier

Le portage commands → skills n'a **jamais été 1:1** : les skills s'auto-invoquent (matching de
description) et restent appelables par `/nom` ; les fichiers de `commands/` portent les entrées
**uniquement explicites**. Cette asymétrie est structurelle, mais elle n'était écrite nulle part :
toute dérive de parité (command sans raison d'être, skill détaché) était indétectable au recompte.
Ce fichier est l'allowlist — ce qui est apparié, ce qui est orphelin **par intention**, et la
recette de re-vérification.

## État mesuré (2026-10-05, firsthand — 5 commands, 9 skills)

### Paires command ↔ skill (2)

| Command | Skill | Rôle |
|---|---|---|
| `/executor` | `executor` | Session d'exécution autonome (cron `41 */4`) |
| `/debrief` | `debrief` | Bilan de session |

### Commands sans skill (3) — INTENTIONNEL

| Command | Pourquoi sans skill |
|---|---|
| `/coordinate` | Session coordinateur ai-01 — invoquée par cron `23 */12`, jamais par auto-trigger (un auto-trigger coordinator serait une régression d'intention) |
| `/switch-provider` | Bascule explicite de provider — geste utilisateur deliberé, aucun contexte à matcher |
| `/team` | Pipeline team-… explicite — l'auto-invocation d'un orchestrateur multi-étapes n'est pas voulue |

### Skills sans command (7) — INTENTIONNEL

| Skill | Vocation |
|---|---|
| `git-sync` | Patrouille/sync — auto-invoquée au contexte git |
| `github-status` | Vue d'état GitHub — auto-invoquée |
| `memory-inject` | Injection mémoire de début de session — auto-invoquée par le Session Pattern |
| `pr-review` | Review de PRs — auto-invoquée en fallback executor (priorité 8) |
| `redistribute-memory` | Maintenance mémoire — auto-invoquée |
| `sync-tour` | Tour de synchronisation flotte — auto-invoquée |
| `validate` | Checklist validation consolidation/refactoring — auto-invoquée au contexte |

Ces skills restent appelables `/nom` (un skill est toujours slash-invocable) ; leur absence de
fichier dans `commands/` signifie seulement qu'aucune entrée **purement explicite** n'est requise.

## Preuve qu'aucune étape de portage n'a été perdue (D9, smoking gun réfuté)

`git log --diff-filter=D --name-only -- .claude/commands/` (main, 05/10) : **un seul** fichier
command supprimé dans l'histoire — `switch-provider.md` (e71b7c3c8, restauré depuis ; présent à
HEAD). Les 7 skills orphelins sont **nés skills** (`--diff-filter=A` sur `.claude/skills/` :
pr-review 25/04, memory-inject 17/04, executor 28/03, debrief 12/02…) — aucun n'est un command
porté incomplètement. L'écart de parité est structurel, pas une régression.

## Recette de re-vérification (à jour à chaque recompte #3321)

```bash
comm -3 <(ls .claude/commands/*.md | sed 's|.*/||;s|\.md||' | sort) \
        <(ls -d .claude/skills/*/ | sed 's|.*/\([^/]*\)/|\1|' | sort)
# lignes préfixées tab = skills-only ; préfixées colon = commands-only
# Toute ligne NON listée ci-dessus = dérive → mise à jour de cet allowlist (ou du code)
```

---

**Règle de maintenance :** toute nouvelle command ou tout nouveau skill met à jour ce fichier
dans la même PR (règle de recompte #3321 étendue à la parité).
