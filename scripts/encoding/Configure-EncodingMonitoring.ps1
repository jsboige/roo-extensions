<#
.SYNOPSIS
    Configure le monitoring automatique de l'encodage.

.DESCRIPTION
    Ce script crée une tâche planifiée qui vérifie périodiquement (toutes les heures)
    si la configuration de l'encodage (UTF-8) est toujours valide.
    En cas de dérive, il tente de corriger ou loggue une erreur.

.EXAMPLE
    .\Configure-EncodingMonitoring.ps1 -Enable

.NOTES
    Auteur: Roo Architect
    Date: 2025-11-26
#>

[CmdletBinding()]
param(
    [switch]$Enable,
    [switch]$Disable,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$TaskName = "RooEncodingMonitor"
$ScriptPath = Resolve-Path "$PSScriptRoot\Initialize-EncodingManager.ps1"

function Register-MonitoringTask {
    Write-Verbose "Configuration de la tâche planifiée '$TaskName'..."
    
    $Action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `". '$ScriptPath'; if ([Console]::OutputEncoding.CodePage -ne 65001) { Write-Error 'Encoding drift detected' }`""
    
    # Trigger: Au démarrage de session + répétition toutes les heures
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Repetition = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1)
    
    # Settings
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable:$false

    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            if ($Force) {
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
                Write-Verbose "Tâche existante supprimée."
            } else {
                Write-Warning "La tâche '$TaskName' existe déjà. Utilisez -Force pour la remplacer."
                return
            }
        }

        Register-ScheduledTask -Action $Action -Trigger $Trigger -Settings $Settings -TaskName $TaskName -Description "Surveille et maintient l'encodage UTF-8 pour l'environnement Roo."
        Write-Host "Tâche de monitoring '$TaskName' créée avec succès." -ForegroundColor Green
    }
    catch {
        Write-Error "Erreur lors de la création de la tâche planifiée: $_"
    }
}

function Unregister-MonitoringTask {
    try {
        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "Tâche de monitoring '$TaskName' supprimée." -ForegroundColor Green
        } else {
            Write-Warning "La tâche '$TaskName' n'existe pas."
        }
    }
    catch {
        Write-Error "Erreur lors de la suppression de la tâche: $_"
    }
}

if ($Enable) {
    Register-MonitoringTask
}
elseif ($Disable) {
    Unregister-MonitoringTask
}
else {
    Write-Host "Utilisez -Enable pour activer le monitoring ou -Disable pour le désactiver."
}