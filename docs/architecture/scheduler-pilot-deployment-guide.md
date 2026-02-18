# Guide de Déploiement Pilote - Scheduler Claude Code

**Date:** 2026-02-18
**Machine Pilote:** myia-po-2026
**Issue:** #487 - [SCHEDULER] Maturation Roo + Préparation scheduler Claude Code

---

## Résumé Exécutif

Ce guide détaille le déploiement du scheduler Claude Code sur la machine pilote **myia-po-2026**.

**Objectif :** Valider l'architecture proposée dans `scheduler-claude-code-design.md` avant déploiement multi-machines.

---

## Pré-requis

### 1.1. Logiciels Requis

| Logiciel | Version Minimale | Vérification |
|-----------|-------------------|---------------|
| PowerShell | 7.0+ | `$PSVersionTable.PSVersion` |
| Git | 2.40+ | `git --version` |
| Node.js | 18+ | `node --version` |
| Claude Code | Dernière | `claude --version` |
| Ralph Wiggum | Plugin installé | Vérifier dans Claude Code |

### 1.2. Vérification de l'Environnement

```powershell
# scripts/scheduling/check-prerequisites.ps1
Write-Host "=== Vérification Pré-requis ===" -ForegroundColor Cyan

# PowerShell
$PSVersion = $PSVersionTable.PSVersion
Write-Host "PowerShell: $PSVersion" -ForegroundColor $(if ($PSVersion.Major -ge 7) { "Green" } else { "Red" })

# Git
try {
    $GitVersion = git --version
    Write-Host "Git: $GitVersion" -ForegroundColor Green
} catch {
    Write-Host "Git: Non installé" -ForegroundColor Red
}

# Node.js
try {
    $NodeVersion = node --version
    Write-Host "Node.js: $NodeVersion" -ForegroundColor Green
} catch {
    Write-Host "Node.js: Non installé" -ForegroundColor Red
}

# Claude Code
try {
    $ClaudeVersion = claude --version
    Write-Host "Claude Code: $ClaudeVersion" -ForegroundColor Green
} catch {
    Write-Host "Claude Code: Non installé" -ForegroundColor Red
}

# Ralph Wiggum
# Vérifier via Claude Code settings
Write-Host "Ralph Wiggum: À vérifier dans Claude Code" -ForegroundColor Yellow
```

---

## Phase 1 : Installation Ralph Wiggum

### 1.1. Qu'est-ce que Ralph Wiggum ?

Ralph Wiggum est un plugin officiel Anthropic qui permet des **boucles autonomes** pour Claude Code.

**Caractéristiques :**
- Boucle : gather context → take action → verify work → repeat
- Détection intelligente de sortie (évite boucles infinies)
- Limites API intégrées
- Compatible avec `--dangerously-skip-permissions`

### 1.2. Installation

```bash
# Via Claude Code CLI
claude plugin install ralph-wiggum

# Ou manuellement
# Télécharger depuis : https://github.com/frankbria/ralph-claude-code
# Copier dans : ~/.claude/plugins/ralph-wiggum/
```

### 1.3. Configuration

Créer le fichier `.claude/ralph-config.json` :

```json
{
  "maxIterations": 10,
  "maxDurationMinutes": 30,
  "exitConditions": {
    "success": true,
    "error": true,
    "timeout": true,
    "noProgress": {
      "enabled": true,
      "iterations": 3
    }
  },
  "verification": {
    "enabled": true,
    "afterEachIteration": true
  },
  "logging": {
    "enabled": true,
    "logFile": ".claude/logs/ralph-$(date +%Y%m%d-%H%M%S).log"
  }
}
```

### 1.4. Test

```bash
# Test simple avec Ralph Wiggum
claude --dangerously-skip-permissions --plugin ralph-wiggum -p "Créer un fichier test.txt avec le contenu 'Hello World'"
```

**Attendu :** Claude crée le fichier et vérifie le résultat, puis s'arrête.

---

## Phase 2 : Création des Scripts de Base

### 2.1. Structure des Répertoires

```
scripts/scheduling/
├── acquire-lock.ps1          # Locking RooSync
├── create-worktree.ps1        # Worktree Git
├── get-next-task.ps1          # Queue de priorité
├── report-result.ps1          # Rapport JSON/Markdown
├── collect-metrics.ps1        # Métriques
├── start-claude-worker.ps1    # Worker principal (existant)
├── sync-tour-scheduled.ps1    # Sync-tour (existant)
├── setup-scheduler.ps1         # Setup Task Scheduler (existant)
└── check-prerequisites.ps1     # Vérification pré-requis
```

### 2.2. Scripts à Créer

#### 2.2.1. acquire-lock.ps1

```powershell
<#
.SYNOPSIS
    Acquisition et libération de locks RooSync

.DESCRIPTION
    Implémente un mécanisme de locking optimiste avec timeout
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('acquire', 'release', 'check')]
    [string]$Action,
    
    [string]$TaskId,
    [int]$Timeout = 300
)

$LockFile = ".claude\scheduler-lock.json"

function Acquire-Lock {
    param([string]$TaskId, [int]$Timeout)
    
    for ($i = 0; $i -lt 10; $i++) {
        if (-not (Test-Path $LockFile)) {
            $LockData = @{
                taskId = $TaskId
                machine = $env:COMPUTERNAME
                acquiredAt = (Get-Date -Format "o")
                expiresAt = ((Get-Date).AddSeconds($Timeout)).ToString("o")
            }
            $LockData | ConvertTo-Json | Out-File $LockFile
            Write-Host "Lock acquis pour tâche: $TaskId" -ForegroundColor Green
            return $true
        }
        
        $ExistingLock = Get-Content $LockFile | ConvertFrom-Json
        $ExpiresAt = [DateTime]::Parse($ExistingLock.expiresAt)
        
        if ((Get-Date) -gt $ExpiresAt) {
            Remove-Item $LockFile
            $LockData = @{
                taskId = $TaskId
                machine = $env:COMPUTERNAME
                acquiredAt = (Get-Date -Format "o")
                expiresAt = ((Get-Date).AddSeconds($Timeout)).ToString("o")
            }
            $LockData | ConvertTo-Json | Out-File $LockFile
            Write-Host "Lock expiré, réacquis pour tâche: $TaskId" -ForegroundColor Yellow
            return $true
        }
        
        Write-Host "Lock occupé par $($ExistingLock.taskId) sur $($ExistingLock.machine), attente..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    
    Write-Host "Échec acquisition lock après 10 tentatives" -ForegroundColor Red
    return $false
}

function Release-Lock {
    param([string]$TaskId)
    
    if (Test-Path $LockFile) {
        $ExistingLock = Get-Content $LockFile | ConvertFrom-Json
        
        if ($ExistingLock.taskId -eq $TaskId) {
            Remove-Item $LockFile
            Write-Host "Lock libéré pour tâche: $TaskId" -ForegroundColor Green
            return $true
        } else {
            Write-Host "Impossible de libérer lock : appartient à $($ExistingLock.taskId)" -ForegroundColor Red
            return $false
        }
    }
    
    Write-Host "Aucun lock à libérer" -ForegroundColor Yellow
    return $false
}

function Check-Lock {
    if (-not (Test-Path $LockFile)) {
        Write-Host "Aucun lock actif" -ForegroundColor Green
        return $true
    }
    
    $ExistingLock = Get-Content $LockFile | ConvertFrom-Json
    $ExpiresAt = [DateTime]::Parse($ExistingLock.expiresAt)
    
    if ((Get-Date) -gt $ExpiresAt) {
        Write-Host "Lock expiré (acquis par $($ExistingLock.taskId))" -ForegroundColor Yellow
        return $true
    }
    
    Write-Host "Lock actif par $($ExistingLock.taskId) sur $($ExistingLock.machine)" -ForegroundColor Red
    return $false
}

switch ($Action) {
    'acquire' { Acquire-Lock -TaskId $TaskId -Timeout $Timeout }
    'release' { Release-Lock -TaskId $TaskId }
    'check' { Check-Lock }
}
```

#### 2.2.2. create-worktree.ps1

```powershell
<#
.SYNOPSIS
    Création et suppression de worktrees Git

.DESCRIPTION
    Créer un worktree isolé pour chaque tâche planifiée
#>

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('create', 'remove', 'list')]
    [string]$Action,
    
    [string]$TaskId,
    [string]$Branch = "main"
)

$WorktreesDir = ".git-worktrees"

function New-TaskWorktree {
    param([string]$TaskId, [string]$Branch)
    
    $WorktreeDir = Join-Path $WorktreesDir $TaskId
    
    # Nettoyer si existe déjà
    if (Test-Path $WorktreeDir) {
        Write-Host "Worktree existe déjà, suppression..." -ForegroundColor Yellow
        Remove-TaskWorktree -TaskId $TaskId
    }
    
    # Créer nouveau worktree
    Write-Host "Création worktree: $WorktreeDir (branche: $Branch)" -ForegroundColor Green
    git worktree add $WorktreeDir $Branch
    
    return $WorktreeDir
}

function Remove-TaskWorktree {
    param([string]$TaskId)
    
    $WorktreeDir = Join-Path $WorktreesDir $TaskId
    
    if (Test-Path $WorktreeDir) {
        Write-Host "Suppression worktree: $WorktreeDir" -ForegroundColor Yellow
        git worktree remove $WorktreeDir --force
        return $true
    }
    
    Write-Host "Worktree introuvable: $WorktreeDir" -ForegroundColor Red
    return $false
}

function List-TaskWorktrees {
    Write-Host "=== Worktrees Actifs ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $WorktreesDir)) {
        Write-Host "Aucun worktree" -ForegroundColor Yellow
        return
    }
    
    Get-ChildItem $WorktreesDir -Directory | ForEach-Object {
        $WorktreeName = $_.Name
        $LastModified = $_.LastWriteTime
        
        # Vérifier si le worktree est dans git
        $GitDir = Join-Path $_.FullName ".git"
        if (Test-Path $GitDir) {
            Write-Host "✓ $WorktreeName (modifié: $LastModified)" -ForegroundColor Green
        } else {
            Write-Host "✗ $WorktreeName (corrompu, modifié: $LastModified)" -ForegroundColor Red
        }
    }
}

switch ($Action) {
    'create' { New-TaskWorktree -TaskId $TaskId -Branch $Branch }
    'remove' { Remove-TaskWorktree -TaskId $TaskId }
    'list' { List-TaskWorktrees }
}
```

#### 2.2.3. get-next-task.ps1

```powershell
<#
.SYNOPSIS
    Récupère la prochaine tâche de la queue de priorité

.DESCRIPTION
    Lit la queue, calcule les scores et retourne la tâche prioritaire
#>

param(
    [string]$QueueFile = ".claude\scheduler-queue.json"
)

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
    
    # Poids âge
    $AgeHours = ((Get-Date) - [DateTime]::Parse($Task.scheduledFor)).TotalHours
    $Score += $AgeHours * 10
    
    return $Score
}

if (-not (Test-Path $QueueFile)) {
    Write-Host "Queue introuvable: $QueueFile" -ForegroundColor Red
    return $null
}

$Queue = Get-Content $QueueFile | ConvertFrom-Json

if ($Queue.tasks.Count -eq 0) {
    Write-Host "Aucune tâche dans la queue" -ForegroundColor Yellow
    return $null
}

# Calculer scores et trier
$Queue.tasks | ForEach-Object {
    $_ | Add-Member -NotePropertyName "score" -NotePropertyValue (Get-TaskScore -Task $_)
} | Sort-Object -Property score -Descending | Select-Object -First 1
```

---

## Phase 3 : Configuration

### 3.1. Créer scheduler-config.json

```powershell
# Créer le fichier de configuration
$Config = @{
    version = "1.0"
    coordinateur = "myia-ai-01"
    machines = @("myia-po-2023", "myia-po-2024", "myia-po-2025", "myia-po-2026", "myia-web1")
    locking = @{
        enabled = $true
        lockFile = ".claude\scheduler-lock.json"
        lockTimeout = 300
    }
    worktrees = @{
        enabled = $true
        directory = ".git-worktrees"
        autoCleanup = $true
    }
    queue = @{
        file = ".claude\scheduler-queue.json"
        maxSize = 100
        prioritization = @{
            enabled = $true
            algorithm = "priority-deadline"
        }
    }
    reporting = @{
        json = $true
        markdown = $true
        github = $true
        roosync = $true
    }
}

$Config | ConvertTo-Json -Depth 10 | Out-File ".claude\scheduler-config.json"
Write-Host "Configuration créée: .claude\scheduler-config.json" -ForegroundColor Green
```

### 3.2. Créer scheduler-queue.json

```powershell
# Créer la queue vide
$Queue = @{
    version = "1.0"
    generatedAt = (Get-Date -Format "o")
    generatedBy = $env:COMPUTERNAME
    tasks = @()
}

$Queue | ConvertTo-Json -Depth 10 | Out-File ".claude\scheduler-queue.json"
Write-Host "Queue créée: .claude\scheduler-queue.json" -ForegroundColor Green
```

---

## Phase 4 : Tests

### 4.1. Test 1 : Tâche Simple (Git Sync)

```powershell
# Créer une tâche de test
$TestTask = @{
    id = "test-20260218-001"
    title = "Test Git Sync"
    description = "Synchroniser le dépôt Git"
    category = "maintenance"
    priority = "medium"
    assignedTo = "myia-po-2026"
    scheduledFor = (Get-Date).ToString("o")
    deadline = ((Get-Date).AddMinutes(15)).ToString("o")
    estimatedDuration = 5
    maxDuration = 10
    mode = "code-simple"
    escalationMode = "code-complex"
    tags = @{
        scope = "single-file"
        risk = "low"
        dependencies = "external"
    }
    parameters = @{
        useWorktree = $false
    }
    dependencies = @()
}

# Ajouter à la queue
$Queue = Get-Content ".claude\scheduler-queue.json" | ConvertFrom-Json
$Queue.tasks += $TestTask
$Queue | ConvertTo-Json -Depth 10 | Out-File ".claude\scheduler-queue.json"

# Exécuter
.\scripts\scheduling\start-claude-worker.ps1 -TaskId "test-20260218-001" -Mode "code-simple"
```

**Attendu :** Git sync réussi en < 10 min.

### 4.2. Test 2 : Tâche Complexe (Build + Tests)

```powershell
# Créer une tâche de test complexe
$TestTask = @{
    id = "test-20260218-002"
    title = "Test Build + Tests"
    description = "Builder le MCP et exécuter les tests"
    category = "maintenance"
    priority = "high"
    assignedTo = "myia-po-2026"
    scheduledFor = (Get-Date).ToString("o")
    deadline = ((Get-Date).AddMinutes(30)).ToString("o")
    estimatedDuration = 15
    maxDuration = 25
    mode = "code-complex"
    escalationMode = "architect-complex"
    tags = @{
        scope = "multi-file"
        risk = "medium"
        dependencies = "internal"
    }
    parameters = @{
        useWorktree = $true
        runTests = $true
    }
    dependencies = @()
}

# Ajouter à la queue
$Queue = Get-Content ".claude\scheduler-queue.json" | ConvertFrom-Json
$Queue.tasks += $TestTask
$Queue | ConvertTo-Json -Depth 10 | Out-File ".claude\scheduler-queue.json"

# Exécuter
.\scripts\scheduling\start-claude-worker.ps1 -TaskId "test-20260218-002" -Mode "code-complex" -UseWorktree
```

**Attendu :** Build réussi + tests passés en < 25 min.

### 4.3. Test 3 : Locking

```powershell
# Test 1 : Acquérir lock
.\scripts\scheduling\acquire-lock.ps1 -Action acquire -TaskId "test-lock-001"

# Test 2 : Vérifier lock (doit être occupé)
.\scripts\scheduling\acquire-lock.ps1 -Action check

# Test 3 : Libérer lock
.\scripts\scheduling\acquire-lock.ps1 -Action release -TaskId "test-lock-001"

# Test 4 : Vérifier lock (doit être libre)
.\scripts\scheduling\acquire-lock.ps1 -Action check
```

**Attendu :** Lock acquis, occupé, libéré, libre.

### 4.4. Test 4 : Worktree

```powershell
# Test 1 : Créer worktree
$WorktreeDir = .\scripts\scheduling\create-worktree.ps1 -Action create -TaskId "test-worktree-001"
Write-Host "Worktree créé: $WorktreeDir"

# Test 2 : Lister worktrees
.\scripts\scheduling\create-worktree.ps1 -Action list

# Test 3 : Supprimer worktree
.\scripts\scheduling\create-worktree.ps1 -Action remove -TaskId "test-worktree-001"

# Test 4 : Vérifier suppression
.\scripts\scheduling\create-worktree.ps1 -Action list
```

**Attendu :** Worktree créé, listé, supprimé, plus dans la liste.

---

## Phase 5 : Déploiement Production

### 5.1. Activer le Scheduler

```powershell
# Installer les tâches Task Scheduler
cd C:\dev\roo-extensions\scripts\scheduling
.\setup-scheduler.ps1 -Action install -Tasks all -IntervalHours 3

# Vérifier l'installation
.\setup-scheduler.ps1 -Action list
```

### 5.2. Surveiller les Premiers Cycles

```powershell
# Surveiller les logs
Get-Content ".claude\logs\*.log" -Tail 50 -Wait

# Ou ouvrir dans VS Code
code .claude\logs\
```

### 5.3. Collecter les Métriques

```powershell
# Après 3 cycles, collecter les métriques
.\scripts\scheduling\collect-metrics.ps1 -Days 1 -OutputPath ".claude\logs\metrics.json"

# Vérifier le rapport
Get-Content ".claude\logs\metrics.json" | ConvertFrom-Json
```

---

## Checklist de Validation

### Semaine 1

- [ ] Ralph Wiggum installé et testé
- [ ] Scripts de base créés (acquire-lock, create-worktree, get-next-task)
- [ ] start-claude-worker.ps1 modifié pour intégration
- [ ] Test 1 (Git Sync) réussi
- [ ] Test 2 (Build + Tests) réussi
- [ ] Test 3 (Locking) réussi
- [ ] Test 4 (Worktree) réussi

### Semaine 2

- [ ] Scripts de reporting créés (report-result, collect-metrics)
- [ ] scheduler-config.json configuré
- [ ] scheduler-queue.json initialisé
- [ ] Test avec tâche complexe (feature) réussi
- [ ] Test avec tâche bugfix réussi
- [ ] Locking validé en production
- [ ] Worktrees validés en production

### Semaine 3

- [ ] Déploiement production sur myia-po-2026
- [ ] 3 cycles complets sans erreur critique
- [ ] Métriques collectées et analysées
- [ ] Taux de succès > 80%
- [ ] Aucun lock timeout
- [ ] Aucun worktree corrompu

---

## Dépannage

### Problème : Lock Timeout

**Symptôme :** "Échec acquisition lock après 10 tentatives"

**Solution :**
```powershell
# Forcer la libération du lock
.\scripts\scheduling\acquire-lock.ps1 -Action release -TaskId "UNKNOWN" -Force

# Ou supprimer manuellement
Remove-Item ".claude\scheduler-lock.json" -Force
```

### Problème : Worktree Corrompu

**Symptôme :** "Worktree introuvable" ou erreur Git

**Solution :**
```powershell
# Nettoyer tous les worktrees
Get-ChildItem ".git-worktrees" -Directory | ForEach-Object {
    git worktree remove $_.FullName --force
}

# Ou utiliser le script de cleanup
.\scripts\scheduling\cleanup-worktrees.ps1 -OlderThan (Get-Date).AddDays(-1)
```

### Problème : Tâche Bloquée

**Symptôme :** Tâche reste en "pending" indéfiniment

**Solution :**
```powershell
# Annuler la tâche
.\scripts\scheduling\cancel-task.ps1 -TaskId "task-20260218-001" -Reason "Timeout"

# Ou marquer comme échouée
# Modifier le statut dans scheduler-queue.json
```

---

## Prochaines Étapes

1. **Immédiat :** Installer Ralph Wiggum
2. **Court terme :** Créer les scripts de base
3. **Moyen terme :** Tester et valider
4. **Long terme :** Déployer sur toutes les machines

---

## Conclusion

Ce guide fournit un chemin clair pour le déploiement du scheduler Claude Code sur myia-po-2026.

**Points clés :**
- ✅ Installation Ralph Wiggum
- ✅ Scripts de base (locking, worktree, queue)
- ✅ Configuration complète
- ✅ Tests complets
- ✅ Déploiement production
- ✅ Dépannage

**Recommandation :** Suivre le guide séquentiellement, valider chaque étape avant de passer à la suivante.

---

**Rédigé par :** Roo Code (orchestrator-complex)
**Date :** 2026-02-18
**Basé sur :** scheduler-claude-code-design.md (#487)
