#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Analyse détaillée du contenu des stashs Git avec échappement correct
    
.DESCRIPTION
    Script corrigé pour récupérer le vrai contenu des stashs
    Utilise des variables pour éviter les problèmes d'échappement PowerShell
    
.NOTES
    Date: 2025-10-16
    Mission: Récupération de Stashs Git Perdus
    Tâche: 02 - Analyse Détaillée avec Contenu
#>

param(
    [string]$OutputDir = "scripts/stash-recovery/output",
    [string]$Timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
)

# Créer le répertoire de sortie
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$reportFile = "$OutputDir/stash-detailed-analysis-$Timestamp.md"

function Get-StashContent {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    
    Write-Host "=== Analyse détaillée: $RepoName ===" -ForegroundColor Cyan
    
    if (-not (Test-Path "$RepoPath/.git")) {
        Write-Host "ATTENTION: Pas de dépôt Git trouvé!" -ForegroundColor Red
        return $null
    }
    
    Push-Location $RepoPath
    
    try {
        # Obtenir le nombre de stashs
        $stashListOutput = git stash list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Erreur git stash list" -ForegroundColor Red
            return $null
        }
        
        $stashCount = ($stashListOutput | Measure-Object).Count
        Write-Host "Nombre de stashs: $stashCount" -ForegroundColor Yellow
        
        if ($stashCount -eq 0) {
            return @{
                RepoName = $RepoName
                RepoPath = $RepoPath
                StashCount = 0
                Stashes = @()
            }
        }
        
        $stashes = @()
        
        for ($i = 0; $i -lt $stashCount; $i++) {
            Write-Host "  Analyse stash $i..." -ForegroundColor Gray
            
            # Construire le nom du stash
            $stashName = "stash@{$i}"
            
            # Obtenir les infos avec dates
            $stashInfo = (git stash list --date=iso | Select-Object -Index $i) -as [string]
            
            # Parser les infos
            $branch = "unknown"
            $date = "unknown"
            $description = "No description"
            
            if ($stashInfo -match 'On ([^:]+):') {
                $branch = $matches[1]
            }
            if ($stashInfo -match '\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}') {
                $date = $matches[0]
            }
            if ($stashInfo -match ': (.+)$') {
                $description = $matches[1]
            }
            
            # Obtenir les stats (en utilisant une variable pour éviter problème d'échappement)
            $statsOutput = & git stash show $stashName --stat 2>&1
            $statsText = $statsOutput -join "`n"
            
            # Obtenir le diff complet
            $diffOutput = & git stash show -p $stashName 2>&1
            $diffText = $diffOutput -join "`n"
            
            # Compter les fichiers modifiés
            $filesChanged = ($statsOutput | Where-Object { $_ -match '\|' } | Measure-Object).Count
            
            # Extraire insertions/deletions
            $insertions = 0
            $deletions = 0
            if ($statsText -match '(\d+) insertion') {
                $insertions = [int]$matches[1]
            }
            if ($statsText -match '(\d+) deletion') {
                $deletions = [int]$matches[1]
            }
            
            $stashes += @{
                Index = $i
                Reference = $stashName
                Branch = $branch
                Date = $date
                Description = $description
                FullInfo = $stashInfo
                Stats = $statsText
                Diff = $diffText
                FilesChanged = $filesChanged
                Insertions = $insertions
                Deletions = $deletions
            }
        }
        
        return @{
            RepoName = $RepoName
            RepoPath = $RepoPath
            StashCount = $stashCount
            Stashes = $stashes
            CurrentBranch = (git branch --show-current)
            LastCommit = (git log -1 --oneline)
        }
        
    } finally {
        Pop-Location
    }
}

# Début du rapport
$report = @"
# 📋 ANALYSE DÉTAILLÉE DES STASHS GIT
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Mission**: Récupération de Stashs Git Perdus

---

"@

# Analyser les 3 dépôts
$repos = @(
    @{ Name = "mcps-internal"; Path = "mcps/internal" },
    @{ Name = "roo-extensions"; Path = "." }
)

$allAnalyses = @()

foreach ($repo in $repos) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    $analysis = Get-StashContent -RepoPath $repo.Path -RepoName $repo.Name
    
    if ($null -eq $analysis) {
        continue
    }
    
    $allAnalyses += $analysis
    
    # Ajouter au rapport
    $report += @"

## 📦 Dépôt: $($analysis.RepoName)
**Chemin**: ``$($analysis.RepoPath)``
**Branche actuelle**: ``$($analysis.CurrentBranch)``
**Dernier commit**: ``$($analysis.LastCommit)``
**Nombre de stashs**: **$($analysis.StashCount)**

"@

    if ($analysis.StashCount -gt 0) {
        foreach ($stash in $analysis.Stashes) {
            $report += @"

### 🔖 $($stash.Reference) - $($stash.Description)

**Métadonnées**:
- **Branche**: ``$($stash.Branch)``
- **Date**: $($stash.Date)
- **Fichiers modifiés**: $($stash.FilesChanged)
- **Insertions**: +$($stash.Insertions)
- **Suppressions**: -$($stash.Deletions)

**Statistiques détaillées**:
``````
$($stash.Stats)
``````

<details>
<summary>📄 Voir le diff complet ($($stash.Diff.Split("`n").Count) lignes)</summary>

``````diff
$($stash.Diff)
``````

</details>

---

"@
        }
    } else {
        $report += "*Aucun stash trouvé*`n`n"
    }
}

# Statistiques globales
$totalStashes = ($allAnalyses | ForEach-Object { $_.StashCount } | Measure-Object -Sum).Sum
$totalInsertions = ($allAnalyses | ForEach-Object { $_.Stashes | ForEach-Object { $_.Insertions } } | Measure-Object -Sum).Sum
$totalDeletions = ($allAnalyses | ForEach-Object { $_.Stashes | ForEach-Object { $_.Deletions } } | Measure-Object -Sum).Sum

$report += @"

## 📊 STATISTIQUES GLOBALES

| Dépôt | Stashs | Insertions | Suppressions |
|-------|--------|------------|--------------|
"@

foreach ($analysis in $allAnalyses) {
    $repoInsertions = ($analysis.Stashes | ForEach-Object { $_.Insertions } | Measure-Object -Sum).Sum
    $repoDeletions = ($analysis.Stashes | ForEach-Object { $_.Deletions } | Measure-Object -Sum).Sum
    $report += "| $($analysis.RepoName) | $($analysis.StashCount) | +$repoInsertions | -$repoDeletions |`n"
}

$report += "| **TOTAL** | **$totalStashes** | **+$totalInsertions** | **-$totalDeletions** |`n`n"

$report += @"

## 🎯 ANALYSE PAR STASH

"@

# Créer un tableau récapitulatif
foreach ($analysis in $allAnalyses) {
    if ($analysis.StashCount -gt 0) {
        $report += "`n### Dépôt: $($analysis.RepoName)`n`n"
        $report += "| Ref | Branche | Date | Description | Fichiers |`n"
        $report += "|-----|---------|------|-------------|----------|`n"
        
        foreach ($stash in $analysis.Stashes) {
            $shortDesc = if ($stash.Description.Length -gt 50) { 
                $stash.Description.Substring(0, 47) + "..." 
            } else { 
                $stash.Description 
            }
            $report += "| $($stash.Reference) | $($stash.Branch) | $($stash.Date.Split(' ')[0]) | $shortDesc | $($stash.FilesChanged) |`n"
        }
    }
}

$report += @"

---

## 🔍 PROCHAINES ÉTAPES

1. ✅ Inventaire complet effectué
2. ✅ Analyse détaillée du contenu
3. ⏳ Vérifier les doublons avec commits existants
4. ⏳ Créer le plan de récupération (STASH_RECOVERY_PLAN.md)
5. ⏳ Appliquer le plan de récupération

---

*Généré automatiquement par 02-detailed-stash-analysis.ps1*
"@

# Sauvegarder le rapport
$report | Out-File -FilePath $reportFile -Encoding utf8

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "✅ Analyse détaillée terminée!" -ForegroundColor Green
Write-Host "📄 Rapport sauvegardé: $reportFile" -ForegroundColor Cyan
Write-Host "📊 Total de stashs: $totalStashes" -ForegroundColor Yellow
Write-Host "📊 Insertions totales: +$totalInsertions" -ForegroundColor Green
Write-Host "📊 Suppressions totales: -$totalDeletions" -ForegroundColor Red

return $reportFile