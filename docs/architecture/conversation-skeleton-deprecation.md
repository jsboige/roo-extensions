# Dépréciation de `ConversationSkeleton` — Guide de Migration

**Version :** 1.0.0
**Date :** 2026-09-23
**Issue :** #1395 (Phase 5 de l'Epic #1360)
**Issue parente :** #1360 — Unifier systèmes d'extraction de tâches Roo + Claude
**Statut :** Plan documenté — exécution conditionnée à #1394 (migration downstream)

---

## 1. Contexte

L'Epic #1360 a posé les fondations d'un système unifié d'extraction de tâches
(`UnifiedTask`) qui se substitue progressivement au format `ConversationSkeleton`
utilisé par `mcps/internal/servers/roo-state-manager`. Les phases 1 à 3 sont
aujourd'hui livrées (schéma unifié, extracteur cross-format, stockage GDrive) ;
la phase 4 (#1394 — migration des outils downstream) reste **OPEN** et constitue
le verrou structurel pour la dépréciation effective.

## 2. Pourquoi ce plan est documenté et non exécuté à J+0

La timeline initiale (J+0 marquage `@deprecated`, J+30 suppression du code mort,
J+45 documentation finale) suppose que la phase 4 a précédé la phase 5. La réalité
courante est inverse : la phase 5 a été ouverte avant la phase 4, et la phase 5A
(ajout de l'annotation `@deprecated` sur `ConversationSkeleton`) déclenche des
avertissements sur l'ensemble du codebase **sans chemin de migration disponible**.

Mesures de première main au 2026-09-23 (`submodule mcps/internal` à `2f141828`,
issu de `jsboige/jsboige-mcp-servers`) :

| Métrique | Valeur | Source vérifiée |
|----------|--------|-----------------|
| Fichiers référençant `ConversationSkeleton` (src/) | **162** | `grep -rl` |
| Fichiers référençant `ConversationSkeleton` (src/tools/) | **86** | `grep -rl` |
| Fichiers important `UnifiedTask` (src/tools/) | **0** | `grep -rl` |
| Fichiers référençant `UnifiedTask` (src/) | **20** | `grep -rl` |
| Imports internes de `ConversationSkeleton` dans `unified-store/` | **1** | `services/unified-store/dual-write.ts:27` |
| Annotation `@deprecated` sur `ConversationSummary` | Présente | `types/conversation.ts:97` |
| Annotation `@deprecated` sur `ConversationSkeleton` | **Absente** | `types/conversation.ts:76` |
| Fichier fantôme `src/services/skeletons/ConversationSkeletonService.ts` | **N'existe pas** | `docs/architecture/unified-task-extraction-architecture.md:74,486` |

**Conséquence** : marquer `ConversationSkeleton` comme `@deprecated` aujourd'hui
produit ~162 occurrences d'avertissement IDE/TS pour des sites appelants qui n'ont
pas de chemin de remplacement (`UnifiedTask` n'est pas encore consommé par les
outils). C'est l'erreur classique pendule documentée dans
`~/.claude/CLAUDE.md` : remplacer un signal utile par son opposé n'est pas un
équilibre.

## 3. Phase 5A — Marquage `@deprecated` (PR submodule, repo jsboige-mcp-servers)

### 3.1 Préconditions

- [ ] **#1394 livré** — les outils downstream consomment `UnifiedTask`
- [ ] **Aucun site appelant direct** de `ConversationSkeleton` ne reste dans
      `src/tools/`
- [ ] **Documentation dual-write** à jour — `services/unified-store/dual-write.ts:2`
      explique que la dual-write attend un `ConversationSkeleton` complet (avec
      `sequence` non vide)

### 3.2 Modifications minimales

Fichier : `mcps/internal/servers/roo-state-manager/src/types/conversation.ts:76`

```typescript
/**
 * Full skeleton with conversation sequence. Loaded on-demand from disk.
 * Never stored in the cache — only used transiently by view/summarize/export.
 *
 * @deprecated Use `UnifiedTask` from `./unified-task.ts` instead.
 *   Part of the unified extraction pipeline (Epic #1360).
 *   Migration target: complete Phase 4 (#1394) before any removal.
 *   Removal target: J+30 after Phase 4 MERGED.
 */
export interface ConversationSkeleton extends SkeletonHeader {
   sequence: (MessageSkeleton | ActionMetadata)[];
}
```

### 3.3 Sites de référence

| Fichier | Ligne (approximative) | Nature de l'usage |
|---------|----------------------|-------------------|
| `types/conversation.ts` | 76 | Définition |
| `types/enhanced-hierarchy.ts` | 64 | Extension `EnhancedConversationSkeleton` |
| `types/trace-summary.ts` | 99 | Variante JSON-sérialisable |
| `services/skeleton-cache.service.ts` | 20 | `Map<string, ConversationSkeleton>` (cache central) |
| `services/background-services.ts` | 11 | Constructeur `buildSkeleton()` + `toHeader()` |
| `services/archive-skeleton-builder.ts` | 29 | Convertisseur `archiveToSkeleton()` |
| `services/task-navigator.ts` | 2 | Extension `TreeNode` |
| `services/extraction/roo-task-extractor.ts` | 7 | `ConversationSkeleton → UnifiedTask` |
| `services/extraction/claude-task-extractor.ts` | 7 | `ConversationSkeleton → UnifiedTask` |
| `services/synthesis/NarrativeContextBuilderService.ts` | — | Construction de contexte narratif |
| `services/unified-store/dual-write.ts` | 27 | Dual-write Postgres (consomme la valeur) |
| `tools/conversation/conversation-browser.ts` | 18 | Outil consolidé |
| `tools/conversation/list-conversations.tool.ts` | — | List/filter |
| `tools/search/search-semantic.tool.ts` | — | Recherche sémantique |
| `tools/search/search-fallback.tool.ts` | — | Recherche fallback |
| `tools/search/roosync-search.tool.ts` | — | Recherche RooSync |
| `tools/export/export-data.ts` | — | Export conversations |
| `tools/indexing/reset-collection.tool.ts` | — | Reset collection |
| `tools/summary/generate-cluster-summary.tool.ts` | 285 | Type `FindChildTasksFunction` |
| `interfaces/UnifiedToolInterface.ts` | 236 | Méthode `getConversationSkeleton()` |
| `utils/claude-storage-detector.ts` | — | Détection stockage Claude Code |
| `validate-architecture.ts` | 12 | Validation d'architecture |

Liste exhaustive non contractuelle — la commande
`grep -rl "ConversationSkeleton" mcps/internal/servers/roo-state-manager/src/`
rend **162 fichiers** au moment de la rédaction.

### 3.4 Hors-scope explicite

- **Ne PAS ajouter d'avertissements `console.warn` runtime** tant que la phase 4
  n'est pas livrée — la dual-write Postgres consomme la valeur, et un warning à
  chaque écriture cache-row saturerait les logs et masquerait de vrais problèmes.
- **Ne PAS supprimer `ConversationSkeleton`** — sa présence est nécessaire à
  l'exécution tant que les 86 fichiers de `src/tools/` ne sont pas migrés.
- **Ne PAS modifier le fichier fantôme référencé dans la doc d'architecture**
  (`src/services/skeletons/ConversationSkeletonService.ts`) — il n'existe pas
  dans le dépôt, c'est la doc qui est incorrecte (cf. §6).

## 4. Phase 5B — Avertissements runtime (post-Phase 4)

Une fois la phase 4 livrée et qu'aucun appelant direct de `ConversationSkeleton`
ne subsiste dans `src/tools/`, ajouter un avertissement console au point
d'entrée de la dual-write :

```typescript
// services/unified-store/dual-write.ts (top of file)
if (process.env.NODE_ENV !== 'production') {
   console.warn(
      '[DEPRECATION] ConversationSkeleton dual-write is deprecated. ' +
      'Use UnifiedTask via the unified store. Removal: see #1395.'
   );
}
```

Critères d'acceptation :

- L'avertissement apparaît **une fois** par session (pas à chaque appel)
- Il est supprimé en production (`NODE_ENV === 'production'`)
- Il pointe vers la documentation de migration (ce fichier)

## 5. Phase 5C — Suppression du code mort (J+30 après Phase 4 MERGED)

Une fois la phase 5B déployée depuis ≥ 30 jours sans régression :

- Supprimer `interface ConversationSkeleton` et toutes ses extensions
- Supprimer `services/skeleton-cache.service.ts` (remplacé par le reader factory)
- Supprimer `services/archive-skeleton-builder.ts` (remplacé par les extracteurs unifiés)
- Mettre à jour les imports dans les 162 fichiers impactés
- Vérifier que la build et les tests passent : `npm run test:mcp`

**Avant toute suppression**, suivre la procédure de
`.claude/rules/no-deletion-without-proof.md` : preuve de préservation pour
chaque fonction exportée, vérification des importateurs, tests préservés.

## 6. Correction documentaire — fichier fantôme

L'architecture unifiée référence un fichier qui n'existe pas :

```
src/services/skeletons/ConversationSkeletonService.ts
```

Vérifié absent au 2026-09-23 :
`Glob('**/ConversationSkeletonService.ts')` → 0 résultats.

**Action** : ouvrir un PR de documentation (parent) qui retire la référence à
ce fichier dans `docs/architecture/unified-task-extraction-architecture.md:74,486`.
Ne pas inventer de fichier qui n'existe pas — la consolidation
`ConversationSkeleton`→`UnifiedTask` se fait via le cache (`skeleton-cache.service.ts`)
et les extracteurs, pas via un service dédié.

## 7. Critères globaux d'acceptation (rappel issue #1395)

- [ ] Avertissements clairs pour utilisateurs de l'ancien système
- [ ] Code mort supprimé **sans régression** (gate build + tests)
- [ ] Documentation complète et à jour (ce fichier + correction fichier fantôme)
- [ ] Code review approuvé (≥ 1 reviewer qualifiant)
- [ ] Release notes publiées (PR title suit Conventional Commits)

## 8. Calendrier révisé (proposition)

| Jalon | Date cible | Précondition |
|-------|-----------|--------------|
| Phase 5A (`@deprecated` JSDoc) | **À planifier après MERGE #1394** | Phase 4 livrée, 0 imports directs dans `src/tools/` |
| Phase 5B (console.warn runtime) | +30 jours après 5A | 5A mergée, mesure de la portée des warnings |
| Phase 5C (suppression code mort) | +30 jours après 5B | Aucun appelant résiduel, tests passent |
| Documentation finale | +45 jours après 5A | 5B et 5C terminées, release notes publiées |

## 9. Références

- Issue #1360 — Epic parent
- Issue #1391 — Design du schéma unifié (CLOSED)
- Issue #1392 — Extracteur cross-format (CLOSED)
- Issue #1393 — Stockage partagé GDrive (CLOSED)
- Issue #1394 — Migration outils downstream (OPEN)
- `docs/architecture/unified-task-extraction-architecture.md` — Doc d'architecture
- `mcps/internal/servers/roo-state-manager/src/types/conversation.ts:76` —
  Définition actuelle de `ConversationSkeleton`
- `mcps/internal/servers/roo-state-manager/src/types/unified-task.ts:74` —
  Type de remplacement `UnifiedTask`

---

**Co-Authored-By:** Claude <noreply@anthropic.com>
**Source :** Issue #1395 (Phase 5 de l'Epic #1360)
**Submodule vérifié :** `mcps/internal` à `2f141828` (pointeur parent, `git submodule status`)
