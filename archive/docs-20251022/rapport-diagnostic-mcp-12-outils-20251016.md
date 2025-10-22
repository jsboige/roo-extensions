# Rapport de Diagnostic : MCP roo-state-manager n'expose que 12 outils au lieu de 41

**Date** : 16 octobre 2025  
**Statut** : ✅ **CAUSE RACINE IDENTIFIÉE**  
**Sévérité** : 🔴 Critique (29 outils manquants sur 41)

---

## 🎯 Résumé Exécutif

Le serveur MCP `roo-state-manager` charge un **ancien fichier** `build/index.js` (21 septembre) qui contient 12 outils hardcodés, au lieu du **nouveau fichier** `build/src/index.js` (16 octobre) qui enregistre dynamiquement les 41 outils via le système de registry refactorisé.

---

## 📊 État des Lieux

### Outils Attendus
- **Source** : 41 outils définis dans [`src/tools/index.ts`](../mcps/internal/servers/roo-state-manager/src/tools/index.ts)
- **Build** : Tous les 41 outils sont correctement compilés dans `build/src/tools/`
- **Exposés** : ❌ **Seulement 12 outils** visibles dans Roo

### Outils Actuellement Exposés (12)
1. `minimal_test_tool`
2. `detect_roo_storage`
3. `get_storage_stats`
4. `list_conversations`
5. `touch_mcp_settings`
6. `build_skeleton_cache`
7. `get_task_tree`
8. `search_tasks_semantic`
9. `debug_analyze_conversation`
10. `view_conversation_tree`
11. `diagnose_roo_state`
12. `repair_workspace_paths`

### Outils Manquants (29)
- **Storage** : *(déjà inclus)*
- **Conversation** : `view_task_details`, `get_raw_conversation`
- **Task** : `debug_task_parsing`, `export_task_tree_markdown`
- **Search** : `handle_search_fallback`, `diagnose_semantic_index`
- **Export XML** : `export_tasks_xml`, `export_conversation_xml`, `export_project_xml`, `configure_xml_export`
- **Export JSON/CSV** : `export_conversation_json`, `export_conversation_csv`
- **Summary** : `generate_trace_summary`, `generate_cluster_summary`, `get_conversation_synthesis`
- **Indexing** : `index_task_semantic`, `reset_qdrant_collection`
- **RooSync** (9 outils) : `roosync_init`, `roosync_get_status`, `roosync_compare_config`, `roosync_list_diffs`, `roosync_get_decision_details`, `roosync_approve_decision`, `roosync_reject_decision`, `roosync_apply_decision`, `roosync_rollback_decision`
- **Cache & Repair** : `diagnose_conversation_bom`, `repair_conversation_bom`
- **Management** : `read_vscode_logs`, `manage_mcp_settings`, `rebuild_and_restart`, `get_mcp_best_practices`, `rebuild_task_index_fixed`

---

## 🔍 Diagnostic Détaillé

### 1. Vérification du Build ✅

**Résultat** : Le build est **COMPLET** et contient tous les 41 outils.

```powershell
# Structure du build
build/
  ├── index.js              ❌ ANCIEN (21 septembre) - 12 outils hardcodés
  ├── src/
  │   ├── index.js          ✅ NOUVEAU (16 octobre) - 41 outils via registry
  │   └── tools/
  │       ├── index.js      ✅ Exporte tous les modules
  │       ├── storage/      ✅ 2 outils
  │       ├── conversation/ ✅ 4 outils
  │       ├── task/         ✅ 3 outils + handlers
  │       ├── search/       ✅ 2 outils
  │       ├── export/       ✅ 6 outils + handlers
  │       ├── summary/      ✅ 3 outils + handlers
  │       ├── indexing/     ✅ 3 outils
  │       ├── roosync/      ✅ 9 outils
  │       ├── cache/        ✅ 1 outil
  │       └── repair/       ✅ 2 outils
```

### 2. Configuration MCP ⚠️

**Fichier** : `C:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`

```json
{
  "roo-state-manager": {
    "command": "node",
    "args": [
      "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"
      // ❌ Pointe vers l'ANCIEN fichier !
    ]
  }
}
```

**Problème** : La configuration pointe vers `build/index.js` au lieu de `build/src/index.js`

### 3. Analyse des Fichiers Index

#### `build/index.js` (ANCIEN - 21 sept 2025)
- **Taille** : 29.61 KB
- **Architecture** : Ancienne (monolithique)
- **Outils** : 12 outils hardcodés directement dans le fichier
- **Registry** : ❌ Pas de système de registry

```javascript
// Extrait de build/index.js (ANCIEN)
this.server.setRequestHandler(ListToolsRequestSchema, async () => {
    return {
        tools: [
            { name: 'minimal_test_tool', ... },
            { name: 'detect_roo_storage', ... },
            // ... seulement 12 outils hardcodés
        ]
    };
});
```

#### `build/src/index.js` (NOUVEAU - 16 oct 2025)
- **Taille** : 8.79 KB
- **Architecture** : Modulaire avec registry
- **Outils** : 41 outils chargés dynamiquement
- **Registry** : ✅ Système complet dans `build/src/tools/registry.js`

```javascript
// Extrait de build/src/index.js (NOUVEAU)
import { registerListToolsHandler, registerCallToolHandler } from './tools/registry.js';

// Enregistrement dynamique via le registry
registerListToolsHandler(this.server);
registerCallToolHandler(this.server, state, ...);
```

### 4. TypeScript Configuration ✅

**Fichier** : `tsconfig.json`

```json
{
  "compilerOptions": {
    "rootDir": ".",
    "outDir": "./build"
  },
  "include": ["src/**/*.ts"]
}
```

**Comportement** :
- Compile `src/**/*.ts` → `build/src/**/*.js` ✅
- Le fichier source `src/index.ts` → `build/src/index.js` ✅
- L'ancien `build/index.js` n'est **jamais supprimé** ❌

---

## 🎯 Cause Racine

**CONFLIT DE FICHIERS** : Deux fichiers `index.js` coexistent dans le répertoire `build/` :

1. **`build/index.js`** (ANCIEN)
   - Date : 21 septembre 2025
   - Origine : Ancienne architecture avant refactoring
   - Contenu : 12 outils hardcodés
   - État : ❌ Obsolète mais chargé par le MCP

2. **`build/src/index.js`** (NOUVEAU)
   - Date : 16 octobre 2025
   - Origine : Nouvelle architecture avec registry
   - Contenu : 41 outils via système modulaire
   - État : ✅ Correct mais non chargé

**Séquence des Événements** :

```
1. [Ancien] Architecture monolithique → build/index.js (12 outils)
2. [Refactoring] Migration vers src/ avec registry
3. [Compilation] TypeScript compile src/ → build/src/ (41 outils)
4. [Problème] build/index.js n'est jamais supprimé
5. [MCP Config] Pointe toujours vers build/index.js (ancien)
6. [Résultat] MCP charge l'ancien fichier → 12 outils seulement
```

---

## ✅ Solutions Proposées

### Solution A : Supprimer l'Ancien Fichier (RECOMMANDÉ)

**Avantage** : Nettoie le build et évite toute confusion future

```powershell
# Supprimer l'ancien fichier
Remove-Item "mcps/internal/servers/roo-state-manager/build/index.js" -Force
Remove-Item "mcps/internal/servers/roo-state-manager/build/index.d.ts" -Force
Remove-Item "mcps/internal/servers/roo-state-manager/build/index.js.map" -Force
Remove-Item "mcps/internal/servers/roo-state-manager/build/index.d.ts.map" -Force

# Mettre à jour la configuration MCP
# Fichier: C:/Users/jsboi/AppData/Roaming/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json
# Remplacer:
"args": ["D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js"]
# Par:
"args": ["D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/src/index.js"]
```

### Solution B : Mettre à Jour Uniquement la Configuration

**Avantage** : Modification minimale

```json
{
  "roo-state-manager": {
    "args": [
      "D:/Dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/src/index.js"
    ]
  }
}
```

### Solution C : Créer un Pont (Wrapper)

**Avantage** : Rétrocompatibilité

```javascript
// build/index.js (nouveau contenu)
export * from './src/index.js';
```

---

## 🚀 Plan d'Action Recommandé

### Étape 1 : Sauvegarder l'Ancien Fichier (Précaution)
```powershell
Copy-Item "mcps/internal/servers/roo-state-manager/build/index.js" `
          "mcps/internal/servers/roo-state-manager/build/index.js.backup"
```

### Étape 2 : Appliquer la Solution A
```powershell
# 1. Supprimer les anciens fichiers
Remove-Item "mcps/internal/servers/roo-state-manager/build/index.*" -Force

# 2. Mettre à jour mcp_settings.json (manuel ou via outil)
# Remplacer "build/index.js" par "build/src/index.js"
```

### Étape 3 : Redémarrer le MCP
```powershell
# Via l'outil touch_mcp_settings ou redémarrage VSCode
```

### Étape 4 : Vérifier le Nombre d'Outils
```
Ouvrir Roo → Vérifier la liste des outils roo-state-manager
Attendu: 41 outils ✅
```

### Étape 5 : Prévenir les Récidives

**Ajouter un script de nettoyage post-build** :

```json
// package.json
{
  "scripts": {
    "build": "tsc && npm run clean-old-build",
    "clean-old-build": "node scripts/clean-old-build.js"
  }
}
```

```javascript
// scripts/clean-old-build.js
import fs from 'fs/promises';
import path from 'path';

const buildDir = './build';
const filesToRemove = ['index.js', 'index.d.ts', 'index.js.map', 'index.d.ts.map'];

for (const file of filesToRemove) {
    const filePath = path.join(buildDir, file);
    try {
        await fs.unlink(filePath);
        console.log(`✅ Supprimé: ${file}`);
    } catch (error) {
        if (error.code !== 'ENOENT') throw error;
    }
}
```

---

## 📝 Validation de la Solution

### Tests à Effectuer

1. **Vérification du Nombre d'Outils**
   ```
   Attendu: 41 outils disponibles
   ```

2. **Test des Outils RooSync**
   ```
   roosync_init ✅
   roosync_get_status ✅
   ... (9 outils RooSync)
   ```

3. **Test des Outils d'Export**
   ```
   export_tasks_xml ✅
   export_conversation_json ✅
   ... (8 outils export)
   ```

4. **Test des Outils de Synthèse**
   ```
   generate_trace_summary ✅
   get_conversation_synthesis ✅
   ... (3 outils summary)
   ```

---

## 📚 Documentation Associée

- [`inventaire-outils-mcp-avant-sync.md`](inventaire-outils-mcp-avant-sync.md) - Liste complète des 41 outils
- [`rapport-diagnostic-outils-mcp.md`](rapport-diagnostic-outils-mcp.md) - Diagnostic précédent
- [Script de diagnostic](../scripts/diagnostic/debug-mcp-exports-20251016-v2.ps1)

---

## 🔄 Historique des Investigations

| Date | Action | Résultat |
|------|--------|----------|
| 16 oct 2025 | Vérification build | ✅ 41 exports présents |
| 16 oct 2025 | Analyse configuration | ⚠️ Pointe vers ancien fichier |
| 16 oct 2025 | Comparaison fichiers | 🎯 Cause racine identifiée |
| 16 oct 2025 | Script diagnostic | ✅ Outil créé |

---

## 🎓 Leçons Apprises

1. **Nettoyage du Build** : Toujours nettoyer le répertoire `build/` avant recompilation
2. **Tests Post-Build** : Vérifier que seuls les fichiers attendus existent
3. **Configuration MCP** : Valider que la configuration pointe vers les bons fichiers
4. **Versioning** : Documenter les changements d'architecture
5. **Scripts de Maintenance** : Automatiser le nettoyage des anciens fichiers

---

**Rapport rédigé par** : Roo Debug  
**Mode** : 🪲 Debug Complex  
**Coût d'investigation** : $1.63