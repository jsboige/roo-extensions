# Bug #289 - Rapport de Correction BOM UTF-8

**Date:** 2026-01-13  
**Issue:** https://github.com/jsboige/roo-extensions/issues/289  
**Statut:** ✅ RÉSOLU

---

## Résumé

Les fichiers JSON avec BOM UTF-8 (Byte Order Mark) causaient des erreurs de parsing dans le MCP roo-state-manager. Ce bug affectait notamment `roosync_import_baseline` et potentiellement d'autres outils qui lisent des fichiers JSON.

## Problème

### Description

Le BOM UTF-8 est la séquence de bytes: `\uFEFF` (ou `0xEF 0xBB 0xBF` en bytes). Certains éditeurs de texte et outils Windows ajoutent automatiquement ce BOM au début des fichiers JSON, ce qui causait des erreurs de parsing:

```
SyntaxError: Unexpected token ﻿, "..." is not valid JSON
```

### Impact

Les services suivants étaient affectés:
- `BaselineLoader` - Chargement des fichiers de configuration baseline
- `NonNominativeBaselineService` - Gestion des baselines non-nominatives
- `roosync-parsers` - Parsing des fichiers JSON RooSync
- `ConfigService` - Chargement de la configuration
- `InventoryService` - Chargement des inventaires de machines

## Solution Implémentée

### 1. Création d'un Module Utilitaire Centralisé

**Fichier:** [`mcps/internal/servers/roo-state-manager/src/utils/encoding-helpers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/encoding-helpers.ts)

Fonctions créées:
- `stripBOM(content: string): string` - Supprime le BOM UTF-8 d'une chaîne
- `readFileWithoutBOM(filePath, encoding): Promise<string>` - Lit un fichier et supprime le BOM
- `readFileSyncWithoutBOM(filePath, encoding): string` - Version synchrone
- `parseJSONWithoutBOM<T>(content): T` - Parse JSON en supprimant le BOM
- `readJSONFileWithoutBOM<T>(filePath, encoding): Promise<T>` - Lit et parse JSON avec BOM
- `readJSONFileSyncWithoutBOM<T>(filePath, encoding): T` - Version synchrone

### 2. Correction des Fichiers Critiques

#### Fichiers Modifiés

1. **[`BaselineLoader.ts`](../../mcps/internal/servers/roo-state-manager/src/services/baseline/BaselineLoader.ts)**
   - Import de `readJSONFileWithoutBOM`
   - Remplacement de `fs.readFile` + `JSON.parse` par `readJSONFileWithoutBOM`
   - Méthodes affectées: `loadBaseline()`, `readBaselineFile()`

2. **[`NonNominativeBaselineService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/roosync/NonNominativeBaselineService.ts)**
   - Import de `readJSONFileWithoutBOM`
   - Remplacement des appels `fs.readFile` + `JSON.parse`
   - Méthodes affectées: `loadBaseline()`, `saveMachineMapping()`, `loadState()`

3. **[`roosync-parsers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/roosync-parsers.ts)**
   - Import de `readJSONFileSyncWithoutBOM` et `parseJSONWithoutBOM`
   - Remplacement des appels `readFileSync` + `JSON.parse`
   - Fonctions affectées: `parseDashboardJson()`, `parseConfigJson()`, `parseDashboardJsonContent()`, `parseConfigJsonContent()`

4. **[`ConfigService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/ConfigService.ts)**
   - Import de `readJSONFileWithoutBOM`
   - Remplacement dans `loadConfig()`

5. **[`InventoryService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/roosync/InventoryService.ts)**
   - Import de `readJSONFileWithoutBOM`
   - Remplacement dans `loadRemoteInventory()`, `collectMcpServers()`, `collectRooModes()`

## Tests et Validation

### Fichiers de Test Créés

1. **[`tests/data/test-bom-utf8.json`](../../tests/data/test-bom-utf8.json)**
   - Fichier JSON de test avec BOM UTF-8
   - Contient des données de test pour valider le parsing

2. **[`tests/test-bom-utf8.js`](../../tests/test-bom-utf8.js)**
   - Script de validation automatique
   - Teste les scénarios suivants:
     - ✅ Création de fichier avec BOM UTF-8
     - ✅ Échec attendu sans stripBOM
     - ✅ Succès avec stripBOM
     - ✅ Intégrité des données préservée
     - ✅ Compatibilité avec fichiers sans BOM

### Résultats des Tests

```
=== Test BOM UTF-8 - Bug #289 ===

Test 1: Création d'un fichier JSON avec BOM UTF-8...
✅ Fichier créé avec BOM UTF-8

Test 2: Lecture sans stripBOM (doit échouer)...
✅ Attendu: Parsing échoué avec le BOM présent
   Message d'erreur: Unexpected token ﻿, "﻿{
  "test"... is not valid JSON

Test 3: Lecture avec stripBOM (doit réussir)...
✅ Succès: Parsing réussi avec stripBOM
   Données parsées: {
  "test": "Fichier JSON avec BOM UTF-8",
  "description": "Ce fichier contient un BOM UTF-8 (0xEF 0xBB 0xBF) au début",
  "data": {
    "machineId": "test-machine",
    "timestamp": "2026-01-13T23:06:36.209Z",
    "config": {
      "test": true
    }
  }
}

Test 4: Vérification de l'intégrité des données...
✅ Données correctes après parsing avec stripBOM

Test 5: Vérification avec fichier sans BOM...
✅ Succès: Parsing réussi pour fichier sans BOM
   Données parsées: {
  "test": "Fichier JSON avec BOM UTF-8",
  "description": "Ce fichier contient un BOM UTF-8 (0xEF 0xBB 0xBF) au début",
  "data": {
    "machineId": "test-machine",
    "timestamp": "2026-01-13T23:06:36.209Z",
    "data": {
      "test": true
    }
  }
}

=== Tous les tests réussis! ===

Résumé:
✅ Création de fichier avec BOM UTF-8
✅ Échec attendu sans stripBOM
✅ Succès avec stripBOM
✅ Intégrité des données préservée
✅ Compatibilité avec fichiers sans BOM

La correction BOM UTF-8 fonctionne correctement!
```

## Avantages de la Solution

1. **Centralisation:** Un seul module utilitaire pour gérer tous les problèmes d'encodage
2. **Type Safety:** Support des types TypeScript génériques
3. **Flexibilité:** Fonctions async et sync disponibles
4. **Compatibilité:** Fonctionne avec et sans BOM UTF-8
5. **Maintenabilité:** Facile à étendre pour d'autres problèmes d'encodage

## Fichiers Modifiés

### Nouveaux Fichiers
- `mcps/internal/servers/roo-state-manager/src/utils/encoding-helpers.ts` (nouveau)
- `tests/data/test-bom-utf8.json` (nouveau)
- `tests/test-bom-utf8.js` (nouveau)

### Fichiers Modifiés
- `mcps/internal/servers/roo-state-manager/src/services/baseline/BaselineLoader.ts`
- `mcps/internal/servers/roo-state-manager/src/services/roosync/NonNominativeBaselineService.ts`
- `mcps/internal/servers/roo-state-manager/src/utils/roosync-parsers.ts`
- `mcps/internal/servers/roo-state-manager/src/services/ConfigService.ts`
- `mcps/internal/servers/roo-state-manager/src/services/roosync/InventoryService.ts`

## Recommandations

1. **Utiliser les fonctions utilitaires:** Pour tout nouveau code qui lit des fichiers JSON, utiliser les fonctions de `encoding-helpers.ts`
2. **Tests:** Ajouter des tests unitaires pour les fonctions d'encodage
3. **Documentation:** Mettre à jour la documentation des services affectés
4. **Migration:** Considérer l'application de cette correction aux autres services qui lisent des fichiers JSON

## Critères de Succès

- ✅ Identifier le code qui parse les JSON de baseline
- ✅ Ajouter strip BOM avant parsing JSON
- ✅ Tester avec un fichier JSON contenant BOM
- ✅ Documenter la correction

---

**Statut:** ✅ CORRECTION TERMINÉE ET VALIDÉE
