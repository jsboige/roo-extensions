# Outils MCP Essentiels RooSync

**Date :** 2025-10-07  
**Mission :** Phase 8 Tâche 36 - Implémentation couche Presentation (3/5)  
**Objectif :** Implémenter 3 outils MCP qui exposent les services RooSync

---

## Contexte

**Tâche :** Phase 8 Tâche 36  
**Phase :** 8 - Intégration MCP roo-state-manager  
**Couche :** 3 - Presentation (Outils MCP)  
**Estimation :** 3-4 heures

**Pré-requis complétés :**
- ✅ Tâches 30-35 : Configuration, Services, Parsers
- ✅ RooSyncService opérationnel (v2.0.0)
- ✅ Parsers disponibles (parseDashboardJson, parseRoadmapMarkdown, etc.)
- ✅ Architecture 5 couches documentée

**Principe Directeur :**
"Single Entry Point, Multiple Domains" - Les outils MCP exposent les services RooSync via une API unifiée

---

## Spécifications Extraites

### Outil 1 : roosync_get_status

**Source :** [`02-points-integration-roosync.md`](02-points-integration-roosync.md:141-176)

**Description :** Obtenir l'état de synchronisation actuel

**Paramètres :**
```typescript
{
  machineFilter?: string;  // Filtrer par ID machine spécifique (optionnel)
}
```

**Retour :**
```typescript
{
  status: 'synced' | 'diverged' | 'conflict' | 'unknown',
  lastSync: string,  // ISO 8601 timestamp
  machines: [
    {
      id: string,
      status: 'online' | 'offline' | 'unknown',
      lastSync: string,
      pendingDecisions: number,
      diffsCount: number
    }
  ],
  summary: {
    totalMachines: number,
    onlineMachines: number,
    totalDiffs: number,
    totalPendingDecisions: number
  }
}
```

**API RooSyncService utilisée :**
- `loadDashboard()` : Charge sync-dashboard.json avec cache

**Codes d'erreur :**
- `ROOSYNC_CONFIG_ERROR` : Configuration invalide
- `FILE_NOT_FOUND` : Fichier dashboard introuvable
- `MACHINE_NOT_FOUND` : Machine filtrée non trouvée

---

### Outil 2 : roosync_compare_config

**Source :** [`02-points-integration-roosync.md`](02-points-integration-roosync.md:492-552)

**Description :** Compare la configuration locale avec une autre machine

**Paramètres :**
```typescript
{
  targetMachine?: string;  // ID machine cible (auto si non spécifié)
}
```

**Retour :**
```typescript
{
  localMachine: string,
  targetMachine: string,
  differences: [
    {
      field: string,
      localValue: any,
      targetValue: any,
      type: 'added' | 'removed' | 'modified'
    }
  ],
  identical: boolean  // Configurations identiques ?
}
```

**API RooSyncService utilisée :**
- `compareConfig(targetMachineId?)` : Retourne différences structurées

**Codes d'erreur :**
- `NO_TARGET_MACHINE` : Aucune machine disponible pour comparaison
- `FILE_NOT_FOUND` : Fichier sync-config.json introuvable

---

### Outil 3 : roosync_list_diffs

**Source :** [`02-points-integration-roosync.md`](02-points-integration-roosync.md:216-291)

**Description :** Liste les différences détectées entre machines

**Paramètres :**
```typescript
{
  filterType?: 'all' | 'config' | 'files' | 'settings';  // Filtre par type (défaut: all)
}
```

**Retour :**
```typescript
{
  totalDiffs: number,
  diffs: [
    {
      type: string,
      path: string,
      description: string,
      machines: string[],
      severity?: 'low' | 'medium' | 'high'
    }
  ],
  filterApplied: string
}
```

**API RooSyncService utilisée :**
- `listDiffs(filterByType?)` : Retourne différences avec filtrage

**Attribution de sévérité :**
- `config` → `high`
- `file` → `medium`
- `setting` → `low`

**Codes d'erreur :**
- `FILE_NOT_FOUND` : Fichier roadmap introuvable

---

## Architecture

**Répertoire :** `mcps/internal/servers/roo-state-manager/src/tools/roosync/`

**Structure :**
```
src/tools/roosync/
├── get-status.ts           (≈150 lignes)
├── compare-config.ts       (≈130 lignes)
├── list-diffs.ts           (≈140 lignes)
└── index.ts                (≈30 lignes, export centralisé)
```

**Tests :**
```
tests/unit/tools/roosync/
├── get-status.test.ts      (≈200 lignes, 5 tests)
├── compare-config.test.ts  (≈200 lignes, 5 tests)
└── list-diffs.test.ts      (≈200 lignes, 6 tests)
```

---

## Principes d'Implémentation

### 1. Schemas Zod

Chaque outil utilise Zod pour :
- Validation des entrées (`ArgsSchema`)
- Validation des sorties (`ResultSchema`)
- Documentation des paramètres (`.describe()`)

### 2. Gestion d'Erreurs

Pattern standard :
```typescript
try {
  const service = getRooSyncService();
  const result = await service.method();
  return result;
} catch (error) {
  if (error instanceof RooSyncServiceError) {
    throw error;  // Propagation erreur typée
  }
  throw new RooSyncServiceError(
    `Erreur lors de l'opération: ${(error as Error).message}`,
    'ROOSYNC_UNKNOWN_ERROR'
  );
}
```

### 3. Métadonnées d'Outil

Chaque outil exporte :
```typescript
export const toolMetadata = {
  name: 'roosync_xxx',
  description: 'Description courte',
  inputSchema: ArgsSchema,
  outputSchema: ResultSchema
};
```

---

## Implémentation Réalisée

### Fichiers Créés

**Code Source (421 lignes) :**
1. ✅ `src/tools/roosync/get-status.ts` (117 lignes)
2. ✅ `src/tools/roosync/compare-config.ts` (102 lignes)
3. ✅ `src/tools/roosync/list-diffs.ts` (102 lignes)
4. ✅ `src/tools/roosync/index.ts` (60 lignes)

**Tests (529 lignes) :**
1. ✅ `tests/unit/tools/roosync/get-status.test.ts` (156 lignes, 5 tests)
2. ✅ `tests/unit/tools/roosync/compare-config.test.ts` (170 lignes, 5 tests)
3. ✅ `tests/unit/tools/roosync/list-diffs.test.ts` (195 lignes, 6 tests)

**Total :** 950 lignes de code et tests

---

## Validation

- ✅ **16/16 tests unitaires passent** (3 suites de tests complètes)
- ✅ Schemas Zod valident correctement les entrées/sorties
- ✅ Intégration avec RooSyncService fonctionnelle
- ✅ Gestion d'erreurs robuste (codes standardisés RooSyncServiceError)
- ✅ Filtrage machine/type opérationnel
- ✅ Compilation TypeScript sans erreurs
- ✅ Tests ESM compatibles (import.meta.url)

---

## Intégration dans index.ts

Les outils seront enregistrés dans le serveur MCP via :

1. **Liste des outils** (ListToolsRequestSchema)
2. **Handlers** (CallToolRequestSchema)

Le routage se fera via le switch case existant dans `src/index.ts`.

---

## Prochaines Étapes

**Phase 4 - Outils MCP Décision (Tâche 37) :**
- `roosync_get_pending_decisions` : Liste décisions pendantes
- `roosync_submit_decision` : Soumet une décision (approve/reject/defer)

**Phase 5 - Outils MCP Exécution (Tâche 38) :**
- `roosync_apply_decisions` : Applique décisions approuvées
- `roosync_read_report` : Lit rapport de synchronisation

---

## Références

**Documents :**
- [02-points-integration-roosync.md](02-points-integration-roosync.md) : Spécifications complètes
- [03-architecture-integration-roosync.md](03-architecture-integration-roosync.md) : Architecture 5 couches
- [07-checkpoint-phase2-services.md](07-checkpoint-phase2-services.md) : Validation services

**Code :**
- [`RooSyncService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts) : Service principal
- [`roosync-parsers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/roosync-parsers.ts) : Utilitaires parsing

---

**✅ Statut :** Document de travail créé - Prêt pour implémentation