# Design Scheduler Claude Code - Architecture Complète

**Date:** 2026-02-18
**Issue:** #487 - [SCHEDULER] Maturation Roo + Préparation scheduler Claude Code
**Machine Pilote:** myia-po-2026

---

## Résumé Exécutif

Ce document présente le design complet du scheduler Claude Code, basé sur :

1. **L'expérience du scheduler Roo** (scripts, configuration, patterns)
2. **Les solutions identifiées** dans `scheduling-claude-code.md`
3. **Les optimisations proposées** dans `scheduler-optimization-proposals.md`

**Architecture choisie :** Approche hybride Cron + Ralph Wiggum + Git Worktrees

---

## 1. Architecture Globale

### 1.1. Vue d'Ensemble

```
┌─────────────────────────────────────────────────────────────────────┐
│                    myia-ai-01 (Coordinateur)                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Cron/Task    │  │ RooSync      │  │ GitHub Actions   │  │
│  │ Scheduler    │  │ Message Hub  │  │ (webhook)        │  │
│  │ (Windows)    │  │              │  │                  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
│         │                  │                  │                    │
│         │                  │                  │                    │
│         └──────────────────┼──────────────────┘                    │
│                            │                                     │
│                    ┌───────▼────────┐                           │
│                    │ Task Queue     │                           │
│                    │ (JSON file)    │                           │
│                    └───────┬────────┘                           │
└────────────────────────────────┼─────────────────────────────────────┘
                             │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ myia-po-2023   │  │ myia-po-2024   │  │ myia-po-2025   │
│                │  │                │  │                │
│ Ralph Wiggum   │  │ Ralph Wiggum   │  │ Ralph Wiggum   │
│ Loop           │  │ Loop           │  │ Loop           │
│                │  │                │  │                │
│ ┌────────────┐ │  │ ┌────────────┐ │  │ ┌────────────┐ │
│ │ Worktree   │ │  │ │ Worktree   │ │  │ │ Worktree   │ │
│ │ Isolation  │ │  │ │ Isolation  │ │  │ │ Isolation  │ │
│ └────────────┘ │  │ └────────────┘ │  │ └────────────┘ │
└────────────────┘  └────────────────┘  └────────────────┘
```

### 1.2. Composants Principaux

| Composant | Responsabilité | Technologie |
|-----------|----------------|--------------|
| **Coordinateur** | Distribution des tâches, monitoring | Windows Task Scheduler + PowerShell |
| **RooSync** | Communication inter-machines | MCP roo-state-manager |
| **Task Queue** | File d'attente des tâches planifiées | JSON file + locking |
| **Worker** | Exécution des tâches Claude Code | Ralph Wiggum + start-claude-worker.ps1 |
| **Worktree** | Isolation des changements Git | Git worktree |
| **Monitoring** | Collecte de métriques, alertes | collect-metrics.ps1 + RooSync |

---

## 2. Format des Tâches Planifiées

### 2.1. Schéma JSON

```json
{
  "version": "1.0",
  "generatedAt": "2026-02-18T12:00:00Z",
  "generatedBy": "myia-ai-01",
  "tasks": [
    {
      "id": "task-20260218-001",
      "title": "Sync tour quotidien",
      "description": "Exécuter le sync-tour complet sur toutes les machines",
      "category": "maintenance",
      "priority": "high",
      "assignedTo": "all",
      "scheduledFor": "2026-02-18T09:00:00Z",
      "deadline": "2026-02-18T10:00:00Z",
      "estimatedDuration": 20,
      "maxDuration": 30,
      "mode": "sync-simple",
      "escalationMode": "sync-complex",
      "tags": {
        "scope": "cross-system",
        "risk": "low",
        "dependencies": "external"
      },
      "parameters": {
        "skipPhases": [],
        "useWorktree": true
      },
      "dependencies": [],
      "retryPolicy": {
        "maxRetries": 2,
        "backoff": "exponential",
        "backoffFactor": 1.5
      },
      "onFailure": {
        "action": "escalate",
        "notify": ["myia-ai-01"]
      },
      "onSuccess": {
        "action": "report",
        "notify": ["myia-ai-01"]
      }
    },
    {
      "id": "task-20260218-002",
      "title": "Build et tests MCP",
      "description": "Builder le MCP roo-state-manager et exécuter les tests",
      "category": "maintenance",
      "priority": "medium",
      "assignedTo": "myia-po-2026",
      "scheduledFor": "2026-02-18T10:00:00Z",
      "deadline": "2026-02-18T10:30:00Z",
      "estimatedDuration": 15,
      "maxDuration": 25,
      "mode": "code-simple",
      "escalationMode": "code-complex",
      "tags": {
        "scope": "single-file",
        "risk": "medium",
        "dependencies": "internal"
      },
      "parameters": {
        "useWorktree": true,
        "runTests": true
      },
      "dependencies": ["task-20260218-001"],
      "retryPolicy": {
        "maxRetries": 3,
        "backoff": "exponential",
        "backoffFactor": 1.5
      }
    }
  ]
}
```

### 2.2. Champs Expliqués

| Champ | Type | Requis | Description |
|--------|-------|---------|-------------|
| `id` | string | ✅ | Identifiant unique (timestamp + séquence) |
| `title` | string | ✅ | Titre court de la tâche |
| `description` | string | ✅ | Description détaillée |
| `category` | enum | ✅ | maintenance, consolidaton, feature, bugfix, investigation |
| `priority` | enum | ✅ | critical, high, medium, low |
| `assignedTo` | string | ✅ | all, ou nom de machine spécifique |
| `scheduledFor` | ISO8601 | ✅ | Date/heure de début planifiée |
| `deadline` | ISO8601 | ✅ | Date/heure limite absolue |
| `estimatedDuration` | number | ✅ | Durée estimée en minutes |
| `maxDuration` | number | ✅ | Durée maximale autorisée en minutes |
| `mode` | string | ✅ | Mode Claude par défaut (ex: code-simple) |
| `escalationMode` | string | ✅ | Mode d'escalade en cas d'échec |
| `tags` | object | ❌ | Métadonnées pour filtrage |
| `parameters` | object | ❌ | Paramètres spécifiques à la tâche |
| `dependencies` | array | ❌ | IDs des tâches dépendantes |
| `retryPolicy` | object | ❌ | Politique de retry |
| `onFailure` | object | ❌ | Action en cas d'échec |
| `onSuccess` | object | ❌ | Action en cas de succès |

### 2.3. Catégories de Tâches

```json
{
  "categories": {
    "maintenance": {
      "defaultMode": "code-simple",
      "escalationMode": "code-complex",
      "defaultTimeout": 15,
      "maxTimeout": 30,
      "examples": [
        "Git sync et cleanup",
        "Rotation des logs",
        "Mise à jour des dépendances",
        "Nettoyage des worktrees"
      ]
    },
    "consolidation": {
      "defaultMode": "code-complex",
      "escalationMode": "architect-complex",
      "defaultTimeout": 30,
      "maxTimeout": 60,
      "examples": [
        "Consolidation d'outils MCP",
        "Refactoring de patterns",
        "Élimination de code dupliqué",
        "Standardisation des interfaces"
      ]
    },
    "feature": {
      "defaultMode": "code-complex",
      "escalationMode": "architect-complex",
      "defaultTimeout": 45,
      "maxTimeout": 90,
      "examples": [
        "Implémentation d'un nouveau MCP",
        "Ajout de fonctionnalités RooSync",
        "Création de scripts d'automatisation",
        "Intégration avec services externes"
      ]
    },
    "bugfix": {
      "defaultMode": "debug-simple",
      "escalationMode": "debug-complex",
      "defaultTimeout": 20,
      "maxTimeout": 40,
      "examples": [
        "Correction d'erreur de syntaxe",
        "Fix de bug isolé",
        "Correction de test échouant",
        "Résolution de conflit Git"
      ]
    },
    "investigation": {
      "defaultMode": "ask-simple",
      "escalationMode": "ask-complex",
      "defaultTimeout": 25,
      "maxTimeout": 50,
      "examples": [
        "Analyse de performance",
        "Investigation de bug complexe",
        "Recherche de solution technique",
        "Audit de sécurité"
      ]
    }
  }
}
```

---

## 3. Évitement des Conflits

### 3.1. Locking RooSync

**Problème :** Si plusieurs machines exécutent des tâches simultanément, elles peuvent modifier les mêmes fichiers.

**Solution :** Locking via RooSync

```json
{
  "locking": {
    "enabled": true,
    "lockFile": ".claude/scheduler-lock.json",
    "lockTimeout": 300,
    "lockAcquisition": {
      "strategy": "optimistic",
      "retryInterval": 5,
      "maxRetries": 10
    },
    "lockRelease": {
      "strategy": "automatic",
      "onSuccess": true,
      "onFailure": true,
      "onTimeout": true
    }
  }
}
```

**Implémentation :**

```powershell
# scripts/scheduling/acquire-lock.ps1
function Acquire-Lock {
    param([string]$TaskId, [int]$Timeout = 300)
    
    $LockFile = ".claude\scheduler-lock.json"
    
    # Tenter d'acquérir le lock
    for ($i = 0; $i -lt 10; $i++) {
        if (-not (Test-Path $LockFile)) {
            # Lock disponible
            $LockData = @{
                taskId = $TaskId
                machine = $env:COMPUTERNAME
                acquiredAt = (Get-Date -Format "o")
                expiresAt = ((Get-Date).AddSeconds($Timeout)).ToString("o")
            }
            $LockData | ConvertTo-Json | Out-File $LockFile
            return $true
        }
        
        # Lock occupé, vérifier expiration
        $ExistingLock = Get-Content $LockFile | ConvertFrom-Json
        $ExpiresAt = [DateTime]::Parse($ExistingLock.expiresAt)
        
        if ((Get-Date) -gt $ExpiresAt) {
            # Lock expiré, le prendre
            Remove-Item $LockFile
            $LockData = @{
                taskId = $TaskId
                machine = $env:COMPUTERNAME
                acquiredAt = (Get-Date -Format "o")
                expiresAt = ((Get-Date).AddSeconds($Timeout)).ToString("o")
            }
            $LockData | ConvertTo-Json | Out-File $LockFile
            return $true
        }
        
        # Attendre et réessayer
        Start-Sleep -Seconds 5
    }
    
    return $false
}

function Release-Lock {
    param([string]$TaskId)
    
    $LockFile = ".claude\scheduler-lock.json"
    
    if (Test-Path $LockFile) {
        $ExistingLock = Get-Content $LockFile | ConvertFrom-Json
        
        # Vérifier que c'est notre lock
        if ($ExistingLock.taskId -eq $TaskId) {
            Remove-Item $LockFile
            return $true
        }
    }
    
    return $false
}
```

### 3.2. Worktree Isolation

**Problème :** Les tâches peuvent modifier le working directory principal et causer des conflits.

**Solution :** Créer un worktree Git pour chaque tâche

```powershell
# scripts/scheduling/create-worktree.ps1
function New-TaskWorktree {
    param([string]$TaskId, [string]$Branch = "main")
    
    $WorktreeDir = ".git-worktrees\$TaskId"
    
    # Nettoyer si existe déjà
    if (Test-Path $WorktreeDir) {
        git worktree remove $WorktreeDir --force
    }
    
    # Créer nouveau worktree
    git worktree add $WorktreeDir $Branch
    
    return $WorktreeDir
}

function Remove-TaskWorktree {
    param([string]$TaskId)
    
    $WorktreeDir = ".git-worktrees\$TaskId"
    
    if (Test-Path $WorktreeDir) {
        git worktree remove $WorktreeDir --force
    }
}
```

**Intégration dans start-claude-worker.ps1 :**

```powershell
if ($UseWorktree) {
    $WorktreeDir = New-TaskWorktree -TaskId $TaskId
    $RepoRoot = Resolve-Path $WorktreeDir
    Write-Log "Worktree créé: $WorktreeDir"
}
```

### 3.3. Queue de Priorité

**Problème :** Les tâches critiques peuvent être bloquées par des tâches moins importantes.

**Solution :** Queue de priorité avec tri automatique

```json
{
  "taskQueue": {
    "file": ".claude\scheduler-queue.json",
    "maxSize": 100,
    "prioritization": {
      "enabled": true,
      "algorithm": "priority-deadline",
      "weights": {
        "priority": {
          "critical": 100,
          "high": 75,
          "medium": 50,
          "low": 25
        },
        "deadline": {
          "urgent": 50,
          "normal": 25,
          "flexible": 0
        },
        "age": {
          "perHour": 10
        }
      }
    }
  }
}
```

**Algorithme de priorité :**

```powershell
function Get-TaskScore {
    param($Task)
    
    $Score = 0
    
    # Poids priorité
    $PriorityWeight = @{
        "critical" = 100
        "high" = 75
        "medium" = 50
        "low" = 25
    }
    $Score += $PriorityWeight[$Task.priority]
    
    # Poids deadline
    $TimeUntilDeadline = ([DateTime]::Parse($Task.deadline) - (Get-Date)).TotalHours
    if ($TimeUntilDeadline -lt 1) {
        $Score += 50  # Urgent
    } elseif ($TimeUntilDeadline -lt 4) {
        $Score += 25  # Normal
    }
    
    # Poids âge (tâches plus anciennes prioritaires)
    $AgeHours = ((Get-Date) - [DateTime]::Parse($Task.scheduledFor)).TotalHours
    $Score += $AgeHours * 10
    
    return $Score
}

function Get-NextTask {
    $Queue = Get-Content ".claude\scheduler-queue.json" | ConvertFrom-Json
    
    # Calculer scores et trier
    $Queue.tasks | ForEach-Object {
        $_ | Add-Member -NotePropertyName "score" -NotePropertyValue (Get-TaskScore -Task $_)
    } | Sort-Object -Property score -Descending | Select-Object -First 1
}
```

---

## 4. Rapport des Résultats

### 4.1. Format Structuré (JSON)

```json
{
  "taskId": "task-20260218-001",
  "machine": "myia-po-2026",
  "startedAt": "2026-02-18T09:00:00Z",
  "completedAt": "2026-02-18T09:18:32Z",
  "duration": 1112,
  "status": "success",
  "mode": "sync-simple",
  "escalated": false,
  "iterations": 1,
  "toolsUsed": [
    "read_file",
    "execute_command",
    "roosync_read",
    "roosync_send"
  ],
  "actions": [
    {
      "type": "git-sync",
      "status": "success",
      "duration": 45
    },
    {
      "type": "build",
      "status": "success",
      "duration": 120
    },
    {
      "type": "test",
      "status": "success",
      "duration": 180
    }
  ],
  "output": "Sync-tour complété avec succès. 3 tests passés.",
  "errors": [],
  "warnings": [
    "Git conflict résolu automatiquement"
  ],
  "metrics": {
    "cpuUsage": 45,
    "memoryUsage": 512,
    "diskUsage": 1024
  }
}
```

### 4.2. Format Markdown (Rapport Lisible)

```markdown
## Rapport de Tâche - task-20260218-001

**Machine:** myia-po-2026
**Titre:** Sync tour quotidien
**Statut:** ✅ Succès
**Mode:** sync-simple
**Durée:** 18 min 32 sec

---

### Résumé

Sync-tour complété avec succès. 3 tests passés.

### Actions Exécutées

| Action | Statut | Durée |
|--------|---------|--------|
| Git sync | ✅ Succès | 45s |
| Build | ✅ Succès | 2m 0s |
| Tests | ✅ Succès | 3m 0s |

### Outils Utilisés

- read_file (12 appels)
- execute_command (5 appels)
- roosync_read (3 appels)
- roosync_send (2 appels)

### Avertissements

- Git conflict résolu automatiquement

### Métriques Système

- CPU: 45%
- Mémoire: 512 MB
- Disque: 1 GB

---

**Généré le:** 2026-02-18T09:18:32Z
**Par:** Claude Code (sync-simple)
```

### 4.3. Intégration GitHub Issues

**Automatisation :** Créer/mettre à jour des issues GitHub basées sur les résultats

```powershell
# scripts/scheduling/report-to-github.ps1
function Send-GitHubReport {
    param($TaskResult)
    
    if ($TaskResult.status -eq "success") {
        # Marquer issue comme Done
        gh issue close $TaskResult.taskId --comment "Complété avec succès en $($TaskResult.duration)s"
    } else {
        # Créer issue pour échec
        $IssueTitle = "[$($TaskResult.category)] Échec: $($TaskResult.title)"
        $IssueBody = @"
## Échec de Tâche Planifiée

**Tâche ID:** $($TaskResult.taskId)
**Machine:** $($TaskResult.machine)
**Mode:** $($TaskResult.mode)

### Erreur

$($TaskResult.errors[0])

### Logs

Voir: `.claude/logs/worker-$(Get-Date -Format 'yyyyMMdd-HHmmss').log`

### Actions Requises

- [ ] Investiguer la cause racine
- [ ] Corriger le problème
- [ ] Re-tester
"@
        
        gh issue create --title $IssueTitle --body $IssueBody --label "scheduled-task-failure"
    }
}
```

---

## 5. Implémentation

### 5.1. Scripts à Créer

1. **`scripts/scheduling/acquire-lock.ps1`**
   - Acquisition et libération de locks RooSync
   - Gestion des timeouts et expirations

2. **`scripts/scheduling/create-worktree.ps1`**
   - Création et suppression de worktrees Git
   - Nettoyage automatique

3. **`scripts/scheduling/get-next-task.ps1`**
   - Lecture de la queue de priorité
   - Calcul des scores de priorité
   - Retour de la prochaine tâche

4. **`scripts/scheduling/report-result.ps1`**
   - Génération du rapport JSON
   - Génération du rapport Markdown
   - Envoi vers GitHub Issues

5. **`scripts/scheduling/collect-metrics.ps1`**
   - Collecte des métriques d'exécution
   - Calcul des taux de succès/échec
   - Génération de rapport JSON

### 5.2. Modifications Existantes

1. **`scripts/scheduling/start-claude-worker.ps1`**
   - Intégrer acquire-lock.ps1
   - Intégrer create-worktree.ps1
   - Intégrer report-result.ps1
   - Support du format de tâche JSON

2. **`scripts/scheduling/setup-scheduler.ps1`**
   - Ajouter tâches Claude Code
   - Configurer intervals par catégorie
   - Activer locking par défaut

3. **`.roo/schedules.template.json`**
   - Ajouter schéma de tâche JSON
   - Ajouter configuration de queue
   - Ajouter configuration de locking

### 5.3. Fichiers de Configuration

1. **`.claude/scheduler-config.json`**
   ```json
   {
     "version": "1.0",
     "coordinateur": "myia-ai-01",
     "machines": ["myia-po-2023", "myia-po-2024", "myia-po-2025", "myia-po-2026", "myia-web1"],
     "locking": {
       "enabled": true,
       "lockFile": ".claude/scheduler-lock.json",
       "lockTimeout": 300
     },
     "worktrees": {
       "enabled": true,
       "directory": ".git-worktrees",
       "autoCleanup": true
     },
     "queue": {
       "file": ".claude/scheduler-queue.json",
       "maxSize": 100,
       "prioritization": {
         "enabled": true,
         "algorithm": "priority-deadline"
       }
     },
     "reporting": {
       "json": true,
       "markdown": true,
       "github": true,
       "roosync": true
     }
   }
   ```

2. **`.claude/scheduler-queue.json`**
   ```json
   {
     "version": "1.0",
     "generatedAt": "2026-02-18T12:00:00Z",
     "tasks": []
   }
   ```

---

## 6. Plan de Déploiement

### 6.1. Phase Pilote (myia-po-2026)

**Semaine 1 :**
- [ ] Installer Ralph Wiggum plugin
- [ ] Créer scripts de base (acquire-lock, create-worktree, get-next-task)
- [ ] Modifier start-claude-worker.ps1 pour intégration
- [ ] Tester avec tâches simples (git sync + build)

**Semaine 2 :**
- [ ] Créer scripts de reporting (report-result, collect-metrics)
- [ ] Configurer scheduler-config.json
- [ ] Tester avec tâches complexes (feature, bugfix)
- [ ] Valider locking et worktrees

**Semaine 3 :**
- [ ] Déployer sur myia-po-2026 en production
- [ ] Surveiller pendant 3 cycles complets
- [ ] Collecter métriques et ajuster
- [ ] Documenter consignes d'utilisation

### 6.2. Déploiement Multi-Machines

**Pré-requis :**
- Pilote fonctionnel sur myia-po-2026
- Taux de succès > 80%
- Aucun bug critique

**Déploiement progressif :**
1. **myia-po-2025** (semaine 4)
2. **myia-po-2024** (semaine 5)
3. **myia-po-2023** (semaine 6)
4. **myia-web1** (semaine 7)
5. **myia-ai-01** (coordinateur, semaine 8)

**Validation par machine :**
- [ ] Installation Ralph Wiggum
- [ ] Configuration scheduler-config.json
- [ ] Test de tâche simple
- [ ] Test de tâche complexe
- [ ] Validation locking
- [ ] Validation worktrees
- [ ] 3 cycles sans erreur critique

---

## 7. Consignes d'Utilisation

### 7.1. Pour le Coordinateur (myia-ai-01)

**Créer une tâche planifiée :**

```powershell
# scripts/scheduling/create-scheduled-task.ps1
.\create-scheduled-task.ps1 `
  -Title "Sync tour quotidien" `
  -Category "maintenance" `
  -Priority "high" `
  -AssignedTo "all" `
  -ScheduledFor (Get-Date).AddHours(1) `
  -Deadline (Get-Date).AddHours(2) `
  -Mode "sync-simple"
  -Parameters @{ skipPhases = @() }
```

**Surveiller les tâches :**

```powershell
# scripts/scheduling/list-tasks.ps1
.\list-tasks.ps1 -Status "pending" -Priority "high"
```

**Collecter les métriques :**

```powershell
# scripts/scheduling/collect-metrics.ps1
.\collect-metrics.ps1 -Days 7 -OutputPath ".claude\logs\metrics.json"
```

### 7.2. Pour les Exécutants (myia-po-2023/2024/2025/2026, myia-web1)

**Exécuter la prochaine tâche :**

```powershell
# scripts/scheduling/start-claude-worker.ps1
.\start-claude-worker.ps1 -UseWorktree
```

**Exécuter une tâche spécifique :**

```powershell
.\start-claude-worker.ps1 `
  -TaskId "task-20260218-001" `
  -Mode "sync-simple" `
  -UseWorktree
```

**Vérifier le statut :**

```powershell
# scripts/scheduling/check-task-status.ps1
.\check-task-status.ps1 -TaskId "task-20260218-001"
```

### 7.3. Dépannage

**Lock bloqué :**

```powershell
# scripts/scheduling/release-lock.ps1
.\release-lock.ps1 -Force
```

**Worktree corrompu :**

```powershell
# scripts/scheduling/cleanup-worktrees.ps1
.\cleanup-worktrees.ps1 -OlderThan (Get-Date).AddDays(-1)
```

**Tâche bloquée :**

```powershell
# scripts/scheduling/cancel-task.ps1
.\cancel-task.ps1 -TaskId "task-20260218-001" -Reason "Timeout"
```

---

## 8. Prochaines Étapes

1. **Immédiat :** Créer les scripts de base (acquire-lock, create-worktree, get-next-task)
2. **Court terme :** Intégrer dans start-claude-worker.ps1 et tester
3. **Moyen terme :** Déployer pilote sur myia-po-2026
4. **Long terme :** Déployer sur toutes les machines et optimiser

---

## Conclusion

Ce design propose une architecture complète et robuste pour le scheduler Claude Code, basée sur :

- ✅ **Expérience du scheduler Roo** : Scripts, configuration, patterns éprouvés
- ✅ **Solutions matures** : Ralph Wiggum, Git worktrees, RooSync
- ✅ **Optimisations proposées** : Catégories de tâches, timeouts dynamiques, monitoring
- ✅ **Évitement de conflits** : Locking RooSync, worktree isolation, queue de priorité
- ✅ **Rapport structuré** : JSON + Markdown + GitHub Issues

**Recommandation :** Implémenter progressivement, tester sur myia-po-2026, puis déployer sur toutes les machines.

---

**Rédigé par :** Roo Code (orchestrator-complex)
**Date :** 2026-02-18
**Basé sur :** Audit myia-po-2026 (#487) + Optimisations proposées
