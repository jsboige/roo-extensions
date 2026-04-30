<#
.SYNOPSIS
    Finalisation de l'archivage Phase 1 - Cleanup residuel
.DESCRIPTION
    Consolide tous les fichiers residuels et finalise l'archivage Phase 1
.EXAMPLE
    .\finalize-phase1-archiving.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$rootPath = "c:/dev/roo-extensions"
Set-Location $rootPath

Write-Host "=== Debut Archivage Residuel Phase 1 ===" -ForegroundColor Cyan

# ETAPE 1 : Validation prealable
Write-Host "`n[1/5] Validation prealable..." -ForegroundColor Yellow
if (-not (Test-Path "archive.zip")) {
    Write-Error "archive.zip introuvable !"
    exit 1
}
$archiveInfo = Get-Item "archive.zip"
Write-Host "OK archive.zip trouve: $([math]::Round($archiveInfo.Length / 1MB, 2)) MB"

# ETAPE 2 : Organisation des rapports
Write-Host "`n[2/5] Deplacement des rapports d'analyse..." -ForegroundColor Yellow
if (Test-Path "analysis-reports") {
    New-Item -ItemType Directory -Path "docs/rapports/analyses" -Force | Out-Null
    $reports = Get-ChildItem "analysis-reports" -File
    foreach ($report in $reports) {
        Move-Item $report.FullName "docs/rapports/analyses/" -Force
        Write-Host "  OK Deplace: $($report.Name)"
    }
    
    $subDirs = Get-ChildItem "analysis-reports" -Directory
    foreach ($dir in $subDirs) {
        $targetDir = "docs/rapports/analyses/$($dir.Name)"
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        Move-Item "$($dir.FullName)/*" $targetDir -Force
        Write-Host "  OK Deplace dossier: $($dir.Name)"
    }
    Remove-Item "analysis-reports" -Recurse -Force
    Write-Host "OK Rapports deplaces vers docs/rapports/analyses/"
}

# ETAPE 3 : Archivage cleanup-backups
Write-Host "`n[3/5] Archivage cleanup-backups..." -ForegroundColor Yellow
if (Test-Path "cleanup-backups") {
    if (-not (Test-Path "archive/backups")) {
        New-Item -ItemType Directory -Path "archive/backups" -Force | Out-Null
    }
    Compress-Archive -Path "cleanup-backups/*" `
                     -DestinationPath "archive/backups/cleanup-backups-20250527.zip" `
                     -CompressionLevel Optimal -Force
    $backupInfo = Get-Item "archive/backups/cleanup-backups-20250527.zip"
    Write-Host "OK cleanup-backups.zip cree: $([math]::Round($backupInfo.Length / 1MB, 2)) MB"
}

# ETAPE 4 : Consolidation archive.zip
Write-Host "`n[4/5] Consolidation archive.zip..." -ForegroundColor Yellow
$tempArchive = "temp-archive-consolidation"
Expand-Archive -Path "archive.zip" -DestinationPath $tempArchive -Force
Write-Host "OK archive.zip extrait temporairement"

# Ajouter le contenu d'archive/backups/ (extraire les ZIP)
if (Test-Path "archive/backups") {
    $backupZips = Get-ChildItem "archive/backups" -Filter "*.zip"
    foreach ($zip in $backupZips) {
        $extractDir = "$tempArchive/$($zip.BaseName)"
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
        Expand-Archive -Path $zip.FullName -DestinationPath $extractDir -Force
        Write-Host "OK Contenu de $($zip.Name) extrait et ajoute"
    }
}

# Recompresser
Remove-Item "archive.zip" -Force
Start-Sleep -Seconds 2  # Attendre que les handles soient liberes
Compress-Archive -Path "$tempArchive/*" -DestinationPath "archive.zip" -CompressionLevel Optimal -Force
$finalArchiveInfo = Get-Item "archive.zip"
Write-Host "OK archive.zip consolide: $([math]::Round($finalArchiveInfo.Length / 1MB, 2)) MB"

# Nettoyage avec retry
Start-Sleep -Seconds 1
try {
    Remove-Item $tempArchive -Recurse -Force -ErrorAction Stop
} catch {
    Start-Sleep -Seconds 2
    Remove-Item $tempArchive -Recurse -Force -ErrorAction SilentlyContinue
}

# ETAPE 5 : Nettoyage final
Write-Host "`n[5/5] Nettoyage final..." -ForegroundColor Yellow
$toRemove = @("archive", "cleanup-backups", "sync_conflicts", "encoding-fix")
foreach ($item in $toRemove) {
    if (Test-Path $item) {
        Remove-Item $item -Recurse -Force
        Write-Host "OK Supprime: $item"
    }
}

Write-Host "`n=== Archivage Residuel Phase 1 Termine ===" -ForegroundColor Green
Write-Host "`nResume:"
Write-Host "  - archive.zip final: $([math]::Round($finalArchiveInfo.Length / 1MB, 2)) MB"
Write-Host "  - Dossiers supprimes: $($toRemove -join ', ')"
Write-Host "  - Rapports deplaces: docs/rapports/analyses/"