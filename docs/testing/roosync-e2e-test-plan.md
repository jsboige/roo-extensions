# Plan de Tests E2E RooSync - Validation Connexions Réelles

**Version** : 2.0.0  
**Date** : 2025-10-15  
**Objectif** : Valider les connexions TypeScript → PowerShell et robustesse du système  
**Statut** : ✅ Base implémentée, extensions recommandées

---

## 📋 Vue d'Ensemble

### Tests Existants (✅ Implémentés)

**Fichier** : `tests/e2e/roosync-workflow.test.ts` (1182 lignes)

| Test | Statut | Couverture |
|------|--------|-----------|
| Workflow complet detect → approve → apply | ✅ | 100% |
| Création rollback point | ✅ | 100% |
| Application dryRun | ✅ | 100% |
| Gestion erreurs PowerShell | ✅ | 90% |
| Invalidation cache | ✅ | 100% |

### Tests Recommandés (⚠️ À Implémenter)

| Catégorie | Tests | Priorité |
|-----------|-------|----------|
| **Validation Post-Application** | 3 tests | 🔴 P1 |
| **Robustesse Rollback** | 4 tests | 🔴 P1 |
| **Edge Cases PowerShell** | 5 tests | 🟡 P2 |
| **Performance & Timeout** | 3 tests | 🟡 P2 |
| **Multi-Machines** | 2 tests | 🟢 P3 |

---

## 🎯 Catégorie 1 : Validation Post-Application (P1)

### Test 1.1 : Vérification Changements Réels Appliqués

**Objectif** : S'assurer que `apply-decision` modifie réellement `sync-config.ref.json`

**Préconditions** :
- Décision pending disponible dans sync-roadmap.md
- `sync-config.ref.json` contient une version initiale

**Étapes** :
1. Lire `sync-config.ref.json` initial
2. Exécuter `roosync_apply_decision(decisionId, dryRun: false)`
3. Lire `sync-config.ref.json` final
4. Comparer les deux versions

**Critères de Succès** :
```typescript
const configBefore = JSON.parse(await fs.readFile(configPath, 'utf-8'));
await service.executeDecision(decisionId, { dryRun: false });
const configAfter = JSON.parse(await fs.readFile(configPath, 'utf-8'));

expect(configAfter).not.toEqual(configBefore);
expect(configAfter.lastModified).toBeGreaterThan(configBefore.lastModified);
```

**Fichier cible** : `tests/e2e/roosync-validation.test.ts`

---

### Test 1.2 : DryRun Ne Modifie Pas Config

**Objectif** : Vérifier que `dryRun: true` ne modifie AUCUN fichier

**Étapes** :
1. Calculer checksum `sync-config.ref.json` avant
2. Exécuter `roosync_apply_decision(decisionId, dryRun: true)`
3. Calculer checksum après
4. Vérifier identité

**Critères de Succès** :
```typescript
const checksumBefore = await calculateChecksum(configPath);
await service.executeDecision(decisionId, { dryRun: true });
const checksumAfter = await calculateChecksum(configPath);

expect(checksumAfter).toBe(checksumBefore);
```

---

### Test 1.3 : Roadmap Mis à Jour avec Métadonnées Complètes

**Objectif** : Vérifier que le bloc décision dans roadmap contient toutes les métadonnées

**Critères de Succès** :
```typescript
await service.executeDecision(decisionId, { dryRun: false });
const roadmap = await fs.readFile(roadmapPath, 'utf-8');

// Vérifier présence de toutes les métadonnées
expect(roadmap).toContain(`**Statut:** applied`);
expect(roadmap).toContain(`**Appliqué le:**`);
expect(roadmap).toContain(`**Appliqué par:** ${machineId}`);
expect(roadmap).toContain(`**Durée:** `);
expect(roadmap).toMatch(/\*\*Fichiers modifiés:\*\* \d+/);
```

---

## 🔄 Catégorie 2 : Robustesse Rollback (P1)

### Test 2.1 : Rollback Restaure État Exact

**Objectif** : Vérifier que `rollback-decision` restaure précisément l'état avant apply

**Étapes** :
1. Capturer état initial (`sync-config.ref.json`)
2. Appliquer décision
3. Vérifier changements appliqués
4. Exécuter rollback
5. Comparer état restauré vs état initial

**Critères de Succès** :
```typescript
const stateBefore = await captureSystemState();
await service.executeDecision(decisionId, { dryRun: false });
const stateAfterApply = await captureSystemState();

expect(stateAfterApply).not.toEqual(stateBefore); // Changements appliqués

await service.restoreFromRollbackPoint(decisionId);
const stateAfterRollback = await captureSystemState();

expect(stateAfterRollback).toEqual(stateBefore); // Restauration exacte
```

---

### Test 2.2 : Rollback Idempotent

**Objectif** : Vérifier que rollback multiple fois produit le même résultat

**Étapes** :
1. Appliquer décision
2. Rollback (1ère fois)
3. Capturer état
4. Rollback (2ème fois sur même décision)
5. Vérifier état identique

**Critères de Succès** :
```typescript
await service.executeDecision(decisionId, { dryRun: false });
await service.restoreFromRollbackPoint(decisionId);
const state1 = await captureSystemState();

await service.restoreFromRollbackPoint(decisionId); // Re-rollback
const state2 = await captureSystemState();

expect(state2).toEqual(state1); // Idempotent
```

---

### Test 2.3 : Erreur Si Rollback Point Manquant

**Objectif** : Gestion gracieuse si rollback point inexistant

**Critères de Succès** :
```typescript
const result = await service.restoreFromRollbackPoint('non-existent-decision');

expect(result.success).toBe(false);
expect(result.error).toContain('No rollback point found');
expect(result.restoredFiles).toEqual([]);
```

---

### Test 2.4 : Rollback Point Corrompu

**Objectif** : Détecter et gérer rollback point avec fichiers corrompus

**Étapes** :
1. Créer rollback point
2. Corrompre `metadata.json` (JSON invalide)
3. Tenter rollback
4. Vérifier erreur explicite

**Critères de Succès** :
```typescript
await service.createRollbackPoint(decisionId);
const metadataPath = getRollbackMetadataPath(decisionId);
await fs.writeFile(metadataPath, 'INVALID JSON', 'utf-8');

await expect(
  service.restoreFromRollbackPoint(decisionId)
).rejects.toThrow(/metadata.*corrupted|invalid JSON/i);
```

---

## ⚡ Catégorie 3 : Edge Cases PowerShell (P2)

### Test 3.1 : Timeout Gracieux

**Objectif** : Vérifier que timeout PowerShell est géré proprement

**Simulation** : Script PowerShell qui `Start-Sleep` plus long que timeout

**Critères de Succès** :
```typescript
// Simuler script lent avec timeout court
const result = await service.executeDecision(decisionId, {
  timeout: 100 // 100ms très court
});

expect(result.success).toBe(false);
expect(result.error).toMatch(/timeout/i);
expect(result.executionTime).toBeGreaterThanOrEqual(100);
```

---

### Test 3.2 : PowerShell Exit Code Non-Zero

**Objectif** : Capturer erreur si PowerShell retourne exit code != 0

**Simulation** : Script PowerShell qui `exit 1`

**Critères de Succès** :
```typescript
// Modifier temporairement sync-manager.ps1 pour forcer erreur
const result = await service.executeDecision(decisionId, { dryRun: false });

expect(result.success).toBe(false);
expect(result.exitCode).not.toBe(0);
expect(result.logs).toContain('PowerShell execution failed');
```

---

### Test 3.3 : Stderr Non-Critique

**Objectif** : Distinguer warnings stderr vs erreurs critiques

**Critères de Succès** :
```typescript
// PowerShell peut écrire warnings dans stderr sans échec
const result = await service.executeDecision(decisionId, { dryRun: false });

if (result.stderr && result.success) {
  // Warnings OK si exit code === 0
  expect(result.logs).toContain('Warning');
  expect(result.success).toBe(true);
}
```

---

### Test 3.4 : Parsing Sortie PowerShell Robuste

**Objectif** : Parser correctement logs même avec caractères spéciaux

**Simulation** : Logs PowerShell avec emojis, accents, UTF-8

**Critères de Succès** :
```typescript
const result = await service.executeDecision(decisionId, { dryRun: false });

// Vérifier que logs UTF-8 sont préservés
expect(result.logs.join('\n')).toMatch(/Configuration.*mise à jour/);
expect(result.logs.join('\n')).not.toContain(''); // Pas de caractères corrompus
```

---

### Test 3.5 : Chemins avec Espaces

**Objectif** : Gérer chemins de fichiers avec espaces (Windows)

**Critères de Succès** :
```typescript
// Créer décision modifiant fichier avec espace dans nom
const result = await service.executeDecision(decisionId, { dryRun: false });

expect(result.success).toBe(true);
expect(result.changes.filesModified).toContain('Mon Fichier Config.json');
```

---

## 🚀 Catégorie 4 : Performance & Timeout (P2)

### Test 4.1 : Benchmark Temps Exécution

**Objectif** : Mesurer temps moyen d'exécution apply-decision

**Critères de Succès** :
```typescript
const iterations = 5;
const times: number[] = [];

for (let i = 0; i < iterations; i++) {
  const start = Date.now();
  await service.executeDecision(decisionId, { dryRun: true });
  times.push(Date.now() - start);
}

const avgTime = times.reduce((a, b) => a + b, 0) / times.length;

expect(avgTime).toBeLessThan(5000); // < 5s en moyenne
console.log(`[BENCHMARK] Average execution time: ${avgTime}ms`);
```

---

### Test 4.2 : Timeout Configurable

**Objectif** : Vérifier que timeout peut être ajusté dynamiquement

**Critères de Succès** :
```typescript
// Timeout court
const result1 = await service.executeDecision(decisionId, {
  timeout: 1000
});

// Timeout long
const result2 = await service.executeDecision(decisionId, {
  timeout: 120000
});

expect(result1.timeout).toBe(1000);
expect(result2.timeout).toBe(120000);
```

---

### Test 4.3 : Pas de Memory Leak

**Objectif** : Vérifier que cache et processus PowerShell ne créent pas de fuites mémoire

**Critères de Succès** :
```typescript
const memBefore = process.memoryUsage().heapUsed;

// Exécuter 50 fois avec clearCache()
for (let i = 0; i < 50; i++) {
  await service.executeDecision(decisionId, { dryRun: true });
  service.clearCache();
}

const memAfter = process.memoryUsage().heapUsed;
const memDiff = memAfter - memBefore;

expect(memDiff).toBeLessThan(10 * 1024 * 1024); // < 10MB diff
```

---

## 🌐 Catégorie 5 : Multi-Machines (P3)

### Test 5.1 : Conflit Application Simultanée

**Objectif** : Détecter si deux machines appliquent la même décision simultanément

**Simulation** : Deux appels `applyDecision()` en parallèle

**Critères de Succès** :
```typescript
// Simulation avec Promise.allSettled
const [result1, result2] = await Promise.allSettled([
  service.executeDecision(decisionId, { dryRun: false }),
  service.executeDecision(decisionId, { dryRun: false })
]);

// Au moins un devrait échouer (idéalement avec erreur de conflit)
const failures = [result1, result2].filter(r => r.status === 'rejected');
expect(failures.length).toBeGreaterThan(0);
```

**Note** : Test simulation, système actuel n'a pas de lock distribué

---

### Test 5.2 : Propagation Changements Multi-Machines

**Objectif** : Vérifier que dashboard reflète changements après apply

**Étapes** :
1. Machine A applique décision
2. Machine B lit dashboard
3. Vérifier que Machine B voit changements de Machine A

**Critères de Succès** :
```typescript
// Machine A
await serviceA.executeDecision(decisionId, { dryRun: false });

// Machine B (nouvelle instance)
const serviceB = RooSyncService.getInstance({ machineId: 'machineB' });
const dashboard = await serviceB.getDashboard();

const machineAStatus = dashboard.machines.find(m => m.id === 'machineA');
expect(machineAStatus.lastSync).toBeGreaterThan(Date.now() - 60000); // < 1min
```

---

## 📊 Résumé des Tests Recommandés

### Matrice de Couverture

| Catégorie | Tests Totaux | P1 | P2 | P3 | Effort |
|-----------|--------------|----|----|----|----|
| Validation Post-Application | 3 | 3 | 0 | 0 | 4h |
| Robustesse Rollback | 4 | 4 | 0 | 0 | 6h |
| Edge Cases PowerShell | 5 | 0 | 5 | 0 | 8h |
| Performance & Timeout | 3 | 0 | 3 | 0 | 4h |
| Multi-Machines | 2 | 0 | 0 | 2 | 6h |
| **TOTAL** | **17** | **7** | **8** | **2** | **28h** |

### Priorisation par Phase

#### Phase 1 : Validation Critique (P1) - 7 tests, 10h
- ✅ Tests 1.1, 1.2, 1.3 (validation post-application)
- ✅ Tests 2.1, 2.2, 2.3, 2.4 (robustesse rollback)

**Objectif** : Garantir fonctionnement correct des opérations critiques

#### Phase 2 : Edge Cases (P2) - 8 tests, 12h
- Tests 3.1 → 3.5 (edge cases PowerShell)
- Tests 4.1 → 4.3 (performance)

**Objectif** : Robustesse production

#### Phase 3 : Extensions (P3) - 2 tests, 6h
- Tests 5.1 → 5.2 (multi-machines)

**Objectif** : Préparation environnement distribué

---

## 🛠️ Implémentation

### Structure Fichiers Tests

```
tests/e2e/
├── roosync-workflow.test.ts          ← ✅ Existant (1182 lignes)
├── roosync-validation.test.ts        ← ⚠️ À créer (Tests 1.1-1.3)
├── roosync-rollback-robustness.test.ts ← ⚠️ À créer (Tests 2.1-2.4)
├── roosync-powershell-edge-cases.test.ts ← ⚠️ À créer (Tests 3.1-3.5)
├── roosync-performance.test.ts       ← ⚠️ À créer (Tests 4.1-4.3)
├── roosync-multi-machines.test.ts    ← ⚠️ À créer (Tests 5.1-5.2)
└── helpers/
    ├── test-helpers.ts               ← Helpers communs
    ├── state-capture.ts              ← captureSystemState()
    └── checksum-utils.ts             ← calculateChecksum()
```

### Script Exécution

```powershell
# tests/e2e/run-comprehensive-tests.ps1

param(
    [ValidateSet("P1", "P2", "P3", "All")]
    [string]$Priority = "P1",
    
    [switch]$Verbose,
    [switch]$StopOnFailure
)

$testFiles = @()

switch ($Priority) {
    "P1" {
        $testFiles = @(
            "roosync-validation.test.ts",
            "roosync-rollback-robustness.test.ts"
        )
    }
    "P2" {
        $testFiles = @(
            "roosync-powershell-edge-cases.test.ts",
            "roosync-performance.test.ts"
        )
    }
    "P3" {
        $testFiles = @(
            "roosync-multi-machines.test.ts"
        )
    }
    "All" {
        $testFiles = @(
            "roosync-workflow.test.ts",
            "roosync-validation.test.ts",
            "roosync-rollback-robustness.test.ts",
            "roosync-powershell-edge-cases.test.ts",
            "roosync-performance.test.ts",
            "roosync-multi-machines.test.ts"
        )
    }
}

foreach ($file in $testFiles) {
    Write-Host "▶️ Running: $file" -ForegroundColor Cyan
    
    $result = vitest run $file $(if ($Verbose) { "--reporter=verbose" })
    
    if ($LASTEXITCODE -ne 0 -and $StopOnFailure) {
        Write-Host "❌ Test failed, stopping." -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ All tests completed!" -ForegroundColor Green
```

### Utilisation

```bash
# Exécuter tests P1 (critique)
cd tests/e2e
.\run-comprehensive-tests.ps1 -Priority P1

# Exécuter tous les tests avec verbose
.\run-comprehensive-tests.ps1 -Priority All -Verbose

# Stop au premier échec
.\run-comprehensive-tests.ps1 -Priority P2 -StopOnFailure
```

---

## 🎯 Critères de Succès Globaux

### Couverture Cible

| Métrique | Cible | Actuel |
|----------|-------|--------|
| Couverture workflow complet | 100% | ✅ 100% |
| Tests robustesse erreurs | > 20 tests | ⚠️ ~12 tests |
| Tests edge cases | > 8 scénarios | ⚠️ 2 scénarios |
| Tests performance | > 3 benchmarks | ❌ 0 |
| Tests multi-machines | > 2 scénarios | ❌ 0 |
| **TOTAL Tests E2E** | **> 35 tests** | **~15 tests** |

### Acceptance Criteria

**Phase 1 (P1) :**
- ✅ Tous les tests P1 passent (7/7)
- ✅ Aucune régression des tests existants
- ✅ Coverage > 90% pour apply-decision + rollback-decision

**Phase 2 (P2) :**
- ✅ 80% des tests P2 passent (6/8 minimum)
- ✅ Benchmarks performance < 5s en moyenne
- ✅ Aucun memory leak détecté

**Phase 3 (P3) :**
- ✅ Tests multi-machines documentent comportement actuel
- ✅ Recommandations pour lock distribué si nécessaire

---

## 📝 Recommandations Finales

### Priorité Immédiate

1. **Implémenter Tests P1** (10h) - Validation critique
2. **Exécuter Tests Existants** - Confirmer baseline
3. **Documenter Résultats** - Créer rapport test

### Améliorations Futures

1. **CI/CD Integration** - Exécuter tests automatiquement
2. **Test Data Fixtures** - Décisions test standardisées
3. **Mocking Avancé** - Simuler erreurs PowerShell spécifiques
4. **Load Testing** - Tester avec 100+ décisions

---

**Statut Plan** : 📋 **PRÊT POUR IMPLÉMENTATION**