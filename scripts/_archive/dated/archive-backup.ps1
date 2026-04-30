<#
.SYNOPSIS
    Archive un dossier de backup et supprime le dossier source
.DESCRIPTION
    Crée une archive ZIP d'un dossier de backup puis supprime le dossier source
.PARAMETER BackupFolder
    Nom du dossier de backup à archiver
.EXAMPLE
    .\archive-backup.ps1 -BackupFolder "refactor-backup-20250528-223209"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupFolder
)

# Créer le dossier de destination
$archivePath = "archive/backups"
if (-not (Test-Path $archivePath)) {
    New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
    Write-Host "Dossier créé: $archivePath"
}

# Créer l'archive
$sourcePath = $BackupFolder
$destinationZip = "$archivePath/$BackupFolder.zip"

Write-Host "Création de l'archive..."
Compress-Archive -Path "$sourcePath/*" -DestinationPath $destinationZip -Force

# Vérifier l'archive
if (Test-Path $destinationZip) {
    $archiveInfo = Get-Item $destinationZip
    $sizeMB = [math]::Round($archiveInfo.Length / 1MB, 2)
    Write-Host "Archive créée avec succès: $destinationZip"
    Write-Host "Taille: $sizeMB MB"
    
    # Supprimer le dossier source
    Write-Host "Suppression du dossier source..."
    Remove-Item -Path $sourcePath -Recurse -Force
    Write-Host "Dossier source supprimé: $sourcePath"
} else {
    Write-Error "Échec de création de l'archive"
    exit 1
}