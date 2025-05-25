# Script de validation et diagnostic de la synchronisation Roo Environment
# Fichier : d:/roo-extensions/roo-config/scheduler/validate-sync.ps1
# Version: 1.0

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "full", # full, quick, logs, conflicts, health
    
    [Parameter(Mandatory=$false)]
    [int]$LogLines = 50, # Nombre de lignes de log à afficher
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = "d:\roo-extensions"
)

$ErrorActionPreference = "Continue" # Continue pour permettre le diagnostic complet

function Write-DiagLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
}

function Test-GitRepositoryHealth {
    Write-DiagLog "=== DIAGNOSTIC DU DÉPÔT GIT ==="
    
    Set-Location $RepoPath
    
    # Vérifier que c'est un dépôt Git
    Try {
        git rev-parse --git-dir | Out-Null
        Write-DiagLog "✓ Dépôt Git valide détecté"
    } Catch {
        Write-DiagLog "✗ ERREUR: Pas un dépôt Git valide" "ERROR"
        return $false
    }
    
    # Vérifier la branche actuelle
    Try {
        $currentBranch = git branch --show-current
        Write-DiagLog "✓ Branche actuelle: $currentBranch"
    } Catch {
        Write-DiagLog "✗ Impossible de déterminer la branche actuelle" "WARN"
    }
    
    # Vérifier le statut Git
    Try {
        $gitStatus = git status --porcelain
        if ($gitStatus) {
            Write-DiagLog "⚠ Modifications locales détectées:" "WARN"
            $gitStatus | ForEach-Object { Write-DiagLog "  $_" }
        } else {
            Write-DiagLog "✓ Aucune modification locale en attente"
        }
    } Catch {
        Write-DiagLog "✗ Erreur lors de la vérification du statut Git" "ERROR"
    }
    
    # Vérifier la connectivité avec le dépôt distant
    Try {
        git ls-remote origin | Out-Null
        Write-DiagLog "✓ Connectivité avec le dépôt distant OK"
    } Catch {
        Write-DiagLog "✗ Problème de connectivité avec le dépôt distant" "ERROR"
    }
    
    # Vérifier les commits en retard
    Try {
        $behindCommits = git rev-list --count HEAD..origin/main 2>$null
        if ($behindCommits -and $behindCommits -gt 0) {
            Write-DiagLog "⚠ $behindCommits commit(s) en retard par rapport au dépôt distant" "WARN"
        } else {
            Write-DiagLog "✓ Dépôt local à jour avec le distant"
        }
    } Catch {
        Write-DiagLog "⚠ Impossible de vérifier l'état de synchronisation avec le distant" "WARN"
    }
    
    return $true
}

function Test-ConfigurationFiles {
    Write-DiagLog "=== VALIDATION DES FICHIERS DE CONFIGURATION ==="
    
    $criticalFiles = @(
        "roo-config/settings/settings.json",
        "roo-config/settings/servers.json", 
        "roo-config/settings/modes.json",
        "roo-modes/configs/modes.json",
        "roo-modes/configs/new-roomodes.json",
        "roo-modes/configs/standard-modes.json",
        "roo-modes/configs/vscode-custom-modes.json"
    )
    
    $allValid = $true
    
    foreach ($file in $criticalFiles) {
        $fullPath = Join-Path $RepoPath $file
        
        if (Test-Path $fullPath) {
            # Vérifier la validité JSON
            Try {
                Get-Content -Raw $fullPath | ConvertFrom-Json | Out-Null
                Write-DiagLog "✓ $file - JSON valide"
            } Catch {
                Write-DiagLog "✗ $file - JSON INVALIDE: $($_.Exception.Message)" "ERROR"
                $allValid = $false
            }
        } else {
            Write-DiagLog "✗ $file - FICHIER MANQUANT" "ERROR"
            $allValid = $false
        }
    }
    
    return $allValid
}

function Show-SyncLogs {
    param([int]$Lines = 50)
    
    Write-DiagLog "=== DERNIÈRES ENTRÉES DU LOG DE SYNCHRONISATION ==="
    
    $logFile = Join-Path $RepoPath "sync_log.txt"
    
    if (Test-Path $logFile) {
        $logContent = Get-Content $logFile -Tail $Lines
        if ($logContent) {
            Write-DiagLog "Affichage des $Lines dernières lignes de $logFile :"
            Write-Host "--- DÉBUT DU LOG ---"
            $logContent | ForEach-Object { Write-Host $_ }
            Write-Host "--- FIN DU LOG ---"
        } else {
            Write-DiagLog "Le fichier de log est vide" "WARN"
        }
    } else {
        Write-DiagLog "Aucun fichier de log trouvé à l'emplacement: $logFile" "WARN"
    }
}

function Show-ConflictLogs {
    Write-DiagLog "=== LOGS DE CONFLITS ==="
    
    $conflictDir = Join-Path $RepoPath "sync_conflicts"
    
    if (Test-Path $conflictDir) {
        $conflictFiles = Get-ChildItem $conflictDir -Filter "*.log" | Sort-Object LastWriteTime -Descending
        
        if ($conflictFiles) {
            Write-DiagLog "Fichiers de conflit trouvés (du plus récent au plus ancien):"
            foreach ($file in $conflictFiles) {
                Write-DiagLog "  $($file.Name) - $($file.LastWriteTime)"
            }
            
            # Afficher le contenu du conflit le plus récent
            $latestConflict = $conflictFiles[0]
            Write-DiagLog "Contenu du conflit le plus récent ($($latestConflict.Name)):"
            Write-Host "--- DÉBUT DU CONFLIT ---"
            Get-Content $latestConflict.FullName | ForEach-Object { Write-Host $_ }
            Write-Host "--- FIN DU CONFLIT ---"
        } else {
            Write-DiagLog "✓ Aucun fichier de conflit trouvé"
        }
    } else {
        Write-DiagLog "✓ Répertoire de conflits inexistant (aucun conflit enregistré)"
    }
}

function Test-ScheduledTaskHealth {
    Write-DiagLog "=== DIAGNOSTIC DE LA TÂCHE PLANIFIÉE ==="
    
    $taskName = "RooEnvironmentSync"
    
    Try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($task) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName
            
            Write-DiagLog "✓ Tâche planifiée '$taskName' trouvée"
            Write-DiagLog "  État: $($task.State)"
            Write-DiagLog "  Dernière exécution: $($taskInfo.LastRunTime)"
            Write-DiagLog "  Prochaine exécution: $($taskInfo.NextRunTime)"
            Write-DiagLog "  Dernier résultat: $($taskInfo.LastTaskResult)"
            
            # Analyser le code de résultat
            if ($taskInfo.LastTaskResult -eq 0) {
                Write-DiagLog "✓ Dernière exécution réussie"
            } elseif ($taskInfo.LastTaskResult -eq 267009) {
                Write-DiagLog "⚠ Tâche en cours d'exécution" "WARN"
            } else {
                Write-DiagLog "✗ Dernière exécution échouée (code: $($taskInfo.LastTaskResult))" "ERROR"
            }
            
            if ($taskInfo.NumberOfMissedRuns -gt 0) {
                Write-DiagLog "⚠ $($taskInfo.NumberOfMissedRuns) exécution(s) manquée(s)" "WARN"
            }
            
        } else {
            Write-DiagLog "✗ Tâche planifiée '$taskName' non trouvée" "ERROR"
            return $false
        }
    } Catch {
        Write-DiagLog "✗ Erreur lors de la vérification de la tâche planifiée: $($_.Exception.Message)" "ERROR"
        return $false
    }
    
    return $true
}

function Show-SystemInfo {
    Write-DiagLog "=== INFORMATIONS SYSTÈME ==="
    
    # Espace disque
    $drive = Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='D:'"
    if ($drive) {
        $freeSpaceGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($drive.Size / 1GB, 2)
        Write-DiagLog "Espace disque D: $freeSpaceGB GB libre sur $totalSpaceGB GB total"
    }
    
    # Version PowerShell
    Write-DiagLog "Version PowerShell: $($PSVersionTable.PSVersion)"
    
    # Version Git
    Try {
        $gitVersion = git --version
        Write-DiagLog "Version Git: $gitVersion"
    } Catch {
        Write-DiagLog "Git non disponible ou non installé" "WARN"
    }
    
    # Connectivité réseau
    Try {
        Test-NetConnection -ComputerName "github.com" -Port 443 -InformationLevel Quiet | Out-Null
        Write-DiagLog "✓ Connectivité réseau vers GitHub OK"
    } Catch {
        Write-DiagLog "✗ Problème de connectivité réseau vers GitHub" "ERROR"
    }
}

function Perform-QuickCheck {
    Write-DiagLog "=== VÉRIFICATION RAPIDE ==="
    
    $issues = 0
    
    # Vérifier les fichiers critiques
    $criticalFiles = @("sync_roo_environment.ps1", "roo-config/settings/settings.json")
    foreach ($file in $criticalFiles) {
        if (-not (Test-Path (Join-Path $RepoPath $file))) {
            Write-DiagLog "✗ Fichier critique manquant: $file" "ERROR"
            $issues++
        }
    }
    
    # Vérifier le log récent
    $logFile = Join-Path $RepoPath "sync_log.txt"
    if (Test-Path $logFile) {
        $lastLogEntry = Get-Content $logFile -Tail 1
        if ($lastLogEntry -and $lastLogEntry -match "ERREUR") {
            Write-DiagLog "⚠ Dernière entrée de log contient une erreur" "WARN"
            $issues++
        }
    }
    
    # Vérifier la tâche planifiée
    $task = Get-ScheduledTask -TaskName "RooEnvironmentSync" -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-DiagLog "✗ Tâche planifiée non configurée" "ERROR"
        $issues++
    }
    
    if ($issues -eq 0) {
        Write-DiagLog "✓ Vérification rapide: Aucun problème détecté"
    } else {
        Write-DiagLog "⚠ Vérification rapide: $issues problème(s) détecté(s)" "WARN"
    }
    
    return ($issues -eq 0)
}

function Show-Help {
    Write-Host @"
=== VALIDATEUR DE SYNCHRONISATION ROO ENVIRONMENT ===

Usage: .\validate-sync.ps1 -Action <action> [options]

Actions disponibles:
  full       - Diagnostic complet (par défaut)
  quick      - Vérification rapide des éléments critiques
  logs       - Affichage des logs de synchronisation
  conflicts  - Affichage des logs de conflits
  health     - Vérification de l'état de santé du système

Options:
  -LogLines <nombre>    - Nombre de lignes de log à afficher (défaut: 50)
  -RepoPath <chemin>    - Chemin vers le dépôt (défaut: d:\roo-extensions)

Exemples:
  .\validate-sync.ps1
  .\validate-sync.ps1 -Action quick
  .\validate-sync.ps1 -Action logs -LogLines 100
  .\validate-sync.ps1 -Action conflicts

"@
}

# === MAIN EXECUTION ===

Write-DiagLog "=== VALIDATEUR DE SYNCHRONISATION ROO ENVIRONMENT ==="
Write-DiagLog "Action: $Action"
Write-DiagLog "Répertoire: $RepoPath"

if (-not (Test-Path $RepoPath)) {
    Write-DiagLog "ERREUR: Répertoire non trouvé: $RepoPath" "ERROR"
    Exit 1
}

$overallSuccess = $true

switch ($Action.ToLower()) {
    "full" {
        Show-SystemInfo
        $overallSuccess = Test-GitRepositoryHealth -and $overallSuccess
        $overallSuccess = Test-ConfigurationFiles -and $overallSuccess
        $overallSuccess = Test-ScheduledTaskHealth -and $overallSuccess
        Show-SyncLogs -Lines $LogLines
        Show-ConflictLogs
    }
    
    "quick" {
        $overallSuccess = Perform-QuickCheck
    }
    
    "logs" {
        Show-SyncLogs -Lines $LogLines
    }
    
    "conflicts" {
        Show-ConflictLogs
    }
    
    "health" {
        Show-SystemInfo
        $overallSuccess = Test-GitRepositoryHealth -and $overallSuccess
        $overallSuccess = Test-ScheduledTaskHealth -and $overallSuccess
    }
    
    "help" {
        Show-Help
        Exit 0
    }
    
    default {
        Write-DiagLog "Action non reconnue: $Action" "ERROR"
        Show-Help
        Exit 1
    }
}

if ($overallSuccess) {
    Write-DiagLog "=== VALIDATION TERMINÉE: SUCCÈS ==="
    Exit 0
} else {
    Write-DiagLog "=== VALIDATION TERMINÉE: PROBLÈMES DÉTECTÉS ===" "WARN"
    Exit 1
}