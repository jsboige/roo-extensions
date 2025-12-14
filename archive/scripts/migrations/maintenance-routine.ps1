#Requires -Version 5.1
[CmdletBinding()]
param ()

$ErrorActionPreference = "Stop"

function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Write-Output $logLine
}

Write-Log "Début de la routine de maintenance."

# --- Nettoyage des anciens logs ---
$logDir = "logs"
$daysToKeep = 30
$limit = (Get-Date).AddDays(-$daysToKeep)

Write-Log "Nettoyage des fichiers de log de plus de $daysToKeep jours dans le répertoire '$logDir'..."

if (Test-Path -Path $logDir) {
    try {
        $oldLogs = Get-ChildItem -Path $logDir -Recurse -File | Where-Object { $_.LastWriteTime -lt $limit }
        if ($oldLogs) {
            foreach ($log in $oldLogs) {
                Write-Log "Suppression du fichier de log ancien: $($log.FullName)"
                Remove-Item -Path $log.FullName -Force
            }
            Write-Log -Level "SUCCESS" -Message "Nettoyage des anciens fichiers de log terminé."
        } else {
            Write-Log "Aucun fichier de log ancien à supprimer."
        }
    } catch {
        Write-Log -Level "ERROR" -Message "Erreur lors du nettoyage des logs: $($_.Exception.Message)"
    }
} else {
    Write-Log -Level "WARNING" -Message "Le répertoire de logs '$logDir' n'existe pas. Aucune action de nettoyage effectuée."
}


# --- Nettoyage des fichiers temporaires (exemple) ---
# Ajoutez ici d'autres logiques de nettoyage si nécessaire.
# Par exemple, vider un répertoire temporaire spécifique.
# $tempDir = "temp"
# if(Test-Path -Path $tempDir){
#     Remove-Item -Path "$tempDir\*" -Recurse -Force
#     Write-Log "Répertoire temporaire '$tempDir' vidé."
# }

Write-Log "Routine de maintenance terminée."