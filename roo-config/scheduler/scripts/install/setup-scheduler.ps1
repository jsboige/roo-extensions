# Script de configuration du scheduler pour la synchronisation Roo Environment
# Fichier : d:/roo-extensions/roo-config/scheduler/setup-scheduler.ps1
# Version: 1.0

param(
    [Parameter(Mandatory=$false)]
    [string]$Action = "install", # install, uninstall, status, test
    
    [Parameter(Mandatory=$false)]
    [string]$ScheduleInterval = "30", # Intervalle en minutes (par défaut: 30 minutes)
    
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "RooEnvironmentSync",
    
    [Parameter(Mandatory=$false)]
    [string]$ScriptPath = "d:\roo-extensions\sync_roo_environment.ps1"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path "d:\roo-extensions\scheduler_setup.log" -Value $logMessage -ErrorAction SilentlyContinue
}

function Test-AdminRights {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-ScheduledTask {
    Write-Log "Installation de la tâche planifiée '$TaskName'..."
    
    if (-not (Test-AdminRights)) {
        Write-Log "ERREUR: Droits administrateur requis pour installer une tâche planifiée." "ERROR"
        return $false
    }
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "ERREUR: Script de synchronisation non trouvé à l'emplacement: $ScriptPath" "ERROR"
        return $false
    }
    
    Try {
        # Supprimer la tâche existante si elle existe
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Write-Log "Suppression de la tâche existante '$TaskName'..." "WARN"
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }
        
        # Créer l'action de la tâche
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -File `"$ScriptPath`""
        
        # Créer le déclencheur (répétition toutes les X minutes)
        $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $ScheduleInterval) -RepetitionDuration (New-TimeSpan -Days 365)
        
        # Créer les paramètres de la tâche
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
        
        # Créer le principal (utilisateur système pour éviter les problèmes de session)
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        # Enregistrer la tâche
        Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Synchronisation automatique de l'environnement Roo avec le dépôt Git"
        
        Write-Log "Tâche planifiée '$TaskName' installée avec succès."
        Write-Log "Intervalle de répétition: $ScheduleInterval minutes"
        Write-Log "Script exécuté: $ScriptPath"
        
        return $true
        
    } Catch {
        Write-Log "Échec de l'installation de la tâche planifiée. Erreur: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Uninstall-ScheduledTask {
    Write-Log "Désinstallation de la tâche planifiée '$TaskName'..."
    
    if (-not (Test-AdminRights)) {
        Write-Log "ERREUR: Droits administrateur requis pour désinstaller une tâche planifiée." "ERROR"
        return $false
    }
    
    Try {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existingTask) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Log "Tâche planifiée '$TaskName' désinstallée avec succès."
            return $true
        } else {
            Write-Log "Aucune tâche planifiée '$TaskName' trouvée." "WARN"
            return $true
        }
    } Catch {
        Write-Log "Échec de la désinstallation de la tâche planifiée. Erreur: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Get-TaskStatus {
    Write-Log "Vérification du statut de la tâche planifiée '$TaskName'..."
    
    Try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($task) {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
            Write-Log "=== STATUT DE LA TÂCHE PLANIFIÉE ==="
            Write-Log "Nom: $($task.TaskName)"
            Write-Log "État: $($task.State)"
            Write-Log "Dernière exécution: $($taskInfo.LastRunTime)"
            Write-Log "Prochaine exécution: $($taskInfo.NextRunTime)"
            Write-Log "Dernier résultat: $($taskInfo.LastTaskResult)"
            Write-Log "Nombre d'exécutions manquées: $($taskInfo.NumberOfMissedRuns)"
            
            # Afficher les déclencheurs
            Write-Log "=== DÉCLENCHEURS ==="
            foreach ($trigger in $task.Triggers) {
                Write-Log "Type: $($trigger.CimClass.CimClassName)"
                if ($trigger.Repetition) {
                    Write-Log "Répétition: Toutes les $($trigger.Repetition.Interval)"
                    Write-Log "Durée: $($trigger.Repetition.Duration)"
                }
            }
            
            return $true
        } else {
            Write-Log "Aucune tâche planifiée '$TaskName' trouvée." "WARN"
            return $false
        }
    } Catch {
        Write-Log "Erreur lors de la vérification du statut. Erreur: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Test-SyncScript {
    Write-Log "Test d'exécution du script de synchronisation..."
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Log "ERREUR: Script de synchronisation non trouvé à l'emplacement: $ScriptPath" "ERROR"
        return $false
    }
    
    Try {
        Write-Log "Exécution du script de test: $ScriptPath"
        $result = & PowerShell.exe -ExecutionPolicy Bypass -File $ScriptPath
        $exitCode = $LASTEXITCODE
        
        Write-Log "Script terminé avec le code de sortie: $exitCode"
        
        if ($exitCode -eq 0) {
            Write-Log "Test du script de synchronisation réussi."
            return $true
        } else {
            Write-Log "Test du script de synchronisation échoué (code de sortie: $exitCode)." "ERROR"
            return $false
        }
        
    } Catch {
        Write-Log "Erreur lors du test du script. Erreur: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Show-Help {
    Write-Host @"
=== GESTIONNAIRE DE SCHEDULER ROO ENVIRONMENT ===

Usage: .\setup-scheduler.ps1 -Action <action> [options]

Actions disponibles:
  install    - Installe la tâche planifiée (nécessite des droits admin)
  uninstall  - Désinstalle la tâche planifiée (nécessite des droits admin)
  status     - Affiche le statut de la tâche planifiée
  test       - Teste l'exécution du script de synchronisation
  help       - Affiche cette aide

Options:
  -ScheduleInterval <minutes>  - Intervalle de répétition en minutes (défaut: 30)
  -TaskName <nom>             - Nom de la tâche planifiée (défaut: RooEnvironmentSync)
  -ScriptPath <chemin>        - Chemin vers le script de synchronisation

Exemples:
  .\setup-scheduler.ps1 -Action install
  .\setup-scheduler.ps1 -Action install -ScheduleInterval 15
  .\setup-scheduler.ps1 -Action status
  .\setup-scheduler.ps1 -Action test
  .\setup-scheduler.ps1 -Action uninstall

"@
}

# === MAIN EXECUTION ===

Write-Log "=== GESTIONNAIRE DE SCHEDULER ROO ENVIRONMENT ==="
Write-Log "Action demandée: $Action"

switch ($Action.ToLower()) {
    "install" {
        $success = Install-ScheduledTask
        if ($success) {
            Write-Log "Installation terminée avec succès."
            Get-TaskStatus | Out-Null
        } else {
            Write-Log "Installation échouée." "ERROR"
            Exit 1
        }
    }
    
    "uninstall" {
        $success = Uninstall-ScheduledTask
        if ($success) {
            Write-Log "Désinstallation terminée avec succès."
        } else {
            Write-Log "Désinstallation échouée." "ERROR"
            Exit 1
        }
    }
    
    "status" {
        $success = Get-TaskStatus
        if (-not $success) {
            Exit 1
        }
    }
    
    "test" {
        $success = Test-SyncScript
        if (-not $success) {
            Exit 1
        }
    }
    
    "help" {
        Show-Help
    }
    
    default {
        Write-Log "Action non reconnue: $Action" "ERROR"
        Show-Help
        Exit 1
    }
}

Write-Log "=== FIN DU GESTIONNAIRE DE SCHEDULER ==="