# Protocole Meta-Analyse - Architecture 3x2 Scheduler (Roo)

**Version:** 3.0.0 (condensed from 2.0.0, aligned with .claude/rules/)
**MAJ:** 2026-04-08

## Architecture 3 Tiers

| Tier | Frequence | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyste** | 72h | TOUTES | Observer, analyser, PROPOSER |
| Coordinateur | 6-12h | ai-01 only | Trier, dispatcher, suivre |
| Executeur | 6h | TOUTES | Executer les taches assignees |

## Ce que Roo analyse

1. **Traces Roo (auto-analyse)** : Taux succes/echec par mode, escalades, usages outils. Outils MCP OBLIGATOIRES (`conversation_browser`, `roosync_search`).
2. **Traces Claude (croisee)** : Commits, worktrees, logs worker. **LIMITATION #874** : sessions Claude non indexees dans Qdrant.
3. **Harnais Claude** : `.claude/rules/`, `CLAUDE.md`, commands, skills, agents.
4. **Metriques operationnelles** : Issues creees/fermees, taux utilisation, violations.
5. **Frictions semantiques (#637)** : `roosync_search(has_errors: true)` pour patterns recurrents.

## Ce que Roo produit (#1081)

- **Issues GitHub DETAILLEES** avec contexte, donnees, metriques, recommandation
- **Dashboard COMPACT** : max 10 lignes (index vers issues, pas rapport)
- **Issues `needs-approval`** (propositions) / **`needs-approval` + `harness-change`** (modifications bloquantes)

## INTERDICTION ABSOLUE — Pas de fichiers rapport (#1179)

Les meta-analystes NE DOIVENT PAS creer de fichiers dans le depot pour leurs rapports.
Canaux de sortie : 1. Dashboard workspace 2. Issues GitHub 3. GDrive `.shared-state/meta-analysis/`

## Chaine de Decision

| Type | Action | Autorite |
|------|--------|----------|
| Informatif | Dashboard | Autonome |
| Suggestion | Dashboard + coordinateur | Autonome |
| Environnement (MCP HS) | Dashboard + flag coordinateur | Autonome |
| Nouvelle issue (bug, friction) | Creer `needs-approval` | Semi-autonome |
| Changement harnais | Creer `needs-approval` + `harness-change` | **BLOQUE** |

## Checks obligatoires (chaque cycle)

- **Sante outillage** : Outils inactifs >14j, bugs ouverts >14j, workarounds non resolus, secrets exposes
- **Interventions utilisateur (#981)** : BLOCAGE/CORRECTION/STOP=CRITICAL. Chacune = issue potentielle
- **Explosions contexte (#855)** : Taches >50 messages ou >100K chars. Causes : vitest sans troncature, lectures entieres, boucles
- **Performance -simple vs -complex (#981)** : Comparer taux succes, escalades, interventions user

## Garde-Fous (CRITIQUE)

**NE DOIT PAS :** Modifier `.roo/rules/`, `.claude/rules/`, `CLAUDE.md`, `.roomodes`, `modes-config.json`. Fermer/archiver/dispatcher issues. Git push --force/rebase. Creer issues SANS `needs-approval`.

**PEUT :** Lire toutes traces/fichiers. Creer issues avec `needs-approval`. Ecrire dashboard/GDrive. Commenter issues.

## Contraintes contexte

- Seuil condensation GLM : 75% (#1152). Pas de coverage tests. Limiter git log/diff `| head -30`.
- Si contexte sature → arreter, ecrire conclusions partielles sur dashboard.

## Workflow scheduler

`ask-complex` lit workflow → `code-complex` analyse traces → `ask-complex` analyse harnais Claude → `code-simple` ecrit dashboard → `ask-simple` lit reponse Claude → `code-simple` reconciliation → `code-simple` cree issues.

**Ref complete :** `.roo/scheduler-workflow-meta-analyst.md` | `docs/harness/reference/meta-analysis.md` (Claude)

---
**Historique versions completes :** Git history avant 2026-04-08
