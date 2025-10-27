# Deployment Helpers Usage Guide

**Version** : 1.0.0  
**Date** : 2025-10-23  
**Statut** : Production Ready

---

## 📋 Vue d'Ensemble

Le module `deployment-helpers.ts` fournit des wrappers TypeScript typés pour exécuter les scripts PowerShell de déploiement de manière sécurisée et traçable.

### Architecture

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

---

## 🚀 Quick Start

### Import

```typescript
import { getDeploymentHelpers, type DeploymentResult } from '../utils/deployment-helpers.js';

const deployer = getDeploymentHelpers();
```

### Exemple Simple

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

---

## 📚 API Reference

### Interface `DeploymentResult`

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

### Interface `DeploymentOptions`

```typescript
interface DeploymentOptions {
  timeout?: number;                    // Timeout ms (défaut: 300000 = 5min)
  dryRun?: boolean;                    // Mode simulation (-WhatIf)
  logger?: Logger;                     // Logger personnalisé
  env?: Record<string, string>;        // Variables env supplémentaires
}
```

---

## 🔧 Fonctions Spécifiques

### 1. `deployModes()`

Déploie la configuration des modes Roo.

**Script PowerShell** : `deploy-modes.ps1`

```typescript
const result = await deployer.deployModes({
  timeout: 120000,  // 2 minutes
  dryRun: false
});
```

---

### 2. `deployMCPs()`

Installe et configure les MCPs.

**Script PowerShell** : `install-mcps.ps1`

```typescript
const result = await deployer.deployMCPs({
  timeout: 300000,  // 5 minutes (défaut)
  logger: customLogger
});
```

---

### 3. `createProfile(profileName)`

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

---

### 4. `createCleanModes()`

Nettoie et recrée les modes propres.

**Script PowerShell** : `create-clean-modes.ps1`

```typescript
const result = await deployer.createCleanModes({
  timeout: 60000  // 1 minute
});
```

---

### 5. `forceDeployWithEncodingFix()`

Déploiement avec correction d'encodage forcée.

**Script PowerShell** : `force-deploy-with-encoding-fix.ps1`

```typescript
const result = await deployer.forceDeployWithEncodingFix({
  timeout: 120000
});
```

---

### 6. `executeDeploymentScript()` (Générique)

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

---

## 💡 Patterns d'Utilisation

### Pattern 1 : Dry-Run puis Production

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

---

### Pattern 2 : Déploiement avec Retry

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

---

### Pattern 3 : Logger Personnalisé

```typescript
import { createLogger } from '../utils/logger.js';

const customLogger = createLogger('MyDeployment');

const deployer = getDeploymentHelpers();
const result = await deployer.deployModes({
  logger: customLogger
});

// Logs automatiques via customLogger
```

---

### Pattern 4 : Variables Environnement

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

---

## 🧪 Tests

### Test Unitaire Exemple

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

---

## ⚠️ Error Handling

### Codes de Sortie PowerShell

| Exit Code | Signification |
|-----------|---------------|
| 0 | ✅ Succès |
| 1 | ❌ Erreur générale |
| -1 | ❌ Exception TypeScript (timeout, spawn error) |

### Gestion Erreurs Recommandée

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

---

## 📊 Métriques & Monitoring

### Logging Production

Le `DeploymentHelpers` utilise le Logger production qui output à la fois :
- Console (stdout/stderr)
- Fichiers logs (si configuré)

```typescript
// Logs automatiques générés :
[DeploymentHelpers] Deployment helpers initialized { scriptsBasePath: ... }
[DeploymentHelpers] Executing deployment script { scriptName, args, timeout, dryRun }
[DeploymentHelpers] Deployment script succeeded { success, scriptName, duration, exitCode }
```

### Tracking Durée

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

---

## 🔗 Références

### Code Source
- [`deployment-helpers.ts`](../../mcps/internal/servers/roo-state-manager/src/utils/deployment-helpers.ts) - Implementation
- [`PowerShellExecutor.ts`](../../mcps/internal/servers/roo-state-manager/src/services/PowerShellExecutor.ts) - Base executor

### Scripts PowerShell
- [`scripts/deployment/`](../../scripts/deployment/) - Scripts deployment disponibles

### Documentation Associée
- [`scripts-migration-status-20251023.md`](scripts-migration-status-20251023.md) - État scripts
- [`git-requirements.md`](git-requirements.md) - Git helpers (intégration similaire)

---

## 💡 Best Practices

### ✅ À FAIRE

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

### ❌ À ÉVITER

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

---

## 🎓 Exemples Avancés

### Déploiement Orchestré

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

---

**Version** : 1.0.0 | **Phase 2B Complete** ✅