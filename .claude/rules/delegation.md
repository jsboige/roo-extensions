# Règles de Délégation - Sub-agents Claude Code

**Version:** 1.0.0
**Créé:** 2026-03-06
**Issue:** #566

---

## Principe Fondamental

**La conversation principale orchestre, les sub-agents exécutent.**

Le contexte principal est précieux (limité, coûteux). Les sub-agents ont leur propre contexte isolé et peuvent être parallélisés.

### Règle du Contexte Isolé (CRITIQUE)

**Un sub-agent ne doit JAMAIS hériter du contexte de la conversation principale.** Construis précisément ce dont il a besoin.

Un prompt de délégation efficace contient :

1. **La spec complète** de la tâche (pas "voir la conversation")
2. **Les fichiers concernés** avec leurs chemins exacts
3. **Le contexte minimal suffisant** (architecture locale, contraintes connues)
4. **Les sorties attendues** (format du rapport, fichiers à modifier, tests à passer)

**Pourquoi :** Un sous-agent qui hérite du contexte entier produit des résultats confus (trop de bruit), coûte plus cher, et peut mélanger des décisions de tâches précédentes avec la tâche courante.

**Exemple de délégation insuffisante :**

```
"Implémente l'issue #739 comme on en a discuté."
```

**Exemple de délégation correcte :**

```
"Implémente l'issue #739 : ajouter la méthode bulkOperation() dans MessageManager.
Fichiers à modifier : src/services/roosync/MessageManager.ts (ajouter méthode),
src/tools/roosync/manage.tool.ts (nouveau case 'bulk_mark_read').
Contraintes : TypeScript strict, tests vitest requis, build doit passer.
Retourne : DONE avec commit hash, ou BLOCKED avec description du blocage."
```

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

Chaque sub-agent doit retourner un rapport structuré avec un statut parmi :

| Statut | Signification | Action de l'orchestrateur |
|--------|---------------|--------------------------|
| `DONE` | Travail terminé avec succès | Passer à la tâche suivante |
| `DONE_WITH_CONCERNS` | Terminé mais avec des doutes à examiner | Lire les concerns avant de continuer |
| `NEEDS_CONTEXT` | Contexte insuffisant fourni | Re-dispatcher avec le contexte manquant |
| `BLOCKED` | Bloqué, ne peut pas continuer | Changer d'approche ou escalader |

```markdown
## Rapport {NomAgent}

**Statut:** DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED

### Tâche
[Bref rappel de la tâche assignée]

### Résultat
- **Fichiers modifiés:** [liste avec chemins]
- **Tests:** [résultat build/vitest]
- **Commit:** [hash si applicable]

### Détails
[Corps du rapport]

### Concerns / Blocage (si applicable)
[Description du problème ou des doutes]
```

**Gestion des statuts non-DONE :**

- `DONE_WITH_CONCERNS` : lire les concerns, décider si action requise avant de continuer
- `NEEDS_CONTEXT` : identifier ce qui manquait, re-dispatcher avec un prompt enrichi
- `BLOCKED` : (1) fournir plus de contexte et re-dispatcher, (2) dispatcher un agent plus capable, (3) décomposer la tâche, ou (4) escalader à l'utilisateur

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

| Agent | Usage | Créé |
|-------|-------|------|
| `code-fixer` | Investigation + correction bugs | ✅ |
| `consolidation-worker` | Exécution consolidations CONS-X | ✅ |
| `doc-updater` | MAJ documentation | ✅ |
| `test-investigator` | Investigation tests échoués | ✅ |
| `issue-worker` | Exécuter issue GitHub complète | ✅ |
| `config-auditor` | Auditer configs MCP/modes | ✅ |
| `codebase-researcher` | Recherche SDDD multi-pass | ✅ |
| `script-runner` | Exécuter scripts avec rapport | ✅ |
| `pr-reviewer` | Review PR avec critique | ✅ |
| `issue-triager` | Classification issues | ✅ |
| `sync-checker` | Vérification git/MCP/schtasks | ✅ |

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

## État de la Roadmap #566

**Tous les agents ont été créés.** Voir le tableau des Workers ci-dessus.

**Dernière validation:** 2026-03-07 par myia-po-2023

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
- `docs/roosync/agents-architecture.md`: Architecture agents
- `~/.claude/agents/`: Agents globaux

---

**Dernière mise à jour:** 2026-03-06
