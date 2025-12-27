# 👨‍💻 Guide Développeur RooSync v2.1

**Version** : 2.1.0
**Date de création** : 2025-12-27
**Statut** : 🟢 Production Ready
**Auteur** : Roo Architect Mode

---

## 📋 Table des Matières

1.  [Architecture Technique](#1-architecture-technique)
2.  [API & Services Core](#2-api--services-core)
3.  [Stratégie de Test (Cycle 5)](#3-stratégie-de-test-cycle-5)
4.  [Logger & Monitoring](#4-logger--monitoring)
5.  [Git Workflow](#5-git-workflow)
6.  [Bonnes Pratiques](#6-bonnes-pratiques)

---

## 1. Architecture Technique

RooSync v2.1 est construit sur une architecture modulaire au sein du serveur MCP `roo-state-manager`.

### 1.1 Stack Technologique
*   **Langage** : TypeScript 5.x
*   **Runtime** : Node.js 18+ (ES Modules)
*   **Tests** : Vitest
*   **Stockage** : JSON / Markdown sur système de fichiers partagé

### 1.2 Structure du Projet
```
roo-state-manager/
├── src/
│   ├── services/           # Logique métier
│   │   ├── BaselineService.ts
│   │   ├── ConfigSharingService.ts
│   │   ├── ConfigNormalizationService.ts
│   │   ├── ConfigDiffService.ts
│   │   └── InventoryService.ts
│   ├── tools/              # Points d'entrée MCP
│   │   └── roosync/        # Outils RooSync
│   └── utils/              # Utilitaires (Logger, Git)
```

---

## 2. API & Services Core

### 2.1 ConfigNormalizationService (Cycle 7)

Ce service est **CRITIQUE** pour assurer la compatibilité multi-OS et la sécurité.

**Fonctionnalités** :
*   Normalisation des séparateurs de chemin (`\` vs `/`).
*   Remplacement des chemins absolus par des placeholders (`{{WORKSPACE_ROOT}}`).
*   Masquage automatique des secrets (`{{SECRET:key}}`).

**Utilisation** :
```typescript
import { ConfigNormalizationService } from '../services/ConfigNormalizationService.js';

const normalizer = new ConfigNormalizationService();

// Normaliser avant export/partage
const normalizedConfig = await normalizer.normalize(rawConfig);

// Dénormaliser avant application locale
const localConfig = await normalizer.denormalize(normalizedConfig);
```

### 2.2 ConfigDiffService

Moteur de comparaison granulaire pour détecter les changements précis.

**Utilisation** :
```typescript
import { ConfigDiffService } from '../services/ConfigDiffService.js';

const diffService = new ConfigDiffService();
const result = diffService.compare(baseline, current);

// result.changes contient { type: 'add'|'modify'|'delete', path: [...], severity: 'info'|'critical' }
```

### 2.3 InventoryService

Remplace les scripts PowerShell pour la collecte d'inventaire. Utilise les API natives Node.js.

**Utilisation** :
```typescript
import { InventoryService } from '../services/roosync/InventoryService.js';

const inventory = await InventoryService.getInstance().getMachineInventory();
```

---

## 3. Stratégie de Test (Cycle 5)

La stabilité des tests est une priorité absolue (P0).

### 3.1 Règles d'Or (Mocking FS)

❌ **INTERDIT** : Ne JAMAIS utiliser `vi.mock('fs')` globalement. Cela cause des instabilités majeures et des interférences avec d'autres modules.

✅ **RECOMMANDÉ** : Utiliser **`memfs`** combiné avec **`unionfs`** pour simuler un système de fichiers en mémoire isolé et fiable.

**Pattern `memfs`** :
```typescript
import { fs as memfs } from 'memfs';
import { ufs } from 'unionfs';
import * as realFs from 'fs';

// Monter un système de fichiers virtuel
ufs.use(realFs).use(memfs);

// Configurer le service pour utiliser ufs (Dependency Injection)
const service = new MyService(ufs);
```

### 3.2 Exécution des Tests

Le standard est **Vitest**. N'utilisez pas `npm test` s'il lance Jest ou une autre suite obsolète.

```bash
# Lancer tous les tests unitaires
npx vitest run

# Lancer un fichier spécifique
npx vitest run tests/unit/services/BaselineService.test.ts
```

---

## 4. Logger & Monitoring

### 4.1 Utilisation du Logger

Utilisez toujours le wrapper `createLogger` pour bénéficier de la double sortie (Console + Fichier) et de la rotation automatique.

```typescript
import { createLogger } from '../utils/logger.js';

export class MyService {
  private logger = createLogger('MyService');

  async doSomething() {
    this.logger.info('Action started', { param: 'value' });

    try {
      // ...
    } catch (error) {
      this.logger.error('Action failed', error);
    }
  }
}
```

### 4.2 Emplacement des Logs
*   **Dev** : Console (stdout)
*   **Prod** : `.shared-state/logs/roosync-YYYYMMDD.log`

---

## 5. Git Workflow

### 5.1 Git Helpers

Pour toute opération Git (commit, pull, push), utilisez impérativement `GitHelpers`. Il gère les erreurs, les rollbacks et la vérification SHA.

```typescript
import { getGitHelpers } from '../utils/git-helpers.js';

const git = getGitHelpers();

// Pull sécurisé avec vérification SHA
const result = await git.safePull(repoPath, 'origin', 'main');

if (!result.success) {
  // Rollback automatique déjà effectué par le helper
  console.error(result.error);
}
```

---

## 6. Bonnes Pratiques

1.  **Baseline-First** : Ne jamais comparer deux machines directement. Toujours comparer Machine vs Baseline.
2.  **Sécurité** : Ne jamais logger de secrets. Utilisez `ConfigNormalizationService` pour les masquer.
3.  **Atomicité** : Les opérations d'écriture (mise à jour baseline) doivent être atomiques.
4.  **Types** : Utilisez toujours les types stricts définis dans `src/types/`.


##### Variables d'Environnement

```bash
# Configuration déploiement RooSync
ROOSYNC_DEPLOYMENT_TIMEOUT=300000  # 5 minutes en millisecondes
ROOSYNC_DEPLOYMENT_RETRIES=3          # Nombre de tentatives
ROOSYNC_DEPLOYMENT_DRY_RUN=true       # Activer dry-run par défaut
ROOSYNC_DEPLOYMENT_MONITORING=true     # Activer monitoring
ROOSYNC_DEPLOYMENT_ROLLBACK=true       # Activer rollback automatique

# Configuration PowerShell
ROOSYNC_POWERSHELL_EXECUTION_POLICY=Bypass
ROOSYNC_POWERSHELL_NO_PROFILE=true
ROOSYNC_POWERSHELL_NO_LOGO=true
```

##### Monitoring des Déploiements

```typescript
export class DeploymentMetrics {
  private static deployments = {
    total: 0,
    successful: 0,
    failed: 0,
    timeouts: 0,
    rollbacks: 0,
    totalDuration: 0
  };

  static recordDeployment(result: DeploymentResult): void {
    this.deployments.total++;
    this.deployments.totalDuration += result.duration;

    if (result.success) {
      this.deployments.successful++;
    } else {
      this.deployments.failed++;

      if (result.timedOut) {
        this.deployments.timeouts++;
      }

      if (result.rollbackPerformed) {
        this.deployments.rollbacks++;
      }
    }
  }

  static getMetrics(): object {
    const successRate = this.deployments.total > 0
      ? (this.deployments.successful / this.deployments.total) * 100
      : 0;

    return {
      deployments: this.deployments,
      successRate: Math.round(successRate * 100) / 100,
      averageDuration: this.deployments.total > 0
        ? Math.round(this.deployments.totalDuration / this.deployments.total)
        : 0,
      timeoutRate: this.deployments.total > 0
        ? Math.round((this.deployments.timeouts / this.deployments.total) * 100) / 100
        : 0
    };
  }
}
```

##### Système d'Alertes

```typescript
export class DeploymentAlertManager {
  private static thresholds = {
    failureRate: 15,        // 15% d'échecs toléré
    consecutiveFailures: 3,   // 3 échecs consécutifs
    timeoutRate: 10,         // 10% de timeouts toléré
    averageDuration: 300000,  // 5 minutes moyenne maximum
    rollbackRate: 5           // 5% de rollbacks toléré
  };

  static checkDeploymentAlerts(metrics: any): void {
    // Taux d'échec élevé
    if (metrics.failureRate > this.thresholds.failureRate) {
      this.sendDeploymentAlert('HIGH_FAILURE_RATE', metrics);
    }

    // Échecs consécutifs
    if (metrics.consecutiveFailures >= this.thresholds.consecutiveFailures) {
      this.sendDeploymentAlert('CONSECUTIVE_FAILURES', metrics);
    }

    // Timeouts fréquents
    if (metrics.timeoutRate > this.thresholds.timeoutRate) {
      this.sendDeploymentAlert('EXCESSIVE_TIMEOUTS', metrics);
    }

    // Performance dégradée
    if (metrics.averageDuration > this.thresholds.averageDuration) {
      this.sendDeploymentAlert('PERFORMANCE_DEGRADATION', metrics);
    }
  }

  private static sendDeploymentAlert(type: string, metrics: any): void {
    const logger = createLogger('DeploymentAlertManager');
    logger.warn(`🚨 DEPLOYMENT ALERT: ${type}`, {
      metrics,
      timestamp: new Date().toISOString(),
      deployment: 'RooSync'
    });
  }
}
```

##### Communication TypeScript→PowerShell

```typescript
export class PowerShellBridge {
  private logger = createLogger('PowerShellBridge');

  async executeScript(scriptPath: string, args: any[]): Promise<any> {
    // Validation des paramètres
    if (!this.validateParams(scriptPath, args)) {
      throw new Error('Invalid parameters for PowerShell execution');
    }

    // Sérialisation sécurisée des arguments
    const serializedArgs = this.serializeArgs(args);

    // Construction commande robuste
    const command = this.buildCommand(scriptPath, serializedArgs);

    this.logger.debug('Executing PowerShell command', {
      command,
      argsCount: args.length
    });

    return this.executeWithTimeout(command, 300000);
  }

  private serializeArgs(args: any[]): string[] {
    return args.map(arg => {
      if (typeof arg === 'string') {
        return `"${arg.replace(/"/g, '\\"')}"`;
      } else if (typeof arg === 'object' && arg !== null) {
        return this.serializeObject(arg);
      } else {
        return String(arg);
      }
    });
  }

  private serializeObject(obj: any): string {
    try {
      return JSON.stringify(obj);
    } catch (error) {
      this.logger.error('Failed to serialize object', error);
      return '{}';
    }
  }
}
```

##### Patterns de Debugging

```typescript
export class DeploymentDebugPatterns {
  static logDeploymentStart(logger: any, script: string, args: string[]): void {
    logger.info(`[DEPLOYMENT] Starting`, {
      script,
      args: args.join(' '),
      timestamp: new Date().toISOString(),
      nodeVersion: process.version,
      platform: process.platform
    });
  }

  static logDeploymentEnd(logger: any, result: any): void {
    logger.info(`[DEPLOYMENT] Completed`, {
      success: result.success,
      duration: result.duration,
      exitCode: result.exitCode,
      timedOut: result.timedOut,
      timestamp: new Date().toISOString()
    });
  }

  static logDeploymentError(logger: any, error: Error, context: string): void {
    logger.error(`[DEPLOYMENT] Error in ${context}`, error, {
      errorType: error.constructor.name,
      errorMessage: error.message,
      timestamp: new Date().toISOString()
    });
  }

  static logPowerShellCommand(logger: any, command: string): void {
    logger.debug(`[POWERSHELL] Executing`, {
      command,
      timestamp: new Date().toISOString()
    });
  }

  static logTimeout(logger: any, timeoutMs: number, actualDuration: number): void {
    logger.warn(`[DEPLOYMENT] Timeout`, {
      configuredTimeout: timeoutMs,
      actualDuration: actualDuration,
      overtime: actualDuration - timeoutMs,
      timestamp: new Date().toISOString()
    });
  }
}
```

##### Intégration Baseline Complete

Les Deployment Wrappers s'intègrent dans le Baseline Complete comme **couche d'orchestration sécurisée** :
- **Exécution Contrôlée** : Timeout et monitoring intégrés
- **Validation Pré/Déploiement** : Mode dry-run pour tests
- **Récupération** : Rollback automatique en cas d'échec
- **Coordination** : Bridge TypeScript→PowerShell pour synchronisation

**Checkpoints de validation** :
- ✅ **Fonctionnalité** : Timeout 5min, dry-run, rollback
- ✅ **Performance** : Bridge TypeScript→PowerShell optimisé
- ✅ **Fiabilité** : Gestion des erreurs PowerShell et timeouts
- ✅ **Maintenabilité** : Configuration flexible et extensible

**Architecture** :

```
Scripts PowerShell (9 scripts deployment/)
           ↓
     PowerShellExecutor (base, 329 lignes)
           ↓
     DeploymentHelpers (wrapper, 223 lignes)
           ↓
     Fonctions typées TypeScript
```

**Avantages** :
- ✅ Types TypeScript pour résultats
- ✅ Logging automatique production
- ✅ Support dry-run mode
- ✅ Timeout configurable
- ✅ Error handling robuste

##### Quick Start

**Import** :

```typescript
import { getDeploymentHelpers, type DeploymentResult } from '../utils/deployment-helpers.js';

const deployer = getDeploymentHelpers();
```

**Exemple Simple** :

```typescript
// Déployer les modes Roo
const result = await deployer.deployModes();

if (result.success) {
  console.log(`✅ Deployment réussi en ${result.duration}ms`);
} else {
  console.error(`❌ Deployment échoué: ${result.error}`);
  console.error(`stderr: ${result.stderr}`);
}
```

##### API Reference

**Interface `DeploymentResult`** :

```typescript
interface DeploymentResult {
  success: boolean;        // Succès du déploiement
  scriptName: string;      // Nom du script exécuté
  duration: number;        // Durée en ms
  exitCode: number;        // Code de sortie PowerShell
  stdout: string;          // Logs stdout
  stderr: string;          // Logs stderr
  error?: string;          // Message d'erreur si échec
}
```

**Interface `DeploymentOptions`** :

```typescript
interface DeploymentOptions {
  timeout?: number;                    // Timeout ms (défaut: 300000 = 5min)
  dryRun?: boolean;                    // Mode simulation (-WhatIf)
  logger?: Logger;                     // Logger personnalisé
  env?: Record<string, string>;        // Variables env supplémentaires
}
```

##### Fonctions Spécifiques

**1. `deployModes()`**

Déploie la configuration des modes Roo.

**Script PowerShell** : `deploy-modes.ps1`

```typescript
const result = await deployer.deployModes({
  timeout: 120000,  // 2 minutes
  dryRun: false
});
```

**2. `deployMCPs()`**

Installe et configure les MCPs.

**Script PowerShell** : `install-mcps.ps1`

```typescript
const result = await deployer.deployMCPs({
  timeout: 300000,  // 5 minutes (défaut)
  logger: customLogger
});
```

**3. `createProfile(profileName)`**

Crée un nouveau profil Roo.

**Script PowerShell** : `create-profile.ps1`

```typescript
const result = await deployer.createProfile('my-custom-profile', {
  dryRun: true  // Tester sans créer
});

if (result.success) {
  console.log(`Profile créé: ${profileName}`);
}
```

**4. `createCleanModes()`**

Nettoie et recrée les modes propres.

**Script PowerShell** : `create-clean-modes.ps1`

```typescript
const result = await deployer.createCleanModes({
  timeout: 60000  // 1 minute
});
```

**5. `forceDeployWithEncodingFix()`**

Déploiement avec correction d'encodage forcée.

**Script PowerShell** : `force-deploy-with-encoding-fix.ps1`

```typescript
const result = await deployer.forceDeployWithEncodingFix({
  timeout: 120000
});
```

**6. `executeDeploymentScript()` (Générique)**

Pour exécuter n'importe quel script deployment.

```typescript
const result = await deployer.executeDeploymentScript(
  'custom-deploy.ps1',
  ['-Param1', 'Value1', '-Param2', 'Value2'],
  {
    timeout: 180000,
    dryRun: false,
    env: { 'CUSTOM_VAR': 'value' }
  }
);
```

##### Patterns d'Utilisation

**Pattern 1 : Dry-Run puis Production**

```typescript
// 1. Tester en dry-run
const dryResult = await deployer.deployModes({ dryRun: true });

if (dryResult.success) {
  console.log('Dry-run passed ✅');
  console.log(dryResult.stdout);

  // 2. Appliquer en production
  const prodResult = await deployer.deployModes({ dryRun: false });

  if (prodResult.success) {
    console.log(`Deployed in ${prodResult.duration}ms`);
  }
}
```

**Pattern 2 : Déploiement avec Retry**

```typescript
async function deployWithRetry(maxRetries = 3): Promise<DeploymentResult> {
  for (let i = 0; i < maxRetries; i++) {
    const result = await deployer.deployModes();

    if (result.success) {
      return result;
    }

    console.warn(`Attempt ${i + 1} failed, retrying...`);
    await new Promise(resolve => setTimeout(resolve, 5000)); // 5s delay
  }

  throw new Error(`Deployment failed after ${maxRetries} attempts`);
}
```

**Pattern 3 : Logger Personnalisé**

```typescript
import { createLogger } from '../utils/logger.js';

const customLogger = createLogger('MyDeployment');

const deployer = getDeploymentHelpers();
const result = await deployer.deployModes({
  logger: customLogger
});

// Logs automatiques via customLogger
```

**Pattern 4 : Variables Environnement**

```typescript
const result = await deployer.executeDeploymentScript(
  'deploy-with-config.ps1',
  [],
  {
    env: {
      'ROO_CONFIG_PATH': 'custom/path/config.json',
      'DEPLOYMENT_MODE': 'staging'
    }
  }
);
```

##### Tests

**Test Unitaire Exemple** :

```typescript
import { getDeploymentHelpers, resetDeploymentHelpers } from '../utils/deployment-helpers.js';

describe('DeploymentHelpers', () => {
  beforeEach(() => {
    resetDeploymentHelpers(); // Reset singleton
  });

  it('should deploy modes successfully', async () => {
    const deployer = getDeploymentHelpers();
    const result = await deployer.deployModes({ dryRun: true });

    expect(result.success).toBe(true);
    expect(result.scriptName).toBe('deploy-modes.ps1');
    expect(result.exitCode).toBe(0);
  });

  it('should handle timeout errors', async () => {
    const deployer = getDeploymentHelpers();
    const result = await deployer.deployModes({ timeout: 1 }); // 1ms

    expect(result.success).toBe(false);
    expect(result.error).toContain('timeout');
  });
});
```

##### Error Handling

**Codes de Sortie PowerShell** :

| Exit Code | Signification |
|-----------|---------------|
| 0 | ✅ Succès |
| 1 | ❌ Erreur générale |
| -1 | ❌ Exception TypeScript (timeout, spawn error) |

**Gestion Erreurs Recommandée** :

```typescript
const result = await deployer.deployModes();

if (!result.success) {
  // Log détaillé
  console.error(`Deployment failed:`);
  console.error(`  Script: ${result.scriptName}`);
  console.error(`  Exit code: ${result.exitCode}`);
  console.error(`  Duration: ${result.duration}ms`);
  console.error(`  Error: ${result.error}`);

  // Stderr analysis
  if (result.stderr.includes('ParameterBindingException')) {
    console.error('Invalid parameters provided');
  } else if (result.stderr.includes('CommandNotFoundException')) {
    console.error('PowerShell cmdlet not found');
  }

  // Decide action
  if (result.exitCode === -1) {
    // Timeout ou spawn error → retry
  } else {
    // Erreur PowerShell → check logs
  }
}
```

##### Métriques & Monitoring

**Logging Production** :

Le `DeploymentHelpers` utilise le Logger production qui output à la fois :
- Console (stdout/stderr)
- Fichiers logs (si configuré)

```typescript
// Logs automatiques générés :
[DeploymentHelpers] Deployment helpers initialized { scriptsBasePath: ... }
[DeploymentHelpers] Executing deployment script { scriptName, args, timeout, dryRun }
[DeploymentHelpers] Deployment script succeeded { success, scriptName, duration, exitCode }
```

**Tracking Durée** :

```typescript
const results: DeploymentResult[] = [];

for (const script of ['deployModes', 'deployMCPs']) {
  const result = await deployer[script]();
  results.push(result);
}

// Analyse performance
const avgDuration = results.reduce((acc, r) => acc + r.duration, 0) / results.length;
console.log(`Average deployment time: ${avgDuration}ms`);
```

##### Références

**Code Source** :
- [`deployment-helpers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/deployment-helpers.ts) - Implementation
- [`PowerShellExecutor.ts`](../../mcps/internal/servers/roo-state-manager/src/services/PowerShellExecutor.ts) - Base executor

**Scripts PowerShell** :
- [`scripts/deployment/`](../../scripts/deployment/) - Scripts deployment disponibles

**Documentation Associée** :
- [`scripts-migration-status-20251023.md`](scripts-migration-status-20251023.md) - État scripts
- [`git-requirements.md`](git-requirements.md) - Git helpers (intégration similaire)

##### Best Practices

**✅ À FAIRE** :

1. **Toujours tester en dry-run d'abord**
   ```typescript
   const dry = await deployer.deployModes({ dryRun: true });
   if (dry.success) {
     await deployer.deployModes({ dryRun: false });
   }
   ```

2. **Configurer timeout approprié**
   ```typescript
   // Script rapide (< 1min)
   await deployer.createCleanModes({ timeout: 60000 });

   // Script long (> 5min)
   await deployer.deployMCPs({ timeout: 600000 });
   ```

3. **Logger les résultats**
   ```typescript
   const result = await deployer.deployModes();
   logger.info('Deployment result', result);
   ```

4. **Gérer les erreurs explicitement**
   ```typescript
   if (!result.success) {
     // Action spécifique selon error
   }
   ```

**❌ À ÉVITER** :

1. **Ne PAS ignorer les erreurs**
   ```typescript
   // ❌ BAD
   await deployer.deployModes(); // Pas de check result

   // ✅ GOOD
   const result = await deployer.deployModes();
   if (!result.success) {
     throw new Error(result.error);
   }
   ```

2. **Ne PAS utiliser timeout trop court**
   ```typescript
   // ❌ BAD
   await deployer.deployMCPs({ timeout: 1000 }); // 1s trop court

   // ✅ GOOD
   await deployer.deployMCPs({ timeout: 300000 }); // 5min
   ```

3. **Ne PAS créer plusieurs instances**
   ```typescript
   // ❌ BAD
   const d1 = new DeploymentHelpers();
   const d2 = new DeploymentHelpers();

   // ✅ GOOD (singleton)
   const deployer = getDeploymentHelpers();
   ```

##### Exemples Avancés

**Déploiement Orchestré** :

```typescript
async function fullDeployment(): Promise<void> {
  const deployer = getDeploymentHelpers();
  const logger = createLogger('FullDeployment');

  // 1. Clean modes
  logger.info('Step 1: Cleaning modes...');
  const clean = await deployer.createCleanModes();
  if (!clean.success) throw new Error('Clean failed');

  // 2. Deploy modes
  logger.info('Step 2: Deploying modes...');
  const modes = await deployer.deployModes();
  if (!modes.success) throw new Error('Modes deployment failed');

  // 3. Deploy MCPs
  logger.info('Step 3: Deploying MCPs...');
  const mcps = await deployer.deployMCPs();
  if (!mcps.success) throw new Error('MCPs deployment failed');

  logger.info('Full deployment completed!', {
    totalDuration: clean.duration + modes.duration + mcps.duration
  });
}
```

### 2.3 Scripts PowerShell

### 2.4 Développement d'Outils MCP

### 2.5 Nouveaux Services Core (Cycle 7)

**InventoryService** :
Remplace les scripts PowerShell d'inventaire. Collecte MCPs, modes et infos système avec typage fort.

**ConfigDiffService** :
Moteur de diff granulaire capable de comparer des configurations JSON clé par clé, détectant ajouts, modifications et suppressions avec précision.

**ConfigNormalizationService** :
Assure la standardisation des configurations avant comparaison (chemins, secrets, tri des clés).

---

## 3. Logger

### 3.1 Architecture du Logger

Le Logger RooSync v2 fournit un système de logging robuste avec double sortie (console + fichier), rotation automatique, et monitoring intégré.

**Emplacement** : [`mcps/internal/servers/roo-state-manager/src/utils/logger.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/logger.ts:1)

**Features principales** :
- ✅ **Double output** : Console (développement) + Fichier (production)
- ✅ **Rotation automatique** : 10MB max par fichier, 7 jours rétention
- ✅ **Timestamps ISO 8601** : Format standardisé
- ✅ **Source tracking** : Identification du composant émetteur
- ✅ **Metadata structurées** : Contexte enrichi pour debugging

#### Flux de Données

```
Application/Service
       ↓
   Logger.createLogger(source, options)
       ↓
   Log Entry (timestamp, level, source, message, metadata)
       ↓
   ┌─────────────┴─────────────┐
   │                           │
Console Output          File Output
(DEV/DEBUG)            (PRODUCTION)
   │                           │
   ↓                           ↓
Terminal/Task Scheduler    Rotated Files
```

#### Points d'Intégration

**Pattern d'intégration standard** :

```typescript
import { createLogger } from '../utils/logger';

export class InventoryCollector {
  private logger = createLogger('InventoryCollector');

  async collect(): Promise<void> {
    this.logger.info('🔍 Starting inventory collection', {
      machineId: process.env.ROOSYNC_MACHINE_ID
    });

    try {
      // ... logique métier
      this.logger.info('✅ Inventory collected successfully');
    } catch (error) {
      this.logger.error('❌ Inventory collection failed', error, {
        context: 'inventory-collection'
      });
    }
  }
}
```

**Intégration RooSync Baseline Complete** :

Le Logger s'intègre dans le Baseline Complete comme composant critique de monitoring :
- **Visibilité** : Logs visibles dans Windows Task Scheduler
- **Traçabilité** : Historique complet des opérations
- **Diagnostic** : Support au dépannage avancé
- **Coordination** : Logs partagés entre agents pour synchronisation

### 3.2 Configuration

#### Configuration par Défaut

```typescript
{
  logDir: process.env.ROOSYNC_SHARED_PATH
    ? join(process.env.ROOSYNC_SHARED_PATH, 'logs')
    : join(process.cwd(), '.shared-state', 'logs'),
  filePrefix: 'roosync',
  maxFileSize: 10 * 1024 * 1024, // 10MB
  retentionDays: 7,
  source: 'RooSync',
  minLevel: 'INFO'
}
```

#### Variables d'Environnement

```bash
# Chemin de stockage des logs
ROOSYNC_SHARED_PATH=G:/Mon Drive/Synchronisation/RooSync/.shared-state

# Niveau de logging minimal
ROOSYNC_LOG_LEVEL=info  # debug, info, warn, error

# Source des logs
ROOSYNC_LOG_SOURCE=RooSync-Production
```

#### Fichiers de Configuration

**Production Config** :

```json
{
  "logDir": "./RooSync/logs",
  "filePrefix": "roosync",
  "maxFileSize": 10485760,
  "retentionDays": 7,
  "source": "RooSync-Production"
}
```

**Test Config** :

```json
{
  "logDir": "./tests/results/roosync/logger-test-logs",
  "filePrefix": "test-roosync",
  "maxFileSize": 102400,
  "retentionDays": 7,
  "source": "RooSync-Test"
}
```

#### Personnalisation Avancée

```typescript
// Logger personnalisé pour service critique
const criticalLogger = createLogger('CriticalService', {
  filePrefix: 'critical-service',
  minLevel: 'DEBUG',           // Tout logger en développement
  retentionDays: 30,            // Garder 1 mois
  maxFileSize: 50 * 1024 * 1024 // 50MB pour services critiques
});

// Logger minimal pour background tasks
const backgroundLogger = createLogger('BackgroundTask', {
  filePrefix: 'background',
  minLevel: 'WARN',           // Seulement warnings et erreurs
  retentionDays: 3,             // Garder 3 jours seulement
  maxFileSize: 5 * 1024 * 1024  // 5MB maximum
});
```

### 3.3 Utilisation dans le Code

#### Migration Pattern

Remplacer `console.error` par `logger.error` :

```typescript
// AVANT
console.error('[Service] Operation failed');

// APRÈS
import { createLogger } from '../utils/logger';
const logger = createLogger('ServiceName');

logger.error('Operation failed', error, {
  context: 'operation-context',
  additionalData: 'useful-info'
});
```

#### Template Service Integration

```typescript
import { createLogger, LogMetrics } from '../utils/logger';

export class TemplateService {
  private logger = createLogger('TemplateService');
  private metrics = new LogMetrics();

  constructor() {
    this.logger.info('🚀 TemplateService initialized', {
      version: '1.0.0',
      environment: process.env.NODE_ENV || 'production'
    });
  }

  async executeOperation(operation: string): Promise<any> {
    const startTime = Date.now();

    try {
      this.logger.debug(`[${operation}] Starting`, {
        operation,
        timestamp: new Date().toISOString()
      });

      // Logique métier ici
      const result = await this.performOperation(operation);

      const duration = Date.now() - startTime;
      this.logger.info(`[${operation}] Completed successfully`, {
        operation,
        duration: `${duration}ms`,
        result: typeof result
      });

      this.metrics.recordSuccess(operation, duration);
      return result;

    } catch (error) {
      const duration = Date.now() - startTime;
      this.logger.error(`[${operation}] Failed`, error, {
        operation,
        duration: `${duration}ms`,
        errorType: error.constructor.name
      });

      this.metrics.recordFailure(operation, error);
      throw error;
    }
  }

  private async performOperation(operation: string): Promise<any> {
    // Implémentation spécifique au service
    return { success: true, data: `Result for ${operation}` };
  }

  getMetrics(): object {
    return this.metrics.getSummary();
  }
}
```

### 3.4 Rotation des Logs

#### Mécanisme de Rotation

Le Logger implémente une rotation automatique basée sur :
- **Taille** : 10MB maximum par fichier
- **Âge** : 7 jours de rétention
- **Format** : `roosync-YYYYMMDD.log`

#### Tests de Rotation

**Test 1 : Rotation par Taille**

```bash
# Script de test
cat > test-rotation.js << 'EOF'
const { createLogger } = require('./src/utils/logger');
const logger = createLogger('RotationTest', {
  maxFileSize: 1024,  // 1KB pour test rapide
  retentionDays: 1
});

// Écrire 2KB pour déclencher rotation
for(let i = 0; i < 100; i++) {
  logger.info('Test rotation message ' + i + ' with padding to reach size limit quickly');
}
EOF

node test-rotation.js
ls -la logs/  # Devrait montrer 2 fichiers
```

**Test 2 : Rotation par Âge**

```bash
# Créer vieux logs pour test nettoyage
touch -d "7 days ago" logs/roosync-old.log
touch -d "8 days ago" logs/roosync-very-old.log

# Déclencher cleanup (automatique au démarrage)
node -e "const { createLogger } = require('./src/utils/logger'); createLogger('CleanupTest');"
```

**Test 3 : Double Output**

```bash
# Test console + fichier
node -e "
const { createLogger } = require('./src/utils/logger');
const logger = createLogger('OutputTest');

logger.debug('Debug message - console only');
logger.info('Info message - console + file');
logger.error('Error message - console + file');
"

# Vérifier console et fichier
tail logs/roosync-$(date +%Y%m%d).log
```

### 3.5 Monitoring et Dépannage

#### Métriques Clés

**Métriques de Volume** :

```bash
# Surveillance taille logs
du -sh logs/ | tail -1

# Comptage fichiers logs
find logs/ -name "*.log" | wc -l

# Taux de rotation
grep -c "Rotated log file" logs/roosync-*.log
```

**Métriques de Performance** :

```typescript
// Monitoring intégré dans les services
export class LogMetrics {
  private static rotationCount = 0;
  private static errorCount = 0;
  private static warningCount = 0;

  static incrementRotation(): void {
    this.rotationCount++;
    this.logMetric('log_rotation', { count: this.rotationCount });
  }

  static incrementError(): void {
    this.errorCount++;
    this.logMetric('log_error', { count: this.errorCount });
  }

  static getMetrics(): object {
    return {
      rotations: this.rotationCount,
      errors: this.errorCount,
      warnings: this.warningCount,
      uptime: process.uptime()
    };
  }
}
```

**Métriques de Qualité** :

```bash
# Analyse des erreurs par heure
grep "ERROR" logs/roosync-*.log | \
  awk '{print $1 " " $2}' | \
  cut -d'T' -f1 | \
  sort | uniq -c

# Détection de patterns d'erreurs
grep -E "(CRITICAL|FATAL)" logs/roosync-*.log | \
  tail -10

# Analyse des sources d'erreurs
grep "ERROR" logs/roosync-*.log | \
  awk -F'\\[' '{print $2}' | \
  sort | uniq -c | sort -nr
```

#### Alertes et Seuils

**Configuration Alertes** :

```typescript
// Système d'alertes intégré
export class LogAlertManager {
  private static thresholds = {
    errorRate: 10,        // 10 erreurs/heure
    rotationFrequency: 5,  // 5 rotations/jour
    diskUsage: 80,        // 80% espace disque
    logSize: 100          // 100MB total logs
  };

  static checkAlerts(metrics: any): void {
    if (metrics.errors > this.thresholds.errorRate) {
      this.sendAlert('HIGH_ERROR_RATE', metrics);
    }

    if (metrics.rotations > this.thresholds.rotationFrequency) {
      this.sendAlert('EXCESSIVE_ROTATIONS', metrics);
    }
  }

  private static sendAlert(type: string, metrics: any): void {
    const logger = createLogger('AlertManager');
    logger.warn(`🚨 ALERT: ${type}`, { metrics, timestamp: new Date() });

    // Envoyer notification système/Email/Slack
    // Implementation selon infrastructure
  }
}
```

#### Patterns de Debugging

```typescript
// Patterns pour debugging avancé
export class DebugPatterns {
  static logWithContext(logger: any, operation: string, data: any): void {
    logger.debug(`[${operation}] Starting`, {
      operation,
      timestamp: new Date().toISOString(),
      data: JSON.stringify(data, null, 2)
    });
  }

  static logPerformance(logger: any, operation: string, duration: number): void {
    logger.info(`[PERF] ${operation}`, {
      operation,
      duration: `${duration}ms`,
      performance: duration > 1000 ? 'SLOW' : 'OK'
    });
  }

  static logStateTransition(logger: any, from: string, to: string, reason: string): void {
    logger.info(`[STATE] ${from} → ${to}`, {
      transition: `${from}→${to}`,
      reason,
      timestamp: new Date().toISOString()
    });
  }
}
```

#### Procédures de Backup

**Backup Automatique** :

```typescript
// Backup intégré au logger
export class LogBackupManager {
  static async createBackup(logDir: string): Promise<void> {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const backupDir = `${logDir}/backups/${timestamp}`;

    await fs.mkdir(backupDir, { recursive: true });

    // Copier tous les logs actuels
    const logFiles = await fs.readdir(logDir);
    for (const file of logFiles) {
      if (file.endsWith('.log')) {
        await fs.copyFile(
          `${logDir}/${file}`,
          `${backupDir}/${file}`
        );
      }
    }

    const logger = createLogger('BackupManager');
    logger.info(`✅ Log backup created: ${backupDir}`);
  }
}
```

**Backup Externe** :

```bash
# Script de backup externe (cloud/network)
#!/bin/bash
LOG_DIR="${ROOSYNC_SHARED_PATH}/logs"
BACKUP_DIR="/backup/location/roosync-logs"

rsync -av --delete "$LOG_DIR/" "$BACKUP_DIR/"

echo "Log backup completed to $BACKUP_DIR"
```

#### Mises à Jour

**Mise à Jour Logger** :

```bash
# Processus de mise à jour contrôlée
cd mcps/internal/servers/roo-state-manager

# Backup version actuelle
cp src/utils/logger.ts src/utils/logger.ts.backup

# Appliquer mise à jour
git pull origin main
npm run build

# Tester nouvelle version
npm run test:logger

# Si tests OK :
rm src/utils/logger.ts.backup
echo "Logger update completed successfully"

# Si tests KO :
cp src/utils/logger.ts.backup src/utils/logger.ts
echo "Logger update rolled back due to test failures"
```

**Mise à Jour Configuration** :

```bash
# Recharger configuration sans redémarrage
node -e "
const { createLogger } = require('./src/utils/logger');
process.env.ROOSYNC_LOG_LEVEL = 'debug';
const logger = createLogger('ConfigReload');

logger.info('Configuration reloaded', {
  newLevel: process.env.ROOSYNC_LOG_LEVEL,
  timestamp: new Date()
});
"
```

#### Références

**Documentation Technique** :

- **Logger Source** : [`mcps/internal/servers/roo-state-manager/src/utils/logger.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/logger.ts:1) (292 lignes)
- **Usage Guide** : [`docs/roosync/logger-usage-guide.md`](logger-usage-guide.md:1) (361 lignes)
- **Test Results** : [`tests/results/roosync/test1-logger-report.md`](test1-logger-report.md:1) (complet)
- **Phase 3 Tests** : [`docs/roosync/phase3-bugfixes-tests-20251024.md`](phase3-bugfixes-tests-20251024.md:1)

**Architecture Documentation** :

- **Baseline Implementation Plan** : [`docs/roosync/baseline-implementation-plan.md`](baseline-implementation-plan.md:1)
- **System Overview** : [`RooSync/docs/SYSTEM-OVERVIEW.md`](../../RooSync/docs/SYSTEM-OVERVIEW.md:1) (1417 lignes)
- **Convergence Analysis** : [`docs/roosync/convergence-v1-v2-analysis-20251022.md`](convergence-v1-v2-analysis-20251022.md:1)

**Scripts et Outils** :

- **Rotation Test** : [`tests/roosync/test-logger-rotation-dryrun.ts`](../../tests/roosync/test-logger-rotation-dryrun.ts:1)
- **Logger Config** : [`tests/roosync/fixtures/logger-config.json`](../../tests/roosync/fixtures/logger-config.json:1)
- **Test Logs** : [`tests/results/roosync/logger-test-logs/`](../../tests/results/roosync/logger-test-logs/)

### 3.6 Quick Start

#### 1. Importer le Logger

```typescript
import { createLogger, Logger } from '../utils/logger.js';
```

#### 2. Créer une Instance (Pattern Recommandé)

```typescript
export class MyService {
  private logger: Logger;

  constructor() {
    this.logger = createLogger('MyService');
    this.logger.info('Service initialized');
  }
}
```

#### 3. Utiliser les Logs

```typescript
// Logs simples
this.logger.info('Operation started');
this.logger.warn('Deprecated method used');

// Logs avec metadata
this.logger.info('Cache hit', { machineId: 'myia-ai-01', age: 3600 });

// Logs d'erreur avec stack trace
try {
  // ... code risqué
} catch (error) {
  this.logger.error('Operation failed', error, { context: 'additional info' });
}
```

### 3.7 Format de Log

#### Console Output

```
[2025-10-22T21:00:00.000Z] [INFO] [InventoryCollector] Cache hit found | {"machineId":"myia-ai-01","age":3600}
```

#### Fichier Output

**Chemin** : `.shared-state/logs/roosync-YYYYMMDD.log`
**Format identique à console**

### 3.8 Fichiers Déjà Refactorés

#### Services (2/3 complétés)

✅ **InventoryCollector.ts** (19 occurrences)
```typescript
// Avant
console.error('[InventoryCollector] Collecting...');

// Après
this.logger.info('🔍 Collecting inventory...', { machineId });
```

✅ **DiffDetector.ts** (1 occurrence)
```typescript
// Avant
console.error('Erreur lors de la comparaison:', error);

// Après
this.logger.error('Erreur lors de la comparaison baseline/machine', error);
```

#### Tools (0/18 complétés - À FAIRE)

❌ **init.ts** (28 occurrences) - PRIORITAIRE
❌ **send_message.ts** (4 occurrences)
❌ **reply_message.ts** (6 occurrences)
❌ **read_inbox.ts** (4 occurrences)
❌ **mark_message_read.ts** (5 occurrences)
❌ **get_message.ts** (5 occurrences)
❌ **archive_message.ts** (5 occurrences)
❌ **amend_message.ts** (4 occurrences)
❌ Autres tools (~10 fichiers restants)

### 3.9 Stratégie de Migration

#### Étape 1 : Ajouter Logger au Constructeur

```typescript
// Ajouter import
import { createLogger, Logger } from '../../utils/logger.js';

// Ajouter propriété
private logger: Logger;

// Initialiser dans constructeur
constructor() {
  this.logger = createLogger('MonOutil');
}
```

#### Étape 2 : Remplacer console.* par logger.*

| Avant | Après | Niveau |
|-------|-------|--------|
| `console.error('[TAG] ❌ Error')` | `this.logger.error('❌ Error', error)` | ERROR |
| `console.warn('[TAG] ⚠️ Warning')` | `this.logger.warn('⚠️ Warning')` | WARN |
| `console.error('[TAG] ℹ️ Info')` | `this.logger.info('ℹ️ Info')` | INFO |
| `console.error('[TAG] 🔍 Debug')` | `this.logger.debug('🔍 Debug')` | DEBUG |

#### Étape 3 : Utiliser Metadata pour Contexte

```typescript
// Avant
console.error(`[Tool] Processing for machine ${machineId} with ${itemCount} items`);

// Après
this.logger.info('Processing items', { machineId, itemCount });
```

#### Étape 4 : Gérer les Erreurs Proprement

```typescript
// Avant
catch (error) {
  console.error('[Tool] Error:', error instanceof Error ? error.message : String(error));
  if (error instanceof Error && error.stack) {
    console.error('[Tool] Stack:', error.stack);
  }
}

// Après
catch (error) {
  this.logger.error('Operation failed', error); // Stack trace automatique
}
```

### 3.10 Tests et Validation

#### Test 1 : Vérifier Logs Console (Dev)

```bash
# Lancer l'outil MCP
# Observer console : logs doivent apparaître avec timestamps
```

#### Test 2 : Vérifier Logs Fichier (Production)

```bash
# Vérifier création du fichier
ls -la .shared-state/logs/

# Lire dernières lignes
tail -f .shared-state/logs/roosync-20251022.log
```

#### Test 3 : Vérifier Rotation

```bash
# Simuler log massif pour dépasser 10MB
# Vérifier création de roosync-YYYYMMDD-1.log
```

#### Test 4 : Task Scheduler Windows (CRITIQUE)

```powershell
# Créer tâche planifiée test
$action = New-ScheduledTaskAction -Execute "node" -Argument "path/to/mcp/index.js"
Register-ScheduledTask -TaskName "RooSync-Logger-Test" -Action $action

# Exécuter
Start-ScheduledTask -TaskName "RooSync-Logger-Test"

# Vérifier logs dans fichier (console non visible dans scheduler)
Get-Content .shared-state\logs\roosync-*.log -Tail 20
```

### 3.11 Métriques de Convergence

#### Avant Logger (v2.0)

- ❌ **0%** visibilité Task Scheduler Windows
- ❌ Pas de logs persistants
- ❌ Debugging production impossible

#### Après Logger (v2.1)

- ✅ **100%** visibilité Task Scheduler via fichiers
- ✅ Logs persistants avec rotation
- ✅ Debugging production facile
- ✅ **+20%** score convergence v1→v2 (67% → 87%)

### 3.12 Best Practices Logger

#### ✅ À FAIRE

- Utiliser niveaux appropriés (DEBUG pour détails, INFO pour opérations, ERROR pour problèmes)
- Inclure metadata structurée plutôt que concaténation de strings
- Créer une instance par classe/service
- Logguer AVANT et APRÈS opérations critiques
- Utiliser émojis pour visibilité rapide (🔍 📦 ✅ ❌ ⚠️)

#### ❌ À ÉVITER

- Ne pas logguer de données sensibles (tokens, mots de passe)
- Ne pas logguer dans des boucles serrées (préférer agrégation)
- Ne pas mélanger console.* et logger.* dans le même fichier
- Ne pas utiliser ERROR pour des warnings (dégrade signal/bruit)
- Ne pas oublier de supprimer les anciens console.* après migration

### 3.13 Prochaines Étapes (TODO pour Agents Futurs)

#### Phase 2.4 : Refactorer tools/roosync/ (45 occurrences restantes)

**Priorité** : HAUTE
**Effort** : 2-3 heures
**Impact** : Visibilité complète Task Scheduler pour tous les outils

**Fichiers à traiter** (par ordre de priorité) :

1. ✅ **URGENT** : init.ts (28 occurrences) - Initialisation RooSync
2. ⚠️ **IMPORTANT** : send_message.ts (4), reply_message.ts (6), read_inbox.ts (4) - Messagerie
3. ℹ️ **NORMAL** : Autres tools restants (~15 occurrences)

**Estimation** :
- init.ts seul : 45 minutes
- Tools messagerie : 30 minutes
- Tests validation : 30 minutes
- **TOTAL** : ~2h

#### Validation Finale

Après migration complète :
- [ ] Build TypeScript sans erreurs
- [ ] Tests unitaires passent
- [ ] Logs visibles dans Task Scheduler
- [ ] Rotation fonctionne après 10MB
- [ ] Cleanup automatique après 7 jours

---

## 4. Tests

### 4.1 Architecture des Tests

#### Vue d'Ensemble

Guide de référence pour l'utilisation, l'ajout et la maintenance des tests unitaires RooSync en mode **dry-run**.

#### Structure Consolidée

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

### 4.2 Batteries de Tests

#### Test 1 : Logger Rotation

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

#### Test 2 : Git Helpers

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

#### Test 3 : Deployment Wrappers

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

#### Test 4 : Task Scheduler

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

### 4.3 Exécution des Tests

#### Runner Automatique (Recommandé)

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

#### Exécution Manuelle

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

### 4.4 Rapports de Tests

#### Format JSON Standard

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

#### Rapport Consolidé

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

### 4.5 Ajout de Nouveaux Tests

#### Étape 1 : Utiliser les Helpers

Importer les utilitaires communs :

```typescript
import { TestLogger, TestResult, generateTestReport } from './helpers/test-logger';
import { mockVerifyGitAvailable, mockSafePull } from './helpers/test-git';
import { createTimeoutTestScript } from './helpers/test-deployment';

const logger = new TestLogger('./tests/results/roosync/my-test.log');
```

#### Étape 2 : Utiliser les Fixtures

Charger configurations réutilisables :

```typescript
import loggerConfig from './fixtures/logger-config.json';
import deploymentScripts from './fixtures/deployment-scripts.json';

const logger = new Logger(loggerConfig.testConfig);
const scriptsDir = deploymentScripts.testScriptsDir;
```

#### Étape 3 : Créer Fichier Test

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

#### Étape 4 : Ajouter au Runner

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

### 4.6 Best Practices de Tests

#### ✅ À FAIRE

1. **Utiliser helpers/** : Pas de duplication code logger/mocks
2. **Isoler logs** : `tests/results/roosync/` uniquement
3. **Mode dry-run** : Aucune modification production
4. **Rapports JSON** : Traçabilité complète
5. **Nettoyage** : `cleanupTestEnv()` avant/après tests
6. **Commentaires JSDoc** : Documentation inline
7. **Assertions claires** : Messages d'erreur explicites

#### ❌ À ÉVITER

1. Modifier logs production (`RooSync/logs/`)
2. Modifier configuration production (`RooSync/config/`)
3. Commiter fichiers `tests/results/` (ajoutés au `.gitignore`)
4. Créer nouveau logger (utiliser `helpers/test-logger.ts`)
5. Exécuter sans dry-run (risque corruption)
6. Supprimer fixtures (données réutilisables)
7. Tests interdépendants (isolation obligatoire)

### 4.7 Debugging

#### Logs Détaillés

Activer logs verbeux :

```bash
export DEBUG=true
npx ts-node tests/roosync/test-logger-rotation-dryrun.ts
```

#### Rapports JSON

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

#### Logs Fichiers

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

### 4.8 Maintenance

#### Nettoyage Logs Test

Nettoyer logs test anciens :

```bash
# Supprimer logs >7 jours
find tests/results/roosync/ -name "*.log" -mtime +7 -delete

# Nettoyer tous logs test (réinitialisation)
rm -rf tests/results/roosync/*.log
rm -rf tests/results/roosync/logger-test-logs/*.log
```

#### Mise à Jour Helpers

Modifier helpers communs :

1. Éditer `helpers/test-logger.ts`, `helpers/test-git.ts`, etc.
2. Vérifier compatibilité avec tests existants
3. Exécuter `run-all-tests.ts` pour validation
4. Commiter si 14/14 tests PASS

#### Ajout Fixtures

Ajouter configurations réutilisables :

1. Créer `fixtures/nouvelle-config.json`
2. Importer dans tests : `import config from './fixtures/nouvelle-config.json'`
3. Documenter dans `README.md`

### 4.9 Dépendances

- **Node.js** >= 18.x
- **TypeScript** >= 5.x
- **PowerShell** >= 7.x (pour Test 4)
- **Git** >= 2.x (pour Test 2)

Installation :

```bash
npm install --save-dev typescript ts-node @types/node
```

### 4.10 Objectifs de Qualité

#### Cibles

- **Couverture tests** : 100% composants critiques
- **Taux succès** : 14/14 tests PASS (100%)
- **Temps exécution** : <2 minutes (4 batteries)
- **Isolation** : 0 modification production

#### Métriques

Consulter rapport consolidé :

```bash
npx ts-node tests/roosync/run-all-tests.ts
# Affiche :
# - Batteries : 4/4 PASS (100%)
# - Tests individuels : 14/14 PASS (100%)
# - Durée totale : ~120s
```

### 4.11 Support

**Questions** : Consulter `tests/roosync/README.md`

**Issues** : Vérifier logs `tests/results/roosync/*.log`

**Rapports** : Consulter `tests/results/roosync/*-report.json`

### 4.12 Historique

- **2025-10-24** : Phase 3 - Création tests unitaires dry-run
- **2025-10-24** : Consolidation structure (helpers/, fixtures/, runner)
- **2025-10-24** : Documentation guide tests unitaires

### 4.13 Prochaines Étapes

1. **CI/CD** : Intégrer tests dans pipeline GitHub Actions
2. **Coverage** : Ajouter analyse couverture code (Jest/NYC)
3. **Performance** : Ajouter tests charge/stress
4. **Intégration** : Tests multi-composants (logger + Git + deployment)
5. **E2E** : Tests bout-en-bout RooSync complet

### 4.14 Références

- [README Tests](../../tests/roosync/README.md)
- [Helper Logger](../../tests/roosync/helpers/test-logger.ts)
- [Helper Git](../../tests/roosync/helpers/test-git.ts)
- [Helper Deployment](../../tests/roosync/helpers/test-deployment.ts)
- [Fixtures Logger](../../tests/roosync/fixtures/logger-config.json)
- [Fixtures Deployment](../../tests/roosync/fixtures/deployment-scripts.json)

### 4.15 Bonnes Pratiques de Test (Cycle 5)

**Mocking du Système de Fichiers** :
Pour éviter les instabilités et les interférences globales, l'utilisation de `vi.mock('fs')` est **déconseillée** pour les nouveaux tests.

**Recommandation** :
- Utiliser la librairie **`memfs`** avec `unionfs` pour simuler un système de fichiers en mémoire isolé.
- Ou adopter l'**injection de dépendances** pour passer une instance de service de fichiers (abstraction `FileSystemService`).

**Exemple avec memfs** :
```typescript
import { fs as memfs } from 'memfs';
import { ufs } from 'unionfs';
import * as realFs from 'fs';

// Monter un système de fichiers virtuel
ufs.use(realFs).use(memfs);

// Utiliser ufs dans les tests
```

---

## 5. Git Workflow

### 5.1 Git Helpers

Les Git Helpers fournissent une couche de sécurité critique pour les opérations Git dans RooSync v2.1.

**Emplacement** : [`mcps/internal/servers/roo-state-manager/src/utils/git-helpers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/git-helpers.ts:1)

**Features principales** :
- ✅ **Vérification Git** : Détection automatique de disponibilité et version
- ✅ **Protection SHA** : Vérification avant/après chaque opération
- ✅ **Rollback Automatique** : Restauration en cas d'échec ou corruption
- ✅ **Cache Intelligent** : Optimisation des performances avec invalidation
- ✅ **Logging Structuré** : Traçabilité complète des opérations

**Flux de Données** :

```
Service RooSync
       ↓
   GitHelpers.getGitHelpers()
       ↓
   Vérification État Git
       ↓
   ┌─────────────┴─────────────┐
   │                           │
Opération Sécurisée      Validation SHA
   │                           │
   ↓                           ↓
Exécution Git              Vérification Post-Opération
   │                           │
   ↓                           ↓
Succès ✅                    Rollback si Échec ❌
```

**Configuration par Défaut** :

```typescript
const defaultGitConfig = {
  timeoutMs: 120000,        // 2 minutes timeout
  retryAttempts: 3,          // 3 tentatives maximum
  retryDelayMs: 5000,       // 5 secondes entre tentatives
  enableCache: true,         // Cache activé par défaut
  cacheValidityMs: 300000,  // 5 minutes validité cache
  verifySHA: true,           // Vérification SHA activée
  autoRollback: true         // Rollback automatique activé
};
```

**Variables d'Environnement** :

```bash
# Configuration Git RooSync
GIT_AUTHOR_NAME="RooSync Automation"
GIT_AUTHOR_EMAIL="roosync@automation.local"
GIT_SSH_COMMAND="ssh -i ~/.ssh/roosync_key"
GIT_TERMINAL_PROMPT=0  # Désactiver prompts interactifs

# Timeout et retry
ROOSYNC_GIT_TIMEOUT=120000
ROOSYNC_GIT_RETRY_ATTEMPTS=3
ROOSYNC_GIT_CACHE_VALIDITY=300000
```

### 5.2 Opérations Sécurisées

#### Pattern d'Intégration Standard

```typescript
import { getGitHelpers } from '../utils/git-helpers';
import { createLogger } from '../utils/logger';

export class RooSyncService {
  private gitHelpers = getGitHelpers();
  private logger = createLogger('RooSyncService');

  constructor() {
    this.initGit();
  }

  private async initGit(): Promise<void> {
    const gitCheck = await this.gitHelpers.verifyGitAvailable();
    if (!gitCheck.available) {
      this.logger.error('Git NON disponible - fonctionnalités limitées');
      throw new Error('Git required for RooSync operations');
    }

    this.logger.info('Git disponible', {
      version: gitCheck.version,
      path: gitCheck.path
    });
  }

  async syncWithRemote(repoPath: string): Promise<boolean> {
    // Vérifier HEAD avant opération
    const headValid = await this.gitHelpers.verifyHeadValid(repoPath);
    if (!headValid) {
      this.logger.error('HEAD SHA invalide avant sync');
      return false;
    }

    // Pull avec protection SHA
    const result = await this.gitHelpers.safePull(repoPath, 'origin', 'main');

    if (!result.success) {
      if (result.error?.includes('HEAD SHA corrupted')) {
        this.logger.error('❌ Repository corrompu après pull - ROLLBACK AUTOMATIQUE');
        // safePull() a déjà tenté le rollback
      }
      return false;
    }

    this.logger.info('✅ Synchronisation réussie', {
      commitsPulled: result.commitsCount,
      headSHA: result.newHeadSHA
    });

    return true;
  }
}
```

#### Personnalisation Avancée

```typescript
// GitHelpers personnalisés pour environnement spécifique
const productionGitHelpers = getGitHelpers({
  timeoutMs: 300000,        // 5 minutes pour production
  retryAttempts: 5,          // Plus de tentatives
  verifySHA: true,           // Toujours vérifier SHA
  autoRollback: true,         // Rollback obligatoire
  enableCache: false,         // Pas de cache en production
  loggerOptions: {
    source: 'GitHelpers-Production',
    minLevel: 'INFO'
  }
});

const developmentGitHelpers = getGitHelpers({
  timeoutMs: 60000,         // 1 minute pour développement
  retryAttempts: 1,          // Une seule tentative
  verifySHA: false,          // Pas de vérification SHA en dev
  autoRollback: false,        // Pas de rollback automatique
  enableCache: true,          // Cache activé pour performance
  loggerOptions: {
    source: 'GitHelpers-Dev',
    minLevel: 'DEBUG'
  }
});
```

### 5.3 Gestion des Conflits

#### Patterns de Résolution de Conflits

```typescript
// Gestion des conflits avec GitHelpers
async function handleConflictResolution(repoPath: string): Promise<void> {
  const gitHelpers = getGitHelpers();
  const logger = createLogger('ConflictResolution');

  // 1. Mettre de côté les changements locaux
  logger.info('Stashing local changes before conflict resolution');
  await gitHelpers.safeStash(repoPath, 'Auto-stash before conflict resolution');

  // 2. Reset à état propre
  logger.info('Resetting to clean state');
  await gitHelpers.safeReset(repoPath, 'HEAD');

  // 3. Pull propre
  logger.info('Pulling clean from remote');
  const pullResult = await gitHelpers.safePull(repoPath, 'origin', 'main');

  if (!pullResult.success) {
    logger.error('Pull failed after reset', { error: pullResult.error });
    throw new Error('Conflict resolution failed');
  }

  // 4. Appliquer changements stashés
  logger.info('Applying stashed changes');
  const stashResult = await gitHelpers.safeStashPop(repoPath);

  if (!stashResult.success) {
    logger.warn('Stash pop had conflicts - manual resolution required');
    // Résolution manuelle des conflits restants
    logger.info('Manual conflict resolution required');
    logger.info('Run: git status');
    logger.info('Run: git diff');
  }
}
```

### 5.4 Rollback Automatique

#### Mécanisme de Rollback

Les Git Helpers implémentent un rollback automatique en cas d'échec d'opération :

```typescript
// Exemple de rollback automatique dans safePull
async safePull(repoPath: string, remote: string, branch: string): Promise<GitOperationResult> {
  const logger = createLogger('GitHelpers');

  // 1. Sauvegarder SHA avant opération
  const shaBefore = await this.getHeadSHA(repoPath);
  logger.debug('SHA avant opération', { sha: shaBefore });

  try {
    // 2. Exécuter pull
    const result = await this.executePull(repoPath, remote, branch);

    // 3. Vérifier SHA après opération
    const shaAfter = await this.getHeadSHA(repoPath);
    logger.debug('SHA après opération', { sha: shaAfter });

    // 4. Valider intégrité
    if (!await this.verifyHeadValid(repoPath)) {
      logger.error('HEAD SHA invalide après pull - ROLLBACK');
      await this.rollbackToSHA(repoPath, shaBefore);
      return {
        success: false,
        error: 'HEAD SHA corrupted after pull',
        rollbackPerformed: true
      };
    }

    return {
      success: true,
      newHeadSHA: shaAfter,
      commitsCount: result.commitsCount
    };
  } catch (error) {
    logger.error('Pull échoué - ROLLBACK', { error });
    await this.rollbackToSHA(repoPath, shaBefore);
    return {
      success: false,
      error: error.message,
      rollbackPerformed: true
    };
  }
}
```

### 5.5 Patterns d'Utilisation

#### Pattern 1 : Opération Sécurisée avec Retry

```typescript
async function safeOperationWithRetry(repoPath: string, operation: string): Promise<GitOperationResult> {
  const gitHelpers = getGitHelpers();
  const logger = createLogger('SafeOperation');

  const maxRetries = 3;
  const retryDelay = 5000; // 5 secondes

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    logger.info(`Tentative ${attempt}/${maxRetries} pour ${operation}`);

    const result = await gitHelpers.safePull(repoPath, 'origin', 'main');

    if (result.success) {
      logger.info(`✅ ${operation} réussie`, { attempt });
      return result;
    }

    logger.warn(`Échec tentative ${attempt}`, { error: result.error });

    if (attempt < maxRetries) {
      logger.info(`Attente ${retryDelay}ms avant retry...`);
      await new Promise(resolve => setTimeout(resolve, retryDelay));
    }
  }

  logger.error(`❌ ${operation} échouée après ${maxRetries} tentatives`);
  return {
    success: false,
    error: `Operation failed after ${maxRetries} attempts`
  };
}
```

#### Pattern 2 : Monitoring des Opérations Git

```typescript
export class GitMetrics {
  private static operations = {
    pull: { success: 0, failed: 0, totalDuration: 0 },
    checkout: { success: 0, failed: 0, totalDuration: 0 },
    push: { success: 0, failed: 0, totalDuration: 0 },
    rollback: { performed: 0, triggered: 0 }
  };

  static recordOperation(type: string, success: boolean, duration: number): void {
    if (!this.operations[type]) {
      this.operations[type] = { success: 0, failed: 0, totalDuration: 0 };
    }

    if (success) {
      this.operations[type].success++;
    } else {
      this.operations[type].failed++;
    }

    this.operations[type].totalDuration += duration;
  }

  static getMetrics(): object {
    return {
      operations: this.operations,
      successRate: {
        pull: this.calculateSuccessRate('pull'),
        checkout: this.calculateSuccessRate('checkout'),
        push: this.calculateSuccessRate('push')
      },
      averageDuration: {
        pull: this.calculateAverageDuration('pull'),
        checkout: this.calculateAverageDuration('checkout'),
        push: this.calculateAverageDuration('push')
      }
    };
  }

  private static calculateSuccessRate(type: string): number {
    const ops = this.operations[type];
    const total = ops.success + ops.failed;
    return total > 0 ? (ops.success / total) * 100 : 0;
  }

  private static calculateAverageDuration(type: string): number {
    const ops = this.operations[type];
    const total = ops.success + ops.failed;
    return total > 0 ? ops.totalDuration / total : 0;
  }
}
```

#### Pattern 3 : Backup Incrémentiel

```typescript
export class IncrementalBackupManager {
  private static lastBackupSHA: string | null = null;

  static async performIncrementalBackup(repoPath: string, backupDir: string): Promise<void> {
    const gitHelpers = getGitHelpers();
    const logger = createLogger('IncrementalBackup');

    // Obtenir SHA actuel
    const currentSHA = await gitHelpers.getHeadSHA(repoPath);

    if (this.lastBackupSHA === currentSHA) {
      logger.info('No changes since last backup');
      return;
    }

    logger.info('Starting incremental backup', {
      fromSHA: this.lastBackupSHA,
      toSHA: currentSHA
    });

    // Créer backup des changements seulement
    const changes = await gitHelpers.getDiff(repoPath, this.lastBackupSHA || 'HEAD~10', currentSHA);

    // Sauvegarder changements
    const backupFile = `${backupDir}/incremental-${Date.now()}.json`;
    await fs.writeFile(backupFile, JSON.stringify({
      timestamp: new Date().toISOString(),
      fromSHA: this.lastBackupSHA,
      toSHA: currentSHA,
      changes: changes
    }, null, 2));

    this.lastBackupSHA = currentSHA;
    logger.info('✅ Incremental backup completed', { backupFile });
  }
}
```

#### Pattern 4 : Debugging Git Operations

```typescript
export class GitDebugPatterns {
  static logGitOperation(logger: any, operation: string, repoPath: string): void {
    logger.debug(`[GIT] ${operation}`, {
      operation,
      repository: repoPath,
      timestamp: new Date().toISOString(),
      gitVersion: require('child_process').execSync('git --version').toString().trim()
    });
  }

  static logPerformance(logger: any, operation: string, duration: number, details: any): void {
    logger.info(`[GIT_PERF] ${operation}`, {
      operation,
      duration: `${duration}ms`,
      performance: duration > 5000 ? 'SLOW' : 'OK',
      details
    });
  }

  static logStateTransition(logger: any, from: string, to: string, context: string): void {
    logger.info(`[GIT_STATE] ${from} → ${to}`, {
      transition: `${from}→${to}`,
      context,
      timestamp: new Date().toISOString()
    });
  }

  static logErrorWithRecovery(logger: any, error: Error, operation: string, recovery: string): void {
    logger.error(`[GIT_ERROR] ${operation}`, error, {
      operation,
      errorType: error.constructor.name,
      errorMessage: error.message,
      recovery,
      timestamp: new Date().toISOString()
    });
  }
}
```

#### Tests et Validation

**Test 1 : Git Disponible**

```typescript
const gitHelpers = getGitHelpers();
const result = await gitHelpers.verifyGitAvailable();

console.log('Git available:', result.available); // true
console.log('Git version:', result.version);     // "git version 2.43.0"
```

**Test 2 : Git Absent (Simulé)**

```bash
# Temporairement renommer git.exe
mv "C:\Program Files\Git\bin\git.exe" "C:\Program Files\Git\bin\git.exe.bak"

# Tester
node test-git-verification.js
# Attendu: "Git NON TROUVÉ dans PATH"

# Restaurer
mv "C:\Program Files\Git\bin\git.exe.bak" "C:\Program Files\Git\bin\git.exe"
```

**Test 3 : SHA Verification**

```typescript
const headSHA = await gitHelpers.getHeadSHA('/path/to/repo');
console.log('HEAD SHA:', headSHA); // "a1b2c3d4e5f6g7h8..."

const isValid = await gitHelpers.verifyHeadValid('/path/to/repo');
console.log('HEAD valid:', isValid); // true
```

**Test 4 : Safe Pull avec Rollback**

```typescript
// Créer situation de conflit
const result = await gitHelpers.safePull('/path/to/repo', 'origin', 'main');

if (!result.success) {
  console.log('Pull failed:', result.error);
  console.log('Exit code:', result.exitCode);
}
```

#### Métriques de Convergence

**Avant git-helpers (v2.0)** :
- ❌ **0%** vérification Git au démarrage
- ❌ **0%** vérification exit code Git
- ❌ **0%** logging SHA pour opérations critiques
- ❌ **0%** rollback automatique
- 🔴 **Score convergence v1→v2** : 67%

**Après git-helpers (v2.1)** :
- ✅ **100%** vérification Git au démarrage (comme v1)
- ✅ **100%** vérification exit code Git (comme v1)
- ✅ **100%** logging SHA pour opérations critiques (comme v1)
- ✅ **100%** rollback automatique sur corruption
- ✅ **Score convergence v1→v2** : **85%** (+18%)

#### Best Practices Git

**✅ À FAIRE** :

1. **Toujours vérifier Git au démarrage du service**
   ```typescript
   const gitCheck = await this.gitHelpers.verifyGitAvailable();
   if (!gitCheck.available) {
     throw new Error('Git required but not found in PATH');
   }
   ```

2. **Utiliser `execGitCommand()` pour toutes opérations Git**
   ```typescript
   const result = await gitHelpers.execGitCommand(
     'git pull origin main',
     'Pull depuis origin/main',
     { cwd: projectRoot, logSHA: true }
   );
   ```

3. **Activer `logSHA: true` pour pull, merge, checkout, reset**
   ```typescript
   const result = await gitHelpers.execGitCommand(
     'git merge feature-branch',
     'Merge feature branch',
     { cwd: repoPath, logSHA: true }
   );
   ```

4. **Vérifier `result.success` avant de continuer**
   ```typescript
   if (!result.success) {
     logger.error('Pull failed', { error: result.error, exitCode: result.exitCode });
     return;
   }
   ```

5. **Logger les échecs Git avec contexte (exitCode, stderr)**
   ```typescript
   logger.error('Git operation failed', {
     operation: 'pull',
     exitCode: result.exitCode,
     stderr: result.stderr,
     error: result.error
   });
   ```

6. **Sauvegarder SHA avant opérations risquées**
   ```typescript
   const shaBefore = await gitHelpers.getHeadSHA(repoPath);
   // Opération risquée...
   if (!result.success) {
     await gitHelpers.rollbackToSHA(repoPath, shaBefore);
   }
   ```

**❌ À ÉVITER** :

1. **Ne pas utiliser `execAsync()` directement pour Git**
   ```typescript
   // ❌ BAD
   const { stdout } = await execAsync('git pull origin main');

   // ✅ GOOD
   const result = await gitHelpers.execGitCommand('git pull origin main', 'Pull', { cwd: repoPath });
   ```

2. **Ne pas ignorer les `exitCode !== 0`**
   ```typescript
   // ❌ BAD
   const result = await gitHelpers.execGitCommand('git pull', 'Pull', { cwd: repoPath });
   // Continue sans vérifier result.success

   // ✅ GOOD
   if (!result.success) {
     // Gérer l'erreur
   }
   ```

3. **Ne pas oublier de vérifier SHA HEAD après opérations critiques**
   ```typescript
   // ❌ BAD
   await gitHelpers.execGitCommand('git merge feature', 'Merge', { cwd: repoPath });
   // Continue sans vérifier SHA

   // ✅ GOOD
   const result = await gitHelpers.execGitCommand('git merge feature', 'Merge', { cwd: repoPath, logSHA: true });
   const isValid = await gitHelpers.verifyHeadValid(repoPath);
   if (!isValid) {
     // Rollback
   }
   ```

4. **Ne pas continuer si Git n'est pas disponible (sauf mode dégradé explicite)**
   ```typescript
   // ❌ BAD
   const gitCheck = await gitHelpers.verifyGitAvailable();
   // Continue même si !gitCheck.available

   // ✅ GOOD
   if (!gitCheck.available) {
     throw new Error('Git required but not found');
   }
   ```

5. **Ne pas oublier le rollback en cas d'échec**
   ```typescript
   // ❌ BAD
   const shaBefore = await gitHelpers.getHeadSHA(repoPath);
   const result = await gitHelpers.execGitCommand('git reset --hard', 'Reset', { cwd: repoPath });
   if (!result.success) {
     // Pas de rollback
   }

   // ✅ GOOD
   const shaBefore = await gitHelpers.getHeadSHA(repoPath);
   const result = await gitHelpers.execGitCommand('git reset --hard', 'Reset', { cwd: repoPath });
   if (!result.success) {
     await gitHelpers.rollbackToSHA(repoPath, shaBefore);
   }
   ```

---

## 6. Bonnes Pratiques

### 6.1 Code Style

### 6.2 Documentation

### 6.3 Gestion des Erreurs

### 6.4 Performance

### 6.5 Sécurité

---

**Version du document** : 1.0
**Dernière mise à jour** : 2025-12-27
