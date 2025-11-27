<#
.SYNOPSIS
    Effectue la rotation et le nettoyage des logs de monitoring d'encodage.
.DESCRIPTION
    Ce script archive le fichier de log courant (monitor.log) en ajoutant un timestamp,
    et supprime les archives plus anciennes qu'un nombre de jours spécifié.
.PARAMETER LogDir
    Répertoire contenant les logs (défaut: logs/encoding).
.PARAMETER RetentionDays
    Nombre de jours de rétention des logs (défaut: 30).
.EXAMPLE
    .\Maintenance-CleanLogs.ps1 -RetentionDays 7
#>

[CmdletBinding()]
param(
    [string]$LogDir = "logs\encoding",
    [int]$RetentionDays = 30
)

$ErrorActionPreference = "Stop"

# Résolution du chemin absolu
if (-not (Test-Path $LogDir)) {
    $LogDir = Join-Path (Get-Location) $LogDir
}

if (-not (Test-Path $LogDir)) {
    Write-Warning "Le répertoire de logs '$LogDir' n'existe pas."
    return
}

Write-Host "Maintenance des logs dans: $LogDir" -ForegroundColor Cyan

# 1. Rotation du log courant
$CurrentLog = Join-Path $LogDir "monitor.log"
if (Test-Path $CurrentLog) {
    $FileInfo = Get-Item $CurrentLog
    if ($FileInfo.Length -gt 0) {
        $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $ArchiveName = "monitor-$Timestamp.log"
        $ArchivePath = Join-Path $LogDir $ArchiveName

        Rename-Item -Path $CurrentLog -NewName $ArchiveName
        Write-Host "Log courant archivé: $ArchiveName" -ForegroundColor Green

        # Création d'un nouveau fichier vide
        New-Item -Path $CurrentLog -ItemType File | Out-Null
    } else {
        Write-Host "Log courant vide, pas de rotation nécessaire." -ForegroundColor Gray
    }
} else {
    Write-Host "Pas de fichier monitor.log trouvé." -ForegroundColor Yellow
}

# 2. Nettoyage des vieux logs
$CutoffDate = (Get-Date).AddDays(-$RetentionDays)
$OldLogs = Get-ChildItem -Path $LogDir -Filter "monitor-*.log" | Where-Object { $_.LastWriteTime -lt $CutoffDate }

if ($OldLogs) {
    foreach ($Log in $OldLogs) {
        Remove-Item -Path $Log.FullName -Force
        Write-Host "Log supprimé (expiration): $($Log.Name)" -ForegroundColor Yellow
    }
    Write-Host "$($OldLogs.Count) fichiers supprimés." -ForegroundColor Green
} else {
    Write-Host "Aucun log à supprimer (Rétention: $RetentionDays jours)." -ForegroundColor Gray
}

Write-Host "Maintenance terminée." -ForegroundColor Cyan