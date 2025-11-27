<#
.SYNOPSIS
    Configure la surveillance automatisée de l'encodage.
.DESCRIPTION
    Installe une tâche planifiée Windows qui exécute périodiquement le dashboard d'encodage
    et enregistre les résultats dans un fichier de log.
.PARAMETER IntervalMinutes
    Intervalle de vérification en minutes (défaut: 60).
.PARAMETER Uninstall
    Supprime la configuration de monitoring existante.
.EXAMPLE
    .\Configure-EncodingMonitoring.ps1
.EXAMPLE
    .\Configure-EncodingMonitoring.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [int]$IntervalMinutes = 60,
    [switch]$Uninstall
)

$TaskName = "RooEncodingMonitor"
$ScriptPath = Resolve-Path "scripts/encoding/Get-EncodingDashboard.ps1"
$LogDir = Join-Path (Get-Location) "logs\encoding"
$LogFile = Join-Path $LogDir "monitor.log"
$PwshPath = (Get-Command pwsh).Source

# --- Désinstallation ---
if ($Uninstall) {
    Write-Host "Suppression de la configuration de monitoring..." -ForegroundColor Yellow
    
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Tâche planifiée '$TaskName' supprimée." -ForegroundColor Green
    } else {
        Write-Host "Tâche planifiée '$TaskName' introuvable." -ForegroundColor Gray
    }
    return
}

# --- Installation ---
Write-Host "Configuration du monitoring d'encodage..." -ForegroundColor Cyan

# 1. Création répertoire logs
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
    Write-Host "Répertoire de logs créé: $LogDir" -ForegroundColor Green
}

# 2. Définition de l'action
# On utilise un wrapper pour rediriger la sortie vers le log
$ActionScript = @"
`$Date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
`$Result = & '$ScriptPath' -OutputFormat JSON
Add-Content -Path '$LogFile' -Value "`[`$Date`] `$Result"
"@

$WrapperPath = Join-Path $LogDir "run-monitor.ps1"
$ActionScript | Out-File -FilePath $WrapperPath -Encoding UTF8 -Force

$Action = New-ScheduledTaskAction -Execute $PwshPath -Argument "-NoProfile -WindowStyle Hidden -File `"$WrapperPath`""

# 3. Définition du déclencheur
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# 4. Enregistrement de la tâche
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Description "Surveillance automatique de l'encodage Roo" -Force | Out-Null
    Write-Host "Tâche planifiée '$TaskName' créée avec succès." -ForegroundColor Green
    Write-Host "Intervalle: $IntervalMinutes minutes" -ForegroundColor Gray
    Write-Host "Logs: $LogFile" -ForegroundColor Gray
    
    # Test immédiat
    Write-Host "Lancement d'un test immédiat..." -ForegroundColor Cyan
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Test lancé. Vérifiez le fichier de log dans quelques secondes." -ForegroundColor Green
} catch {
    Write-Error "Erreur lors de la création de la tâche planifiée: $_"
    Write-Warning "Essayez d'exécuter ce script en tant qu'administrateur."
}