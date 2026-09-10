# conversation_browser — Guide Complet

> **Note relocalisation (2026-05-19)** : Ancien `.claude/rules/conversation-browser-guide.md` (version slim) merge dans ce document. Plus de rule auto-chargée séparée — tout est ici.

**Issue :** #1063, fix #881

---

## Point d'Entree OBLIGATOIRE

**TOUJOURS commencer par `list`** pour obtenir les IDs :

```
conversation_browser(action: "list", workspace: "C:/dev/roo-extensions", limit: 20)
```

Sans IDs, `view`/`tree`/`summarize` sont impossibles. `current` seul est insuffisant.

## Actions Principales

| Action | Usage | Parametres cles |
|--------|-------|-----------------|
| **`list`** | Lister taches recentes (OBLIGATOIRE en premier) | `limit`, `contentPattern` |
| `tree` | Arbre des taches | `conversation_id`, `output_format: "ascii-tree"` |
| `current` | Tache active | `workspace` |
| `view` | Squelette conversation | `task_id`, `detail_level: "summary"`, `smart_truncation: true` |
| `summarize` | Resume/stats | `summarize_type: "trace"`, `taskId`, `detailLevel: "Summary"` |

Les deux réglages de détail sont distincts et leurs vocabulaires ne se mélangent pas :

| Action | Paramètre | Valeurs |
|--------|-----------|---------|
| `view` | `detail_level` | `skeleton`, `summary`, `full` |
| `summarize` | `detailLevel` | `Summary`, `NoTools`, `Compact`, `NoResults`, `Messages`, `UserOnly`, `NoToolParams`, `Full` |

Pour `view`, utiliser `detail_level: "summary"`. Pour `summarize`, préférer
`detailLevel: "Summary"` ou `"NoTools"` et ne jamais demander `"Full"`.
Une valeur réelle du vocabulaire d'une autre action est rejetée explicitement plutôt qu'ignorée.
Les bindings qui imposent tous les champs du schéma plat peuvent utiliser `null` pour « non
applicable » ; cette sentinelle de transport n'est jamais une valeur métier.

---

## summarize.detailLevel — Reference Complete

**TOUJOURS activer `smart_truncation: true` sur `view`** pour conversations >10K chars.
**TOUJOURS definir `truncationChars`** quand `summarize_type != "trace"`.

| Niveau | Contenu | Recommandation |
|--------|---------|----------------|
| **`Summary`** | Vue condensee | Recommande |
| **`Compact`** | Messages + outils resumes (nom + statut) | Expose depuis #3196 (`NoTools` reste l'alias recommande) |
| **`NoTools`** | Alias vers `Compact` (fix #881) | Recommande pour ce niveau |
| **`NoResults`** | Messages + params sans resultats | Compact |
| **`Messages`** | Messages seulement | Tres compact |
| **`UserOnly`** | Messages utilisateur seulement | Plus compact |
| **`NoToolParams`** | Params masques, resultats complets | Expose depuis #3196 |
| **`Full`** | Tout inclus | JAMAIS (explosion contextuelle) |

## summarize_type

| Type | Usage | truncationChars |
|------|-------|-----------------|
| `trace` | Stats (messages par type, taille, breakdown) | Pas requis |
| `cluster` | Grappes parent-enfant | Recommande |
| `synthesis` | Désactivé (#788), absent du schéma servi | Non disponible |

Utiliser `trace` ou `cluster` ; `synthesis` est rejeté tant que le pipeline LLM n'est pas disponible.

## Anti-Patterns

- Deviner les IDs de taches
- Utiliser `current` comme seul point d'entree
- Aller a `view`/`tree` sans `list` prealable
- Passer `detailLevel` à `view` ou `detail_level` à `summarize`
- Utiliser `summarize.detailLevel: "Full"`
- Ignorer les metadonnees (timestamp, workspace, mode)

---

## Nouvelles fonctionnalites — #1752 (2026-05-21)

### Bug #1 — Support sessions Claude Code dans `view_task_details`

`view_task_details` charge maintenant les sessions Claude Code JSONL directement depuis
`~/.claude/projects/`. Les taches retournees par `list` avec un `taskId` prefixe `claude-`
sont viewables sans erreur.

```typescript
view_task_details(task_id: "claude-my-project/abc123...", max_output_length: 8000)
```

### Bug #2 — `max_output_length` desormais respecte

Le parametre `max_output_length` applique une troncature par hard cap (debut + fin preserved).
Valeur par defaut : 100 000 chars. Utiliser une valeur plus basse pour eviter les explosions contextuelles.

```typescript
view_task_details(task_id: "...", max_output_length: 8000)  // retourne ≤ 8 000 chars
```

### Bug #3 — Archives GDrive cross-machine via `includeArchives`

`conversation_browser(action: "list")` et `list_conversations` acceptent desormais
`includeArchives: true` pour charger les squelettes d'autres machines depuis
`SkeletonCacheService` (Tier 3 GDrive).

```typescript
conversation_browser(action: "list", includeArchives: true, machineId: "myia-po-2026")
```

| Parametre | Description |
| --- | --- |
| `includeArchives` | `true` = inclure les archives Tier 3 GDrive (defaut: `false`) |
| `machineId` | Filtrer par machine source (ex: `"myia-po-2026"`) |
| `source` | `"roo"`, `"claude"`, ou `"all"` |

Les archives deja presentes dans le cache local ne sont pas dupliquees.

---

**Reference complete :** `docs/harness/reference/sddd-conversational-grounding.md` (344 lignes)
