# Script d'archivage spécifique pour jupyter-mcp-server
$sourcePath = "mcps/internal/servers/jupyter-mcp-server"
$date = Get-Date -Format "yyyyMMdd-HHmm"
$backupName = "jupyter-mcp-server-legacy-backup-$date"
$archiveDir = "archive/backups"

# Vérifier si la source existe
if (-not (Test-Path $sourcePath)) {
    Write-Error "Le dossier source n'existe pas : $sourcePath"
    exit 1
}

# Créer le dossier d'archive s'il n'existe pas
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
    Write-Host "Dossier d'archive créé : $archiveDir"
}

$destinationZip = Join-Path $archiveDir "$backupName.zip"

Write-Host "Archivage de $sourcePath vers $destinationZip..."

# Compresser
Compress-Archive -Path $sourcePath -DestinationPath $destinationZip -Force

if (Test-Path $destinationZip) {
    Write-Host "✅ Archive créée avec succès : $destinationZip"
    
    # Supprimer le dossier source
    Write-Host "Suppression du dossier source..."
    Remove-Item -Path $sourcePath -Recurse -Force
    Write-Host "✅ Dossier source supprimé."
} else {
    Write-Error "❌ Échec de la création de l'archive."
    exit 1
}