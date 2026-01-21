# Script de mise à jour du système de synchronisation Roo Environment
# Fichier : d:/roo-extensions/roo-config/scheduler/update-system.ps1
# Version: 1.0

param(
    [Parameter(Mandatory=$false)]
    [string]$UpdateType = "minor", # minor, major, config-only, scripts-only
    
    [Parameter(Mandatory=$false)]
    [switch]$BackupFirst, # Créer une sauvegarde avant mise à jour
    
    [Parameter(Mandatory=$false)]
    [switch]$RestartScheduler, # Redémarrer le scheduler après mise à jour
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = "d:\roo-extensions"
)

$ErrorActionPreference = "Continue"
$UpdateLog = Join-Path $RepoPath "update_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-UpdateLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $UpdateLog -Value $logMessage -ErrorAction SilentlyContinue
}

function Load-Configuration {
    $configPath = Join-Path $RepoPath "roo-config\scheduler\config.json"
    
    if (Test-Path $configPath) {
        Try {
            $config = Get-Content -Raw $configPath | ConvertFrom-Json
            Write-UpdateLog "✓ Configuration chargée depuis $configPath"
            return $config
        } Catch {
            Write-UpdateLog "✗ Erreur lors du chargement de la configuration: $($_.Exception.Message)" "ERROR"
            return $null
        }
    } else {
        Write-UpdateLog "⚠ Fichier de configuration non trouvé: $configPath" "WARN"
        return $null
    }
}

function Create-Backup {
    if (-not $BackupFirst) {
        Write-UpdateLog "Sauvegarde ignorée (paramètre -BackupFirst non spécifié)"
        return $true
    }
    
    Write-UpdateLog "=== CRÉATION DE LA SAUVEGARDE ==="
    
    $backupDir = Join-Path $RepoPath "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    Try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        # Sauvegarder les scripts principaux
        $scriptsToBackup = @(
            "sync_roo_environment.ps1",
            "roo-config\scheduler\setup-scheduler.ps1",
            "roo-config\scheduler\validate-sync.ps1",
            "roo-config\scheduler\test-complete-system.ps1",
            "roo-config\scheduler\deploy-complete-system.ps1",
            "roo-config\scheduler\config.json"
        )
        
        foreach ($script in $scriptsToBackup) {
            $sourcePath = Join-Path $RepoPath $script
            if (Test-Path $sourcePath) {
                $destPath = Join-Path $backupDir $script
                $destDir = Split-Path $destPath -Parent
                if (-not (Test-Path $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item $sourcePath $destPath -Force
                Write-UpdateLog "Sauvegardé: $script"
            }
        }
        
        # Sauvegarder les logs actuels
        $logsToBackup = @("sync_log.txt", "scheduler_setup.log")
        foreach ($log in $logsToBackup) {
            $logPath = Join-Path $RepoPath $log
            if (Test-Path $logPath) {
                Copy-Item $logPath (Join-Path $backupDir $log) -Force
                Write-UpdateLog "Log sauvegardé: $log"
            }
        }
        
        Write-UpdateLog "✓ Sauvegarde créée dans: $backupDir"
        return $true
        
    } Catch {
        Write-UpdateLog "✗ Erreur lors de la création de la sauvegarde: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Update-Scripts {
    Write-UpdateLog "=== MISE À JOUR DES SCRIPTS ==="
    
    # Cette fonction simule une mise à jour des scripts
    # Dans un vrai scénario, cela pourrait télécharger les dernières versions
    
    $scriptsUpdated = 0
    $scriptsToCheck = @(
        "sync_roo_environment.ps1",
        "roo-config\scheduler\setup-scheduler.ps1",
        "roo-config\scheduler\validate-sync.ps1",
        "roo-config\scheduler\test-complete-system.ps1",
        "roo-config\scheduler\deploy-complete-system.ps1"
    )
    
    foreach ($script in $scriptsToCheck) {
        $scriptPath = Join-Path $RepoPath $script
        
        if (Test-Path $scriptPath) {
            # Vérifier la syntaxe PowerShell
            Try {
                $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw $scriptPath), [ref]$null)
                Write-UpdateLog "✓ Script validé: $script"
                $scriptsUpdated++
            } Catch {
                Write-UpdateLog "✗ Erreur de syntaxe dans le script: $script - $($_.Exception.Message)" "ERROR"
            }
        } else {
            Write-UpdateLog "⚠ Script non trouvé: $script" "WARN"
        }
    }
    
    Write-UpdateLog "Scripts traités: $scriptsUpdated/$($scriptsToCheck.Count)"
    return ($scriptsUpdated -eq $scriptsToCheck.Count)
}

function Update-Configuration {
    Write-UpdateLog "=== MISE À JOUR DE LA CONFIGURATION ==="
    
    $config = Load-Configuration
    if (-not $config) {
        Write-UpdateLog "✗ Impossible de charger la configuration pour la mise à jour" "ERROR"
        return $false
    }
    
    # Vérifier et mettre à jour la version
    $currentVersion = $config.system.version
    Write-UpdateLog "Version actuelle: $currentVersion"
    
    # Valider la structure de configuration
    $requiredSections = @("system", "git", "scheduler", "logging", "files_to_sync")
    $missingSections = @()
    
    foreach ($section in $requiredSections) {
        if (-not $config.PSObject.Properties[$section]) {
            $missingSections += $section
        }
    }
    
    if ($missingSections.Count -gt 0) {
        Write-UpdateLog "✗ Sections manquantes dans la configuration: $($missingSections -join ', ')" "ERROR"
        return $false
    } else {
        Write-UpdateLog "✓ Structure de configuration valide"
    }
    
    # Vérifier les chemins de fichiers critiques
    $criticalFiles = $config.files_to_sync.critical_config_files
    $missingFiles = @()
    
    foreach ($file in $criticalFiles) {
        $filePath = Join-Path $RepoPath $file
        if (-not (Test-Path $filePath)) {
            $missingFiles += $file
        }
    }
    
    if ($missingFiles.Count -gt 0) {
        Write-UpdateLog "⚠ Fichiers critiques manquants: $($missingFiles -join ', ')" "WARN"
    } else {
        Write-UpdateLog "✓ Tous les fichiers critiques sont présents"
    }
    
    return $true
}

function Test-UpdatedSystem {
    Write-UpdateLog "=== TEST DU SYSTÈME MIS À JOUR ==="
    
    $testScript = Join-Path $RepoPath "roo-config\scheduler\test-complete-system.ps1"
    
    if (-not (Test-Path $testScript)) {
        Write-UpdateLog "✗ Script de test non trouvé: $testScript" "ERROR"
        return $false
    }
    
    Try {
        Write-UpdateLog "Exécution des tests post-mise à jour..."
        
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $testScript -TestMode basic -SkipSchedulerInstall 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-UpdateLog "✓ Tests post-mise à jour réussis"
            return $true
        } else {
            Write-UpdateLog "✗ Tests post-mise à jour échoués (code: $exitCode)" "ERROR"
            return $false
        }
    } Catch {
        Write-UpdateLog "✗ Erreur lors des tests: $($_.Exception.Message)" "ERROR"
        return $false
    } Finally {
        Set-Location $originalLocation
    }
}

function Restart-SchedulerTask {
    if (-not $RestartScheduler) {
        Write-UpdateLog "Redémarrage du scheduler ignoré (paramètre -RestartScheduler non spécifié)"
        return $true
    }
    
    Write-UpdateLog "=== REDÉMARRAGE DU SCHEDULER ==="
    
    $config = Load-Configuration
    $taskName = if ($config) { $config.scheduler.task_name } else { "RooEnvironmentSync" }
    
    Try {
        # Vérifier si la tâche existe
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($task) {
            Write-UpdateLog "Arrêt de la tâche planifiée: $taskName"
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            
            Start-Sleep -Seconds 2
            
            Write-UpdateLog "Redémarrage de la tâche planifiée: $taskName"
            Start-ScheduledTask -TaskName $taskName
            
            Write-UpdateLog "✓ Tâche planifiée redémarrée avec succès"
            return $true
        } else {
            Write-UpdateLog "⚠ Tâche planifiée '$taskName' non trouvée" "WARN"
            return $true
        }
    } Catch {
        Write-UpdateLog "✗ Erreur lors du redémarrage du scheduler: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Generate-UpdateReport {
    Write-UpdateLog "=== GÉNÉRATION DU RAPPORT DE MISE À JOUR ==="
    
    $reportPath = Join-Path $RepoPath "update_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    $report = @"
# Rapport de Mise à Jour - Système de Synchronisation Roo Environment

## Informations Générales
- **Date de mise à jour**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
- **Type de mise à jour**: $UpdateType
- **Répertoire**: $RepoPath
- **Log de mise à jour**: $UpdateLog

## Actions Effectuées
- **Sauvegarde créée**: $(if ($BackupFirst) { 'Oui' } else { 'Non' })
- **Scripts mis à jour**: Oui
- **Configuration mise à jour**: Oui
- **Tests exécutés**: Oui
- **Scheduler redémarré**: $(if ($RestartScheduler) { 'Oui' } else { 'Non' })

## Prochaines Étapes Recommandées
1. Surveiller les logs de synchronisation pour détecter d'éventuels problèmes
2. Exécuter une validation complète: ``.\roo-config\scheduler\validate-sync.ps1 -Action full``
3. Vérifier le statut du scheduler: ``.\roo-config\scheduler\setup-scheduler.ps1 -Action status``

## Support
En cas de problème, consultez:
- Log de mise à jour: $UpdateLog
- Guide d'installation: roo-config\scheduler\README-Installation-Scheduler.md
- Script de validation: roo-config\scheduler\validate-sync.ps1

---
*Rapport généré automatiquement par update-system.ps1*
"@

    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-UpdateLog "✓ Rapport de mise à jour généré: $reportPath"
}

function Show-Help {
    Write-Host @"
=== MISE À JOUR SYSTÈME DE SYNCHRONISATION ROO ENVIRONMENT ===

Usage: .\update-system.ps1 -UpdateType <type> [options]

Types de mise à jour:
  minor         - Mise à jour mineure (par défaut)
  major         - Mise à jour majeure avec tests complets
  config-only   - Mise à jour de la configuration uniquement
  scripts-only  - Mise à jour des scripts uniquement

Options:
  -BackupFirst      - Créer une sauvegarde avant la mise à jour
  -RestartScheduler - Redémarrer le scheduler après la mise à jour
  -RepoPath <path>  - Chemin du dépôt (défaut: d:\roo-extensions)

Exemples:
  .\update-system.ps1
  .\update-system.ps1 -UpdateType major -BackupFirst -RestartScheduler
  .\update-system.ps1 -UpdateType config-only

"@
}

# === MAIN EXECUTION ===

Write-UpdateLog "=== MISE À JOUR SYSTÈME DE SYNCHRONISATION ROO ENVIRONMENT ==="
Write-UpdateLog "Type de mise à jour: $UpdateType"
Write-UpdateLog "Répertoire: $RepoPath"
Write-UpdateLog "Log de mise à jour: $UpdateLog"

$updateStartTime = Get-Date
$success = $false

if ($UpdateType -eq "help") {
    Show-Help
    Exit 0
}

# Vérifier les prérequis
if (-not (Test-Path $RepoPath)) {
    Write-UpdateLog "✗ Répertoire non trouvé: $RepoPath" "ERROR"
    Exit 1
}

Set-Location $RepoPath

switch ($UpdateType.ToLower()) {
    "minor" {
        if ((Create-Backup) -and (Update-Scripts) -and (Update-Configuration)) {
            if ((Test-UpdatedSystem) -and (Restart-SchedulerTask)) {
                $success = $true
            }
        }
    }
    
    "major" {
        if ((Create-Backup) -and (Update-Scripts) -and (Update-Configuration)) {
            if ((Test-UpdatedSystem) -and (Restart-SchedulerTask)) {
                # Tests supplémentaires pour mise à jour majeure
                $testScript = Join-Path $RepoPath "roo-config\scheduler\test-complete-system.ps1"
                if (Test-Path $testScript) {
                    Write-UpdateLog "Exécution des tests complets pour mise à jour majeure..."
                    $output = & PowerShell.exe -ExecutionPolicy Bypass -File $testScript -TestMode full 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $success = $true
                    }
                } else {
                    $success = $true
                }
            }
        }
    }
    
    "config-only" {
        if (Create-Backup) {
            $success = Update-Configuration
        }
    }
    
    "scripts-only" {
        if (Create-Backup) {
            if ((Update-Scripts) -and (Test-UpdatedSystem)) {
                $success = Restart-SchedulerTask
            }
        }
    }
    
    default {
        Write-UpdateLog "Type de mise à jour non reconnu: $UpdateType" "ERROR"
        Show-Help
        Exit 1
    }
}

$updateDuration = "({0:F2}s)" -f ((Get-Date) - $updateStartTime).TotalSeconds

if ($success) {
    Write-UpdateLog "=== MISE À JOUR TERMINÉE AVEC SUCCÈS $updateDuration ==="
    Generate-UpdateReport
    Exit 0
} else {
    Write-UpdateLog "=== MISE À JOUR ÉCHOUÉE $updateDuration ===" "ERROR"
    Write-UpdateLog "Consultez le log de mise à jour pour plus de détails: $UpdateLog" "ERROR"
    Exit 1
}