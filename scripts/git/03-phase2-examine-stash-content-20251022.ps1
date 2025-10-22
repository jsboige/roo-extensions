#!/usr/bin/env pwsh
# ==============================================================================
# Script: 03-phase2-examine-stash-content-20251022.ps1
# Description: Examine le contenu exact des 6 stashs pour identifier les fichiers présents
# Phase: Phase 2 - Analyse Comparative Scripts Sync
# Date: 2025-10-22
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PHASE 2 - EXAMEN CONTENU DES STASHS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration
$stashIndices = @(0, 1, 5, 7, 8, 9)
$outputDir = "docs/git/phase2-analysis"
$reportFile = "$outputDir/stash-content-report.txt"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Initialiser le rapport
$report = @()
$report += "═══════════════════════════════════════════════════════"
$report += "  PHASE 2 - CONTENU DES STASHS"
$report += "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "═══════════════════════════════════════════════════════"
$report += ""

Write-Host "🔍 Examen des stashs..." -ForegroundColor Yellow
Write-Host ""

foreach ($index in $stashIndices) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  📦 STASH @{$index}" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    $report += "═══════════════════════════════════════════════════════"
    $report += "  📦 STASH @{$index}"
    $report += "═══════════════════════════════════════════════════════"
    $report += ""
    
    # Obtenir les métadonnées du stash
    Write-Host "📋 Métadonnées:" -ForegroundColor Yellow
    $stashInfo = git stash list --format="%gD|%gs|%gd" | Where-Object { $_ -match "^stash@\{$index\}" }
    if ($stashInfo) {
        $parts = $stashInfo -split '\|'
        Write-Host "  Référence: $($parts[0])" -ForegroundColor White
        Write-Host "  Message: $($parts[1])" -ForegroundColor White
        $report += "  Référence: $($parts[0])"
        $report += "  Message: $($parts[1])"
    }
    Write-Host ""
    $report += ""
    
    # Lister tous les fichiers dans le stash
    Write-Host "📁 Fichiers modifiés:" -ForegroundColor Yellow
    $files = git stash show "stash@{$index}" --name-only 2>$null
    
    if ($LASTEXITCODE -eq 0 -and $files) {
        $report += "  Fichiers modifiés:"
        foreach ($file in $files) {
            Write-Host "  • $file" -ForegroundColor Green
            $report += "  • $file"
        }
    } else {
        Write-Host "  ⚠️  Aucun fichier modifié ou erreur" -ForegroundColor Yellow
        $report += "  ⚠️  Aucun fichier modifié ou erreur"
    }
    Write-Host ""
    $report += ""
    
    # Chercher spécifiquement les fichiers sync
    Write-Host "🔍 Fichiers 'sync' détectés:" -ForegroundColor Yellow
    $syncFiles = $files | Where-Object { $_ -like "*sync*" }
    if ($syncFiles) {
        foreach ($syncFile in $syncFiles) {
            Write-Host "  ✓ $syncFile" -ForegroundColor Cyan
            $report += "  ✓ $syncFile"
            
            # Obtenir les statistiques de ce fichier
            $stats = git stash show "stash@{$index}" --stat -- $syncFile 2>$null
            if ($stats) {
                Write-Host "    Stats: $stats" -ForegroundColor DarkGray
                $report += "    Stats: $stats"
            }
        }
    } else {
        Write-Host "  ⚠️  Aucun fichier 'sync' trouvé" -ForegroundColor Yellow
        $report += "  ⚠️  Aucun fichier 'sync' trouvé"
    }
    Write-Host ""
    $report += ""
    
    # Afficher les premières lignes du diff
    Write-Host "📄 Aperçu du diff (20 premières lignes):" -ForegroundColor Yellow
    $diff = git stash show "stash@{$index}" -p 2>$null | Select-Object -First 20
    if ($diff) {
        $report += "  Aperçu du diff:"
        foreach ($line in $diff) {
            Write-Host "  $line" -ForegroundColor DarkGray
            $report += "  $line"
        }
    } else {
        Write-Host "  ⚠️  Pas de diff disponible" -ForegroundColor Yellow
        $report += "  ⚠️  Pas de diff disponible"
    }
    Write-Host ""
    $report += ""
}

# Résumé
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$report += "═══════════════════════════════════════════════════════"
$report += "  RÉSUMÉ"
$report += "═══════════════════════════════════════════════════════"
$report += ""

# Analyser les patterns communs
Write-Host "📊 Analyse des patterns:" -ForegroundColor Yellow
Write-Host ""

$allFiles = @()
foreach ($index in $stashIndices) {
    $files = git stash show "stash@{$index}" --name-only 2>$null
    if ($files) {
        $allFiles += $files
    }
}

$uniqueFiles = $allFiles | Select-Object -Unique
Write-Host "  Fichiers uniques touchés: $($uniqueFiles.Count)" -ForegroundColor White
$report += "  Fichiers uniques touchés: $($uniqueFiles.Count)"

if ($uniqueFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "  Liste des fichiers uniques:" -ForegroundColor White
    $report += ""
    $report += "  Liste des fichiers uniques:"
    foreach ($file in $uniqueFiles) {
        Write-Host "  • $file" -ForegroundColor Green
        $report += "  • $file"
    }
}

Write-Host ""
$report += ""

# Sauvegarder le rapport
$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "💾 Rapport sauvegardé: $reportFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Examen terminé!" -ForegroundColor Green
Write-Host ""

# Recommandations
Write-Host "💡 RECOMMANDATIONS:" -ForegroundColor Yellow
Write-Host ""
if ($uniqueFiles.Count -eq 0) {
    Write-Host "  ⚠️  ALERTE: Aucun fichier détecté dans les stashs!" -ForegroundColor Red
    Write-Host "  → Les stashs sont peut-être vides ou corrompus" -ForegroundColor Red
    Write-Host "  → Vérifier manuellement avec: git stash show stash@{X} -p" -ForegroundColor Yellow
} elseif ($uniqueFiles -notcontains "RooSync/sync_roo_environment.ps1") {
    Write-Host "  ⚠️  ATTENTION: Le fichier RooSync/sync_roo_environment.ps1 n'est pas présent" -ForegroundColor Yellow
    Write-Host "  → Chemin potentiellement différent dans les stashs" -ForegroundColor Yellow
    Write-Host "  → Vérifier les chemins réels listés ci-dessus" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ Fichier sync trouvé dans les stashs" -ForegroundColor Green
    Write-Host "  → Procéder à l'analyse des checksums" -ForegroundColor Green
}
Write-Host ""