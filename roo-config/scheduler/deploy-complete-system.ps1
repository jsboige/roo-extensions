# Script de déploiement complet du système de synchronisation Roo Environment
# Fichier : d:/roo-extensions/roo-config/scheduler/deploy-complete-system.ps1
# Version: 1.0

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "install", # install, uninstall, reinstall, verify
    
    [Parameter(Mandatory=$false)]
    [int]$ScheduleInterval = 30, # Intervalle en minutes
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests, # Ignorer les tests préliminaires
    
    [Parameter(Mandatory=$false)]
    [switch]$Force, # Forcer l'installation même en cas d'avertissements
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = "d:\roo-extensions"
)

$ErrorActionPreference = "Stop"
$DeploymentLog = Join-Path $RepoPath "deployment_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

function Write-DeployLog {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $DeploymentLog -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    Write-DeployLog "=== VÉRIFICATION DES PRÉREQUIS ==="
    
    $issues = @()
    
    # Vérifier les droits administrateur
    if (-not (Test-AdminRights)) {
        $issues += "Droits administrateur requis pour installer le scheduler"
    }
    
    # Vérifier PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1+ requis (version actuelle: $($PSVersionTable.PSVersion))"
    }
    
    # Vérifier Git
    Try {
        git --version | Out-Null
    } Catch {
        $issues += "Git non installé ou non accessible"
    }
    
    # Vérifier le répertoire
    if (-not (Test-Path $RepoPath)) {
        $issues += "Répertoire $RepoPath non trouvé"
    }
    
    # Vérifier que c'est un dépôt Git
    $originalLocation = Get-Location
    Try {
        Set-Location $RepoPath
        git rev-parse --git-dir | Out-Null
    } Catch {
        $issues += "Le répertoire $RepoPath n'est pas un dépôt Git valide"
    } Finally {
        Set-Location $originalLocation
    }
    
    # Vérifier la connectivité
    Try {
        Set-Location $RepoPath
        git ls-remote origin | Out-Null
        Write-DeployLog "✓ Connectivité avec le dépôt distant vérifiée"
    } Catch {
        $issues += "Impossible de se connecter au dépôt distant"
    } Finally {
        Set-Location $originalLocation
    }
    
    if ($issues.Count -gt 0) {
        Write-DeployLog "PROBLÈMES DÉTECTÉS:" "ERROR"
        foreach ($issue in $issues) {
            Write-DeployLog "  - $issue" "ERROR"
        }
        
        if (-not $Force) {
            Write-DeployLog "Utilisez -Force pour ignorer ces avertissements" "ERROR"
            return $false
        } else {
            Write-DeployLog "Poursuite forcée malgré les avertissements" "WARN"
        }
    } else {
        Write-DeployLog "✓ Tous les prérequis sont satisfaits"
    }
    
    return $true
}

function Run-Tests {
    if ($SkipTests) {
        Write-DeployLog "Tests ignorés (paramètre -SkipTests)"
        return $true
    }
    
    Write-DeployLog "=== EXÉCUTION DES TESTS PRÉLIMINAIRES ==="
    
    $testScript = Join-Path $RepoPath "roo-config\scheduler\test-complete-system.ps1"
    
    if (-not (Test-Path $testScript)) {
        Write-DeployLog "Script de test non trouvé: $testScript" "WARN"
        return $true
    }
    
    Try {
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        Write-DeployLog "Exécution des tests de base..."
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $testScript -TestMode basic -SkipSchedulerInstall 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeployLog "✓ Tests préliminaires réussis"
            return $true
        } else {
            Write-DeployLog "✗ Tests préliminaires échoués (code: $exitCode)" "ERROR"
            if (-not $Force) {
                Write-DeployLog "Utilisez -Force pour ignorer les échecs de tests" "ERROR"
                return $false
            } else {
                Write-DeployLog "Poursuite forcée malgré les échecs de tests" "WARN"
                return $true
            }
        }
    } Catch {
        Write-DeployLog "Erreur lors de l'exécution des tests: $($_.Exception.Message)" "ERROR"
        return $Force
    } Finally {
        Set-Location $originalLocation
    }
}

function Install-System {
    Write-DeployLog "=== INSTALLATION DU SYSTÈME ==="
    
    $setupScript = Join-Path $RepoPath "roo-config\scheduler\setup-scheduler.ps1"
    
    if (-not (Test-Path $setupScript)) {
        Write-DeployLog "Script d'installation non trouvé: $setupScript" "ERROR"
        return $false
    }
    
    Try {
        Write-DeployLog "Installation de la tâche planifiée (intervalle: $ScheduleInterval minutes)..."
        
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action install -ScheduleInterval $ScheduleInterval 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeployLog "✓ Tâche planifiée installée avec succès"
            
            # Vérifier l'installation
            $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action status 2>&1
            $statusExitCode = $LASTEXITCODE
            
            if ($statusExitCode -eq 0) {
                Write-DeployLog "✓ Vérification de l'installation réussie"
                return $true
            } else {
                Write-DeployLog "⚠ Installation réussie mais vérification échouée" "WARN"
                return $true
            }
        } else {
            Write-DeployLog "✗ Échec de l'installation de la tâche planifiée (code: $exitCode)" "ERROR"
            return $false
        }
    } Catch {
        Write-DeployLog "Erreur lors de l'installation: $($_.Exception.Message)" "ERROR"
        return $false
    } Finally {
        Set-Location $originalLocation
    }
}

function Uninstall-System {
    Write-DeployLog "=== DÉSINSTALLATION DU SYSTÈME ==="
    
    $setupScript = Join-Path $RepoPath "roo-config\scheduler\setup-scheduler.ps1"
    
    if (-not (Test-Path $setupScript)) {
        Write-DeployLog "Script de désinstallation non trouvé: $setupScript" "ERROR"
        return $false
    }
    
    Try {
        Write-DeployLog "Désinstallation de la tâche planifiée..."
        
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $setupScript -Action uninstall 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeployLog "✓ Tâche planifiée désinstallée avec succès"
            return $true
        } else {
            Write-DeployLog "✗ Échec de la désinstallation (code: $exitCode)" "ERROR"
            return $false
        }
    } Catch {
        Write-DeployLog "Erreur lors de la désinstallation: $($_.Exception.Message)" "ERROR"
        return $false
    } Finally {
        Set-Location $originalLocation
    }
}

function Verify-Installation {
    Write-DeployLog "=== VÉRIFICATION DE L'INSTALLATION ==="
    
    $validateScript = Join-Path $RepoPath "roo-config\scheduler\validate-sync.ps1"
    
    if (-not (Test-Path $validateScript)) {
        Write-DeployLog "Script de validation non trouvé: $validateScript" "WARN"
        return $true
    }
    
    Try {
        Write-DeployLog "Exécution de la validation complète..."
        
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $validateScript -Action full 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeployLog "✓ Validation complète réussie"
            return $true
        } else {
            Write-DeployLog "⚠ Validation complète avec avertissements (code: $exitCode)" "WARN"
            return $true
        }
    } Catch {
        Write-DeployLog "Erreur lors de la validation: $($_.Exception.Message)" "ERROR"
        return $false
    } Finally {
        Set-Location $originalLocation
    }
}

function Test-SyncExecution {
    Write-DeployLog "=== TEST D'EXÉCUTION DE LA SYNCHRONISATION ==="
    
    $syncScript = Join-Path $RepoPath "sync_roo_environment.ps1"
    
    if (-not (Test-Path $syncScript)) {
        Write-DeployLog "Script de synchronisation non trouvé: $syncScript" "ERROR"
        return $false
    }
    
    Try {
        Write-DeployLog "Test d'exécution du script de synchronisation..."
        
        $originalLocation = Get-Location
        Set-Location $RepoPath
        
        $output = & PowerShell.exe -ExecutionPolicy Bypass -File $syncScript 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($exitCode -eq 0) {
            Write-DeployLog "✓ Test de synchronisation réussi"
            return $true
        } else {
            Write-DeployLog "✗ Test de synchronisation échoué (code: $exitCode)" "ERROR"
            return $false
        }
    } Catch {
        Write-DeployLog "Erreur lors du test de synchronisation: $($_.Exception.Message)" "ERROR"
        return $false
    } Finally {
        Set-Location $originalLocation
    }
}

function Show-PostInstallationInfo {
    Write-DeployLog "=== INFORMATIONS POST-INSTALLATION ==="
    
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                    INSTALLATION TERMINÉE AVEC SUCCÈS                        ║
╚══════════════════════════════════════════════════════════════════════════════╝

📋 RÉSUMÉ DE L'INSTALLATION:
   • Tâche planifiée: RooEnvironmentSync
   • Intervalle: $ScheduleInterval minutes
   • Script principal: sync_roo_environment.ps1
   • Log de déploiement: $DeploymentLog

🔧 COMMANDES UTILES:
   • Vérifier le statut:
     .\roo-config\scheduler\setup-scheduler.ps1 -Action status
   
   • Validation complète:
     .\roo-config\scheduler\validate-sync.ps1 -Action full
   
   • Voir les logs de synchronisation:
     .\roo-config\scheduler\validate-sync.ps1 -Action logs
   
   • Test complet du système:
     .\roo-config\scheduler\test-complete-system.ps1 -TestMode full

📊 SURVEILLANCE:
   • Logs principaux: sync_log.txt
   • Logs de conflits: sync_conflicts\
   • Planificateur de tâches Windows: Rechercher "RooEnvironmentSync"

⚠️  IMPORTANT:
   • La première synchronisation aura lieu dans $ScheduleInterval minutes
   • Surveillez les logs pour détecter d'éventuels problèmes
   • Consultez le guide: roo-config\scheduler\README-Installation-Scheduler.md

"@
}

function Show-Help {
    Write-Host @"
=== DÉPLOYEUR SYSTÈME DE SYNCHRONISATION ROO ENVIRONMENT ===

Usage: .\deploy-complete-system.ps1 -Action <action> [options]

Actions:
  install     - Installation complète du système (par défaut)
  uninstall   - Désinstallation complète du système
  reinstall   - Désinstallation puis réinstallation
  verify      - Vérification de l'installation existante

Options:
  -ScheduleInterval <minutes>  - Intervalle de synchronisation (défaut: 30)
  -SkipTests                   - Ignorer les tests préliminaires
  -Force                       - Forcer l'installation malgré les avertissements
  -RepoPath <chemin>          - Chemin du dépôt (défaut: d:\roo-extensions)

Exemples:
  .\deploy-complete-system.ps1
  .\deploy-complete-system.ps1 -Action install -ScheduleInterval 15
  .\deploy-complete-system.ps1 -Action reinstall -Force
  .\deploy-complete-system.ps1 -Action verify

"@
}

# === MAIN EXECUTION ===

Write-DeployLog "=== DÉPLOYEUR SYSTÈME DE SYNCHRONISATION ROO ENVIRONMENT ==="
Write-DeployLog "Version: 1.0"
Write-DeployLog "Action: $Action"
Write-DeployLog "Répertoire: $RepoPath"
Write-DeployLog "Intervalle: $ScheduleInterval minutes"
Write-DeployLog "Log de déploiement: $DeploymentLog"

$deploymentStartTime = Get-Date
$success = $false

switch ($Action.ToLower()) {
    "install" {
        if ((Test-Prerequisites) -and (Run-Tests)) {
            if (Install-System) {
                if ((Test-SyncExecution) -and (Verify-Installation)) {
                    $success = $true
                    Show-PostInstallationInfo
                }
            }
        }
    }
    
    "uninstall" {
        if (Test-Prerequisites) {
            $success = Uninstall-System
            if ($success) {
                Write-DeployLog "✓ Système désinstallé avec succès"
            }
        }
    }
    
    "reinstall" {
        if (Test-Prerequisites) {
            Write-DeployLog "Désinstallation de l'installation existante..."
            Uninstall-System | Out-Null  # Ignorer les erreurs de désinstallation
            
            if (Run-Tests) {
                if (Install-System) {
                    if ((Test-SyncExecution) -and (Verify-Installation)) {
                        $success = $true
                        Show-PostInstallationInfo
                    }
                }
            }
        }
    }
    
    "verify" {
        if (Test-Prerequisites) {
            $success = Verify-Installation
            if ($success) {
                Write-DeployLog "✓ Vérification terminée avec succès"
            }
        }
    }
    
    "help" {
        Show-Help
        Exit 0
    }
    
    default {
        Write-DeployLog "Action non reconnue: $Action" "ERROR"
        Show-Help
        Exit 1
    }
}

$deploymentDuration = "({0:F2}s)" -f ((Get-Date) - $deploymentStartTime).TotalSeconds

if ($success) {
    Write-DeployLog "=== DÉPLOIEMENT TERMINÉ AVEC SUCCÈS $deploymentDuration ==="
    Exit 0
} else {
    Write-DeployLog "=== DÉPLOIEMENT ÉCHOUÉ $deploymentDuration ===" "ERROR"
    Write-DeployLog "Consultez le log de déploiement pour plus de détails: $DeploymentLog" "ERROR"
    Exit 1
}