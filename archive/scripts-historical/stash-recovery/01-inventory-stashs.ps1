#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Inventaire complet des stashs Git pour la mission de récupération
    
.DESCRIPTION
    Script d'inventaire des stashs dans les 3 dépôts :
    - roo-extensions (principal)
    - mcps/internal (submodule)
    - mcps/internal/servers/roo-state-manager (submodule)
    
.NOTES
    Date: 2025-10-16
    Mission: Récupération de Stashs Git Perdus
    Tâche: 01 - Inventaire Complet
#>

param(
    [string]$OutputDir = "scripts/stash-recovery/output",
    [string]$Timestamp = (Get-Date -Format "yyyyMMdd-HHmmss")
)

# Créer le répertoire de sortie
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$reportFile = "$OutputDir/stash-inventory-$Timestamp.md"

function Invoke-StashInventory {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    
    Write-Host "=== Inventaire: $RepoName ===" -ForegroundColor Cyan
    Write-Host "Chemin: $RepoPath" -ForegroundColor Gray
    
    if (-not (Test-Path "$RepoPath/.git")) {
        Write-Host "ATTENTION: Pas de dépôt Git trouvé!" -ForegroundColor Red
        return @{
            RepoName = $RepoName
            RepoPath = $RepoPath
            Error = "No Git repository found"
            Stashes = @()
        }
    }
    
    Push-Location $RepoPath
    
    try {
        # Obtenir la liste des stashs
        $stashList = git stash list --date=iso 2>&1
        $stashCount = ($stashList | Measure-Object).Count
        
        Write-Host "Nombre de stashs: $stashCount" -ForegroundColor Yellow
        
        $stashes = @()
        
        if ($stashCount -gt 0) {
            for ($i = 0; $i -lt $stashCount; $i++) {
                Write-Host "  Analyse stash@{$i}..." -ForegroundColor Gray
                
                # Obtenir les infos du stash
                $stashInfo = git stash list --date=iso | Select-Object -Index $i
                
                # Obtenir les stats
                $stats = git stash show stash@{$i} --stat 2>&1
                
                # Obtenir le diff (limité pour ne pas surcharger)
                $diff = git stash show -p stash@{$i} 2>&1
                
                # Obtenir la branche d'origine
                $branch = if ($stashInfo -match 'On ([^:]+):') { $matches[1] } else { "unknown" }
                
                # Obtenir la date
                $date = if ($stashInfo -match '\d{4}-\d{2}-\d{2}') { $matches[0] } else { "unknown" }
                
                # Obtenir la description
                $description = if ($stashInfo -match ': (.+)$') { $matches[1] } else { "No description" }
                
                $stashes += @{
                    Index = $i
                    Reference = "stash@{$i}"
                    Branch = $branch
                    Date = $date
                    Description = $description
                    FullInfo = $stashInfo
                    Stats = $stats -join "`n"
                    DiffLineCount = ($diff | Measure-Object).Count
                    Diff = $diff -join "`n"
                }
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
# 📋 INVENTAIRE DES STASHS GIT
**Date**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Mission**: Récupération de Stashs Git Perdus

---

"@

# Inventorier les 3 dépôts
$repos = @(
    @{ Name = "roo-state-manager"; Path = "mcps/internal/servers/roo-state-manager" },
    @{ Name = "mcps-internal"; Path = "mcps/internal" },
    @{ Name = "roo-extensions"; Path = "." }
)

$allInventories = @()

foreach ($repo in $repos) {
    Write-Host "`n========================================" -ForegroundColor Magenta
    $inventory = Invoke-StashInventory -RepoPath $repo.Path -RepoName $repo.Name
    $allInventories += $inventory
    
    # Ajouter au rapport
    $report += @"

## 📦 Dépôt: $($inventory.RepoName)
**Chemin**: ``$($inventory.RepoPath)``
**Branche actuelle**: ``$($inventory.CurrentBranch)``
**Dernier commit**: ``$($inventory.LastCommit)``
**Nombre de stashs**: **$($inventory.StashCount)**

"@

    if ($inventory.StashCount -gt 0) {
        foreach ($stash in $inventory.Stashes) {
            $report += @"

### 🔖 $($stash.Reference)
- **Branche**: ``$($stash.Branch)``
- **Date**: $($stash.Date)
- **Description**: *$($stash.Description)*
- **Lignes de diff**: $($stash.DiffLineCount)

**Statistiques**:
``````
$($stash.Stats)
``````

<details>
<summary>📄 Voir le diff complet</summary>

``````diff
$($stash.Diff)
``````

</details>

"@
        }
    } else {
        $report += "*Aucun stash trouvé*`n`n"
    }
    
    $report += "---`n`n"
}

# Résumé global
$totalStashes = ($allInventories | ForEach-Object { $_.StashCount } | Measure-Object -Sum).Sum

$report += @"

## 📊 RÉSUMÉ GLOBAL

| Dépôt | Nombre de Stashs |
|-------|------------------|
"@

foreach ($inv in $allInventories) {
    $report += "| $($inv.RepoName) | $($inv.StashCount) |`n"
}

$report += @"
| **TOTAL** | **$totalStashes** |

---

## 🎯 PROCHAINES ÉTAPES

1. ✅ Inventaire complet effectué
2. ⏳ Analyser le contenu de chaque stash
3. ⏳ Vérifier les doublons avec commits existants
4. ⏳ Créer le plan de récupération
5. ⏳ Appliquer le plan de récupération

---

*Généré automatiquement par 01-inventory-stashs.ps1*
"@

# Sauvegarder le rapport
$report | Out-File -FilePath $reportFile -Encoding utf8

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "✅ Inventaire terminé!" -ForegroundColor Green
Write-Host "📄 Rapport sauvegardé: $reportFile" -ForegroundColor Cyan
Write-Host "📊 Total de stashs trouvés: $totalStashes" -ForegroundColor Yellow

# Retourner le chemin du rapport
return $reportFile