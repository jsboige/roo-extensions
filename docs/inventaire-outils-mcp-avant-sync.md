# Inventaire des Outils MCP roo-state-manager - AVANT SYNCHRONISATION

Date : 2025-10-16T00:22:30Z

## Récapitulatif par Catégorie

### 1. Storage (2 outils)
- ✅ `detectStorageTool`
- ✅ `getStorageStatsTool`

### 2. Conversation (4 outils)
- ✅ `listConversationsTool`
- ✅ `debugAnalyzeTool`
- ✅ `getRawConversationTool`
- ✅ `viewTaskDetailsTool`

### 3. Task (3 outils)
- ✅ `getTaskTreeTool`
- ✅ `debugTaskParsingTool`
- ✅ `exportTaskTreeMarkdownTool`

### 4. Search (2 outils)
- ✅ `searchTasksSemanticTool`
- ✅ `handleSearchTasksSemanticFallback`

### 5. Export (6 outils)
- ✅ `exportTasksXmlTool`
- ✅ `exportConversationXmlTool`
- ✅ `exportProjectXmlTool`
- ✅ `configureXmlExportTool`
- ✅ `exportConversationJsonTool`
- ✅ `exportConversationCsvTool`

### 6. Indexing (3 outils)
- ✅ `indexTaskSemanticTool`
- ✅ `handleDiagnoseSemanticIndex`
- ✅ `resetQdrantCollectionTool`

### 7. Summary (3 outils)
- ✅ `generateTraceSummaryTool`
- ✅ `generateClusterSummaryTool`
- ✅ `getConversationSynthesisTool`

### 8. RooSync (9 outils)
- ✅ `roosyncInit`
- ✅ `roosyncGetStatus`
- ✅ `roosyncCompareConfig`
- ✅ `roosyncListDiffs`
- ✅ `roosyncApproveDecision`
- ✅ `roosyncRejectDecision`
- ✅ `roosyncApplyDecision`
- ✅ `roosyncRollbackDecision`
- ✅ `roosyncGetDecisionDetails`

### 9. Cache (1 outil)
- ✅ `buildSkeletonCacheDefinition`

### 10. Repair (2 outils)
- ✅ `diagnoseConversationBomTool`
- ✅ `repairConversationBomTool`

### 11. Autres outils directs (6 outils)
- ✅ `readVscodeLogs` (read-vscode-logs.ts)
- ✅ `rebuildAndRestart` (rebuild-and-restart.ts)
- ✅ `getMcpBestPractices` (get_mcp_best_practices.js)
- ✅ `manageMcpSettings` (manage-mcp-settings.ts)
- ✅ `rebuildTaskIndexFixed` (manage-mcp-settings.ts)
- ✅ `viewConversationTree` (view-conversation-tree.js)

### 12. Outils DÉSACTIVÉS (commentés)
- ❌ `vscode-global-state` (problème runtime)
- ❌ `examineRooGlobalStateTool` (dépend de vscode-global-state)
- ❌ `repairTaskHistoryTool` (dépend de vscode-global-state)
- ❌ `normalize-workspace-paths` (dépend de vscode-global-state)

## 🎯 TOTAL ACTUEL CONFIRMÉ : 41 OUTILS

**Décompte complet :**
- Storage: 2
- Conversation: 4
- Task: 3
- Search: 2
- Export: 6
- Indexing: 3
- Summary: 3
- RooSync: 9
- Cache: 1
- Repair: 2
- Directs: 6
**TOTAL = 41 outils**

## ⚠️ ANALYSE DE LA DIFFÉRENCE

**CONSTAT IMPORTANT :**
Le code actuel contient **exactement 41 outils**, ce qui correspond à la machine de référence !

**Hypothèses sur le problème :**
1. ❓ Le MCP n'a pas été recompilé depuis les derniers commits
2. ❓ Le fichier `build/index.js` est obsolète
3. ❓ Les sous-modules ne sont pas à jour
4. ❓ La configuration VSCode n'a pas rechargé les MCPs

**Outils mentionnés comme manquants :**
- ❌ `minimal_test_tool` - NON trouvé dans le code source
- ❌ `touch_mcp_settings` - NON trouvé (mais `manageMcpSettings` existe)
- ✅ `rebuild_task_index` - TROUVÉ ! (exporté comme `rebuildTaskIndexFixed`)

## Prochaine Étape

Lire les fichiers individuels pour compter précisément tous les outils exportés.