# Rapport Validation Tests - 2025-10-18

**Date d'exécution**: 2025-10-19 18:27:12  
**Durée totale**: 1044.15 secondes

---

## Résumé Exécutif

| Métrique | Valeur | Pourcentage |
|----------|--------|-------------|
| **Total tests exécutés** | 0 | 100% |
| **Tests passés** | 0 | 0% |
| **Tests échoués** | 0 | % |
| **Tests ignorés** | 0 | % |

**Statut global**: ✅ SUCCÈS

---

## Détails par Module

### ❓ github-projects-mcp

**Chemin**: `D:\roo-extensions\mcps\internal\servers\github-projects-mcp`  
**Durée**: 21.57s  
**Statut**: Error

**Résultats**:
- Tests passés: 0
- Tests échoués: 0
- Tests ignorés: 0

**Erreurs notables**:
```
Cannot index into a null array.
```

### ⚠️ roo-state-manager

**Chemin**: `D:\roo-extensions\mcps\internal\servers\roo-state-manager`  
**Durée**: 161.53s  
**Statut**: Warning

**Résultats**:
- Tests passés: 0
- Tests échoués: 0
- Tests ignorés: 0

**Erreurs notables**:
```
[22m[39m❌ [SynthesisOrchestrator] Erreur synthèse test-task-id: Error: Mock context builder error
[22m[39m❌ [SynthesisOrchestrator] Erreur synthèse test-task-id: Error: Mock context builder error for contextTree test
[22m[39m❌ [SynthesisOrchestrator] Erreur LLM pour test-task-id: Error: Mock OpenAI API error
[49324:000001733F0C1000]   150899 ms: Mark-Compact 4046.1 (4133.4) -> 4031.7 (4134.7) MB, pooled: 1 MB, 2183.99 / 0.90 ms  (average mu = 0.075, current mu = 0.032) allocation failure; scavenge might not succeed
[49324:000001733F0C1000]   153269 ms: Mark-Compact 4047.8 (4134.9) -> 4033.4 (4136.4) MB, pooled: 0 MB, 2320.41 / 1.01 ms  (average mu = 0.049, current mu = 0.021) allocation failure; scavenge might not succeed
FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
[31m[1mSerialized Error:[22m[39m [90m{ code: 'ERR_IPC_CHANNEL_CLOSED' }[39m
```

### ⚠️ quickfiles-server

**Chemin**: `D:\roo-extensions\mcps\internal\servers\quickfiles-server`  
**Durée**: 8.72s  
**Statut**: Warning

**Résultats**:
- Tests passés: 0
- Tests échoués: 0
- Tests ignorés: 0

**Erreurs notables**:
```
FAIL __tests__/quickfiles.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
FAIL __tests__/performance.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
FAIL __tests__/file-operations.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
FAIL __tests__/error-handling.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
FAIL __tests__/search-replace.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
FAIL __tests__/anti-regression.test.js
  ● Test suite failed to run
    Jest failed to parse a file. This happens e.g. when your code or its dependencies use non-standard JavaScript syntax, or when Jest is not configured to support such syntax.
    SyntaxError: Cannot use import statement outside a module
Test Suites: 6 failed, 6 total
```

### ✅ indexer-phase1-unit-tests

**Chemin**: `D:\roo-extensions`  
**Durée**: 2.18s  
**Statut**: Success

**Résultats**:
- Tests passés: 0
- Tests échoués: 0
- Tests ignorés: 0

**Erreurs notables**:
```
    "failed": 0,
```

### ✅ indexer-phase2-load-tests

**Chemin**: `D:\roo-extensions`  
**Durée**: 800.88s  
**Statut**: Success

**Résultats**:
- Tests passés: 0
- Tests échoués: 0
- Tests ignorés: 0

---

## Analyse
### ✅ Tous les tests passent avec succès

Aucun test échoué détecté. L'infrastructure de tests est en bon état.


---

## Actions Requises
- ✅ Aucune action immédiate requise
- Procéder à la Partie 5: Augmentation de la couverture tests

---

## Métadonnées

- **Script**: `scripts\testing\validate-all-tests-20251018.ps1`
- **Timestamp**: 20251019-180947
- **Système**: Windows PowerShell 7.5.3
- **Répertoire**: `D:\roo-extensions`

