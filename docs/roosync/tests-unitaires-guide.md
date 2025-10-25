# Guide Tests Unitaires RooSync - Phase 3

## 🎯 Objectif

Guide de référence pour l'utilisation, l'ajout et la maintenance des tests unitaires RooSync en mode **dry-run**.

---

## 📦 Architecture Tests

### Structure Consolidée

```
tests/roosync/
├── README.md                            # Documentation principale
├── helpers/                             # Utilitaires communs (DRY)
│   ├── test-logger.ts                  # Logger isolé tests
│   ├── test-git.ts                     # Mocks Git safe
│   └── test-deployment.ts              # Mocks PowerShell
├── fixtures/                            # Données test réutilisables
│   ├── logger-config.json              # Configurations logger
│   └── deployment-scripts.json         # Scripts PowerShell test
├── run-all-tests.ts                    # Runner exécution 4 batteries
├── test-logger-rotation-dryrun.ts      # Test 1: Logger rotation
├── test-git-helpers-dryrun.ts          # Test 2: Git helpers
├── test-deployment-wrappers-dryrun.ts  # Test 3: Deployment wrappers
└── test-task-scheduler-dryrun.ps1      # Test 4: Task scheduler
```

---

## 🧪 Batteries de Tests

### Test 1 : Logger Rotation

**Fichier** : `test-logger-rotation-dryrun.ts`

**Objectifs** :
- Valider rotation logs par taille (10MB max)
- Valider rotation logs par date (7 jours)
- Valider suppression anciens logs (>7 jours)

**Contraintes** :
- Mode dry-run uniquement
- Logs isolés dans `tests/results/roosync/logger-test-logs/`
- Aucune modification logs production (`RooSync/logs/`)

**Exécution** :
```bash
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts
```

**Rapport** : `tests/results/roosync/logger-test-logs/test-report.json`

---

### Test 2 : Git Helpers

**Fichier** : `test-git-helpers-dryrun.ts`

**Objectifs** :
- Valider `verifyGitAvailable()` (Git présent/absent)
- Valider `safePull()` avec mock (succès/échec + rollback)
- Valider `safeCheckout()` avec mock (succès/échec + rollback)

**Contraintes** :
- Mocks uniquement (pas de modifications repo Git)
- Vérification SHA avant/après opération
- Rollback automatique en cas d'échec

**Exécution** :
```bash
npx ts-node tests/roosync/test-git-helpers-dryrun.ts
```

**Rapport** : `tests/results/roosync/test2-git-helpers-report.json`

---

### Test 3 : Deployment Wrappers

**Fichier** : `test-deployment-wrappers-dryrun.ts`

**Objectifs** :
- Valider timeout scripts PowerShell (>30s)
- Valider gestion erreurs (exit code != 0)
- Valider mode dry-run (deployModes({ dryRun: true }))

**Contraintes** :
- Scripts PowerShell test isolés (`deployment-test-scripts/`)
- Timeout détecté correctement
- Erreurs gérées sans interruption

**Exécution** :
```bash
npx ts-node tests/roosync/test-deployment-wrappers-dryrun.ts
```

**Rapport** : `tests/results/roosync/test3-deployment-report.json`

---

### Test 4 : Task Scheduler

**Fichier** : `test-task-scheduler-dryrun.ps1`

**Objectifs** :
- Vérifier task scheduler Windows accessible
- Simuler création tâche (dry-run)
- Vérifier triggers cron (2h interval)

**Contraintes** :
- Mode dry-run uniquement (pas de tâche créée)
- Vérification permissions administrateur
- Validation format cron

**Exécution** :
```bash
pwsh -File tests/roosync/test-task-scheduler-dryrun.ps1
```

**Rapport** : Console output (pas de JSON généré)

---

## 🚀 Exécution Tests

### Runner Automatique (Recommandé)

Exécute les 4 batteries séquentiellement :

```bash
npx ts-node tests/roosync/run-all-tests.ts
```

**Avantages** :
- Exécution séquentielle (évite conflits)
- Rapport consolidé unique
- Taux succès global calculé
- Logs détaillés

**Rapport consolidé** : `tests/results/roosync/all-tests-report.json`

---

### Exécution Manuelle

Pour exécuter tests individuellement :

```bash
# Test 1 - Logger Rotation
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts

# Test 2 - Git Helpers
npx ts-node tests/roosync/test-git-helpers-dryrun.ts

# Test 3 - Deployment Wrappers
npx ts-node tests/roosync/test-deployment-wrappers-dryrun.ts

# Test 4 - Task Scheduler
pwsh -File tests/roosync/test-task-scheduler-dryrun.ps1
```

---

## 📊 Rapports de Tests

### Format JSON Standard

Tous les tests TypeScript génèrent un rapport JSON standardisé :

```json
{
  "timestamp": "2025-10-24T23:00:00.000Z",
  "testsRun": 3,
  "testsPassed": 3,
  "testsFailed": 0,
  "successRate": 100,
  "results": [
    {
      "testName": "Rotation par taille (10MB)",
      "success": true,
      "details": "✅ Rotation déclenchée après dépassement seuil. Fichiers créés: 2",
      "observations": [
        "Fichier initial: test-roosync-20251024.log",
        "Fichier après rotation: test-roosync-20251024-2.log",
        "Nombre fichiers logs: 2"
      ]
    }
  ]
}
```

### Rapport Consolidé

Le runner `run-all-tests.ts` génère un rapport consolidé :

```json
{
  "timestamp": "2025-10-24T23:00:00.000Z",
  "batteriesRun": 4,
  "batteriesSuccess": 4,
  "batteriesFailed": 0,
  "overallSuccessRate": 100,
  "individualTests": {
    "total": 14,
    "passed": 14,
    "failed": 0
  },
  "results": [...]
}
```

---

## 🛠️ Ajout de Nouveaux Tests

### Étape 1 : Utiliser les Helpers

Importer les utilitaires communs :

```typescript
import { TestLogger, TestResult, generateTestReport } from './helpers/test-logger';
import { mockVerifyGitAvailable, mockSafePull } from './helpers/test-git';
import { createTimeoutTestScript } from './helpers/test-deployment';

const logger = new TestLogger('./tests/results/roosync/my-test.log');
```

### Étape 2 : Utiliser les Fixtures

Charger configurations réutilisables :

```typescript
import loggerConfig from './fixtures/logger-config.json';
import deploymentScripts from './fixtures/deployment-scripts.json';

const logger = new Logger(loggerConfig.testConfig);
const scriptsDir = deploymentScripts.testScriptsDir;
```

### Étape 3 : Créer Fichier Test

Suivre le pattern standard :

```typescript
/**
 * TEST X - Description
 * 
 * Objectif : ...
 * 
 * Tests :
 * - X.1 : ...
 * - X.2 : ...
 * 
 * CONTRAINTES :
 * - Mode DRY-RUN uniquement
 * - Logs isolés dans tests/results/roosync/
 */

import { TestLogger, TestResult, generateTestReport } from './helpers/test-logger';

const logger = new TestLogger('./tests/results/roosync/testX-output.log');
const REPORT_PATH = './tests/results/roosync/testX-report.json';

const results: TestResult[] = [];

// Test X.1 : ...
function testCase1(): TestResult {
  logger.section('Test X.1 : ...');
  
  try {
    // Implémentation test...
    
    return {
      testName: 'Test X.1',
      success: true,
      details: '✅ Test réussi',
      observations: ['...']
    };
  } catch (error) {
    return {
      testName: 'Test X.1',
      success: false,
      details: `❌ Erreur : ${error.message}`
    };
  }
}

// Exécuter tests
results.push(testCase1());

// Générer rapport
generateTestReport(results, REPORT_PATH);

// Exit code
const allPassed = results.every((r) => r.success);
process.exit(allPassed ? 0 : 1);
```

### Étape 4 : Ajouter au Runner

Modifier `run-all-tests.ts` pour inclure le nouveau test :

```typescript
const TESTS = [
  // ... tests existants
  {
    name: 'Test X - Description',
    command: 'npx ts-node tests/roosync/testX.ts',
    reportPath: 'tests/results/roosync/testX-report.json',
  },
];
```

---

## 📚 Best Practices

### ✅ DO

1. **Utiliser helpers/** : Pas de duplication code logger/mocks
2. **Isoler logs** : `tests/results/roosync/` uniquement
3. **Mode dry-run** : Aucune modification production
4. **Rapports JSON** : Traçabilité complète
5. **Nettoyage** : `cleanupTestEnv()` avant/après tests
6. **Commentaires JSDoc** : Documentation inline
7. **Assertions claires** : Messages d'erreur explicites

### ❌ DON'T

1. Modifier logs production (`RooSync/logs/`)
2. Modifier configuration production (`RooSync/config/`)
3. Commiter fichiers `tests/results/` (ajoutés au `.gitignore`)
4. Créer nouveau logger (utiliser `helpers/test-logger.ts`)
5. Exécuter sans dry-run (risque corruption)
6. Supprimer fixtures (données réutilisables)
7. Tests interdépendants (isolation obligatoire)

---

## 🔍 Debugging

### Logs Détaillés

Activer logs verbeux :

```bash
export DEBUG=true
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts
```

### Rapports JSON

Consulter rapports individuels :

```bash
# Test 1 - Logger
cat tests/results/roosync/logger-test-logs/test-report.json | jq .

# Test 2 - Git
cat tests/results/roosync/test2-git-helpers-report.json | jq .

# Test 3 - Deployment
cat tests/results/roosync/test3-deployment-report.json | jq .

# Rapport consolidé
cat tests/results/roosync/all-tests-report.json | jq .
```

### Logs Fichiers

Consulter logs détaillés :

```bash
# Test 1 - Logger
tail -f tests/results/roosync/logger-test-logs/test-roosync-20251024.log

# Test 2 - Git
tail -f tests/results/roosync/test2-git-helpers-output.log

# Test 3 - Deployment
tail -f tests/results/roosync/test3-deployment-output.log

# Runner
tail -f tests/results/roosync/run-all-tests.log
```

---

## 🔧 Maintenance

### Nettoyage Logs Test

Nettoyer logs test anciens :

```bash
# Supprimer logs >7 jours
find tests/results/roosync/ -name "*.log" -mtime +7 -delete

# Nettoyer tous logs test (réinitialisation)
rm -rf tests/results/roosync/*.log
rm -rf tests/results/roosync/logger-test-logs/*.log
```

### Mise à Jour Helpers

Modifier helpers communs :

1. Éditer `helpers/test-logger.ts`, `helpers/test-git.ts`, etc.
2. Vérifier compatibilité avec tests existants
3. Exécuter `run-all-tests.ts` pour validation
4. Commiter si 14/14 tests PASS

### Ajout Fixtures

Ajouter configurations réutilisables :

1. Créer `fixtures/nouvelle-config.json`
2. Importer dans tests : `import config from './fixtures/nouvelle-config.json'`
3. Documenter dans `README.md`

---

## 📦 Dépendances

- **Node.js** >= 18.x
- **TypeScript** >= 5.x
- **PowerShell** >= 7.x (pour Test 4)
- **Git** >= 2.x (pour Test 2)

Installation :

```bash
npm install --save-dev typescript ts-node @types/node
```

---

## 🎯 Objectifs de Qualité

### Cibles

- **Couverture tests** : 100% composants critiques
- **Taux succès** : 14/14 tests PASS (100%)
- **Temps exécution** : <2 minutes (4 batteries)
- **Isolation** : 0 modification production

### Métriques

Consulter rapport consolidé :

```bash
npx ts-node tests/roosync/run-all-tests.ts
# Affiche :
# - Batteries : 4/4 PASS (100%)
# - Tests individuels : 14/14 PASS (100%)
# - Durée totale : ~120s
```

---

## 📞 Support

**Questions** : Consulter `tests/roosync/README.md`

**Issues** : Vérifier logs `tests/results/roosync/*.log`

**Rapports** : Consulter `tests/results/roosync/*-report.json`

---

## 📅 Historique

- **2025-10-24** : Phase 3 - Création tests unitaires dry-run
- **2025-10-24** : Consolidation structure (helpers/, fixtures/, runner)
- **2025-10-24** : Documentation guide tests unitaires

---

## 🚀 Prochaines Étapes

1. **CI/CD** : Intégrer tests dans pipeline GitHub Actions
2. **Coverage** : Ajouter analyse couverture code (Jest/NYC)
3. **Performance** : Ajouter tests charge/stress
4. **Intégration** : Tests multi-composants (logger + Git + deployment)
5. **E2E** : Tests bout-en-bout RooSync complet

---

## 📖 Références

- [README Tests](../../tests/roosync/README.md)
- [Helper Logger](../../tests/roosync/helpers/test-logger.ts)
- [Helper Git](../../tests/roosync/helpers/test-git.ts)
- [Helper Deployment](../../tests/roosync/helpers/test-deployment.ts)
- [Fixtures Logger](../../tests/roosync/fixtures/logger-config.json)
- [Fixtures Deployment](../../tests/roosync/fixtures/deployment-scripts.json)