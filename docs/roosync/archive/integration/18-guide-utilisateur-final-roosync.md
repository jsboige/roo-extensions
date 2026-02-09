# Guide Utilisateur Final - RooSync MCP Tools

**Version** : 1.0  
**Date** : 12 octobre 2025  
**Auteur** : Roo AI Assistant  
**Audience** : Développeurs, Agents IA, Administrateurs système

---

## Introduction

Ce guide vous permet de maîtriser l'utilisation des **8 outils MCP RooSync** pour gérer la synchronisation multi-machines de manière programmatique via des agents IA ou des scripts.

### Qu'est-ce que RooSync ?

**RooSync** est un système PowerShell de synchronisation bidirectionnelle multi-machines qui maintient la cohérence de fichiers de configuration et scripts entre plusieurs environnements de travail.

### Qu'apportent les outils MCP ?

Les **8 outils MCP** permettent aux agents IA d'orchestrer RooSync programmatiquement :
- 📊 **Consulter** l'état de synchronisation en temps réel
- 🔍 **Analyser** les différences détectées entre machines
- ✅ **Approuver** ou ❌ **rejeter** des décisions de changement
- ⚡ **Exécuter** des synchronisations de fichiers
- ↩️ **Annuler** des changements via rollback

---

## Prérequis

### Installation et Configuration

#### 1. RooSync v2.0.0 Installé

Vérifier la version RooSync :
```powershell
# Dans le répertoire RooSync
Get-Content .\CHANGELOG.md | Select-String "v2.0.0"
```

#### 2. Serveur MCP roo-state-manager Configuré

Vérifier le serveur MCP :
```bash
# Vérifier que le serveur est actif
cd mcps/internal/servers/roo-state-manager
npm test
```

#### 3. Variables d'Environnement

Créer `.env` dans `mcps/internal/servers/roo-state-manager/` :

```env
# Chemin vers répertoire partagé RooSync
ROOSYNC_SHARED_PATH=D:/roo-extensions/RooSync

# Chemin vers dashboard de synchronisation
ROOSYNC_DASHBOARD_PATH=D:/roo-extensions/RooSync/sync-dashboard.json

# Chemin vers roadmap des décisions
ROOSYNC_ROADMAP_PATH=D:/roo-extensions/RooSync/sync-roadmap.md

# Chemin vers configuration de synchronisation
ROOSYNC_CONFIG_PATH=D:/roo-extensions/RooSync/sync-config.json

# Timeout exécution PowerShell (millisecondes)
ROOSYNC_TIMEOUT=30000
```

#### 4. PowerShell 7+ et Node.js 18+

Vérifier les versions :
```powershell
pwsh --version  # PowerShell 7.x.x
node --version  # v18.x.x ou supérieur
```

---

## Vue d'Ensemble des 8 Outils

### Catégorisation par Usage

| Outil | Catégorie | Usage Principal | Fréquence |
|-------|-----------|-----------------|-----------|
| [`roosync_get_status`](#outil-1--roosync_get_status) | 📊 Essentiel | Obtenir état synchronisation | Élevée |
| [`roosync_compare_config`](#outil-2--roosync_compare_config) | 📊 Essentiel | Comparer configurations | Moyenne |
| [`roosync_list_diffs`](#outil-3--roosync_list_diffs) | 📊 Essentiel | Lister différences | Élevée |
| [`roosync_approve_decision`](#outil-4--roosync_approve_decision) | ✅ Décision | Approuver changement | Moyenne |
| [`roosync_reject_decision`](#outil-5--roosync_reject_decision) | ❌ Décision | Rejeter changement | Faible |
| [`roosync_apply_decision`](#outil-6--roosync_apply_decision) | ⚡ Exécution | Appliquer changement | Moyenne |
| [`roosync_rollback_decision`](#outil-7--roosync_rollback_decision) | ↩️ Exécution | Annuler changement | Faible |
| [`roosync_get_decision_details`](#outil-8--roosync_get_decision_details) | 🔍 Exécution | Consulter détails | Moyenne |

### Architecture 5 Couches

```
Layer 5 (Exécution) → apply, rollback, get-details
Layer 4 (Décision) → approve, reject
Layer 3 (Présentation) → get-status, compare-config, list-diffs
Layer 2 (Services) → RooSyncService, PowerShellExecutor
Layer 1 (Configuration) → .env validation
```

---

## Workflows Recommandés

### Workflow 1 : Synchronisation Standard (Le Plus Courant)

**Objectif** : Détecter, analyser, approuver et appliquer un changement de manière contrôlée.

**Durée estimée** : 2-5 minutes

#### Étape 1 : Vérifier l'État Actuel 📊

**Outil** : `roosync_get_status`

**Appel** :
```json
{
  "includeMetrics": true
}
```

**Réponse attendue** :
```json
{
  "globalStatus": "differences_detected",
  "machines": [
    {
      "name": "MACHINE-A",
      "status": "up_to_date",
      "lastSync": "2025-10-12T10:00:00Z"
    },
    {
      "name": "MACHINE-B",
      "status": "needs_sync",
      "lastSync": "2025-10-11T15:30:00Z"
    }
  ],
  "pendingDecisions": 3,
  "metrics": {
    "totalMachines": 2,
    "upToDate": 1,
    "needsSync": 1,
    "errorState": 0
  }
}
```

**Interprétation** :
- ✅ `globalStatus: "differences_detected"` → Des changements sont détectés
- 📊 `pendingDecisions: 3` → 3 décisions en attente d'approbation
- 🔍 Passer à l'étape 2 pour lister les différences

---

#### Étape 2 : Lister les Différences 🔍

**Outil** : `roosync_list_diffs`

**Appel** :
```json
{
  "filterByType": "config",
  "filterByStatus": "pending"
}
```

**Réponse attendue** :
```json
{
  "differences": [
    {
      "id": "DECISION-001",
      "type": "config",
      "title": "Mise à jour roo-config.json",
      "description": "Ajout variable ROOSYNC_TIMEOUT",
      "sourceMachine": "MACHINE-A",
      "targetMachines": ["MACHINE-B"],
      "filesAffected": [
        {
          "path": "roo-config.json",
          "action": "update",
          "size": "2.5 KB"
        }
      ],
      "status": "pending",
      "priority": "medium",
      "createdAt": "2025-10-12T09:00:00Z"
    }
  ],
  "totalDifferences": 1,
  "summary": {
    "pending": 1,
    "approved": 0,
    "rejected": 0
  }
}
```

**Interprétation** :
- 📝 ID `DECISION-001` : Mise à jour configuration
- 🎯 Action : Update `roo-config.json` (2.5 KB)
- ⚠️ Statut : `pending` (nécessite approbation)

**Décision** : Cette modification semble légitime → Passer étape 3 pour examiner détails

---

#### Étape 3 : Examiner les Détails 🔬

**Outil** : `roosync_get_decision_details`

**Appel** :
```json
{
  "decisionId": "DECISION-001",
  "includeHistory": true,
  "includeLogs": false
}
```

**Réponse attendue** :
```json
{
  "decision": {
    "id": "DECISION-001",
    "type": "config",
    "title": "Mise à jour roo-config.json",
    "description": "Ajout variable ROOSYNC_TIMEOUT",
    "sourceMachine": "MACHINE-A",
    "targetMachines": ["MACHINE-B"],
    "filesAffected": [
      {
        "path": "roo-config.json",
        "action": "update",
        "changes": [
          {
            "line": 15,
            "before": "// Configuration timeout",
            "after": "// Configuration timeout\n\"ROOSYNC_TIMEOUT\": 30000"
          }
        ]
      }
    ],
    "status": "pending",
    "priority": "medium",
    "createdAt": "2025-10-12T09:00:00Z",
    "history": [
      {
        "timestamp": "2025-10-12T09:00:00Z",
        "action": "created",
        "actor": "system"
      }
    ]
  }
}
```

**Interprétation** :
- ✅ Changement ligne 15 : Ajout variable `ROOSYNC_TIMEOUT: 30000`
- 📊 Historique : Décision créée par système à 09:00
- ✅ Validation : Changement conforme → Passer étape 4 pour approuver

---

#### Étape 4 : Approuver la Décision ✅

**Outil** : `roosync_approve_decision`

**Appel** :
```json
{
  "decisionId": "DECISION-001",
  "comment": "Validation manuelle effectuée - Changement conforme aux standards"
}
```

**Réponse attendue** :
```json
{
  "success": true,
  "decisionId": "DECISION-001",
  "newStatus": "approved",
  "message": "Décision DECISION-001 approuvée avec succès",
  "approvedAt": "2025-10-12T10:15:00Z",
  "approvedBy": "agent-ia"
}
```

**Interprétation** :
- ✅ Statut changé : `pending` → `approved`
- 📅 Approuvé à : 10:15
- ⚡ Prêt pour application → Passer étape 5

---

#### Étape 5 : Appliquer la Décision ⚡

**Outil** : `roosync_apply_decision`

**Appel** :
```json
{
  "decisionId": "DECISION-001",
  "dryRun": false,
  "createRollbackPoint": true
}
```

**⚠️ Recommandation** : Toujours tester avec `dryRun: true` d'abord !

**Réponse attendue** :
```json
{
  "success": true,
  "decisionId": "DECISION-001",
  "executionTime": 2500,
  "logs": [
    "[INFO] Création rollback point ROLLBACK-DECISION-001",
    "[INFO] Exécution Apply-Decisions.ps1 -DecisionId DECISION-001",
    "[INFO] Synchronisation MACHINE-A → MACHINE-B",
    "[INFO] Fichier roo-config.json mis à jour sur MACHINE-B",
    "[SUCCESS] Synchronisation terminée avec succès"
  ],
  "changes": [
    {
      "machine": "MACHINE-B",
      "file": "roo-config.json",
      "action": "updated",
      "size": "2.5 KB → 2.6 KB"
    }
  ],
  "rollbackId": "ROLLBACK-DECISION-001",
  "appliedAt": "2025-10-12T10:20:00Z"
}
```

**Interprétation** :
- ✅ Synchronisation réussie en 2.5 secondes
- 📝 Rollback point créé : `ROLLBACK-DECISION-001`
- 📊 Changements appliqués sur MACHINE-B
- ✅ **Workflow terminé avec succès** 🎉

---

### Workflow 2 : Rollback d'une Synchronisation ↩️

**Objectif** : Annuler un changement appliqué suite à une erreur détectée.

**Durée estimée** : 1-2 minutes

#### Étape 1 : Identifier la Décision Appliquée

**Outil** : `roosync_list_diffs`

**Appel** :
```json
{
  "filterByStatus": "applied"
}
```

**Réponse** : Liste décisions avec `status: "applied"`

---

#### Étape 2 : Consulter les Détails et Logs

**Outil** : `roosync_get_decision_details`

**Appel** :
```json
{
  "decisionId": "DECISION-002",
  "includeLogs": true,
  "includeHistory": true
}
```

**Vérifier** :
- Logs d'exécution
- Changements effectués
- Rollback ID disponible

---

#### Étape 3 : Exécuter le Rollback ↩️

**Outil** : `roosync_rollback_decision`

**Appel** :
```json
{
  "decisionId": "DECISION-002",
  "reason": "Erreur détectée post-application : Fichier corrompu sur MACHINE-B"
}
```

**Réponse attendue** :
```json
{
  "success": true,
  "decisionId": "DECISION-002",
  "rollbackId": "ROLLBACK-DECISION-002",
  "executionTime": 1800,
  "logs": [
    "[INFO] Restauration depuis ROLLBACK-DECISION-002",
    "[INFO] Fichiers restaurés sur MACHINE-B",
    "[SUCCESS] Rollback terminé avec succès"
  ],
  "filesRestored": [
    {
      "machine": "MACHINE-B",
      "file": "roo-config.json",
      "status": "restored"
    }
  ],
  "rolledBackAt": "2025-10-12T10:30:00Z"
}
```

**Résultat** : ✅ Fichiers restaurés depuis rollback point, état initial récupéré

---

### Workflow 3 : Rejet de Changements Indésirables ❌

**Objectif** : Rejeter une décision sans l'appliquer (ex: changement non conforme).

**Durée estimée** : 1 minute

#### Étape 1 : Lister Décisions Pending

**Outil** : `roosync_list_diffs`

**Appel** :
```json
{
  "filterByStatus": "pending"
}
```

---

#### Étape 2 : Rejeter la Décision

**Outil** : `roosync_reject_decision`

**Appel** :
```json
{
  "decisionId": "DECISION-003",
  "reason": "Changement non conforme aux standards : Variable mal nommée"
}
```

**Réponse attendue** :
```json
{
  "success": true,
  "decisionId": "DECISION-003",
  "newStatus": "rejected",
  "message": "Décision DECISION-003 rejetée",
  "rejectedAt": "2025-10-12T10:40:00Z",
  "rejectedBy": "agent-ia",
  "reason": "Changement non conforme aux standards : Variable mal nommée"
}
```

**Résultat** : ❌ Décision marquée `rejected`, ne sera jamais appliquée

---

## Cas d'Usage Avancés

### Cas 1 : Comparaison Multi-Machines

**Objectif** : Comparer configurations entre plusieurs machines pour détecter incohérences.

**Outil** : `roosync_compare_config`

**Appel** :
```json
{
  "machines": ["MACHINE-A", "MACHINE-B", "MACHINE-C"],
  "includeFileHashes": true
}
```

**Réponse** :
```json
{
  "comparison": {
    "MACHINE-A": {
      "config": { ... },
      "fileHashes": {
        "roo-config.json": "abc123...",
        "roosync.ps1": "def456..."
      }
    },
    "MACHINE-B": {
      "config": { ... },
      "fileHashes": {
        "roo-config.json": "abc123...",
        "roosync.ps1": "ghi789..."
      }
    },
    "MACHINE-C": {
      "config": { ... },
      "fileHashes": {
        "roo-config.json": "xyz999...",
        "roosync.ps1": "def456..."
      }
    }
  },
  "differences": [
    {
      "file": "roo-config.json",
      "differingMachines": ["MACHINE-C"],
      "hash": "xyz999..."
    },
    {
      "file": "roosync.ps1",
      "differingMachines": ["MACHINE-B"],
      "hash": "ghi789..."
    }
  ]
}
```

**Interprétation** :
- ⚠️ MACHINE-C : `roo-config.json` diffère (hash xyz999)
- ⚠️ MACHINE-B : `roosync.ps1` diffère (hash ghi789)
- 🎯 Action : Créer décisions pour synchroniser

---

### Cas 2 : Dry-Run Avant Application (RECOMMANDÉ)

**Objectif** : Simuler une synchronisation sans modifier les fichiers.

**Outil** : `roosync_apply_decision`

**Appel avec dry-run** :
```json
{
  "decisionId": "DECISION-004",
  "dryRun": true,
  "createRollbackPoint": false
}
```

**Réponse** :
```json
{
  "success": true,
  "dryRun": true,
  "decisionId": "DECISION-004",
  "simulatedChanges": [
    {
      "machine": "MACHINE-B",
      "file": "scripts/deploy.ps1",
      "action": "would_update",
      "size": "5.2 KB → 5.8 KB"
    }
  ],
  "warnings": [],
  "estimatedTime": 3000,
  "message": "Simulation réussie - Aucun changement appliqué"
}
```

**Avantages** :
- ✅ Vérifier changements avant application réelle
- ✅ Détecter warnings potentiels
- ✅ Estimer temps d'exécution
- ✅ **TOUJOURS recommandé pour changements critiques**

---

### Cas 3 : Gestion Conflits Manuels

**Scénario** : Deux machines ont modifié le même fichier.

**Étape 1** : Détecter conflit via `roosync_list_diffs`

**Réponse** :
```json
{
  "differences": [
    {
      "id": "DECISION-005",
      "type": "conflict",
      "title": "Conflit détecté : roo-config.json",
      "description": "MACHINE-A et MACHINE-B ont modifié le fichier",
      "conflictType": "both_modified",
      "status": "pending",
      "priority": "high"
    }
  ]
}
```

**Étape 2** : Examiner détails conflit

**Outil** : `roosync_get_decision_details`

**Réponse** :
```json
{
  "decision": {
    "id": "DECISION-005",
    "conflictDetails": {
      "file": "roo-config.json",
      "machineA": {
        "changes": ["Ligne 10: Ajout variable X"],
        "timestamp": "2025-10-12T09:00:00Z"
      },
      "machineB": {
        "changes": ["Ligne 12: Ajout variable Y"],
        "timestamp": "2025-10-12T09:05:00Z"
      }
    }
  }
}
```

**Étape 3** : Résolution manuelle

**Options** :
1. ❌ **Rejeter** → Conserver versions actuelles
2. ✅ **Approuver avec merge manuel** → Créer version fusionnée
3. ⚡ **Forcer sync depuis MACHINE-A** → Écraser MACHINE-B

---

## Troubleshooting

### Erreur : "Decision not found"

**Message** :
```json
{
  "error": "Decision not found",
  "decisionId": "DECISION-999",
  "code": "DECISION_NOT_FOUND"
}
```

**Cause** : ID décision invalide ou décision supprimée du roadmap.

**Solution** :
1. Vérifier ID via `roosync_list_diffs`
2. Vérifier que décision n'a pas été archivée
3. Contrôler format ID (ex: `DECISION-001`, pas `DECISION_001`)

---

### Erreur : "PowerShell execution failed"

**Message** :
```json
{
  "error": "PowerShell execution failed",
  "exitCode": 1,
  "stderr": "Apply-Decisions.ps1 : File not found",
  "code": "POWERSHELL_ERROR"
}
```

**Cause** : Script PowerShell absent ou erreur exécution.

**Solutions** :
1. **Vérifier ROOSYNC_SHARED_PATH** dans `.env` :
   ```powershell
   Test-Path $env:ROOSYNC_SHARED_PATH\scripts\Apply-Decisions.ps1
   ```

2. **Tester manuellement script** :
   ```powershell
   cd D:\roo-extensions\RooSync\scripts
   .\Apply-Decisions.ps1 -DecisionId DECISION-001 -DryRun
   ```

3. **Vérifier permissions** :
   ```powershell
   Get-ExecutionPolicy
   # Doit être RemoteSigned ou Unrestricted
   ```

4. **Consulter logs PowerShell** :
   ```powershell
   Get-Content D:\roo-extensions\RooSync\logs\apply-decisions.log
   ```

---

### Erreur : "Timeout exceeded"

**Message** :
```json
{
  "error": "Timeout exceeded",
  "timeout": 30000,
  "code": "TIMEOUT_ERROR"
}
```

**Cause** : Script PowerShell trop long (> 30s par défaut).

**Solutions** :
1. **Augmenter timeout** dans `.env` :
   ```env
   ROOSYNC_TIMEOUT=60000  # 60 secondes
   ```

2. **Optimiser script PowerShell** : Réduire traitements lourds

3. **Diviser décision** : Créer plusieurs décisions plus petites

---

### Erreur : "Invalid decision status"

**Message** :
```json
{
  "error": "Invalid decision status",
  "currentStatus": "applied",
  "requiredStatus": "approved",
  "code": "INVALID_STATUS"
}
```

**Cause** : Transition état invalide (ex: tenter d'appliquer décision déjà applied).

**Solution** : Respecter workflow :
```
pending → approved → applied
pending → rejected (fin)
applied → (rollback) → pending
```

---

### Erreur : "Rollback point not found"

**Message** :
```json
{
  "error": "Rollback point not found",
  "rollbackId": "ROLLBACK-DECISION-002",
  "code": "ROLLBACK_NOT_FOUND"
}
```

**Cause** : Rollback point supprimé ou absent.

**Solutions** :
1. **Vérifier existence backup** :
   ```powershell
   Test-Path D:\roo-extensions\RooSync\rollbacks\ROLLBACK-DECISION-002
   ```

2. **Lister rollbacks disponibles** :
   ```powershell
   Get-ChildItem D:\roo-extensions\RooSync\rollbacks
   ```

3. **Si absent** : Rollback impossible, restaurer manuellement depuis backup système

---

### Erreur : "Configuration validation failed"

**Message** :
```json
{
  "error": "Configuration validation failed",
  "details": [
    {
      "field": "ROOSYNC_SHARED_PATH",
      "message": "Path does not exist"
    }
  ],
  "code": "CONFIG_VALIDATION_ERROR"
}
```

**Cause** : Variables `.env` invalides.

**Solution** :
1. **Valider `.env`** :
   ```bash
   cd mcps/internal/servers/roo-state-manager
   npm test -- roosync-config.test.ts
   ```

2. **Corriger chemins** dans `.env`

3. **Redémarrer serveur MCP**

---

## Bonnes Pratiques

### 1. Toujours utiliser `dryRun=true` en premier

**❌ Mauvaise pratique** :
```json
{
  "decisionId": "DECISION-001",
  "dryRun": false  // Application directe risquée
}
```

**✅ Bonne pratique** :
```json
// Étape 1 : Simulation
{
  "decisionId": "DECISION-001",
  "dryRun": true
}

// Étape 2 : Si simulation OK, appliquer
{
  "decisionId": "DECISION-001",
  "dryRun": false
}
```

---

### 2. Consulter détails avant approbation

**❌ Mauvaise pratique** :
```
list_diffs → approve → apply  // Risque : changements non examinés
```

**✅ Bonne pratique** :
```
list_diffs → get_decision_details → approve → apply
```

---

### 3. Documenter rejets avec raison explicite

**❌ Mauvaise pratique** :
```json
{
  "decisionId": "DECISION-003",
  "reason": ""  // Raison vide
}
```

**✅ Bonne pratique** :
```json
{
  "decisionId": "DECISION-003",
  "reason": "Variable ROOSYNC_MAX_SIZE mal nommée - Doit être ROOSYNC_MAX_FILE_SIZE selon conventions"
}
```

---

### 4. Monitorer logs après `apply_decision`

**✅ Bonne pratique** :
```json
// Toujours inclure logs dans réponse
{
  "decisionId": "DECISION-004",
  "dryRun": false
}

// Puis examiner logs retournés
// Si warnings ou errors → Envisager rollback
```

---

### 5. Tester rollback en environnement dev avant prod

**Workflow recommandé** :
1. **Dev** : Appliquer décision → Rollback → Vérifier restauration
2. **Staging** : Idem
3. **Prod** : Appliquer avec confiance

---

### 6. Utiliser `includeMetrics` pour monitoring

**✅ Bonne pratique** :
```json
// Appel régulier pour monitoring
{
  "includeMetrics": true
}

// Tracker évolution :
// - Nombre décisions pending
// - Machines needs_sync
// - Dernière sync timestamp
```

---

### 7. Filtrer décisions par priorité

**✅ Bonne pratique** :
```json
// Traiter d'abord les high priority
{
  "filterByPriority": "high"
}

// Puis medium, puis low
```

---

### 8. Créer rollback points systématiquement

**✅ Bonne pratique** :
```json
{
  "decisionId": "DECISION-005",
  "createRollbackPoint": true  // TOUJOURS true en prod
}
```

**Exception** : Tests dev où rollback non nécessaire.

---

## Annexes

### Annexe A : Schémas JSON Complets

#### Schema `roosync_get_status` Input
```typescript
{
  includeMetrics?: boolean;  // Défaut: false
}
```

#### Schema `roosync_get_status` Output
```typescript
{
  globalStatus: "synchronized" | "differences_detected" | "error";
  machines: Array<{
    name: string;
    status: "up_to_date" | "needs_sync" | "error";
    lastSync: string; // ISO 8601
  }>;
  pendingDecisions: number;
  metrics?: {
    totalMachines: number;
    upToDate: number;
    needsSync: number;
    errorState: number;
  };
}
```

#### Schema `roosync_apply_decision` Input
```typescript
{
  decisionId: string;         // Requis: ID décision
  dryRun?: boolean;          // Défaut: false
  createRollbackPoint?: boolean; // Défaut: true
}
```

#### Schema `roosync_apply_decision` Output
```typescript
{
  success: boolean;
  decisionId: string;
  executionTime: number;     // Millisecondes
  logs: string[];
  changes: Array<{
    machine: string;
    file: string;
    action: "created" | "updated" | "deleted";
    size?: string;
  }>;
  rollbackId?: string;       // Si createRollbackPoint=true
  appliedAt: string;         // ISO 8601
}
```

[Schemas complets pour les 8 outils disponibles sur demande]

---

### Annexe B : Exemples Scripts Automation

#### Script Bash : Synchronisation Quotidienne

```bash
#!/bin/bash
# sync-daily.sh - Synchronisation automatique quotidienne

# Appel API MCP (exemple avec curl)
STATUS=$(curl -X POST http://localhost:3000/mcp/roosync_get_status \
  -H "Content-Type: application/json" \
  -d '{"includeMetrics": true}')

PENDING=$(echo $STATUS | jq '.pendingDecisions')

if [ "$PENDING" -gt 0 ]; then
  echo "🔍 $PENDING décisions pending détectées"
  
  # Lister décisions
  DIFFS=$(curl -X POST http://localhost:3000/mcp/roosync_list_diffs \
    -H "Content-Type: application/json" \
    -d '{"filterByStatus": "pending"}')
  
  # Approuver automatiquement décisions low priority
  echo $DIFFS | jq -r '.differences[] | select(.priority=="low") | .id' | \
  while read DECISION_ID; do
    echo "✅ Auto-approbation: $DECISION_ID"
    curl -X POST http://localhost:3000/mcp/roosync_approve_decision \
      -H "Content-Type: application/json" \
      -d "{\"decisionId\": \"$DECISION_ID\", \"comment\": \"Auto-approved by daily sync\"}"
  done
fi
```

---

#### Script PowerShell : Rollback Automatique

```powershell
# rollback-on-error.ps1
# Rollback automatique si erreur détectée

param(
    [string]$DecisionId,
    [string]$ErrorPattern = "ERROR|FAILED"
)

# Appliquer décision
$result = Invoke-RestMethod -Method Post `
    -Uri "http://localhost:3000/mcp/roosync_apply_decision" `
    -Body (@{
        decisionId = $DecisionId
        dryRun = $false
        createRollbackPoint = $true
    } | ConvertTo-Json) `
    -ContentType "application/json"

# Vérifier logs
$hasError = $result.logs | Where-Object { $_ -match $ErrorPattern }

if ($hasError) {
    Write-Host "❌ Erreur détectée dans logs - Rollback automatique" -ForegroundColor Red
    
    # Rollback
    Invoke-RestMethod -Method Post `
        -Uri "http://localhost:3000/mcp/roosync_rollback_decision" `
        -Body (@{
            decisionId = $DecisionId
            reason = "Erreur détectée automatiquement: $($hasError -join ', ')"
        } | ConvertTo-Json) `
        -ContentType "application/json"
    
    Write-Host "✅ Rollback effectué avec succès" -ForegroundColor Green
} else {
    Write-Host "✅ Application réussie sans erreur" -ForegroundColor Green
}
```

---

### Annexe C : FAQ

#### Q1 : Quelle est la différence entre `approve` et `apply` ?

**R** : 
- `approve` : Change statut `pending` → `approved` (AUTORISATION)
- `apply` : Exécute la synchronisation réelle (ACTION)

Un `apply` nécessite un `approve` préalable.

---

#### Q2 : Puis-je annuler un `reject` ?

**R** : Non, une fois rejetée, une décision ne peut plus être approuvée. Il faut créer une nouvelle décision.

---

#### Q3 : Combien de temps sont conservés les rollback points ?

**R** : Par défaut, 30 jours. Configurable dans `sync-config.json` :
```json
{
  "rollbackRetentionDays": 30
}
```

---

#### Q4 : Puis-je synchroniser plus de 2 machines ?

**R** : Oui, RooSync supporte N machines. Configurer dans `sync-config.json`.

---

#### Q5 : Comment purger les décisions `rejected` ?

**R** : Utiliser script PowerShell :
```powershell
# purge-rejected.ps1
# Supprimer décisions rejected > 7 jours
```

---

#### Q6 : Les outils MCP sont-ils thread-safe ?

**R** : Oui, RooSyncService utilise un singleton avec cache. Appels simultanés sont sérialisés.

---

#### Q7 : Puis-je désactiver le cache TTL ?

**R** : Oui, définir `ROOSYNC_CACHE_TTL=0` dans `.env` (non recommandé).

---

## Support et Ressources

### Documentation Technique

- [Architecture 5 Couches](03-architecture-integration-roosync.md)
- [Services RooSync](06-services-roosync.md)
- [Tests E2E](13-resultats-tests-e2e.md)

### Dépôts Git

- **Dépôt principal** : `d:/roo-extensions/`
- **Sous-module MCP** : `mcps/internal/servers/roo-state-manager/`
- **RooSync autonome** : `RooSync/`

### Contact

Pour questions ou bugs, ouvrir une issue GitHub.

---

**Document établi le** : 12 octobre 2025  
**Version** : 1.0  
**Statut** : ✅ Guide Utilisateur Final Phase 8

---

**Fin du Guide**