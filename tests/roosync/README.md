# Tests Unitaires RooSync - Phase 3

## 🎯 Objectif

Batterie de tests unitaires pour valider les composants critiques RooSync en mode **dry-run** (aucune modification environnement production).

## 📦 Structure

```
tests/roosync/
├── README.md (ce fichier)
├── helpers/ (utilitaires communs)
│   ├── test-logger.ts (logger isolé pour tests)
│   ├── test-git.ts (mocks Git safe)
│   └── test-deployment.ts (mocks PowerShell)
├── fixtures/ (données test réutilisables)
│   ├── logger-config.json (configuration logger test)
│   └── deployment-scripts.json (scripts PS1 test)
├── run-all-tests.ts (runner exécution 4 batteries)
├── test-logger-rotation-dryrun.ts (Test 1: Logger rotation)
├── test-git-helpers-dryrun.ts (Test 2: Git helpers)
├── test-deployment-wrappers-dryrun.ts (Test 3: Deployment wrappers)
└── test-task-scheduler-dryrun.ps1 (Test 4: Task scheduler)
```

## 🧪 Batteries de Tests

### Test 1 : Logger Rotation (test-logger-rotation-dryrun.ts)

**Objectif** : Valider rotation logs (7 jours, 10MB max) sans modifier logs production

**Tests** :
- 1.1 : Rotation par taille (10MB)
- 1.2 : Rotation par date (7 jours)
- 1.3 : Suppression anciens logs (>7 jours)

**Commande** :
```bash
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts
```

**Rapport** : `tests/results/roosync/logger-test-logs/test-report.json`

---

### Test 2 : Git Helpers (test-git-helpers-dryrun.ts)

**Objectif** : Valider `verifyGitAvailable()`, `safePull()`, `safeCheckout()` avec mocks

**Tests** :
- 2.1 : verifyGitAvailable() avec Git présent/absent
- 2.2 : safePull() avec mock (succès/échec + rollback)
- 2.3 : safeCheckout() avec mock (succès/échec + rollback)

**Commande** :
```bash
npx ts-node tests/roosync/test-git-helpers-dryrun.ts
```

**Rapport** : `tests/results/roosync/test2-git-helpers-report.json`

---

### Test 3 : Deployment Wrappers (test-deployment-wrappers-dryrun.ts)

**Objectif** : Valider `deployment-helpers.ts` (timeout, erreurs, dry-run)

**Tests** :
- 3.1 : Timeout - Script PowerShell long (>30s)
- 3.2 : Gestion erreurs - Script échoué (exit code != 0)
- 3.3 : Dry-run mode - deployModes({ dryRun: true })

**Commande** :
```bash
npx ts-node tests/roosync/test-deployment-wrappers-dryrun.ts
```

**Rapport** : `tests/results/roosync/test3-deployment-report.json`

---

### Test 4 : Task Scheduler (test-task-scheduler-dryrun.ps1)

**Objectif** : Valider scheduler Windows (2h interval, cron persistence)

**Tests** :
- 4.1 : Vérifier task scheduler accessible
- 4.2 : Simuler création tâche (dry-run)
- 4.3 : Vérifier triggers cron (2h interval)

**Commande** :
```powershell
pwsh -File tests/roosync/test-task-scheduler-dryrun.ps1
```

**Rapport** : Console output (pas de JSON généré)

---

## 🚀 Exécution Complète

### Runner Automatique (Recommandé)

Exécute les 4 batteries séquentiellement et génère un rapport consolidé :

```bash
npx ts-node tests/roosync/run-all-tests.ts
```

**Options** :
- `--dry-run` : Mode simulation (défaut: activé)
- `--verbose` : Logs détaillés

**Rapport consolidé** : `tests/results/roosync/all-tests-report.json`

### Exécution Manuelle

Pour exécuter les tests individuellement :

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

## 📊 Résultats Attendus

### Statut Idéal

| Test | Résultat | Commentaire |
|------|----------|-------------|
| Test 1.1 | ✅ PASS | Rotation taille OK |
| Test 1.2 | ✅ PASS | Rotation date OK |
| Test 1.3 | ✅ PASS | Nettoyage anciens logs OK |
| Test 2.1 | ✅ PASS | Git disponible |
| Test 2.2 | ✅ PASS | safePull() + rollback OK |
| Test 2.3 | ✅ PASS | safeCheckout() + rollback OK |
| Test 3.1 | ✅ PASS | Timeout détecté |
| Test 3.2 | ✅ PASS | Erreur gérée |
| Test 3.3 | ✅ PASS | Dry-run sans modification |
| Test 4.1 | ✅ PASS | Scheduler accessible |
| Test 4.2 | ✅ PASS | Tâche créée (dry-run) |
| Test 4.3 | ✅ PASS | Triggers cron valides |

**Total** : **14/14 tests PASS** (100% success)

---

## 🛠️ Ajout de Nouveaux Tests

### 1. Utiliser les Helpers Communs

```typescript
import { TestLogger } from './helpers/test-logger';
import { mockVerifyGitAvailable } from './helpers/test-git';
import { createTimeoutTestScript } from './helpers/test-deployment';

const logger = new TestLogger('./tests/results/roosync/my-test.log');
logger.section('Mon Nouveau Test');
```

### 2. Utiliser les Fixtures

```typescript
import loggerConfig from './fixtures/logger-config.json';
import deploymentScripts from './fixtures/deployment-scripts.json';

const logger = new Logger(loggerConfig.testConfig);
```

### 3. Créer un Fichier Test

```typescript
/**
 * TEST X - Description
 * 
 * Objectif : ...
 * 
 * Tests :
 * - X.1 : ...
 * - X.2 : ...
 */

import { TestLogger } from './helpers/test-logger';

const logger = new TestLogger('./tests/results/roosync/testX-output.log');

interface TestResult {
  testName: string;
  success: boolean;
  details: string;
  observations?: string[];
}

const results: TestResult[] = [];

// Implémentation tests...
```

---

## 📚 Best Practices

### ✅ DO

- Utiliser `TestLogger` du helpers/ (pas de duplication)
- Isoler logs dans `tests/results/roosync/`
- Mode **dry-run ONLY** (pas de modifications production)
- Générer rapports JSON pour traçabilité
- Nettoyer environnement test (`cleanupTestEnv()`)

### ❌ DON'T

- Modifier logs production (`RooSync/logs/`)
- Modifier configuration production (`RooSync/config/`)
- Commiter fichiers `tests/results/` (ajoutés au `.gitignore`)
- Créer nouveau logger (utiliser `helpers/test-logger.ts`)
- Exécuter sans dry-run (risque corruption)

---

## 🔍 Debugging

### Logs Détaillés

```bash
# Activer logs verbeux
export DEBUG=true
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts
```

### Rapports JSON

Tous les tests génèrent des rapports JSON dans `tests/results/roosync/` :

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
      "details": "✅ Rotation déclenchée",
      "observations": ["..."]
    }
  ]
}
```

---

## 📦 Dépendances

- Node.js >= 18.x
- TypeScript >= 5.x
- PowerShell >= 7.x (pour Test 4)
- Git >= 2.x (pour Test 2)

---

## 📅 Historique

- **2025-10-24** : Phase 3 - Création tests unitaires dry-run
- **2025-10-24** : Consolidation structure (helpers/, fixtures/, runner)

---

## 🎯 Prochaines Étapes

1. Automatiser exécution tests (CI/CD)
2. Ajouter tests intégration (multi-composants)
3. Tests performance (charge, stress)
4. Coverage analysis (Jest/NYC)

---

## 📞 Support

**Questions** : Voir documentation `docs/roosync/tests-unitaires-guide.md`

**Issues** : Vérifier logs `tests/results/roosync/*.log`

**Rapports** : Consulter `tests/results/roosync/*-report.json`