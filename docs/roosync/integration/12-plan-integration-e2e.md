# Plan d'Intégration E2E RooSync MCP ↔ PowerShell

**Version :** 1.0.0  
**Date :** 2025-01-09  
**Tâche :** 40 - Tests End-to-End RooSync Multi-Machines  
**Phase :** 1.4 - Création Plan d'Intégration

---

## 1. Architecture PowerShell Existante

### 1.1 Structure Identifiée

```
RooSync/
├── src/
│   ├── sync-manager.ps1           # Orchestrateur principal
│   └── modules/
│       ├── Core.psm1              # Get-LocalContext, utilitaires
│       └── Actions.psm1           # Compare-Config, Apply-Decisions, Initialize-Workspace
├── .config/
│   └── sync-config.json           # Configuration locale (version 2.0.0)
├── .env                           # SHARED_STATE_PATH vers Google Drive
└── tests/
    ├── test-refactoring.ps1
    ├── test-format-validation.ps1
    └── test-decision-format-fix.ps1
```

### 1.2 Scripts PowerShell Clés

#### sync-manager.ps1
**Rôle :** Point d'entrée principal du système RooSync  
**Actions disponibles :**
- `Compare-Config` : Détecte différences entre config locale et référence
- `Apply-Decisions` : Applique décisions approuvées depuis roadmap
- `Status` : Affiche état dashboard
- `Initialize-Workspace` : Initialise structure fichiers partagés

**Invocation :**
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "RooSync/src/sync-manager.ps1" -Action <Action>
```

#### modules/Actions.psm1
**Fonctions exportées :**
1. `Compare-Config` (lignes 25-130)
2. `Apply-Decisions` (lignes 132-183)
3. `Initialize-Workspace` (lignes 185-230)

### 1.3 Fichiers Partagés (Google Drive)

**Emplacement :** `G:\Mon Drive\MyIA\Dev\roo-code\RooSync` (configuré dans `.env`)

**Fichiers clés :**
- `sync-roadmap.md` : Contient décisions avec marqueurs HTML `<!-- DECISION_BLOCK_START -->` / `<!-- DECISION_BLOCK_END -->`
- `sync-dashboard.json` : État machines (`{ "machineStates": [...] }`)
- `sync-config.ref.json` : Configuration de référence
- `sync-report.md` : Rapport d'exécution avec contexte système

---

## 2. Points d'Intégration MCP ↔ PowerShell

### 2.1 RooSyncService.executeDecision()

#### 2.1.1 Mapping vers PowerShell

**Script PowerShell :** `sync-manager.ps1 -Action Apply-Decisions`  
**Fonction sous-jacente :** `Apply-Decisions` dans `modules/Actions.psm1`

**Mécanisme d'exécution :**
1. Lit `sync-roadmap.md` depuis `$SHARED_STATE_PATH`
2. Cherche décisions approuvées via regex : `\[x\] \*\*Approuver & Fusionner\*\*`
3. Copie `sync-config.json` locale → `sync-config.ref.json` référence
4. Archive décision (remplace `DECISION_BLOCK_START` → `DECISION_BLOCK_ARCHIVED`)

**Paramètres d'entrée :**
- Aucun paramètre direct (utilise `$decisionId` implicite depuis roadmap)
- Configuration via `.env` (`SHARED_STATE_PATH`)

**Format sortie :**
- **Standard Output :** Messages textuels `Write-Host`
- **Exit Code :** 
  - `0` : Succès
  - `1` : Erreur (via `Write-Error`)

**Données nécessaires pour intégration :**
- Décision doit être pré-approuvée dans `sync-roadmap.md` (checkbox `[x]`)
- Decision ID extrait depuis roadmap (format : `### DECISION ID: <uuid>`)

#### 2.1.2 Implémentation Node.js

**Wrapper PowerShell :**
```typescript
async executeDecision(
  decisionId: string,
  options?: { dryRun?: boolean; force?: boolean }
): Promise<ExecutionResult>
```

**Stratégie d'implémentation :**
1. **Pré-traitement :** Approuver décision programmatiquement dans roadmap
   - Lire `sync-roadmap.md`
   - Trouver bloc décision par `decisionId`
   - Remplacer `- [ ]` → `- [x]` pour "Approuver & Fusionner"
   - Réécrire fichier
2. **Exécution :** Invoquer `sync-manager.ps1 -Action Apply-Decisions`
3. **Post-traitement :** Parser sortie console pour extraire logs et changements

**Gestion dryRun :**
- RooSync natif ne supporte pas `dryRun`
- **Solution :** Simulation via copie temporaire roadmap :
  1. Backup `sync-roadmap.md`
  2. Approuver décision
  3. Exécuter Apply-Decisions
  4. Restaurer backup si `dryRun=true`

**Format sortie attendu :**
```typescript
{
  success: boolean,
  logs: string[],  // Lignes de Write-Host
  changes: {
    filesModified: string[],  // ["sync-config.ref.json"]
    filesCreated: string[],   // []
    filesDeleted: string[]    // []
  },
  executionTime: number,
  error?: string
}
```

---

### 2.2 RooSyncService.createRollbackPoint()

#### 2.2.1 Analyse Architecture Existante

**⚠️ CONTRAINTE CRITIQUE :** RooSync natif **ne dispose PAS** de mécanisme de rollback.

**Scripts manquants :**
- ❌ `Create-RollbackPoint.ps1`
- ❌ `Restore-RollbackPoint.ps1`
- ❌ Système de versioning fichiers

**Données disponibles pour rollback :**
- ✅ `sync-roadmap.md` contient historique décisions
- ✅ Décisions archivées (`DECISION_BLOCK_ARCHIVED`)
- ✅ Contexte système dans chaque décision (timestamp, machine, diff)

#### 2.2.2 Stratégies d'Implémentation

**Option A : Rollback Simplifié (Court-Terme)**

Utiliser Git pour versioning automatique :

```typescript
async createRollbackPoint(decisionId: string): Promise<void> {
  const sharedPath = process.env.SHARED_STATE_PATH;
  
  // Commit snapshot état actuel
  await PowerShellExecutor.executeScript('git', [
    '-C', sharedPath,
    'add', 'sync-config.ref.json', 'sync-roadmap.md',
  ]);
  
  await PowerShellExecutor.executeScript('git', [
    '-C', sharedPath,
    'commit', '-m', `Rollback point: ${decisionId}`,
  ]);
}
```

**Avantages :**
- ✅ Implémentation rapide
- ✅ Utilise infrastructure Git existante
- ✅ Historique complet avec diff

**Inconvénients :**
- ❌ Nécessite Git dans environnement
- ❌ Pas de restore automatique intégré
- ❌ Complexité multi-machines (merge conflicts)

**Option B : Rollback Natif PowerShell (Long-Terme)**

Créer nouveaux scripts PowerShell :

**Script :** `RooSync/scripts/Create-RollbackPoint.ps1`
```powershell
param([string]$DecisionId)

$sharedPath = $env:SHARED_STATE_PATH
$rollbackDir = "$sharedPath/.rollback"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$rollbackPath = "$rollbackDir/${DecisionId}_${timestamp}"

New-Item -Path $rollbackPath -ItemType Directory -Force

# Backup fichiers critiques
Copy-Item "$sharedPath/sync-config.ref.json" "$rollbackPath/"
Copy-Item "$sharedPath/sync-roadmap.md" "$rollbackPath/"

# Metadata rollback
$metadata = @{
  decisionId = $DecisionId
  timestamp = $timestamp
  files = @("sync-config.ref.json", "sync-roadmap.md")
} | ConvertTo-Json

Set-Content "$rollbackPath/metadata.json" $metadata
```

**Script :** `RooSync/scripts/Restore-RollbackPoint.ps1`
```powershell
param([string]$DecisionId)

$sharedPath = $env:SHARED_STATE_PATH
$rollbackDir = "$sharedPath/.rollback"
$rollbackPoint = Get-ChildItem "$rollbackDir/${DecisionId}_*" | Sort-Object -Descending | Select-Object -First 1

Copy-Item "$rollbackPoint/sync-config.ref.json" "$sharedPath/" -Force
Copy-Item "$rollbackPoint/sync-roadmap.md" "$sharedPath/" -Force
```

**Avantages :**
- ✅ Autonome (pas de dépendance Git)
- ✅ Contrôle total sur logique rollback
- ✅ Intégration native RooSync

**Inconvénients :**
- ❌ Développement additionnel requis
- ❌ Gestion manuelle expiration rollbacks
- ❌ Pas d'historique diff visuel

#### 2.2.3 Implémentation Recommandée

**Approche Hybride :** Option A pour Phase 1, migration vers Option B en Phase 2

**Phase 1 (Tâche 40) :**
```typescript
async createRollbackPoint(decisionId: string): Promise<void> {
  // Backup manuel dans répertoire dédié
  const sharedPath = process.env.SHARED_STATE_PATH;
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = `${sharedPath}/.rollback/${decisionId}_${timestamp}`;
  
  await fs.mkdir(backupPath, { recursive: true });
  await fs.copyFile(
    `${sharedPath}/sync-config.ref.json`,
    `${backupPath}/sync-config.ref.json`
  );
  await fs.copyFile(
    `${sharedPath}/sync-roadmap.md`,
    `${backupPath}/sync-roadmap.md`
  );
}
```

**Phase 2 (Post-Tâche 40) :**
- Implémenter scripts PowerShell natifs
- Ajouter gestion expiration automatique (30 jours)
- Intégrer dans `sync-manager.ps1` comme action (`-Action Create-Rollback`)

---

### 2.3 RooSyncService.restoreFromRollbackPoint()

#### 2.3.1 Implémentation Phase 1

```typescript
async restoreFromRollbackPoint(decisionId: string): Promise<RestoreResult> {
  const sharedPath = process.env.SHARED_STATE_PATH;
  const rollbackDir = `${sharedPath}/.rollback`;
  
  // Trouver dernier rollback pour decisionId
  const backups = await fs.readdir(rollbackDir);
  const matching = backups
    .filter(name => name.startsWith(decisionId))
    .sort()
    .reverse();
  
  if (matching.length === 0) {
    return {
      success: false,
      restoredFiles: [],
      logs: [`Aucun rollback trouvé pour ${decisionId}`]
    };
  }
  
  const backupPath = `${rollbackDir}/${matching[0]}`;
  const restoredFiles: string[] = [];
  
  // Restaurer fichiers
  await fs.copyFile(
    `${backupPath}/sync-config.ref.json`,
    `${sharedPath}/sync-config.ref.json`
  );
  restoredFiles.push('sync-config.ref.json');
  
  await fs.copyFile(
    `${backupPath}/sync-roadmap.md`,
    `${sharedPath}/sync-roadmap.md`
  );
  restoredFiles.push('sync-roadmap.md');
  
  return {
    success: true,
    restoredFiles,
    logs: [`Restauré depuis ${backupPath}`]
  };
}
```

---

## 3. Stratégie d'Implémentation

### 3.1 Architecture Intégration

```
Node.js MCP Server (roo-state-manager)
│
├─ PowerShellExecutor (nouveau)
│  ├─ executeScript(scriptPath, args, options)
│  └─ parseJsonOutput<T>(stdout)
│
├─ RooSyncService (mis à jour)
│  ├─ executeDecision() → Apply-Decisions
│  ├─ createRollbackPoint() → Backup manuel
│  └─ restoreFromRollbackPoint() → Restore manuel
│
└─ RooSync PowerShell (existant)
   └─ sync-manager.ps1 -Action Apply-Decisions
```

### 3.2 Gestion Erreurs

**Types d'erreurs attendues :**
1. **PowerShell indisponible :** `pwsh.exe` introuvable
2. **Google Drive inaccessible :** `$SHARED_STATE_PATH` non monté
3. **Décision introuvable :** `decisionId` invalide dans roadmap
4. **Timeout :** Exécution > 60s (opérations fichiers lentes)

**Stratégie de gestion :**
```typescript
try {
  const result = await PowerShellExecutor.executeScript(...);
  if (!result.success) {
    return { success: false, error: result.stderr };
  }
} catch (error) {
  if (error.message.includes('timeout')) {
    return { success: false, error: 'Timeout dépassé' };
  }
  throw error; // Erreurs critiques remontées
}
```

### 3.3 Tests Unitaires

**Fichier :** `tests/unit/services/powershell-executor.test.ts`

**Scénarios de test :**
1. ✅ Exécution script simple (`echo "test"`)
2. ✅ Parsing JSON output
3. ✅ Gestion timeout (script long)
4. ✅ Gestion erreurs PowerShell (exit code ≠ 0)
5. ✅ Chemins avec espaces et caractères spéciaux

### 3.4 Tests E2E

**Fichier :** `tests/e2e/roosync-workflow.test.ts`

**Workflows testés :**
1. **Workflow complet (detect → approve → apply) :**
   - Compare-Config détecte différence
   - Décision créée dans roadmap
   - MCP approuve décision
   - Apply-Decisions exécuté avec succès
   
2. **Workflow rollback (apply → rollback) :**
   - Créer rollback point avant apply
   - Appliquer décision
   - Restaurer depuis rollback
   - Vérifier état restauré

3. **Gestion erreurs :**
   - Decision ID invalide
   - SHARED_STATE_PATH non accessible
   - Script PowerShell échoue

---

## 4. Tests E2E Planifiés

### 4.1 Configuration Test

**Environnement requis :**
- 2 machines avec RooSync configuré
- Google Drive synchronisé (`SHARED_STATE_PATH` accessible)
- Node.js ≥ 18.x
- PowerShell 7.x

**Setup initial :**
```bash
# Machine A
cd RooSync
pwsh -c "./src/sync-manager.ps1 -Action Initialize-Workspace"
pwsh -c "./src/sync-manager.ps1 -Action Compare-Config"

# Machine B
# Même configuration Google Drive
pwsh -c "./src/sync-manager.ps1 -Action Compare-Config"
# → Génère décision (différence machine A vs B)
```

### 4.2 Scénarios de Test

#### Test 1 : Workflow Complet Automatisé
```typescript
it('should execute full workflow: detect → approve → apply', async () => {
  // 1. Lister décisions pending
  const decisions = await service.loadDecisions();
  const pending = decisions.find(d => d.status === 'pending');
  
  // 2. Approuver via MCP
  await service.approveDecision(pending.id);
  
  // 3. Créer rollback
  await service.createRollbackPoint(pending.id);
  
  // 4. Appliquer décision
  const result = await service.executeDecision(pending.id);
  
  expect(result.success).toBe(true);
  expect(result.changes.filesModified).toContain('sync-config.ref.json');
});
```

#### Test 2 : Rollback Workflow
```typescript
it('should handle rollback workflow', async () => {
  const decisionId = 'test-decision-uuid';
  
  // 1. Créer rollback
  await service.createRollbackPoint(decisionId);
  
  // 2. Modifier état (appliquer décision)
  await service.executeDecision(decisionId);
  
  // 3. Restaurer rollback
  const restoreResult = await service.restoreFromRollbackPoint(decisionId);
  
  expect(restoreResult.success).toBe(true);
  expect(restoreResult.restoredFiles.length).toBeGreaterThan(0);
});
```

#### Test 3 : Gestion Erreurs
```typescript
it('should handle invalid decision ID', async () => {
  const result = await service.executeDecision('INVALID_ID');
  expect(result.success).toBe(false);
  expect(result.error).toBeDefined();
});

it('should timeout on long operations', async () => {
  await expect(
    PowerShellExecutor.executeScript('Start-Sleep', ['-Seconds', '120'], { timeout: 1000 })
  ).rejects.toThrow();
});
```

### 4.3 Métriques de Succès

**Critères de validation :**
- ✅ Tous tests E2E passants (≥ 90%)
- ✅ Temps moyen `executeDecision` < 10s
- ✅ Temps moyen `rollback` < 5s
- ✅ Gestion timeout robuste (pas de deadlock)
- ✅ Logs détaillés pour debugging

---

## 5. Contraintes et Limitations

### 5.1 Contraintes Techniques

1. **Google Drive obligatoire :** `SHARED_STATE_PATH` doit pointer vers Google Drive synchronisé
2. **Pas de rollback natif :** Nécessite implémentation manuelle backup/restore
3. **Décisions pré-approuvées :** `Apply-Decisions` nécessite checkbox `[x]` dans roadmap
4. **Pas de dryRun natif :** Nécessite simulation via backup temporaire

### 5.2 Limitations Connues

1. **Format sortie non-structuré :** `Apply-Decisions` retourne texte console, pas JSON
2. **Pas de progression :** Pas de callback pour opérations longues
3. **Multi-machines concurrency :** Conflits possibles si 2 machines appliquent simultanément

### 5.3 Recommandations Amélioration

**Court-terme (Post-Tâche 40) :**
1. Ajouter sortie JSON dans `Apply-Decisions`
2. Implémenter scripts rollback natifs PowerShell
3. Ajouter locking Google Drive pour éviter conflits

**Long-terme (Phase 9+) :**
1. Migration vers backend HTTP/REST pour coordination
2. Webhook notifications entre machines
3. Interface CLI interactive RooSync

---

## 6. Checklist Implémentation

### Phase 2 : Implémentation Intégration PowerShell
- [ ] Créer `PowerShellExecutor.ts`
- [ ] Mettre à jour `RooSyncService.executeDecision()`
- [ ] Implémenter `createRollbackPoint()` (backup manuel)
- [ ] Implémenter `restoreFromRollbackPoint()` (restore manuel)
- [ ] Tests unitaires `PowerShellExecutor`
- [ ] Commit Phase 2

### Phase 3 : Tests End-to-End
- [ ] Créer `roosync-workflow.test.ts`
- [ ] Créer `roosync-error-handling.test.ts`
- [ ] Exécuter suite tests E2E
- [ ] Documenter résultats dans `13-resultats-tests-e2e.md`
- [ ] Commit Phase 3

### Phase 4 : Documentation Finale
- [ ] Guide utilisation 8 outils MCP RooSync
- [ ] Mettre à jour README sous-module
- [ ] Troubleshooting et FAQ
- [ ] Commit Phase 4

---

## Conclusion

Ce plan d'intégration E2E fournit une feuille de route détaillée pour remplacer les stubs PowerShell par une intégration réelle avec le système RooSync existant. 

**Points clés :**
- ✅ Architecture PowerShell RooSync analysée en profondeur
- ⚠️ Contrainte rollback natif absente (solution manuelle proposée)
- ✅ Stratégie d'implémentation hybride (court et long-terme)
- ✅ Tests E2E planifiés avec scénarios détaillés

**Prochaine étape :** Phase 2 - Implémentation `PowerShellExecutor` et mise à jour `RooSyncService`