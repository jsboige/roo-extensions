#!/usr/bin/env pwsh
# ==============================================================================
# Script: 04-phase2-compare-sync-checksums-20251022.ps1
# Description: Compare les checksums de sync_roo_environment.ps1 (RACINE) entre stashs
# Phase: Phase 2 - Analyse Comparative Scripts Sync
# Date: 2025-10-22
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PHASE 2 - COMPARAISON CHECKSUMS SYNC_ROO_ENVIRONMENT.PS1" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration - FICHIER À LA RACINE
$scriptPath = "sync_roo_environment.ps1"
$stashIndices = @(1, 5, 7, 8, 9)  # @{0} exclu car ne contient pas le script
$outputDir = "docs/git/phase2-analysis"
$reportFile = "$outputDir/sync-checksums-final-report.md"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "📁 Fichier analysé: $scriptPath (à la racine)" -ForegroundColor Yellow
Write-Host "📦 Stashs analysés: @{1}, @{5}, @{7}, @{8}, @{9}" -ForegroundColor Yellow
Write-Host "❌ Stash @{0} exclu: ne contient pas le script sync" -ForegroundColor Red
Write-Host ""

# Fonction pour extraire et hasher un fichier d'un stash
function Get-StashFileHash {
    param(
        [int]$StashIndex,
        [string]$FilePath
    )
    
    try {
        # Extraire le contenu du fichier depuis le stash
        $tempFile = [System.IO.Path]::GetTempFileName()
        git show "stash@{$StashIndex}:$FilePath" 2>$null | Out-File -FilePath $tempFile -Encoding UTF8
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $tempFile)) {
            $hash = (Get-FileHash -Path $tempFile -Algorithm SHA256).Hash
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            return $hash
        } else {
            Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            return $null
        }
    } catch {
        return $null
    }
}

# Table des résultats
$results = @()

Write-Host "🔍 Calcul des checksums..." -ForegroundColor Yellow
Write-Host ""

# Analyser chaque stash
foreach ($index in $stashIndices) {
    Write-Host "  📦 Stash @{$index}..." -NoNewline
    
    $hash = Get-StashFileHash -StashIndex $index -FilePath $scriptPath
    
    if ($hash) {
        $results += [PSCustomObject]@{
            Stash = "@{$index}"
            Hash = $hash
            ShortHash = $hash.Substring(0, 12)
        }
        Write-Host " ✓ $($hash.Substring(0, 12))..." -ForegroundColor Green
    } else {
        Write-Host " ✗ (erreur)" -ForegroundColor Red
        $results += [PSCustomObject]@{
            Stash = "@{$index}"
            Hash = "ERROR"
            ShortHash = "ERROR"
        }
    }
}

Write-Host ""
Write-Host "📄 Version actuelle (HEAD)..." -NoNewline

# Analyser HEAD
try {
    if (Test-Path $scriptPath) {
        $headHash = (Get-FileHash -Path $scriptPath -Algorithm SHA256).Hash
        $results += [PSCustomObject]@{
            Stash = "HEAD"
            Hash = $headHash
            ShortHash = $headHash.Substring(0, 12)
        }
        Write-Host " ✓ $($headHash.Substring(0, 12))..." -ForegroundColor Green
    } else {
        $headHash = "NOT_FOUND"
        $results += [PSCustomObject]@{
            Stash = "HEAD"
            Hash = "NOT_FOUND"
            ShortHash = "NOT_FOUND"
        }
        Write-Host " ✗ (fichier absent)" -ForegroundColor Red
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

# Initialiser le rapport Markdown
$report = @()
$report += "# PHASE 2 - RAPPORT FINAL CHECKSUMS SYNC"
$report += ""
$report += "**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "**Fichier analysé**: ``$scriptPath``"
$report += ""
$report += "## 📊 Checksums SHA256"
$report += ""
$report += "| Stash | Hash (12 premiers caractères) | Hash Complet |"
$report += "|-------|-------------------------------|--------------|"
foreach ($result in $results) {
    if ($result.Hash -eq "ERROR" -or $result.Hash -eq "NOT_FOUND") {
        $report += "| $($result.Stash.PadRight(6)) | $($result.Hash) | - |"
    } else {
        $report += "| $($result.Stash.PadRight(6)) | ``$($result.ShortHash)...`` | ``$($result.Hash)`` |"
    }
}
$report += ""

# Analyse des doublons
Write-Host "🔍 ANALYSE DES DOUBLONS:" -ForegroundColor Yellow
Write-Host ""

$report += "## 🔍 Analyse des Doublons"
$report += ""

$groupedByHash = $results | Where-Object { $_.Hash -ne "ERROR" -and $_.Hash -ne "NOT_FOUND" } | Group-Object -Property Hash

$duplicateGroups = @()
foreach ($group in $groupedByHash) {
    if ($group.Count -gt 1) {
        $stashList = ($group.Group.Stash -join ", ")
        Write-Host "  ⚠️  IDENTIQUES: $stashList" -ForegroundColor Cyan
        Write-Host "     Hash: $($group.Name.Substring(0, 16))..." -ForegroundColor DarkGray
        Write-Host ""
        
        $duplicateGroups += [PSCustomObject]@{
            Stashs = $stashList
            Hash = $group.Name
            Count = $group.Count
        }
        
        $report += "### ⚠️ Groupe de Doublons"
        $report += ""
        $report += "**Stashs identiques**: $stashList"
        $report += "**Hash**: ``$($group.Name)``"
        $report += "**Nombre**: $($group.Count)"
        $report += ""
    }
}

if ($duplicateGroups.Count -eq 0) {
    Write-Host "  ✓ Aucun doublon détecté" -ForegroundColor Green
    $report += "✓ **Aucun doublon détecté** - Chaque stash contient une version unique"
    $report += ""
}

# Comparaison avec HEAD
Write-Host "📊 COMPARAISON AVEC HEAD:" -ForegroundColor Yellow
Write-Host ""

$report += "## 📊 Comparaison avec HEAD"
$report += ""

$identicalToHead = @()
$differentFromHead = @()

foreach ($result in $results) {
    if ($result.Stash -ne "HEAD" -and $result.Hash -ne "ERROR" -and $result.Hash -ne "NOT_FOUND") {
        if ($headHash -ne "ERROR" -and $headHash -ne "NOT_FOUND") {
            if ($result.Hash -eq $headHash) {
                $identicalToHead += $result.Stash
                Write-Host "  ✓ $($result.Stash) : IDENTIQUE à HEAD" -ForegroundColor Green
                $report += "- ✅ **$($result.Stash)**: IDENTIQUE à HEAD"
            } else {
                $differentFromHead += $result.Stash
                Write-Host "  ⚠️  $($result.Stash) : DIFFÉRENT de HEAD" -ForegroundColor Yellow
                $report += "- ⚠️ **$($result.Stash)**: DIFFÉRENT de HEAD"
            }
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

$report += "## 📈 Résumé Exécutif"
$report += ""

Write-Host "📈 STATISTIQUES:" -ForegroundColor Yellow
Write-Host "  • Total stashs analysés: $($stashIndices.Count)" -ForegroundColor White
Write-Host "  • Identiques à HEAD: $($identicalToHead.Count)" -ForegroundColor Green
Write-Host "  • Différents de HEAD: $($differentFromHead.Count)" -ForegroundColor Yellow
Write-Host "  • Groupes de doublons: $($duplicateGroups.Count)" -ForegroundColor Cyan
Write-Host ""

$report += "- **Total stashs analysés**: $($stashIndices.Count)"
$report += "- **Identiques à HEAD**: $($identicalToHead.Count)"
$report += "- **Différents de HEAD**: $($differentFromHead.Count)"
$report += "- **Groupes de doublons**: $($duplicateGroups.Count)"
$report += ""

$report += "## 🎯 Classification et Recommandations"
$report += ""

# Catégorie A: Doublons exacts
if ($duplicateGroups.Count -gt 0) {
    Write-Host "✅ CATÉGORIE A - DOUBLONS EXACTS (DROP SÉCURISÉ):" -ForegroundColor Green
    $report += "### ✅ Catégorie A - Doublons Exacts"
    $report += ""
    $report += "**Recommandation**: DROP IMMÉDIAT des doublons (conserver 1 seul par groupe)"
    $report += ""
    
    foreach ($dupGroup in $duplicateGroups) {
        $stashs = $dupGroup.Stashs -split ', '
        $keepStash = $stashs[0]
        $dropStashs = $stashs[1..($stashs.Length-1)]
        
        Write-Host "  Groupe: $($dupGroup.Stashs)" -ForegroundColor White
        Write-Host "    → CONSERVER: $keepStash" -ForegroundColor Green
        Write-Host "    → DROP: $($dropStashs -join ', ')" -ForegroundColor Red
        Write-Host ""
        
        $report += "**Groupe**: $($dupGroup.Stashs)"
        $report += "- ✅ **CONSERVER**: $keepStash"
        $report += "- ❌ **DROP**: $($dropStashs -join ', ')"
        $report += ""
    }
}

# Catégorie B: Déjà intégrés
if ($identicalToHead.Count -gt 0) {
    Write-Host "✅ CATÉGORIE B - DÉJÀ INTÉGRÉS (DROP SÉCURISÉ):" -ForegroundColor Green
    $report += "### ✅ Catégorie B - Déjà Intégrés dans HEAD"
    $report += ""
    $report += "**Recommandation**: DROP IMMÉDIAT (100% identiques à la version actuelle)"
    $report += ""
    
    foreach ($stash in $identicalToHead) {
        Write-Host "  • $stash : 100% identique à HEAD → DROP" -ForegroundColor Green
        $report += "- ❌ **$stash**: 100% identique à HEAD → DROP"
    }
    Write-Host ""
    $report += ""
}

# Catégorie C: Modifications uniques
if ($differentFromHead.Count -gt 0) {
    Write-Host "⚠️  CATÉGORIE C - MODIFICATIONS UNIQUES (À ANALYSER):" -ForegroundColor Yellow
    $report += "### ⚠️ Catégorie C - Modifications Uniques"
    $report += ""
    $report += "**Recommandation**: ANALYSE APPROFONDIE requise avant décision"
    $report += ""
    
    foreach ($stash in $differentFromHead) {
        Write-Host "  • $stash : Contient modifications NON présentes dans HEAD" -ForegroundColor Yellow
        Write-Host "    → Nécessite examen détaillé du diff" -ForegroundColor Yellow
        $report += "- ⚠️ **$stash**: Modifications NON présentes dans HEAD"
        $report += "  - Action requise: Examiner le diff avec ``git stash show -p $stash``"
    }
    Write-Host ""
    $report += ""
}

# Note spéciale pour @{0}
$report += "## 🚫 Stash Exclu de l'Analyse"
$report += ""
$report += "- **@{0}**: Ne contient PAS ``sync_roo_environment.ps1``"
$report += "  - Contient: ``cleanup-backups/`` et ``mcps/tests/github-projects/``"
$report += "  - **Recommandation**: Examiner séparément si nécessaire"
$report += ""

# Prochaines étapes
$report += "## 🔄 Prochaines Étapes"
$report += ""
$report += "1. **Valider les drops sécurisés** (Catégories A + B)"
$report += "2. **Analyser en détail Catégorie C** (diffs complets)"
$report += "3. **Décider de la récupération sélective** si modifications importantes"
$report += "4. **Créer script de validation finale** avant drops"
$report += "5. **Exécuter les drops** après triple vérification"
$report += ""

# Sauvegarder le rapport
$report | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "💾 Rapport sauvegardé: $reportFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Analyse terminée!" -ForegroundColor Green
Write-Host ""

# Retourner les résultats pour traitement ultérieur
return [PSCustomObject]@{
    Results = $results
    DuplicateGroups = $duplicateGroups
    IdenticalToHead = $identicalToHead
    DifferentFromHead = $differentFromHead
    ReportFile = $reportFile
}