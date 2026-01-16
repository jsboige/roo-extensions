# Diagnostic des 15 Tests en Échec - MCP roo-state-manager

**Date:** 2026-01-13
**Machine:** myia-po-2026
**Projet:** RooSync Multi-Agent Consolidation
**MCP:** `mcps/internal/servers/roo-state-manager`
**Git commit:** 021f65b
**Auteur:** Diagnostic Mode Debug

---

## Résumé Exécutif

**15 tests sont en échec** répartis dans 5 fichiers de test différents. Les causes racines identifiées sont :

1. **Incohérence d'API** (3 tests) - Structure de tool incompatible avec les tests
2. **Problèmes de mock fs** (5 tests) - Tests d'intégration avec système de fichiers réel
3. **Changements d'implémentation** (5 tests) - `TaskIndexer` ne gère plus les erreurs comme attendu
4. **Problèmes de mock** (1 test) - `mockReaddir.mockRejectedValue` non disponible
5. **Race condition** (1 test) - Test de concurrence avec délais

---

## 1. Liste Complète des Tests en Échec

### 1.1 `tests/unit/tools/minimal-test.test.ts` (3 échecs)

| Test | Erreur |
|------|--------|
| `devrait retourner un message de test avec timestamp` | `minimal_test_tool.execute is not a function` |
| `devrait gérer un message vide` | `minimal_test_tool.execute is not a function` |
| `devrait contenir les informations de base` | `minimal_test_tool.execute is not a function` |

### 1.2 `tests/unit/services/roosync/PresenceManager.integration.test.ts` (5 échecs)

| Test | Erreur |
|------|--------|
| `should update presence with lock` | `expected false to be true` |
| `should read presence` | `expected null not to be null` |
| `should remove presence with lock` | `expected false to be true` |
| `should update current presence` | `expected false to be true` |
| `should list all presence` | `expected [] to have a length of 2 but got 0` |

### 1.3 `tests/unit/services/task-indexer.test.ts` (5 échecs)

| Test | Erreur |
|------|--------|
| `Circuit Breaker - État CLOSED : Permet les requêtes` | `Task test-task-id not found in any storage location` |
| `Circuit Breaker - État OPEN : Bloque les requêtes après 3 échecs` | `Task test-task-id-fail not found in any storage location` |
| `Circuit Breaker - Délai exponentiel : 2s, 4s, 8s` | `Task test-retry-timing not found in any storage location` |
| `Gestion des erreurs parentTaskId manquant` | `Task orphan-task not found in any storage location` |
| `Logging détaillé - Capture des métriques critiques` | `Task test-logging not found in any storage location` |

### 1.4 `tests/unit/tools/read-vscode-logs.test.ts` (1 échec)

| Test | Erreur |
|------|--------|
| `should handle undefined args gracefully` | `mockReaddir.mockRejectedValue is not a function` |

### 1.5 `tests/unit/services/roosync/FileLockManager.simple.test.ts` (1 échec)

| Test | Erreur |
|------|--------|
| `should handle concurrent operations with delays` | `expected undefined to be 5` |

---

## 2. Analyse des Causes Racines

### 2.1 Incohérence d'API - `minimal-test.tool.ts`

**Fichiers concernés:**
- [`src/tools/test/minimal-test.tool.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/test/minimal-test.tool.ts)
- [`tests/unit/tools/minimal-test.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/minimal-test.test.ts)

**Problème identifié:**

L'implémentation du tool utilise une structure avec `handler` :

```typescript
export const minimal_test_tool: Tool = {
    definition: { ... },
    handler: handleMinimalTest  // ← Utilise 'handler'
};
```

Mais les tests appellent `execute` :

```typescript
const result = await minimal_test_tool.execute(args);  // ← Appelle 'execute'
```

**Cause racine:**
Incohérence entre la définition de l'interface `Tool` et les tests. Le test attend une méthode `execute` mais l'implémentation fournit `handler`.

**Impact:**
- 3 tests échouent avec la même erreur
- Le tool ne peut pas être testé correctement

---

### 2.2 Problèmes de Mock fs - `PresenceManager.integration.test.ts`

**Fichiers concernés:**
- [`tests/unit/services/roosync/PresenceManager.integration.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/services/roosync/PresenceManager.integration.test.ts)
- [`tests/setup/presence.setup.js`](../../mcps/internal/servers/roo-state-manager/tests/setup/presence.setup.js)
- [`src/services/roosync/PresenceManager.ts`](../../mcps/internal/servers/roo-state-manager/src/services/roosync/PresenceManager.ts)

**Problème identifié:**

Le setup tente de désactiver le mock de fs :

```javascript
// presence.setup.js
beforeAll(() => {
  vi.unmock('fs');
  vi.unmock('fs/promises');
});
```

Mais les tests échouent avec des erreurs indiquant que les opérations de fichiers ne fonctionnent pas correctement.

**Causes racines possibles:**

1. **Problème de timing:** `vi.unmock()` peut ne pas fonctionner correctement avec Vitest si le module a déjà été importé
2. **Problème de singleton:** `FileLockManager` utilise un singleton qui peut avoir été initialisé avec le mock fs
3. **Problème de permissions sur Windows:** Les tests créent des répertoires temporaires dans `process.cwd()` qui peuvent avoir des problèmes de permissions
4. **Problème de nettoyage:** Le `afterEach` peut ne pas nettoyer correctement les fichiers entre les tests

**Analyse du code:**

```typescript
// PresenceManager.ts - Ligne 131
const result = await this.lockManager.updateJsonWithLock<PresenceData>(
    presenceFile,
    (existingData) => { ... },
    lockOptions
);
```

Le test attend `result.success` à `true` mais obtient `false`, ce qui indique que l'opération de verrouillage ou de fichier échoue.

**Impact:**
- 5 tests d'intégration échouent
- Les tests ne peuvent pas valider le fonctionnement de `PresenceManager` avec le vrai système de fichiers

---

### 2.3 Changements d'Implémentation - `task-indexer.test.ts`

**Fichiers concernés:**
- [`tests/unit/services/task-indexer.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/services/task-indexer.test.ts)
- [`src/services/task-indexer.ts`](../../mcps/internal/servers/roo-state-manager/src/services/task-indexer.ts)

**Problème identifié:**

Les tests mockent `fs.access` pour rejeter avec "File not found" :

```typescript
mockFs.access.mockRejectedValue(new Error('File not found'));
```

Et attendent que `indexTask` retourne `[]` :

```typescript
const result = await taskIndexer.indexTask('test-task-id');
expect(result).toEqual([]);
```

Mais l'implémentation lance une erreur au lieu de retourner `[]` :

```
Task test-task-id not found in any storage location
```

**Cause racine:**

L'implémentation de `TaskIndexer.indexTask()` a probablement changé et ne gère plus les erreurs de fichier non trouvé de la même manière. Au lieu de retourner un tableau vide, elle lance une exception.

**Analyse du test:**

```typescript
// Lignes 109-118
test('Circuit Breaker - État CLOSED : Permet les requêtes', async () => {
    mockFs.access.mockRejectedValue(new Error('File not found'));
    const result = await taskIndexer.indexTask('test-task-id');
    expect(result).toEqual([]);  // ← Attend []
});
```

Le commentaire indique : "La fonction indexTask globale retourne [] quand la tâche n'est pas trouvée (voir lignes 816-824 dans task-indexer.ts)"

Cela suggère que le test a été écrit pour une version spécifique de l'implémentation qui n'est plus actuelle.

**Impact:**
- 5 tests échouent avec la même erreur
- Les tests de circuit breaker et de gestion d'erreurs ne peuvent pas être validés

---

### 2.4 Problème de Mock - `read-vscode-logs.test.ts`

**Fichiers concernés:**
- [`tests/unit/tools/read-vscode-logs.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/read-vscode-logs.test.ts)

**Problème identifié:**

Le test essaie d'utiliser `mockReaddir.mockRejectedValue` :

```typescript
const mockReaddir = vi.mocked(fs.promises.readdir);
mockReaddir.mockRejectedValue(new Error('ENOENT: no such file or directory...'));
```

Mais obtient l'erreur : `mockReaddir.mockRejectedValue is not a function`

**Cause racine:**

`vi.mocked()` ne retourne pas un mock avec les méthodes de mock comme `mockRejectedValue`. C'est une incohérence dans l'utilisation de l'API de Vitest.

**Solution correcte:**

```typescript
// Utiliser vi.spyOn au lieu de vi.mocked
const mockReaddir = vi.spyOn(fs.promises, 'readdir');
mockReaddir.mockRejectedValue(new Error('ENOENT...'));
```

**Impact:**
- 1 test échoue
- Le test de robustesse ne peut pas être validé

---

### 2.5 Race Condition - `FileLockManager.simple.test.ts`

**Fichiers concernés:**
- [`tests/unit/services/roosync/FileLockManager.simple.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/services/roosync/FileLockManager.simple.test.ts)
- [`src/services/roosync/FileLockManager.simple.ts`](../../mcps/internal/servers/roo-state-manager/src/services/roosync/FileLockManager.simple.ts)

**Problème identifié:**

Le test `should handle concurrent operations with delays` échoue avec :

```
expected undefined to be 5
```

**Analyse du test:**

```typescript
// Lignes 219-249
it('should handle concurrent operations with delays', async () => {
    const operations = 5;
    const promises: Promise<LockOperationResult<any>>[] = [];

    for (let i = 0; i < operations; i++) {
      promises.push(
        lockManager.updateJsonWithLock(
          testFilePath,
          async (data: any) => {
            await new Promise(resolve => setTimeout(resolve, Math.random() * 50));
            return { ...data, counter: data.counter + 1 };
          }
        )
      );
    }

    const results = await Promise.all(promises);
    results.forEach(result => {
      expect(result.success).toBe(true);
    });

    const content = await fs.readFile(testFilePath, 'utf-8');
    const fileData = JSON.parse(content);
    expect(fileData.counter).toBe(operations);  // ← Échoue ici
});
```

**Cause racine:**

Le test attend que le compteur final soit 5, mais obtient `undefined`. Cela peut être dû à :

1. **Race condition dans le verrouillage:** Le `FileLockManager` peut ne pas gérer correctement les opérations concurrentes avec des délais
2. **Problème de lecture du fichier:** Le fichier peut ne pas être écrit correctement
3. **Problème de mock fs:** Si le mock fs ne gère pas correctement les écritures concurrentes

**Analyse de l'implémentation:**

```typescript
// FileLockManager.simple.ts - Lignes 222-234
async updateJsonWithLock<T>(
    filePath: string,
    updater: (data: T) => T,
    options?: LockOptions
): Promise<LockOperationResult<T>> {
    return this.withLock(filePath, async () => {
      const content = await fs.readFile(filePath, 'utf-8');
      const data = JSON.parse(content) as T;
      const updated = updater(data);
      await fs.writeFile(filePath, JSON.stringify(updated, null, 2), 'utf-8');
      return updated;
    }, options);
}
```

Le problème peut venir du fait que `updater` est une fonction asynchrone dans le test mais l'implémentation ne l'attend pas explicitement.

**Impact:**
- 1 test échoue
- La gestion de la concurrence ne peut pas être validée

---

## 3. Stratégie de Correction Proposée

### 3.1 Priorité 1 - Incohérence d'API (minimal-test.tool.ts)

**Action requise:**
1. Vérifier l'interface `Tool` dans [`src/types/tool-definitions.ts`](../../mcps/internal/servers/roo-state-manager/src/types/tool-definitions.ts)
2. Soit modifier l'implémentation pour utiliser `execute` au lieu de `handler`
3. Soit modifier les tests pour appeler `handler` au lieu de `execute`

**Recommandation:**
Modifier l'implémentation pour utiliser `execute` car c'est plus standard et cohérent avec les autres tools.

---

### 3.2 Priorité 2 - Problèmes de Mock fs (PresenceManager)

**Action requise:**
1. Vérifier si `vi.unmock()` fonctionne correctement avec Vitest
2. Considérer l'utilisation de `vi.doUnmock()` ou une approche différente
3. Vérifier les permissions sur Windows pour les répertoires temporaires
4. Ajouter des logs de debug dans `PresenceManager` pour identifier où l'opération échoue

**Recommandation:**
Créer un setup spécifique pour les tests d'intégration qui n'utilise pas de mocks du tout, ou utiliser un framework de test d'intégration dédié.

---

### 3.3 Priorité 2 - Changements d'Implémentation (task-indexer)

**Action requise:**
1. Vérifier l'implémentation actuelle de `TaskIndexer.indexTask()`
2. Mettre à jour les tests pour correspondre au comportement actuel
3. OU modifier l'implémentation pour retourner `[]` au lieu de lancer une erreur

**Recommandation:**
Mettre à jour les tests pour correspondre au comportement actuel de l'implémentation, car l'implémentation est probablement correcte (lancer une erreur est plus approprié que retourner un tableau vide silencieusement).

---

### 3.3 Priorité 3 - Problème de Mock (read-vscode-logs)

**Action requise:**
1. Remplacer `vi.mocked(fs.promises.readdir)` par `vi.spyOn(fs.promises, 'readdir')`
2. Ajouter le nettoyage du spy dans `afterEach`

**Recommandation:**
Utiliser `vi.spyOn()` qui est l'API correcte de Vitest pour mocker des méthodes existantes.

---

### 3.4 Priorité 3 - Race Condition (FileLockManager)

**Action requise:**
1. Ajouter des logs de debug dans `FileLockManager.updateJsonWithLock()`
2. Vérifier si le problème vient du mock fs ou de l'implémentation
3. Ajouter des assertions intermédiaires pour identifier où le compteur devient `undefined`

**Recommandation:**
Vérifier d'abord si le problème vient du mock fs en exécutant le test sans mocks (test d'intégration réel).

---

## 4. Risques et Dépendances

### 4.1 Risques

1. **Risque de régression:** Modifier l'implémentation de `minimal_test_tool` peut affecter d'autres parties du code qui l'utilisent
2. **Risque de compatibilité Windows:** Les tests d'intégration avec le vrai système de fichiers peuvent avoir des problèmes spécifiques à Windows
3. **Risque de performance:** Les tests de concurrence peuvent être instables sur certaines machines

### 4.2 Dépendances

1. **Dépendance sur Vitest:** Certains problèmes peuvent être liés à la version de Vitest utilisée
2. **Dépendance sur mock-fs:** Le package `mock-fs` peut avoir des limitations sur Windows
3. **Dépendance sur l'implémentation:** Les tests dépendent fortement de l'implémentation actuelle, ce qui les rend fragiles

---

## 5. Recommandations Générales

### 5.1 Améliorer la Robustesse des Tests

1. **Utiliser des interfaces stables:** Les tests devraient dépendre des interfaces publiques plutôt que de l'implémentation interne
2. **Ajouter des logs de debug:** Les tests devraient avoir des logs détaillés pour faciliter le diagnostic
3. **Utiliser des fixtures:** Créer des fixtures réutilisables pour les configurations de test complexes

### 5.2 Améliorer la Documentation

1. **Documenter les interfaces:** Les interfaces comme `Tool` devraient être clairement documentées
2. **Documenter les conventions:** Les conventions de test devraient être documentées (ex: comment utiliser les mocks)
3. **Documenter les changements:** Les changements d'implémentation qui affectent les tests devraient être documentés

### 5.3 Améliorer le Processus de Test

1. **Tests unitaires vs tests d'intégration:** Séparer clairement les tests unitaires (avec mocks) des tests d'intégration (sans mocks)
2. **Tests de régression:** Ajouter des tests de régression pour les bugs corrigés
3. **Tests de performance:** Ajouter des tests de performance pour les opérations critiques (ex: verrouillage de fichiers)

---

## 6. Conclusion

Ce diagnostic a identifié **15 tests en échec** répartis en **5 catégories de problèmes** :

1. **Incohérence d'API** (3 tests) - Facile à corriger
2. **Problèmes de mock fs** (5 tests) - Nécessite une investigation plus approfondie
3. **Changements d'implémentation** (5 tests) - Nécessite de mettre à jour les tests
4. **Problème de mock** (1 test) - Facile à corriger
5. **Race condition** (1 test) - Nécessite une investigation plus approfondie

**Prochaines étapes:**
1. Corriger les problèmes faciles (incohérence d'API, problème de mock)
2. Investiguer les problèmes plus complexes (mock fs, race condition)
3. Mettre à jour les tests pour correspondre à l'implémentation actuelle
4. Ajouter des tests de régression pour éviter les régressions futures

---

**Document généré par:** Mode Debug - Diagnostic Systematique
**Date de génération:** 2026-01-13T13:00:00Z
**Version:** 1.0.0
