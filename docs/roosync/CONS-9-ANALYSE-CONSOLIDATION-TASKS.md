# CONS-9 : Analyse Consolidation Outils Tasks (4→2)

**Issue GitHub :** #375
**Machine assignée :** myia-po-2024
**Date d'analyse :** 2026-02-01
**Auteur :** Claude Code (myia-po-2024)

---

## 1. État Actuel (4 outils)

### 1.1 Inventaire des outils

| Outil | Fichier | Lignes | Fonction |
|-------|---------|--------|----------|
| `get_task_tree` | get-tree.tool.ts | 512 | Arbre hiérarchique des tâches (4 formats) |
| `get_current_task` | get-current-task.tool.ts | 168 | Tâche la plus récente d'un workspace |
| `export_task_tree_markdown` | export-tree-md.tool.ts | 210 | Export arbre vers fichier markdown |
| `debug_task_parsing` | debug-parsing.tool.ts | 151 | Diagnostic parsing et balises task |

**Total actuel :** ~1041 lignes de code

### 1.2 Analyse des dépendances

```
get_task_tree ←─────────────── export_task_tree_markdown (wrapper)
     │
     └── Formats: json, markdown, ascii-tree, hierarchical

get_current_task ←─────────── Indépendant (scan disque + cache)

debug_task_parsing ←───────── Indépendant (analyse fichiers task)
```

**Observation clé :** `export_task_tree_markdown` est un simple wrapper de `get_task_tree` avec sauvegarde fichier.

### 1.3 Paramètres actuels

**get_task_tree :**
```typescript
interface GetTaskTreeArgs {
    conversation_id: string;      // Requis
    max_depth?: number;
    include_siblings?: boolean;
    output_format?: 'json' | 'markdown' | 'ascii-tree' | 'hierarchical';
    current_task_id?: string;
    truncate_instruction?: number;
    show_metadata?: boolean;
}
```

**get_current_task :**
```typescript
interface GetCurrentTaskArgs {
    workspace?: string;  // Optionnel (détection auto)
}
```

**export_task_tree_markdown :**
```typescript
interface ExportTaskTreeMarkdownArgs {
    conversation_id: string;      // Requis
    filePath?: string;            // Chemin fichier sortie
    max_depth?: number;
    include_siblings?: boolean;
    current_task_id?: string;
    output_format?: 'ascii-tree' | 'markdown' | 'hierarchical' | 'json';
    truncate_instruction?: number;
    show_metadata?: boolean;
}
```

**debug_task_parsing :**
```typescript
interface DebugTaskParsingArgs {
    task_id: string;  // Requis
}
```

---

## 2. Proposition de Consolidation

### 2.1 Option A : 2 outils (Recommandée)

Suivant le pattern CONS-5, consolider en 2 outils avec actions :

#### Outil 1 : `task_browse` (Navigation/Consultation)

**Remplace :** `get_task_tree` + `get_current_task`

```typescript
interface TaskBrowseArgs {
    action: 'tree' | 'current';

    // Pour action='tree'
    conversation_id?: string;     // Requis si action='tree'
    max_depth?: number;
    include_siblings?: boolean;
    output_format?: 'json' | 'markdown' | 'ascii-tree' | 'hierarchical';
    current_task_id?: string;
    truncate_instruction?: number;
    show_metadata?: boolean;

    // Pour action='current'
    workspace?: string;           // Optionnel (détection auto)
}
```

**Logique :**
- `action='tree'` → Appelle `handleGetTaskTree()` existant
- `action='current'` → Appelle `getCurrentTaskTool.handler()` existant

#### Outil 2 : `task_export` (Export/Debug)

**Remplace :** `export_task_tree_markdown` + `debug_task_parsing`

```typescript
interface TaskExportArgs {
    action: 'markdown' | 'debug';

    // Pour action='markdown'
    conversation_id?: string;     // Requis si action='markdown'
    filePath?: string;
    max_depth?: number;
    include_siblings?: boolean;
    current_task_id?: string;
    output_format?: 'ascii-tree' | 'markdown' | 'hierarchical' | 'json';
    truncate_instruction?: number;
    show_metadata?: boolean;

    // Pour action='debug'
    task_id?: string;             // Requis si action='debug'
}
```

**Logique :**
- `action='markdown'` → Appelle `handleExportTaskTreeMarkdown()` existant
- `action='debug'` → Appelle `handleDebugTaskParsing()` existant

### 2.2 Option B : 1 seul outil (Alternative)

Un seul outil `task` avec toutes les actions :

```typescript
interface TaskArgs {
    action: 'tree' | 'current' | 'export' | 'debug';
    // ... tous les paramètres combinés
}
```

**Inconvénient :** Trop de paramètres, moins clair pour l'utilisateur.

### 2.3 Recommandation

**Option A (2 outils)** car :
- Séparation claire : consultation vs export/debug
- Cohérent avec CONS-5 (pattern action)
- Maintient la lisibilité des paramètres
- Réutilise le code existant (handlers)

---

## 3. Plan d'Implémentation

### Phase 1 : Créer les squelettes

```
src/tools/task/
├── browse.ts              # NOUVEAU - task_browse
├── export.ts              # NOUVEAU - task_export
├── utils/
│   └── task-helpers.ts    # NOUVEAU - Fonctions partagées
├── get-tree.tool.ts       # EXISTANT - Sera appelé par browse
├── get-current-task.tool.ts  # EXISTANT - Sera appelé par browse
├── export-tree-md.tool.ts    # EXISTANT - Sera appelé par export
├── debug-parsing.tool.ts     # EXISTANT - Sera appelé par export
└── index.ts               # Mettre à jour exports
```

### Phase 2 : Implémenter les nouveaux outils

1. **browse.ts** (~150 lignes estimées)
   - Définition `taskBrowseTool`
   - Handler `handleTaskBrowse()` avec switch sur action
   - Validation Zod des arguments

2. **export.ts** (~120 lignes estimées)
   - Définition `taskExportTool`
   - Handler `handleTaskExport()` avec switch sur action
   - Validation Zod des arguments

3. **task-helpers.ts** (~50 lignes estimées)
   - Validation des arguments selon action
   - Formatage des erreurs

### Phase 3 : Tests unitaires

Créer `__tests__/task-browse.test.ts` et `__tests__/task-export.test.ts` :
- Tests des schémas Zod
- Tests des validations d'action
- Tests d'intégration avec handlers existants

### Phase 4 : Migration

1. Marquer les 4 anciens outils comme `@deprecated`
2. Mettre à jour `index.ts` avec nouveaux exports
3. Documenter la migration dans CHANGELOG

---

## 4. Métriques Attendues

| Métrique | Avant | Après | Réduction |
|----------|-------|-------|-----------|
| Nombre d'outils | 4 | 2 | -50% |
| Lignes de code (total) | ~1041 | ~600 | -42% |
| Points d'entrée API | 4 | 2 | -50% |

**Note :** La réduction de code est modérée car on réutilise les handlers existants (composition).

---

## 5. Risques et Mitigations

| Risque | Probabilité | Impact | Mitigation |
|--------|-------------|--------|------------|
| Régression fonctionnelle | Faible | Moyen | Tests E2E existants + nouveaux tests |
| Complexité accrue | Faible | Faible | Pattern action éprouvé (CONS-5) |
| Breaking change API | Moyen | Moyen | Période de dépréciation (2 versions) |

---

## 6. Validation Requise

**Avant implémentation :**
- [ ] Validation du coordinateur (myia-ai-01)
- [ ] Accord sur Option A vs Option B
- [ ] Confirmation machine assignée

**Après implémentation :**
- [ ] Build sans erreurs
- [ ] Tests passent (100%)
- [ ] Review coordinateur
- [ ] Commit et push

---

## 7. Annexes

### 7.1 Exemple d'utilisation (après consolidation)

```typescript
// Navigation dans l'arbre des tâches
await mcp.call('task_browse', {
    action: 'tree',
    conversation_id: '12345678',
    output_format: 'ascii-tree'
});

// Obtenir la tâche courante
await mcp.call('task_browse', {
    action: 'current',
    workspace: '/path/to/project'
});

// Export vers fichier
await mcp.call('task_export', {
    action: 'markdown',
    conversation_id: '12345678',
    filePath: './task-tree.md'
});

// Debug parsing
await mcp.call('task_export', {
    action: 'debug',
    task_id: '12345678'
});
```

### 7.2 Références

- Issue #375 : [CONS-9] Consolidation Tasks (4→2 outils)
- CONS-5 : Pattern de référence (decision.ts, decision-info.ts)
- Fichiers source : `mcps/internal/servers/roo-state-manager/src/tools/task/`

---

**Créé par :** Claude Code (myia-po-2024)
**Date :** 2026-02-01
**Status :** En attente validation coordinateur
