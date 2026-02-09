# Guide d'Utilisation des Outils MCP RooSync

**Version :** 1.0.0  
**Date :** 2025-01-11  
**Tâche :** 40 - Tests End-to-End RooSync Multi-Machines  
**Phase :** 4.1 - Guide utilisation

---

## Table des Matières

1. [Introduction](#introduction)
2. [Configuration Préalable](#configuration-préalable)
3. [Les 8 Outils RooSync](#les-8-outils-roosync)
4. [Workflows Courants](#workflows-courants)
5. [Exemples Pratiques](#exemples-pratiques)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Introduction

Les 8 outils MCP RooSync permettent de gérer la synchronisation multi-machines via une interface programmatique unifiée. Ils s'intègrent parfaitement avec l'architecture PowerShell RooSync existante.

### Vue d'Ensemble

**Outils disponibles :**
1. `roosync_get_status` - État synchronisation
2. `roosync_list_diffs` - Lister différences
3. `roosync_list_decisions` - Lister décisions
4. `roosync_get_decision` - Détail d'une décision
5. `roosync_approve_decision` - Approuver une décision
6. `roosync_reject_decision` - Rejeter une décision
7. `roosync_apply_decision` - Appliquer une décision
8. `roosync_rollback_decision` - Annuler une décision

**Architecture :**
- Service Singleton `RooSyncService`
- Intégration PowerShell via `PowerShellExecutor`
- Cache intelligent (TTL 30s)
- Gestion erreurs robuste

---

## Configuration Préalable

### 1. Variables d'Environnement

```bash
# Fichier .env à la racine de roo-state-manager
SHARED_STATE_PATH="G:\Mon Drive\MyIA\Dev\roo-code\RooSync"
ROO_HOME="d:/roo-extensions"
```

### 2. Structure Fichiers RooSync

```
${SHARED_STATE_PATH}/
├── sync-roadmap.md        # Décisions de synchronisation
├── sync-dashboard.json    # État des machines
├── sync-config.ref.json   # Configuration de référence
└── .rollback/             # Points de rollback
    └── <decision_id>_<timestamp>/
        ├── sync-config.ref.json
        ├── sync-roadmap.md
        └── metadata.json
```

### 3. Vérification

```bash
# Vérifier configuration
echo $env:SHARED_STATE_PATH

# Vérifier accessibilité
Test-Path $env:SHARED_STATE_PATH

# Vérifier fichiers RooSync
ls $env:SHARED_STATE_PATH
```

---

## Les 8 Outils RooSync

### 1. roosync_get_status

**Description :** Obtient l'état actuel de synchronisation pour la machine courante.

**Paramètres :**
- `includeMetrics` (optional, boolean) : Inclure métriques détaillées
- `targetMachine` (optional, string) : Filtrer par machine spécifique

**Exemple d'appel :**
```json
{
  "includeMetrics": true,
  "targetMachine": "PC-PRINCIPAL"
}
```

**Réponse :**
```json
{
  "machineId": "PC-PRINCIPAL",
  "overallStatus": "synchronized",
  "lastSync": "2025-01-11T10:30:00Z",
  "pendingDecisions": 2,
  "diffsCount": 5
}
```

**Cas d'usage :**
- Vérifier état avant synchronisation
- Monitoring automatique
- Dashboard de supervision

---

### 2. roosync_list_diffs

**Description :** Liste toutes les différences détectées entre machines.

**Paramètres :**
- `filterByType` (optional, string) : Filtrer par type
  - `"all"` : Toutes les différences (défaut)
  - `"config"` : Configurations seulement
  - `"files"` : Fichiers seulement
  - `"settings"` : Paramètres seulement

**Exemple d'appel :**
```json
{
  "filterByType": "config"
}
```

**Réponse :**
```json
{
  "totalDiffs": 5,
  "diffs": [
    {
      "type": "config",
      "path": "sync-config.json",
      "description": "Configuration locale différente de la référence",
      "machines": ["PC-PRINCIPAL", "PC-SECONDAIRE"]
    }
  ]
}
```

**Cas d'usage :**
- Audit pré-synchronisation
- Identification divergences
- Rapport de conformité

---

### 3. roosync_list_decisions

**Description :** Liste toutes les décisions de synchronisation avec filtres.

**Paramètres :**
- `status` (optional, string) : Filtrer par statut
  - `"pending"` : En attente d'approbation
  - `"approved"` : Approuvées
  - `"rejected"` : Rejetées
  - `"applied"` : Appliquées
  - `"rolled_back"` : Annulées
- `limit` (optional, number) : Nombre max de résultats
- `sortBy` (optional, string) : Critère de tri
  - `"timestamp"` : Par date (défaut)
  - `"machine"` : Par machine
  - `"type"` : Par type

**Exemple d'appel :**
```json
{
  "status": "pending",
  "limit": 10,
  "sortBy": "timestamp"
}
```

**Réponse :**
```json
{
  "totalDecisions": 2,
  "decisions": [
    {
      "id": "dec-12345-abcdef",
      "status": "pending",
      "title": "Différence configuration détectée",
      "type": "config",
      "machine": "PC-PRINCIPAL",
      "timestamp": "2025-01-11T10:00:00Z",
      "targetMachines": ["PC-PRINCIPAL"],
      "path": "sync-config.json"
    }
  ]
}
```

**Cas d'usage :**
- Workflow d'approbation
- Historique décisions
- Audit trail

---

### 4. roosync_get_decision

**Description :** Obtient les détails complets d'une décision spécifique.

**Paramètres :**
- `decisionId` (required, string) : ID unique de la décision

**Exemple d'appel :**
```json
{
  "decisionId": "dec-12345-abcdef"
}
```

**Réponse :**
```json
{
  "id": "dec-12345-abcdef",
  "status": "pending",
  "title": "Différence configuration détectée",
  "type": "config",
  "machine": "PC-PRINCIPAL",
  "timestamp": "2025-01-11T10:00:00Z",
  "targetMachines": ["PC-PRINCIPAL"],
  "path": "sync-config.json",
  "diff": "Configuration de référence vs Configuration locale:\n[LOCAL] ...",
  "context": {
    "computerInfo": { ... },
    "powershell": { ... }
  }
}
```

**Cas d'usage :**
- Review détaillée avant approbation
- Debugging problèmes sync
- Documentation changements

---

### 5. roosync_approve_decision

**Description :** Approuve une décision pour permettre son application.

**Paramètres :**
- `decisionId` (required, string) : ID de la décision à approuver
- `comment` (optional, string) : Commentaire d'approbation

**Exemple d'appel :**
```json
{
  "decisionId": "dec-12345-abcdef",
  "comment": "Changement validé par l'équipe"
}
```

**Réponse :**
```json
{
  "success": true,
  "decisionId": "dec-12345-abcdef",
  "newStatus": "approved",
  "message": "Décision approuvée avec succès"
}
```

**Cas d'usage :**
- Workflow validation manuelle
- Approbation batch de décisions
- Integration CI/CD

---

### 6. roosync_reject_decision

**Description :** Rejette une décision pour empêcher son application.

**Paramètres :**
- `decisionId` (required, string) : ID de la décision à rejeter
- `reason` (optional, string) : Raison du rejet

**Exemple d'appel :**
```json
{
  "decisionId": "dec-12345-abcdef",
  "reason": "Changement non conforme aux politiques"
}
```

**Réponse :**
```json
{
  "success": true,
  "decisionId": "dec-12345-abcdef",
  "newStatus": "rejected",
  "message": "Décision rejetée"
}
```

**Cas d'usage :**
- Refus changements non désirés
- Gestion exceptions
- Audit négatif

---

### 7. roosync_apply_decision

**Description :** Applique une décision approuvée via PowerShell `Apply-Decisions`.

**Paramètres :**
- `decisionId` (required, string) : ID de la décision à appliquer
- `dryRun` (optional, boolean) : Simulation sans modification
- `force` (optional, boolean) : Forcer application même si déjà appliquée
- `createRollback` (optional, boolean) : Créer point rollback avant (défaut: true)

**Exemple d'appel :**
```json
{
  "decisionId": "dec-12345-abcdef",
  "dryRun": false,
  "force": false,
  "createRollback": true
}
```

**Réponse :**
```json
{
  "success": true,
  "decisionId": "dec-12345-abcdef",
  "logs": [
    "Configuration de référence mise à jour avec succès.",
    "La feuille de route a été mise à jour et la décision a été archivée."
  ],
  "changes": {
    "filesModified": ["sync-config.ref.json"],
    "filesCreated": [],
    "filesDeleted": []
  },
  "executionTime": 3542,
  "rollbackPointCreated": true
}
```

**Cas d'usage :**
- Application manuelle validée
- Déploiement automatisé
- Tests en dryRun

---

### 8. roosync_rollback_decision

**Description :** Annule une décision appliquée en restaurant depuis le rollback point.

**Paramètres :**
- `decisionId` (required, string) : ID de la décision à annuler

**Exemple d'appel :**
```json
{
  "decisionId": "dec-12345-abcdef"
}
```

**Réponse :**
```json
{
  "success": true,
  "decisionId": "dec-12345-abcdef",
  "restoredFiles": [
    "sync-config.ref.json",
    "sync-roadmap.md"
  ],
  "logs": [
    "Restauré depuis 2025-01-11T10-30-00Z",
    "Restauré: sync-config.ref.json",
    "Restauré: sync-roadmap.md"
  ]
}
```

**Cas d'usage :**
- Annulation changements problématiques
- Retour arrière d'urgence
- Tests réversibilité

---

## Workflows Courants

### Workflow 1 : Synchronisation Manuelle Complète

**Objectif :** Détecter, approuver et appliquer les changements manuellement.

```bash
# 1. Vérifier état
roosync_get_status { includeMetrics: true }

# 2. Lister différences
roosync_list_diffs { filterByType: "all" }

# 3. Lister décisions pending
roosync_list_decisions { status: "pending" }

# 4. Examiner détails d'une décision
roosync_get_decision { decisionId: "dec-123" }

# 5. Approuver la décision
roosync_approve_decision { 
  decisionId: "dec-123",
  comment: "Validé" 
}

# 6. Appliquer la décision
roosync_apply_decision { 
  decisionId: "dec-123",
  dryRun: false,
  createRollback: true 
}
```

**Temps estimé :** 5-10 minutes

---

### Workflow 2 : Application avec Rollback

**Objectif :** Appliquer un changement avec possibilité de rollback.

```bash
# 1. Appliquer décision
roosync_apply_decision { 
  decisionId: "dec-456",
  createRollback: true 
}

# 2. Vérifier résultat
roosync_get_status {}

# 3. Si problème : rollback
roosync_rollback_decision { 
  decisionId: "dec-456" 
}
```

**Temps estimé :** 2-5 minutes

---

### Workflow 3 : Test en DryRun

**Objectif :** Simuler application sans modifier l'état.

```bash
# 1. Test application
roosync_apply_decision { 
  decisionId: "dec-789",
  dryRun: true 
}

# 2. Analyser logs simulés

# 3. Si OK : appliquer réellement
roosync_apply_decision { 
  decisionId: "dec-789",
  dryRun: false 
}
```

**Temps estimé :** 3-5 minutes

---

### Workflow 4 : Audit et Reporting

**Objectif :** Générer rapport de conformité.

```bash
# 1. État global
roosync_get_status { includeMetrics: true }

# 2. Toutes les différences
roosync_list_diffs { filterByType: "all" }

# 3. Historique décisions
roosync_list_decisions { 
  limit: 100,
  sortBy: "timestamp" 
}

# 4. Générer rapport (script personnalisé)
```

**Temps estimé :** 1-2 minutes

---

## Exemples Pratiques

### Exemple 1 : Script Automatisation Quotidienne

```powershell
# sync-daily.ps1
# Vérifier et appliquer automatiquement les décisions approuvées

# 1. Statut
$status = Invoke-RooSyncTool "roosync_get_status" @{
    includeMetrics = $true
}

Write-Host "Pending decisions: $($status.pendingDecisions)"

# 2. Lister pending
$decisions = Invoke-RooSyncTool "roosync_list_decisions" @{
    status = "pending"
    limit = 10
}

foreach ($decision in $decisions.decisions) {
    Write-Host "Processing: $($decision.id) - $($decision.title)"
    
    # 3. Auto-approve si type=config
    if ($decision.type -eq "config") {
        Invoke-RooSyncTool "roosync_approve_decision" @{
            decisionId = $decision.id
            comment = "Auto-approved by daily sync"
        }
        
        # 4. Appliquer
        $result = Invoke-RooSyncTool "roosync_apply_decision" @{
            decisionId = $decision.id
            dryRun = $false
            createRollback = $true
        }
        
        if ($result.success) {
            Write-Host "✅ Applied successfully"
        } else {
            Write-Host "❌ Failed: $($result.error)"
        }
    }
}
```

---

### Exemple 2 : Validation Interactive

```typescript
// interactive-sync.ts
import { RooSyncService } from './services/RooSyncService';

async function interactiveSync() {
  const service = RooSyncService.getInstance();
  
  // 1. Lister décisions pending
  const decisions = await service.loadPendingDecisions();
  
  console.log(`${decisions.length} décisions en attente`);
  
  for (const decision of decisions) {
    console.log(`\n${decision.id}: ${decision.title}`);
    console.log(`Type: ${decision.type}`);
    console.log(`Machine: ${decision.machine}`);
    
    // 2. Demander validation utilisateur
    const approved = await askUser(`Approuver ? (o/n)`);
    
    if (approved) {
      // 3. Appliquer
      const result = await service.executeDecision(decision.id, {
        dryRun: false,
        force: false
      });
      
      console.log(result.success ? '✅ Appliqué' : '❌ Échec');
    }
  }
}
```

---

## Troubleshooting

### Problème 1 : "Decision not found"

**Cause :** ID décision invalide ou décision déjà archivée.

**Solution :**
```bash
# Vérifier décisions disponibles
roosync_list_decisions { status: "all" }

# Vérifier ID exact
roosync_get_decision { decisionId: "<ID>" }
```

---

### Problème 2 : "PowerShell execution failed"

**Cause :** PowerShell indisponible ou script en erreur.

**Solution :**
```bash
# Vérifier PowerShell
pwsh --version

# Vérifier SHARED_STATE_PATH
Test-Path $env:SHARED_STATE_PATH

# Tester manuellement
pwsh -c "& 'RooSync/src/sync-manager.ps1' -Action Status"
```

---

### Problème 3 : "Timeout dépassé"

**Cause :** Opération trop longue (> 60s).

**Solution :**
- Vérifier Google Drive synchronisé
- Réduire taille fichiers sync
- Augmenter timeout dans PowerShellExecutor

---

### Problème 4 : "Rollback point not found"

**Cause :** Pas de rollback créé avant application.

**Solution :**
```bash
# Toujours créer rollback
roosync_apply_decision { 
  decisionId: "dec-123",
  createRollback: true  # Important !
}
```

---

## Best Practices

### 1. Toujours Utiliser DryRun d'Abord

```bash
# ✅ Bon
roosync_apply_decision { decisionId: "dec-123", dryRun: true }
# Analyser résultat
roosync_apply_decision { decisionId: "dec-123", dryRun: false }

# ❌ Mauvais
roosync_apply_decision { decisionId: "dec-123" }  # Direct sans test
```

---

### 2. Créer Rollback Points Systématiquement

```bash
# ✅ Bon
roosync_apply_decision { 
  decisionId: "dec-123",
  createRollback: true 
}

# ❌ Mauvais
roosync_apply_decision { 
  decisionId: "dec-123",
  createRollback: false  # Dangereux !
}
```

---

### 3. Valider État Après Application

```bash
# Application
roosync_apply_decision { decisionId: "dec-123" }

# ✅ Vérifier immédiatement
roosync_get_status {}
roosync_list_diffs {}
```

---

### 4. Commenter Approbations

```bash
# ✅ Bon
roosync_approve_decision { 
  decisionId: "dec-123",
  comment: "Validé par équipe ops - Ticket JIRA-456" 
}

# ❌ Mauvais
roosync_approve_decision { decisionId: "dec-123" }  # Sans contexte
```

---

### 5. Utiliser Filtres pour Performance

```bash
# ✅ Bon
roosync_list_diffs { filterByType: "config" }  # Ciblé

# ❌ Mauvais
roosync_list_diffs { filterByType: "all" }  # Trop large si inutile
```

---

## Annexes

### A. Codes Erreur Courants

| Code | Description | Solution |
|------|-------------|----------|
| `FILE_NOT_FOUND` | Fichier RooSync manquant | Vérifier SHARED_STATE_PATH |
| `DECISION_NOT_FOUND` | Décision introuvable | Vérifier ID décision |
| `MACHINE_NOT_FOUND` | Machine pas dans dashboard | Initialiser workspace |
| `ROLLBACK_CREATION_FAILED` | Échec création rollback | Vérifier permissions écriture |
| `POWERSHELL_EXECUTION_FAILED` | Script PowerShell en erreur | Voir logs PowerShell |

---

### B. Limites et Restrictions

**Timeouts :**
- `executeDecision` : 60s max
- `createRollbackPoint` : 30s max
- `restoreFromRollbackPoint` : 60s max

**Cache :**
- TTL : 30 secondes
- Invalidation automatique après modification

**Concurrence :**
- 1 opération à la fois recommandé
- Pas de locking multi-machines natif

---

### C. Ressources

**Documentation :**
- Plan intégration : [`docs/integration/12-plan-integration-e2e.md`](12-plan-integration-e2e.md)
- Résultats tests : [`docs/integration/13-resultats-tests-e2e.md`](13-resultats-tests-e2e.md)

**Code Source :**
- Service : [`mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts`](../../mcps/internal/servers/roo-state-manager/src/services/RooSyncService.ts)
- PowerShell Executor : [`mcps/internal/servers/roo-state-manager/src/services/PowerShellExecutor.ts`](../../mcps/internal/servers/roo-state-manager/src/services/PowerShellExecutor.ts)

**Tests :**
- Tests unitaires : [`mcps/internal/servers/roo-state-manager/tests/unit/services/`](../../mcps/internal/servers/roo-state-manager/tests/unit/services/)
- Tests E2E : [`mcps/internal/servers/roo-state-manager/tests/e2e/`](../../mcps/internal/servers/roo-state-manager/tests/e2e/)

---

**Document créé par :** Tâche 40 Phase 4.1  
**Dernière mise à jour :** 2025-01-11  
**Statut :** ✅ Complet et opérationnel