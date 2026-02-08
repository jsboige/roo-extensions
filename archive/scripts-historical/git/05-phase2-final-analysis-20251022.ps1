#!/usr/bin/env pwsh
# ==============================================================================
# Script: 05-phase2-final-analysis-20251022.ps1
# Description: Analyse finale Phase 2 avec comparaison RooSync/ vs racine
# Phase: Phase 2 - Analyse Comparative Scripts Sync
# Date: 2025-10-22
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PHASE 2 - ANALYSE FINALE ET CLASSIFICATION" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuration
$stashIndices = @(1, 5, 7, 8, 9)
$rootScriptPath = "sync_roo_environment.ps1"
$roosyncScriptPath = "RooSync/sync_roo_environment.ps1"
$outputDir = "docs/git/phase2-analysis"
$finalReportFile = "$outputDir/phase2-final-report.md"

Write-Host "🔍 Détection version actuelle..." -ForegroundColor Yellow
Write-Host ""

# Vérifier où se trouve le fichier actuellement
$currentScriptPath = $null
$currentScriptHash = $null

if (Test-Path $rootScriptPath) {
    $currentScriptPath = $rootScriptPath
    $currentScriptHash = (Get-FileHash -Path $rootScriptPath -Algorithm SHA256).Hash
    Write-Host "  ✓ Fichier trouvé à la RACINE" -ForegroundColor Green
} elseif (Test-Path $roosyncScriptPath) {
    $currentScriptPath = $roosyncScriptPath
    $currentScriptHash = (Get-FileHash -Path $roosyncScriptPath -Algorithm SHA256).Hash
    Write-Host "  ✓ Fichier trouvé dans ROOSYNC/" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Fichier absent des deux emplacements" -ForegroundColor Yellow
}

Write-Host "  📄 Emplacement: $currentScriptPath" -ForegroundColor White
if ($currentScriptHash) {
    Write-Host "  🔑 Hash: $($currentScriptHash.Substring(0, 16))..." -ForegroundColor DarkGray
}
Write-Host ""

# Fonction pour extraire et hasher un fichier d'un stash
function Get-StashFileHash {
    param(
        [int]$StashIndex,
        [string]$FilePath
    )
    
    try {
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

# Charger les checksums précédents
$stashChecksums = @{
    "@{1}" = "C1937E731CDEBE1160091732D07654316D8C13C6D88964A8BAF6DE2FE89895CD"
    "@{5}" = "20B68B6BE2E8DF6F11A38724978FE5D27FABEEC959C91E43D023A2BD10A48665"
    "@{7}" = "E10FB080D55CF71EC3192EC87D9D9457DE86314BD191F447EC2F50435BA2BB44"
    "@{8}" = "64C62577DF398528A294BEA23550F6F0418485862E80658D53ED13E705540C5C"
    "@{9}" = "6A8AFA5FD638CF0F26476433888DB0B5ECE7834AEEC3EDFD9A1CE9A913AA4290"
}

# Initialiser le rapport final
$report = @()
$report += "# PHASE 2 - RAPPORT FINAL D'ANALYSE"
$report += ""
$report += "**Date**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$report += "**Stashs analysés**: @{1}, @{5}, @{7}, @{8}, @{9}"
$report += "**Stash exclu**: @{0} (ne contient pas le script sync)"
$report += ""

# Analyse comparative avec HEAD
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  ANALYSE COMPARATIVE AVEC VERSION ACTUELLE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$report += "## 📊 Analyse Comparative"
$report += ""
$report += "### Version Actuelle"
$report += ""
if ($currentScriptPath) {
    $report += "- **Emplacement**: ``$currentScriptPath``"
    $report += "- **Hash**: ``$currentScriptHash``"
} else {
    $report += "- **Status**: ⚠️ Fichier absent (probablement supprimé ou renommé)"
}
$report += ""

$identicalToHead = @()
$differentFromHead = @()

if ($currentScriptHash) {
    $report += "### Comparaison Stashs vs HEAD"
    $report += ""
    
    foreach ($stash in $stashChecksums.Keys | Sort-Object) {
        $hash = $stashChecksums[$stash]
        
        if ($hash -eq $currentScriptHash) {
            $identicalToHead += $stash
            Write-Host "  ✅ $stash : IDENTIQUE à HEAD" -ForegroundColor Green
            $report += "- ✅ **$stash**: IDENTIQUE à HEAD → Peut être DROP"
        } else {
            $differentFromHead += $stash
            Write-Host "  ⚠️  $stash : DIFFÉRENT de HEAD" -ForegroundColor Yellow
            $report += "- ⚠️ **$stash**: DIFFÉRENT de HEAD → Analyse requise"
        }
    }
    Write-Host ""
    $report += ""
} else {
    $report += "⚠️ **Impossible de comparer** : version actuelle absente"
    $report += ""
    $differentFromHead = $stashChecksums.Keys
}

# Classification finale
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CLASSIFICATION FINALE" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$report += "## 🎯 Classification Finale des Stashs"
$report += ""

# Catégorie B: Déjà intégrés
if ($identicalToHead.Count -gt 0) {
    Write-Host "✅ CATÉGORIE B - DÉJÀ INTÉGRÉS (DROP SÉCURISÉ)" -ForegroundColor Green
    Write-Host ""
    
    $report += "### ✅ Catégorie B - Déjà Intégrés dans HEAD"
    $report += ""
    $report += "**Nombre**: $($identicalToHead.Count)"
    $report += "**Recommandation**: ❌ **DROP IMMÉDIAT**"
    $report += ""
    
    foreach ($stash in $identicalToHead) {
        Write-Host "  • $stash → DROP sécurisé" -ForegroundColor Green
        $report += "- $stash : 100% identique à HEAD"
    }
    Write-Host ""
    $report += ""
}

# Catégorie C: Modifications uniques
if ($differentFromHead.Count -gt 0) {
    Write-Host "⚠️  CATÉGORIE C - VERSIONS HISTORIQUES UNIQUES" -ForegroundColor Yellow
    Write-Host ""
    
    $report += "### ⚠️ Catégorie C - Versions Historiques Uniques"
    $report += ""
    $report += "**Nombre**: $($differentFromHead.Count)"
    
    if (-not $currentScriptHash) {
        $report += "**Contexte**: Version actuelle ABSENTE → Fichier probablement déplacé/renommé"
        $report += "**Recommandation**: ⚠️ **CONSERVER 1-2 versions** pour historique"
    } else {
        $report += "**Recommandation**: ⚠️ **ANALYSER** avant décision finale"
    }
    $report += ""
    
    foreach ($stash in $differentFromHead) {
        Write-Host "  • $stash : Version historique unique" -ForegroundColor Yellow
        $report += "- $stash : ``$($stashChecksums[$stash].Substring(0, 16))...``"
    }
    Write-Host ""
    $report += ""
}

# Résumé exécutif
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ EXÉCUTIF" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$report += "## 📈 Résumé Exécutif"
$report += ""
$report += "| Métrique | Valeur |"
$report += "|----------|--------|"
$report += "| Stashs analysés | $($stashIndices.Count) |"
$report += "| Identiques à HEAD | $($identicalToHead.Count) |"
$report += "| Versions uniques | $($differentFromHead.Count) |"
$report += "| Doublons détectés | 0 |"
$report += ""

Write-Host "📊 STATISTIQUES FINALES:" -ForegroundColor Yellow
Write-Host "  • Stashs analysés: $($stashIndices.Count)" -ForegroundColor White
Write-Host "  • Identiques à HEAD: $($identicalToHead.Count)" -ForegroundColor Green
Write-Host "  • Versions uniques: $($differentFromHead.Count)" -ForegroundColor Yellow
Write-Host "  • Doublons: 0" -ForegroundColor Cyan
Write-Host ""

# Recommandations finales
$report += "## 💡 Recommandations Finales"
$report += ""

Write-Host "💡 RECOMMANDATIONS FINALES:" -ForegroundColor Cyan
Write-Host ""

if ($identicalToHead.Count -gt 0) {
    Write-Host "✅ Actions immédiates:" -ForegroundColor Green
    Write-Host "  • DROP des stashs Catégorie B (identiques à HEAD)" -ForegroundColor Green
    Write-Host "    Commande: git stash drop stash@{X}" -ForegroundColor DarkGray
    Write-Host ""
    
    $report += "### ✅ Actions Immédiates"
    $report += ""
    $report += "**DROP des stashs Catégorie B** (identiques à HEAD):"
    $report += ""
    foreach ($stash in $identicalToHead) {
        $report += "``````bash"
        $report += "git stash drop $stash"
        $report += "``````"
    }
    $report += ""
}

if ($differentFromHead.Count -gt 0) {
    Write-Host "⚠️  Actions avec précaution:" -ForegroundColor Yellow
    
    if (-not $currentScriptHash) {
        Write-Host "  • Version actuelle ABSENTE" -ForegroundColor Red
        Write-Host "  • Fichier probablement déplacé dans RooSync/" -ForegroundColor Yellow
        Write-Host "  • CONSERVER 1-2 stashs pour référence historique" -ForegroundColor Yellow
        Write-Host "  • Analyser chronologie avec git stash list" -ForegroundColor Yellow
        Write-Host ""
        
        $report += "### ⚠️ Actions avec Précaution"
        $report += ""
        $report += "**Contexte spécial** : Version actuelle ABSENTE à la racine"
        $report += ""
        $report += "Le fichier ``sync_roo_environment.ps1`` n'existe plus à la racine."
        $report += "Il a probablement été:"
        $report += "- Déplacé dans ``RooSync/sync_roo_environment.ps1``"
        $report += "- Renommé ou restructuré"
        $report += ""
        $report += "**Recommandations** :"
        $report += "1. **CONSERVER** au moins 1-2 stashs récents comme référence historique"
        $report += "2. Examiner la chronologie : ``git stash list --date=iso``"
        $report += "3. Identifier le stash le plus récent"
        $report += "4. DROP les autres stashs après vérification"
        $report += ""
    } else {
        Write-Host "  • Analyser diffs avec: git stash show -p stash@{X}" -ForegroundColor Yellow
        Write-Host "  • Décider de la récupération sélective si nécessaire" -ForegroundColor Yellow
        Write-Host ""
        
        $report += "### ⚠️ Actions avec Précaution"
        $report += ""
        $report += "Les stashs contiennent des versions différentes de HEAD."
        $report += ""
        $report += "**Prochaines étapes** :"
        $report += "1. Analyser les diffs : ``git stash show -p stash@{X}``"
        $report += "2. Identifier les modifications importantes"
        $report += "3. Décider de la récupération sélective si nécessaire"
        $report += "4. DROP après validation"
        $report += ""
    }
}

# Matrice de décision
$report += "## 🔍 Matrice de Décision"
$report += ""
$report += "| Stash | Hash (16 chars) | Catégorie | Action Recommandée |"
$report += "|-------|-----------------|-----------|-------------------|"

foreach ($stash in $stashChecksums.Keys | Sort-Object) {
    $hash = $stashChecksums[$stash]
    $hashShort = $hash.Substring(0, 16)
    
    if ($identicalToHead -contains $stash) {
        $report += "| $stash | ``$hashShort...`` | B (Intégré) | ❌ DROP |"
    } else {
        $report += "| $stash | ``$hashShort...`` | C (Unique) | ⚠️ Analyser |"
    }
}
$report += ""

# Prochaines étapes
$report += "## 🔄 Prochaines Étapes"
$report += ""
$report += "1. ✅ Valider ce rapport"
$report += "2. ❌ Exécuter les DROP sécurisés (Catégorie B)"
$report += "3. ⚠️ Analyser en détail Catégorie C"
$report += "4. 📋 Créer script de validation finale"
$report += "5. 🧹 Nettoyer les stashs après triple vérification"
$report += ""

# Sauvegarder le rapport
$report | Out-File -FilePath $finalReportFile -Encoding UTF8
Write-Host "💾 Rapport final sauvegardé: $finalReportFile" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Analyse Phase 2 terminée!" -ForegroundColor Green
Write-Host ""

# Retourner résultat
return [PSCustomObject]@{
    CurrentScriptPath = $currentScriptPath
    CurrentScriptHash = $currentScriptHash
    IdenticalToHead = $identicalToHead
    DifferentFromHead = $differentFromHead
    ReportFile = $finalReportFile
}