# Script SDDD 12.6: Nettoyage de l'environnement pnpm
# Date: 2025-10-24T10:16:00Z
# Objectif: Nettoyer l'environnement pnpm corrompu

Write-Host "SDDD 12.6 - Nettoyage de l'environnement pnpm" -ForegroundColor Cyan

# Verification de l'installation de pnpm
try {
    $pnpmVersion = pnpm --version 2>$null
    Write-Host "Version pnpm detectee: $pnpmVersion" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: pnpm n'est pas installe ou accessible" -ForegroundColor Red
    exit 1
}

# Nettoyage des caches pnpm
Write-Host "`nNettoyage des caches pnpm:" -ForegroundColor Yellow

try {
    Write-Host "  Suppression du cache pnpm..." -ForegroundColor Yellow
    pnpm store prune 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Cache pnpm supprime avec succes" -ForegroundColor Green
    } else {
        Write-Host "  Attention: Erreur lors du nettoyage du cache" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Erreur: Impossible de nettoyer le cache pnpm" -ForegroundColor Red
}

# Nettoyage des node_modules
Write-Host "`nNettoyage des node_modules:" -ForegroundColor Yellow

$directoriesToClean = @(
    "node_modules",
    "webview-ui/node_modules",
    "src/node_modules"
)

$cleanedCount = 0

foreach ($dir in $directoriesToClean) {
    if (Test-Path $dir) {
        try {
            Write-Host "  Suppression de $dir..." -ForegroundColor Yellow
            Remove-Item $dir -Recurse -Force
            Write-Host "  $dir supprime avec succes" -ForegroundColor Green
            $cleanedCount++
        } catch {
            Write-Host "  Erreur: Impossible de supprimer $dir" -ForegroundColor Red
        }
    } else {
        Write-Host "  $dir n'existe pas" -ForegroundColor Gray
    }
}

# Nettoyage des fichiers de lock
Write-Host "`nNettoyage des fichiers de lock:" -ForegroundColor Yellow

$lockFiles = @(
    "pnpm-lock.yaml",
    "webview-ui/pnpm-lock.yaml",
    "src/pnpm-lock.yaml"
)

$removedLocks = 0

foreach ($file in $lockFiles) {
    if (Test-Path $file) {
        try {
            Write-Host "  Suppression de $file..." -ForegroundColor Yellow
            Remove-Item $file -Force
            Write-Host "  $file supprime avec succes" -ForegroundColor Green
            $removedLocks++
        } catch {
            Write-Host "  Erreur: Impossible de supprimer $file" -ForegroundColor Red
        }
    } else {
        Write-Host "  $file n'existe pas" -ForegroundColor Gray
    }
}

# Verification de l'espace disque
Write-Host "`nVerification de l'espace disque:" -ForegroundColor Yellow
$drive = Get-PSDrive -Name C
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
Write-Host "  Espace disque disponible: $freeSpaceGB GB" -ForegroundColor Green

Write-Host "`nResume SDDD 12.6:" -ForegroundColor Cyan
Write-Host "  Repertoires nettoyes: $cleanedCount/$($directoriesToClean.Count)" -ForegroundColor Green
Write-Host "  Fichiers de lock supprimes: $removedLocks/$($lockFiles.Count)" -ForegroundColor Green
Write-Host "  Espace disque disponible: $freeSpaceGB GB" -ForegroundColor Green

if ($cleanedCount -gt 0 -or $removedLocks -gt 0) {
    Write-Host "Nettoyage pnpm termine - Pret pour reinstallation des dependances (script 02)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Attention: Aucun nettoyage effectue" -ForegroundColor Yellow
    exit 1
}