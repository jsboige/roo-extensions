# Bug #322 Post-Mortem : compare_config échoue

**Date résolution :** 2026-01-18
**Machines affectées :** Toutes (workflow E2E)
**Sévérité :** HIGH (bloquant workflow RooSync)
**Statut :** RÉSOLU

---

## Résumé Exécutif

Le tool `compare_config` échouait systématiquement avec l'erreur "Échec collecte inventaire pour {machineId}". La cause racine était une chaîne de dépendances incomplète entre `BaselineService`, `InventoryCollectorWrapper` et `InventoryCollector`, où le champ `paths` n'était pas préservé lors des conversions de format.

---

## Chronologie

| Date/Heure | Événement | Machine |
|------------|-----------|---------|
| 2026-01-16 | Bug signalé - compare_config KO | myia-po-2023 |
| 2026-01-18 14:00 | Investigation démarrée | myia-po-2024 |
| 2026-01-18 16:15 | Root cause identifiée | myia-po-2024 |
| 2026-01-18 16:41 | Premier fix (baseline.ts) | myia-po-2024 |
| 2026-01-18 20:17 | Fix complet (InventoryService fallback) | myia-po-2024 |
| 2026-01-18 20:38 | Validation E2E 4/4 PASS | myia-po-2024 |

---

## Analyse Root Cause

### Architecture Impliquée

```
compare_config (tool)
    └── BaselineService
        └── InventoryCollectorWrapper
            └── InventoryCollector (échec)
            └── loadFromSharedState() (échec)
            └── InventoryService (FIX - fallback ajouté)
```

### Problème Initial

1. **`InventoryCollector`** collecte l'inventaire local mais ne fonctionne pas toujours
2. **`loadFromSharedState()`** cherche dans le répertoire partagé mais le fichier n'existe pas toujours
3. **Pas de fallback** → Erreur si les deux méthodes échouent

### Problème Secondaire

Le champ `paths` (contenant `rooExtensions`, `mcpSettings`, etc.) était :
- Présent dans `InventoryService.getMachineInventory()`
- Absent dans `InventoryCollectorWrapper.convertToBaselineFormat()`

---

## Solution Appliquée

### Fix Principal : Fallback InventoryService

**Fichier :** `src/services/InventoryCollectorWrapper.ts` (lignes 72-115)

```typescript
// CORRECTION Bug #322 : Fallback vers InventoryService
logger.debug(`Tentative fallback via InventoryService pour ${machineId}`);
try {
  const inventoryService = InventoryService.getInstance();
  const serviceInventory = await inventoryService.getMachineInventory(machineId);
  if (serviceInventory) {
    logger.info(`✅ Inventaire obtenu via InventoryService pour ${machineId}`);
    return {
      machineId: serviceInventory.machineId,
      timestamp: serviceInventory.timestamp,
      // ... mapping complet incluant paths
      paths: serviceInventory.paths,  // ← Champ critique préservé
    };
  }
} catch (serviceError) {
  logger.error(`Erreur InventoryService pour ${machineId}`, serviceError);
}
```

### Commits

| Commit | Description | Fichier |
|--------|-------------|---------|
| `e85ef6c` | Ajout champ paths à MachineInventory | baseline.ts |
| `90ffb3b` | Fallback InventoryService | InventoryCollectorWrapper.ts |
| `9a8ebf9` | Update submodule | Parent repo |
| `db5bfb7` | Fix DiffDetector test | Submodule |

---

## Validation

### Test E2E (4/4 PASS)

| Outil | Avant Fix | Après Fix |
|-------|-----------|-----------|
| get_machine_inventory | ✅ | ✅ |
| collect_config | ❌ | ✅ |
| compare_config | ❌ | ✅ |
| get_status | ✅ | ✅ |

### Résultat compare_config

```json
{
  "source": "myia-po-2024",
  "target": "myia-ai-01",
  "summary": {
    "total": 33,
    "critical": 2,
    "important": 22,
    "warning": 2,
    "info": 7
  }
}
```

---

## Leçons Apprises

### Ce qui a bien fonctionné

1. **Diagnostic SDDD** - Triple grounding (sémantique + code + tests)
2. **Coordination multi-machine** - Rapports RooSync réguliers
3. **Tests E2E** - Validation complète avant de marquer Done

### Ce qui peut être amélioré

1. **Couverture de tests** - Ajouter tests pour les fallbacks
2. **Documentation des dépendances** - Clarifier la chaîne InventoryCollector → Wrapper → Service
3. **Monitoring** - Logger les chemins de fallback utilisés

### Actions Préventives

| Action | Responsable | Priorité |
|--------|-------------|----------|
| Ajouter tests fallback InventoryService | Roo | LOW |
| Documenter architecture inventaire | Claude | LOW |
| Revoir interfaces baseline | Équipe | MEDIUM |

---

## Références

- **Issue GitHub :** #322
- **Project :** #67 (RooSync Multi-Agent Tasks)
- **INTERCOM :** `.claude/local/INTERCOM-myia-po-2024.md`
- **Fichier source :** `src/services/InventoryCollectorWrapper.ts`

---

**Rédigé par :** Claude Code (myia-po-2024)
**Date :** 2026-01-18
