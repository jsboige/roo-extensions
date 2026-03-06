# Règles de Délégation - Sub-agents Claude Code

**Version:** 1.0.0
**Créé:** 2026-03-06
**Issue:** #566

---

## Principe Fondamental

**La conversation principale orchestre, les sub-agents exécutent.**

Le contexte principal est précieux (limité, coûteux). Les sub-agents ont leur propre contexte isolé et peuvent être parallélisés.

---

## Quand Déléguer (OBLIGATOIRE)

Déléguer à un sub-agent si la tâche :

1. **Nécessite pas le contexte accumulé** de la conversation
2. **Est autonome** = entrées claires, sorties attendues définies
3. **Peut être parallélisée** avec d'autres tâches indépendantes
4. **Implique une recherche approfondie** (codebase, documentation)
5. **Est une implémentation guidée** avec spécifications précises

### Exemples de délégation

| Tâche | Agent | Raison |
|-------|-------|--------|
| Rechercher les usages d'une fonction | `code-explorer` ou `Agent(subagent_type="Explore")` | Recherche isolée |
| Implémenter une issue GitHub bien spécifiée | `issue-worker` (à créer) | Tâche autonome |
| Auditer les configs MCP cross-machine | `config-auditor` (à créer) | Recherche + rapport |
| Exécuter un script avec gestion d'erreurs | `script-runner` (à créer) | Exécution isolée |
| Review une PR/diff | `pr-reviewer` (à créer) | Analyse autonome |

---

## Quand NE PAS Déléguer

Garder dans le contexte principal si :

1. **Décision architecturale** requiert l'historique de discussion
2. **Résolution de conflits** git ou entre parties
3. **Communication utilisateur directe** (réponses à questions)
4. **Nécessite le contexte accumulé** de la conversation
5. **La tâche est triviale** (< 1 minute de travail)

---

## Parallélisation (RECOMMANDÉ)

Si 2+ tâches sont **indépendantes**, lancer les agents **en parallèle** dans une seule réponse.

### Exemple

```markdown
Je lance 3 recherches en parallèle pour analyser les différents aspects :

[Appel Agent 1: Recherche implémentation X]
[Appel Agent 2: Recherche tests liés]
[Appel Agent 3: Recherche documentation]
```

**Avantages :**
- Gain de temps significatif (exécution simultanée)
- Contexte principal reste léger
- Résultats comparables côte-à-côte

---

## Format de Rapport des Agents

Chaque sub-agent doit retourner un rapport structuré :

```markdown
## Rapport {NomAgent}

### Tâche
[Bref rappel de la tâche assignée]

### Résultat
- **Statut:** SUCCESS / PARTIAL / FAILED
- **Fichiers impactés:** [liste]
- **Changements:** [résumé]

### Détails
[Corps du rapport]

### Recommandations
[Actions suivantes si pertinent]
```

---

## Agents Disponibles

### Agents Globaux (`~/.claude/agents/`)

| Agent | Usage |
|-------|-------|
| `git-sync` | Pull conservatif, résolution conflits |
| `test-runner` | Build + tests unitaires |
| `code-explorer` | Exploration codebase |

### Agents Projet (`.claude/agents/`)

| Agent | Usage |
|-------|-------|
| `github-tracker` | Suivi GitHub Project |
| `intercom-handler` | Communication locale Roo |
| `intercom-compactor` | Condensation INTERCOM |
| `sddd-router` | Routage SDDD |
| `task-planner` | Analyse avancement |

### Workers (`.claude/agents/workers/`)

| Agent | Usage |
|-------|-------|
| `code-fixer` | Investigation + correction bugs |
| `consolidation-worker` | Exécution consolidations CONS-X |
| `doc-updater` | MAJ documentation |
| `test-investigator` | Investigation tests échoués |

### Coordinateur (`.claude/agents/coordinator/`)

| Agent | Usage |
|-------|-------|
| `roosync-hub` | Hub RooSync (ai-01) |
| `dispatch-manager` | Assignation tâches |

### Agents Intégrés (Agent tool)

| subagent_type | Usage |
|---------------|-------|
| `Explore` | Exploration codebase rapide |
| `Plan` | Planification implémentation |
| `general-purpose` | Tâches diverses |

---

## Agents à Créer (Roadmap #566)

| Agent proposé | Rôle | Priorité |
|---------------|------|----------|
| `issue-worker` | Exécuter issue GitHub complète | HAUTE |
| `config-auditor` | Auditer configs MCP/modes | HAUTE |
| `codebase-researcher` | Recherche SDDD multi-pass | MOYENNE |
| `script-runner` | Exécuter scripts avec rapport | MOYENNE |
| `pr-reviewer` | Review PR avec critique | BASSE |
| `issue-triager` | Classification issues | BASSE |
| `sync-checker` | Vérification git/MCP/schtasks | BASSE |

---

## Intégration avec les Skills/Commands

Cette règle est automatiquement incluse dans :
- `/coordinate` (myia-ai-01) - Orchestration multi-machine
- `/executor` (autres machines) - Exécution autonome
- `sync-tour` - Phases parallélisables

---

## Références

- Issue #566: Enrichir sub-agents
- Issue #563: Restriction MCPs orchestrateurs Roo (pendant)
- `.claude/rules/agents-architecture.md`: Architecture agents
- `~/.claude/agents/`: Agents globaux

---

**Dernière mise à jour:** 2026-03-06
