#!/usr/bin/env pwsh
# ==============================================================================
# Script: 02-phase2-verify-checksums-20251022.ps1
# Description: Vérification des checksums SHA256 des 6 stashs scripts sync
# Phase: Phase 2 - Analyse Comparative Scripts Sync
# Date: 2025-10-22
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PHASE 2 - VÉRIFICATION CHECKSUMS STASHS SYNC" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration
$stashIndices = @(0, 1, 5, 7, 8, 9)
$scriptPath = "RooSync/sync_roo_environment.ps1"
$outputDir = "docs/git/phase2-analysis"
$reportFile = "$outputDir/checksums-report.txt"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Initialiser le rapport
$report = @()
$report += "═══════════════════════════════════════════════════════"
$report += "  PHASE 2 - RAPPORT CHECKSUMS SHA256"
$report += "  Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "═══════════════════════════════════════════════════════"
$report += ""

# Fonction pour calculer le hash d'un stash
function Get-StashChecksum {
    param(
        [int]$StashIndex,
        [string]$FilePath
    )
    
    try {
        $content = git show "stash@{$StashIndex}:$FilePath" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $hash = ($content | Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($content)))).Hash
            return $hash
        } else {
            return $null
        }
    } catch {
        return $null
    }
}

# Table des résultats
$results = @()

Write-Host "🔍 Analyse des stashs..." -ForegroundColor Yellow
Write-Host ""

# Analyser chaque stash
foreach ($index in $stashIndices) {
    Write-Host "  📦 Stash @{$index}..." -NoNewline
    
    $hash = Get-StashChecksum -StashIndex $index -FilePath $scriptPath
    
    if ($hash) {
        $results += [PSCustomObject]@{
            Stash = "@{$index}"
            Hash = $hash
        }
        Write-Host " ✓" -ForegroundColor Green
    } else {
        Write-Host " ✗ (erreur)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Stash = "@{$index}"
            Hash = "ERROR"
        }
    }
}

Write-Host ""
Write-Host "📄 Version actuelle (HEAD)..." -NoNewline

# Analyser HEAD
try {
    $headContent = git show "HEAD:$scriptPath"
    if ($LASTEXITCODE -eq 0) {
        $headHash = ($headContent | Get-FileHash -Algorithm SHA256 -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($headContent)))).Hash
        $results += [PSCustomObject]@{
            Stash = "HEAD"
            Hash = $headHash
        }
        Write-Host " ✓" -ForegroundColor Green
    } else {
        $headHash = "ERROR"
        Write-Host " ✗ (erreur)" -ForegroundColor Red
    }
} catch {
    $headHash = "ERROR"
    Write-Host " ✗ (erreur)" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSULTATS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Afficher la table
$results | Format-Table -AutoSize

# Ajouter au rapport
$report += "📊 CHECKSUMS SHA256:"
$report += ""
foreach ($result in $results) {
    $report += "$($result.Stash.PadRight(15)) : $($result.Hash)"
}
$report += ""

# Analyse des doublons
Write-Host "🔍 ANALYSE DES DOUBLONS:" -ForegroundColor Yellow
Write-Host ""

$groupedByHash = $results | Group-Object -Property Hash
$report += "🔍 ANALYSE DES DOUBLONS:"
$report += ""

$duplicates = @()
foreach ($group in $groupedByHash) {
    if ($group.Count -gt 1 -and $group.Name -ne "ERROR") {
        $stashList = ($group.Group.Stash -join ", ")
        Write-Host "  ⚠️  IDENTIQUES: $stashList" -ForegroundColor Cyan
        Write-Host "     Hash: $($group.Name)" -ForegroundColor DarkGray
        Write-Host ""
        
        $report += "  ⚠️  IDENTIQUES: $stashList"
        $report += "     Hash: $($group.Name)"
        $report += ""
        
        $duplicates += $group.Group.Stash
    }
}

# Comparaison avec HEAD
Write-Host "📊 COMPARAISON AVEC HEAD:" -ForegroundColor Yellow
Write-Host ""

$report += "📊 COMPARAISON AVEC HEAD:"
$report += ""

$identicalToHead = @()
$differentFromHead = @()

foreach ($result in $results) {
    if ($result.Stash -ne "HEAD" -and $result.Hash -ne "ERROR") {
        if ($result.Hash -eq $headHash) {
            $identicalToHead += $result.Stash
            Write-Host "  ✓ $($result.Stash) : IDENTIQUE à HEAD" -ForegroundColor Green
            $report += "  ✓ $($result.Stash) : IDENTIQUE à HEAD"
        } else {
            $differentFromHead += $result.Stash
            Write-Host "  ⚠️  $($result.Stash) : DIFFÉRENT de HEAD" -ForegroundColor Yellow
            $report += "  ⚠️  $($result.Stash) : DIFFÉRENT de HEAD"
        }
    }
}

Write-Host ""
$report += ""

# Résumé et recommandations
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ ET RECOMMANDATIONS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$report += "═══════════════════════════════════════════════════════"
$report += "  RÉSUMÉ ET RECOMMANDATIONS"
$report += "═══════════════════════════════════════════════════════"
$report += ""

Write-Host "📈 STATISTIQUES:" -ForegroundColor Yellow
Write-Host "  • Stashs analysés: $($stashIndices.Count)" -ForegroundColor White
Write-Host "  • Identiques à HEAD: $($identicalToHead.Count)" -ForegroundColor Green
Write-Host "  • Différents de HEAD: $($differentFromHead.Count)" -ForegroundColor Yellow
Write-Host ""

$report += "📈 STATISTIQUES:"
$report += "  • Stashs analysés: $($stashIndices.Count)"
$report += "  • Identiques à HEAD: $($identicalToHead.Count)"
$report += "  • Différents de HEAD: $($differentFromHead.Count)"
$report += ""

if ($identicalToHead.Count -gt 0) {
    Write-Host "✅ CATÉGORIE B - DÉJÀ INTÉGRÉS (DROP SÉCURISÉ):" -ForegroundColor Green
    foreach ($stash in $identicalToHead) {
        Write-Host "  • $stash : 100% identique à HEAD" -ForegroundColor Green
    }
    Write-Host "  → Recommandation: DROP IMMÉDIAT" -ForegroundColor Green
    Write-Host ""
    
    $report += "✅ CATÉGORIE B - DÉJÀ INTÉGRÉS (DROP SÉCURISÉ):"
    foreach ($stash in $identicalToHead) {
        $report += "  • $stash : 100% identique à HEAD"
    }
    $report += "  → Recommandation: DROP IMMÉDIAT"
    $report += ""
}

if ($differentFromHead.Count -gt 0) {
    Write-Host "⚠️  CATÉGORIE C - MODIFICATIONS UNIQUES (À ANALYSER):" -ForegroundColor Yellow
    foreach ($stash in $differentFromHead) {
        Write-Host "  • $stash : Contient modifications différentes de HEAD" -ForegroundColor Yellow
    }
    Write-Host "  → Recommandation: ANALYSE APPROFONDIE REQUISE" -ForegroundColor Yellow
    Write-Host ""
    
    $report += "⚠️  CATÉGORIE C - MODIFICATIONS UNIQUES (À ANALYSER):"
    foreach ($stash in $differentFromHead) {
        $report += "  • $stash : Contient modifications différentes de HEAD"
    }
    $report += "  → Recommandation: ANALYSE APPROFONDIE REQUISE"
    $report += ""
}

# Sauvegarder le rapport
$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "💾 Rapport sauvegardé: $reportFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Analyse terminée!" -ForegroundColor Green
Write-Host ""

# Retourner les résultats pour traitement ultérieur
return [PSCustomObject]@{
    Results = $results
    IdenticalToHead = $identicalToHead
    DifferentFromHead = $differentFromHead
    ReportFile = $reportFile
}