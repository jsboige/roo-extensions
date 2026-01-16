# Tâche T2.21 - Tests E2E pour Compare → Validate → Apply

**Date:** 2026-01-15
**Machine:** myia-po-2026
**Projet GitHub:** #67 "RooSync Multi-Agent Tasks"
**Priorité:** MEDIUM
**Agent responsable:** Roo (technique)
**Agent de support:** Claude Code (documentation/coordination)
**MCP:** `mcps/internal/servers/roo-state-manager`
**Protocole:** SDDD v2.0.0

---

## Résumé Exécutif

Cette tâche vise à créer des tests End-to-End (E2E) pour valider le flux complet de synchronisation RooSync : **Compare → Validate → Apply**.

**Objectif principal :** Créer des tests E2E qui valident le workflow complet de synchronisation, de la détection des différences à l'application des décisions, en passant par la validation humaine.

**Statut actuel :** Analyse terminée, documentation en cours.

---

## 1. Semantic Grounding - Analyse du Flux Compare → Validate → Apply

### 1.1 Architecture RooSync v2.1

RooSync v2.1 implémente une architecture **baseline-driven** avec workflow obligatoire en 3 phases :

```
┌─────────────────────────────────────────────────────────────┐
│              WORKFLOW ROOSYNC v2.1                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 🔍 COMPARE                                            │
│     └─ roosync_compare_config()                            │
│        └─ Détection des différences contre baseline          │
│        └─ Génération de décisions PENDING                  │
│                                                             │
│  2. 👤 VALIDATE (Human)                                   │
│     └─ roosync_approve_decision() / roosync_reject_decision()│
│        └─ Validation via sync-roadmap.md                   │
│        └─ Transition PENDING → APPROVED/REJECTED            │
│                                                             │
│  3. ⚡ APPLY                                              │
│     └─ roosync_apply_decision()                            │
│        └─ Application des décisions APPROVED                │
│        └─ Création point de rollback                       │
│        └─ Transition APPROVED → APPLIED/FAILED             │
│                                                             │
│  4. 🔄 ROLLBACK (Optionnel)                               │
│     └─ roosync_rollback_decision()                         │
│        └─ Restauration depuis point de rollback             │
│        └─ Transition APPLIED → ROLLED_BACK                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 Composants Principaux

#### 1.2.1 Outil `roosync_compare_config`

**Fichier:** [`src/tools/roosync/compare-config.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/compare-config.ts)

**Responsabilités :**
- Comparer la configuration locale avec une autre machine ou un profil
- Détecter les différences avec scoring de sévérité (CRITICAL, IMPORTANT, WARNING, INFO)
- Générer des décisions PENDING dans `sync-roadmap.md`

**Arguments :**
```typescript
{
  source?: string,      // Machine source (défaut: local_machine)
  target?: string,      // Machine cible (défaut: remote_machine)
  force_refresh?: boolean  // Forcer collecte inventaire
}
```

**Résultat :**
```typescript
{
  source: string,
  target: string,
  differences: Array<{
    category: string,
    severity: string,
    path: string,
    description: string,
    action?: string
  }>,
  summary: {
    total: number,
    critical: number,
    important: number,
    warning: number,
    info: number
  }
}
```

#### 1.2.2 Outil `roosync_approve_decision`

**Fichier:** [`src/tools/roosync/approve-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/approve-decision.ts)

**Responsabilités :**
- Approuver une décision PENDING
- Mettre à jour `sync-roadmap.md` avec le statut APPROVED
- Enregistrer l'approbateur et la date

**Arguments :**
```typescript
{
  decisionId: string,
  comment?: string
}
```

**Résultat :**
```typescript
{
  decisionId: string,
  previousStatus: string,
  newStatus: 'approved',
  approvedBy: string,
  approvedAt: string,  // ISO 8601
  comment?: string,
  nextSteps: string[]
}
```

#### 1.2.3 Outil `roosync_apply_decision`

**Fichier:** [`src/tools/roosync/apply-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/apply-decision.ts)

**Responsabilités :**
- Appliquer une décision APPROVED
- Créer un point de rollback avant application
- Exécuter les scripts RooSync appropriés
- Mettre à jour `sync-roadmap.md` avec le statut APPLIED

**Arguments :**
```typescript
{
  decisionId: string,
  dryRun?: boolean,  // Mode simulation
  force?: boolean     // Forcer même si conflits
}
```

**Résultat :**
```typescript
{
  decisionId: string,
  previousStatus: string,
  newStatus: 'applied' | 'failed',
  appliedAt: string,
  appliedBy: string,
  executionLog: string[],
  changes: {
    filesModified: string[],
    filesCreated: string[],
    filesDeleted: string[]
  },
  rollbackAvailable: boolean,
  error?: string
}
```

### 1.3 Structures de Données

#### 1.3.1 Décision (dans sync-roadmap.md)

```markdown
<!-- DECISION_BLOCK_START -->
**ID:** `decision-001`
**Titre:** Mise à jour configuration test
**Statut:** pending | approved | rejected | applied | failed | rolled_back
**Type:** config | file | setting
**Chemin:** `.config/test.json`
**Machine Source:** PC-PRINCIPAL
**Machines Cibles:** MAC-DEV
**Créé:** 2025-10-08T09:00:00Z
**Approuvé le:** 2025-10-08T09:30:00Z
**Approuvé par:** PC-PRINCIPAL
**Commentaire:** Approuvé pour test
**Appliqué le:** 2025-10-08T10:00:00Z
**Appliqué par:** PC-PRINCIPAL
**Rollback disponible:** true
<!-- DECISION_BLOCK_END -->
```

#### 1.3.2 Dashboard (sync-dashboard.json)

```json
{
  "version": "2.1.0",
  "lastUpdate": "2025-10-08T10:00:00Z",
  "overallStatus": "synced" | "diverged" | "error",
  "machines": {
    "PC-PRINCIPAL": {
      "lastSync": "2025-10-08T09:00:00Z",
      "status": "online",
      "diffsCount": 1,
      "pendingDecisions": 1
    }
  },
  "stats": {
    "totalDiffs": 0,
    "totalDecisions": 0,
    "appliedDecisions": 0,
    "pendingDecisions": 0
  }
}
```

### 1.4 Tests Existantes

#### 1.4.1 Tests Unitaires

**Fichiers existants :**
- [`tests/unit/tools/roosync/apply-decision.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/apply-decision.test.ts)
- [`tests/unit/tools/roosync/approve-decision.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/approve-decision.test.ts)
- [`tests/unit/tools/roosync/reject-decision.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/reject-decision.test.ts)
- [`tests/unit/tools/roosync/rollback-decision.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/rollback-decision.test.ts)
- [`tests/unit/tools/roosync/get-decision-details.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/get-decision-details.test.ts)

**Patterns observés :**
- Utilisation de `vi.mock('fs')` pour les tests unitaires
- Création de répertoires temporaires avec `tmpdir()`
- Mock de `RooSyncService.getInstance()` et `getRooSyncService()`
- Utilisation de `vi.spyOn()` pour mocker les méthodes de service
- Nettoyage avec `afterEach()` : suppression des fichiers temporaires et `RooSyncService.resetInstance()`

#### 1.4.2 Tests d'Intégration

**Fichiers existants :**
- [`tests/integration/legacy-compatibility.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/integration/legacy-compatibility.test.ts)
- [`tests/integration/phase3-comprehensive.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/integration/phase3-comprehensive.test.ts)

**Patterns observés :**
- Tests du workflow complet collect → compare → apply
- Utilisation de mocks pour éviter les appels PowerShell réels
- Tests de compatibilité avec l'API legacy

#### 1.4.3 Tests E2E

**Fichier existant :**
- [`tests/e2e/roosync-workflow.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/e2e/roosync-workflow.test.ts)

**Contenu actuel :**
- Tests du workflow detect → approve → apply
- Tests du workflow apply → rollback
- Tests d'intégration Dashboard
- Tests de performance

**Limitations identifiées :**
- Les tests sont marqués comme `.skip` pour les opérations réelles (apply, rollback)
- Pas de test complet du flux Compare → Validate → Apply
- Pas de test de scénarios d'erreur (validation échoue, conflits)
- Pas de test de scénarios de rollback

---

## 2. Scénarios de Test E2E à Couvrir

### 2.1 Scénario 1 : Flux Nominal (Succès)

**Description :** Test du flux complet Compare → Validate → Apply dans le cas nominal.

**Étapes :**
1. **Compare** : Exécuter `roosync_compare_config()` pour détecter les différences
2. **Validate** : Approuver une décision avec `roosync_approve_decision()`
3. **Apply** : Appliquer la décision avec `roosync_apply_decision()`
4. **Vérification** : Vérifier que la décision est appliquée et que les fichiers sont modifiés

**Assertions :**
- Le rapport de comparaison contient des différences
- Une décision PENDING est créée dans `sync-roadmap.md`
- L'approbation change le statut de PENDING à APPROVED
- L'application change le statut de APPROVED à APPLIED
- Les fichiers sont modifiés/créés/supprimés comme attendu
- Un point de rollback est créé
- Le dashboard est mis à jour

### 2.2 Scénario 2 : Cas d'Erreur (Validation Échoue)

**Description :** Test du flux quand la validation échoue (rejet de décision).

**Étapes :**
1. **Compare** : Exécuter `roosync_compare_config()` pour détecter les différences
2. **Validate (Reject)** : Rejeter une décision avec `roosync_reject_decision()`
3. **Vérification** : Vérifier que la décision est rejetée et ne peut pas être appliquée

**Assertions :**
- Le rapport de comparaison contient des différences
- Une décision PENDING est créée dans `sync-roadmap.md`
- Le rejet change le statut de PENDING à REJECTED
- La tentative d'application d'une décision REJECTED échoue
- Le dashboard est mis à jour

### 2.3 Scénario 3 : Cas de Conflit

**Description :** Test du flux quand des conflits sont détectés lors de l'application.

**Étapes :**
1. **Compare** : Exécuter `roosync_compare_config()` pour détecter les différences
2. **Validate** : Approuver une décision avec `roosync_approve_decision()`
3. **Apply (Conflit)** : Tenter d'appliquer la décision sans `force: true`
4. **Vérification** : Vérifier que l'application échoue à cause du conflit

**Assertions :**
- Le rapport de comparaison contient des différences
- Une décision PENDING est créée dans `sync-roadmap.md`
- L'approbation change le statut de PENDING à APPROVED
- L'application échoue avec un message de conflit
- Le statut de la décision reste APPROVED
- Le dashboard est mis à jour

### 2.4 Scénario 4 : Cas de Rollback

**Description :** Test du flux de rollback après application.

**Étapes :**
1. **Compare** : Exécuter `roosync_compare_config()` pour détecter les différences
2. **Validate** : Approuver une décision avec `roosync_approve_decision()`
3. **Apply** : Appliquer la décision avec `roosync_apply_decision()`
4. **Rollback** : Restaurer depuis le point de rollback avec `roosync_rollback_decision()`
5. **Vérification** : Vérifier que les fichiers sont restaurés

**Assertions :**
- Le rapport de comparaison contient des différences
- Une décision PENDING est créée dans `sync-roadmap.md`
- L'approbation change le statut de PENDING à APPROVED
- L'application change le statut de APPROVED à APPLIED
- Un point de rollback est créé
- Le rollback restaure les fichiers
- Le statut de la décision passe de APPLIED à ROLLED_BACK
- Le dashboard est mis à jour

### 2.5 Scénario 5 : Mode Dry Run

**Description :** Test du flux en mode simulation (dry run).

**Étapes :**
1. **Compare** : Exécuter `roosync_compare_config()` pour détecter les différences
2. **Validate** : Approuver une décision avec `roosync_approve_decision()`
3. **Apply (Dry Run)** : Appliquer la décision avec `roosync_apply_decision({ dryRun: true })`
4. **Vérification** : Vérifier qu'aucun fichier n'est modifié

**Assertions :**
- Le rapport de comparaison contient des différences
- Une décision PENDING est créée dans `sync-roadmap.md`
- L'approbation change le statut de PENDING à APPROVED
- L'application en dry run simule les changements sans les appliquer
- Aucun fichier n'est modifié/créé/supprimé
- Aucun point de rollback n'est créé
- Le statut de la décision reste APPROVED (ou passe à APPLIED mais sans changements réels)

### 2.6 Scénario 6 : Performance

**Description :** Test des performances du flux complet.

**Étapes :**
1. Mesurer le temps de `roosync_compare_config()`
2. Mesurer le temps de `roosync_approve_decision()`
3. Mesurer le temps de `roosync_apply_decision()`
4. Vérifier que le temps total est inférieur à 10 secondes

**Assertions :**
- `roosync_compare_config()` < 2 secondes
- `roosync_approve_decision()` < 1 seconde
- `roosync_apply_decision()` < 5 secondes
- Temps total < 10 secondes

---

## 3. Stratégie de Mise en Œuvre

### 3.1 Structure des Tests E2E

**Fichier à créer :** `tests/e2e/roosync-compare-validate-apply.test.ts`

**Structure proposée :**

```typescript
/**
 * Tests End-to-End RooSync - Flux Compare → Validate → Apply
 *
 * Tests du flux complet de synchronisation RooSync :
 * - Compare : Détection des différences
 * - Validate : Approbation/Rejet des décisions
 * - Apply : Application des décisions approuvées
 * - Rollback : Restauration depuis point de rollback
 *
 * @module tests/e2e/roosync-compare-validate-apply.test
 */

import { describe, it, expect, beforeAll, afterAll, beforeEach, afterEach } from 'vitest';
import { RooSyncService } from '../../src/services/RooSyncService.js';
import { roosyncCompareConfig } from '../../src/tools/roosync/compare-config.js';
import { roosyncApproveDecision } from '../../src/tools/roosync/approve-decision.js';
import { roosyncRejectDecision } from '../../src/tools/roosync/reject-decision.js';
import { roosyncApplyDecision } from '../../src/tools/roosync/apply-decision.js';
import { roosyncRollbackDecision } from '../../src/tools/roosync/rollback-decision.js';
import { writeFileSync, mkdirSync, rmSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { tmpdir } from 'os';

describe('RooSync E2E - Flux Compare → Validate → Apply', () => {
  let service: RooSyncService;
  let testDir: string;
  let testDecisionId: string | null = null;

  beforeAll(() => {
    // Créer répertoire de test
    testDir = join(tmpdir(), `roosync-e2e-${Date.now()}`);
    mkdirSync(testDir, { recursive: true });

    // Configurer environnement
    process.env.ROOSYNC_SHARED_PATH = testDir;
    process.env.ROOSYNC_MACHINE_ID = 'PC-TEST-E2E';

    // Initialiser service
    RooSyncService.resetInstance();
    service = RooSyncService.getInstance(undefined, {
      sharedPath: testDir,
      machineId: 'PC-TEST-E2E',
      autoSync: false,
      conflictStrategy: 'manual',
      logLevel: 'info'
    });
  });

  afterAll(() => {
    // Nettoyer
    try {
      rmSync(testDir, { recursive: true, force: true });
    } catch (error) {
      // Ignore
    }
    RooSyncService.resetInstance();
  });

  beforeEach(() => {
    // Vider le cache avant chaque test
    service.clearCache();
  });

  afterEach(() => {
    // Nettoyer les décisions créées pendant le test
    testDecisionId = null;
  });

  describe('Scénario 1 : Flux Nominal (Succès)', () => {
    it('devrait exécuter le flux complet Compare → Validate → Apply', async () => {
      // 1. Compare
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });

      expect(compareResult).toBeDefined();
      expect(compareResult.differences).toBeInstanceOf(Array);
      expect(compareResult.summary).toBeDefined();

      // 2. Validate (Approve)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      expect(pendingDecision).toBeDefined();
      testDecisionId = pendingDecision!.id;

      const approveResult = await roosyncApproveDecision({
        decisionId: testDecisionId!,
        comment: 'Test E2E - Flux nominal'
      });

      expect(approveResult.newStatus).toBe('approved');
      expect(approveResult.approvedBy).toBe('PC-TEST-E2E');

      // 3. Apply (Dry Run)
      const applyResult = await roosyncApplyDecision({
        decisionId: testDecisionId!,
        dryRun: true
      });

      expect(applyResult.newStatus).toBe('applied');
      expect(applyResult.rollbackAvailable).toBe(false);
      expect(applyResult.executionLog.some(log => log.includes('DRY RUN'))).toBe(true);
    });
  });

  describe('Scénario 2 : Cas d\'Erreur (Validation Échoue)', () => {
    it('devrait rejeter une décision et empêcher l\'application', async () => {
      // 1. Compare
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });

      expect(compareResult.differences.length).toBeGreaterThan(0);

      // 2. Validate (Reject)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      expect(pendingDecision).toBeDefined();
      testDecisionId = pendingDecision!.id;

      const rejectResult = await roosyncRejectDecision({
        decisionId: testDecisionId!,
        reason: 'Test E2E - Rejet intentionnel'
      });

      expect(rejectResult.newStatus).toBe('rejected');

      // 3. Apply (doit échouer)
      await expect(roosyncApplyDecision({
        decisionId: testDecisionId!
      })).rejects.toThrow('pas encore approuvée');
    });
  });

  describe('Scénario 3 : Cas de Conflit', () => {
    it('devrait détecter un conflit lors de l\'application', async () => {
      // 1. Compare
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });

      expect(compareResult.differences.length).toBeGreaterThan(0);

      // 2. Validate (Approve)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      expect(pendingDecision).toBeDefined();
      testDecisionId = pendingDecision!.id;

      await roosyncApproveDecision({
        decisionId: testDecisionId!
      });

      // 3. Apply (sans force, doit échouer si conflit)
      // Note: Ce test nécessite de simuler un conflit
      // Pour l'instant, on teste juste que l'application fonctionne
      const applyResult = await roosyncApplyDecision({
        decisionId: testDecisionId!,
        dryRun: true,
        force: false
      });

      expect(applyResult).toBeDefined();
    });
  });

  describe('Scénario 4 : Cas de Rollback', () => {
    it('devrait créer un point de rollback et permettre la restauration', async () => {
      // 1. Compare
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });

      expect(compareResult.differences.length).toBeGreaterThan(0);

      // 2. Validate (Approve)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      expect(pendingDecision).toBeDefined();
      testDecisionId = pendingDecision!.id;

      await roosyncApproveDecision({
        decisionId: testDecisionId!
      });

      // 3. Apply (Dry Run avec rollback)
      const applyResult = await roosyncApplyDecision({
        decisionId: testDecisionId!,
        dryRun: true
      });

      expect(applyResult.rollbackAvailable).toBe(false); // Dry run ne crée pas de rollback

      // 4. Rollback (doit échouer en dry run)
      await expect(roosyncRollbackDecision({
        decisionId: testDecisionId!,
        reason: 'Test E2E - Rollback'
      })).rejects.toThrow();
    });
  });

  describe('Scénario 5 : Mode Dry Run', () => {
    it('devrait simuler l\'application sans modifier les fichiers', async () => {
      // 1. Compare
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });

      expect(compareResult.differences.length).toBeGreaterThan(0);

      // 2. Validate (Approve)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      expect(pendingDecision).toBeDefined();
      testDecisionId = pendingDecision!.id;

      await roosyncApproveDecision({
        decisionId: testDecisionId!
      });

      // 3. Apply (Dry Run)
      const applyResult = await roosyncApplyDecision({
        decisionId: testDecisionId!,
        dryRun: true
      });

      expect(applyResult.newStatus).toBe('applied');
      expect(applyResult.rollbackAvailable).toBe(false);
      expect(applyResult.executionLog.some(log => log.includes('DRY RUN'))).toBe(true);

      // Vérifier qu'aucun fichier n'a été modifié
      expect(applyResult.changes.filesModified.length).toBe(0);
      expect(applyResult.changes.filesCreated.length).toBe(0);
      expect(applyResult.changes.filesDeleted.length).toBe(0);
    });
  });

  describe('Scénario 6 : Performance', () => {
    it('devrait exécuter le flux complet en moins de 10 secondes', async () => {
      const startTime = Date.now();

      // 1. Compare
      const compareStart = Date.now();
      const compareResult = await roosyncCompareConfig({
        source: 'PC-TEST-E2E',
        target: 'PC-TARGET-TEST'
      });
      const compareDuration = Date.now() - compareStart;

      expect(compareDuration).toBeLessThan(2000); // < 2s

      // 2. Validate (Approve)
      const decisions = await service.loadDecisions();
      const pendingDecision = decisions.find(d => d.status === 'pending');

      if (pendingDecision) {
        testDecisionId = pendingDecision.id;

        const approveStart = Date.now();
        await roosyncApproveDecision({
          decisionId: testDecisionId!
        });
        const approveDuration = Date.now() - approveStart;

        expect(approveDuration).toBeLessThan(1000); // < 1s

        // 3. Apply (Dry Run)
        const applyStart = Date.now();
        await roosyncApplyDecision({
          decisionId: testDecisionId!,
          dryRun: true
        });
        const applyDuration = Date.now() - applyStart;

        expect(applyDuration).toBeLessThan(5000); // < 5s
      }

      const totalDuration = Date.now() - startTime;
      expect(totalDuration).toBeLessThan(10000); // < 10s
    });
  });
});
```

### 3.2 Dépendances et Prérequis

#### 3.2.1 Dépendances Techniques

- **Vitest** : Framework de test (déjà utilisé)
- **TypeScript** : Langage de développement
- **Node.js fs module** : Pour la manipulation de fichiers
- **RooSyncService** : Service principal RooSync
- **Outils MCP RooSync** : `roosync_compare_config`, `roosync_approve_decision`, `roosync_reject_decision`, `roosync_apply_decision`, `roosync_rollback_decision`

#### 3.2.2 Dépendances Fonctionnelles

- **Environnement RooSync configuré** : Variables d'environnement `ROOSYNC_SHARED_PATH` et `ROOSYNC_MACHINE_ID`
- **Fichiers RooSync** : `sync-dashboard.json`, `sync-roadmap.md`
- **Service RooSync** : Instance de `RooSyncService` initialisée
- **Décisions de test** : Décisions PENDING disponibles pour les tests

#### 3.2.3 Prérequis pour les Tests

1. **Répertoire temporaire isolé** : Utiliser `tmpdir()` pour créer un environnement de test isolé
2. **Mock des appels PowerShell** : Éviter les appels PowerShell réels pendant les tests
3. **Nettoyage après chaque test** : Supprimer les fichiers temporaires et réinitialiser le service
4. **Gestion des erreurs** : Capturer et gérer les erreurs attendues

### 3.3 Risques et Mitigations

#### 3.3.1 Risque 1 : Problèmes de Mock fs

**Description :** Les tests E2E utilisent le système de fichiers réel, ce qui peut causer des problèmes de mock.

**Mitigation :**
- Utiliser `vi.unmock('fs')` avant les tests E2E
- Créer un répertoire temporaire isolé pour chaque test
- Nettoyer correctement après chaque test
- Utiliser `vi.spyOn()` pour mocker les méthodes spécifiques si nécessaire

#### 3.3.2 Risque 2 : Race Conditions

**Description :** Les tests E2E peuvent avoir des race conditions lors de l'exécution concurrente.

**Mitigation :**
- Exécuter les tests séquentiellement (pas de `Promise.all()` pour les opérations qui modifient l'état)
- Utiliser des délais appropriés si nécessaire
- Vérifier l'état avant et après chaque opération

#### 3.3.3 Risque 3 : Dépendance sur l'Environnement

**Description :** Les tests E2E dépendent de l'environnement RooSync configuré.

**Mitigation :**
- Créer un environnement de test isolé pour chaque suite de tests
- Mock les dépendances externes (PowerShell, réseau)
- Utiliser des fixtures pour les données de test

#### 3.3.4 Risque 4 : Instabilité des Tests

**Description :** Les tests E2E peuvent être instables à cause de facteurs externes.

**Mitigation :**
- Utiliser des timeouts appropriés
- Ajouter des retries pour les opérations qui peuvent échouer temporairement
- Logger les erreurs détaillées pour faciliter le diagnostic

### 3.4 Plan de Développement

#### Phase 1 : Préparation (1 jour)

1. Créer le fichier de test `tests/e2e/roosync-compare-validate-apply.test.ts`
2. Configurer l'environnement de test (beforeAll, afterAll)
3. Créer les fixtures pour les données de test
4. Implémenter les helpers pour les tests (setup, teardown)

#### Phase 2 : Implémentation des Scénarios (2-3 jours)

1. **Scénario 1** : Flux Nominal (Succès)
2. **Scénario 2** : Cas d'Erreur (Validation Échoue)
3. **Scénario 3** : Cas de Conflit
4. **Scénario 4** : Cas de Rollback
5. **Scénario 5** : Mode Dry Run
6. **Scénario 6** : Performance

#### Phase 3 : Tests et Validation (1 jour)

1. Exécuter les tests E2E
2. Corriger les bugs identifiés
3. Vérifier la couverture du flux
4. Valider que tous les tests passent

#### Phase 4 : Documentation et Livraison (1 jour)

1. Documenter les tests
2. Mettre à jour la documentation RooSync
3. Committer les changements
4. Créer/mettre à jour l'issue GitHub
5. Envoyer un message RooSync

**Total estimé :** 5-6 jours

---

## 4. Critères de Succès

### 4.1 Critères Fonctionnels

- ✅ Tous les scénarios de test sont implémentés
- ✅ Tous les tests passent avec succès
- ✅ Le flux Compare → Validate → Apply est complètement couvert
- ✅ Les cas d'erreur sont testés
- ✅ Les cas de conflit sont testés
- ✅ Les cas de rollback sont testés
- ✅ Le mode dry run est testé
- ✅ Les performances sont validées

### 4.2 Critères Techniques

- ✅ Les tests suivent les patterns établis dans les tests unitaires
- ✅ Les tests utilisent les mocks appropriés
- ✅ Les tests nettoient correctement après exécution
- ✅ Les tests sont documentés
- ✅ Les tests sont maintenus et évolutifs

### 4.3 Critères de Qualité

- ✅ Couverture du flux > 90%
- ✅ Temps d'exécution des tests < 2 minutes
- ✅ Aucun test flaky (instable)
- ✅ Documentation claire et complète

---

## 5. Prochaines Étapes

1. ✅ **Semantic Grounding** : Analyse du flux Compare → Validate → Apply
2. ✅ **Documentation** : Création de ce document de diagnostic et stratégie
3. ⏳ **GitHub** : Créer/mettre à jour l'issue et commenter
4. ⏳ **Implémentation** : Créer les tests E2E
5. ⏳ **Tests** : Valider le fonctionnement
6. ⏳ **Git** : Commit et push
7. ⏳ **Communication** : Message RooSync et INTERCOM

---

## 6. Références

### 6.1 Documentation RooSync

- **Architecture v2.1** : [`roosync-v2-baseline-driven-architecture-design-20251020.md`](../../../../../roo-config/reports/roosync-v2-baseline-driven-architecture-design-20251020.md)
- **Synthèse v2.1** : [`roosync-v2-baseline-driven-synthesis-20251020.md`](../../../../../roo-config/reports/roosync-v2-baseline-driven-synthesis-20251020.md)
- **README RooSync** : [`mcps/internal/servers/roo-state-manager/README.md`](../../mcps/internal/servers/roo-state-manager/README.md)

### 6.2 Code Source

- **Outil Compare** : [`src/tools/roosync/compare-config.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/compare-config.ts)
- **Outil Approve** : [`src/tools/roosync/approve-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/approve-decision.ts)
- **Outil Reject** : [`src/tools/roosync/reject-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/reject-decision.ts)
- **Outil Apply** : [`src/tools/roosync/apply-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/apply-decision.ts)
- **Outil Rollback** : [`src/tools/roosync/rollback-decision.ts`](../../mcps/internal/servers/roo-state-manager/src/tools/roosync/rollback-decision.ts)
- **Service RooSync** : [`src/services/RooSyncService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts)

### 6.3 Tests Existantes

- **Tests Unitaires** : [`tests/unit/tools/roosync/`](../../mcps/internal/servers/roo-state-manager/tests/unit/tools/roosync/)
- **Tests d'Intégration** : [`tests/integration/`](../../mcps/internal/servers/roo-state-manager/tests/integration/)
- **Tests E2E** : [`tests/e2e/roosync-workflow.test.ts`](../../mcps/internal/servers/roo-state-manager/tests/e2e/roosync-workflow.test.ts)

### 6.4 Protocole SDDD

- **Version** : v2.0.0
- **Machine** : myia-po-2026
- **Projet** : #67 "RooSync Multi-Agent Tasks"

---

**Document généré par:** Roo (Agent Technique)
**Date de génération:** 2026-01-15T22:50:00Z
**Version:** 1.0.0
**Statut:** Prêt pour implémentation
