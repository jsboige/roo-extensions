# Script d'analyse détaillée d'un stash spécifique
# Usage: .\analyze-stash-detailed.ps1 -RepoPath "d:/roo-extensions" -StashIndex 0

param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath,
    
    [Parameter(Mandatory=$true)]
    [int]$StashIndex,
    
    [string]$OutputDir = "docs/git/stash-details"
)

$ErrorActionPreference = "Stop"

# Créer le répertoire de sortie si nécessaire
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Aller dans le dépôt
Push-Location $RepoPath

try {
    $stashRef = "stash@{$StashIndex}"
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "ANALYSE DÉTAILLÉE - $stashRef" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    # 1. Information de base
    Write-Host "1. INFORMATION DE BASE" -ForegroundColor Yellow
    $stashInfo = git stash list --date=iso | Select-String -Pattern "stash@\{$StashIndex\}"
    Write-Host $stashInfo
    Write-Host ""
    
    # 2. Fichiers modifiés avec statut
    Write-Host "2. FICHIERS MODIFIÉS (avec statut)" -ForegroundColor Yellow
    $filesStatus = git stash show $stashRef --name-status 2>&1
    if ($LASTEXITCODE -eq 0) {
        $filesStatus | ForEach-Object { Write-Host "  $_" }
        $fileCount = ($filesStatus | Measure-Object).Count
        Write-Host "`n  Total fichiers: $fileCount" -ForegroundColor Green
    } else {
        Write-Host "  Erreur lors de la récupération des fichiers" -ForegroundColor Red
    }
    Write-Host ""
    
    # 3. Statistiques
    Write-Host "3. STATISTIQUES" -ForegroundColor Yellow
    $stats = git stash show $stashRef --stat 2>&1
    if ($LASTEXITCODE -eq 0) {
        $stats | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  Erreur lors de la récupération des stats" -ForegroundColor Red
    }
    Write-Host ""
    
    # 4. Vérifier fichiers non suivis (untracked)
    Write-Host "4. FICHIERS NON SUIVIS" -ForegroundColor Yellow
    $untrackedRef = "$stashRef^3"
    $hasUntracked = git rev-parse --verify $untrackedRef 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Ce stash contient des fichiers non suivis!" -ForegroundColor Yellow
        $untrackedFiles = git diff-tree --no-commit-id --name-only -r $untrackedRef 2>&1
        if ($LASTEXITCODE -eq 0) {
            $untrackedFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Cyan }
        }
    } else {
        Write-Host "  Aucun fichier non suivi" -ForegroundColor Gray
    }
    Write-Host ""
    
    # 5. Diff complet (tronqué pour l'affichage)
    Write-Host "5. DIFF (premiers 50 lignes)" -ForegroundColor Yellow
    $diff = git stash show $stashRef -p 2>&1
    if ($LASTEXITCODE -eq 0) {
        $diffLines = $diff | Select-Object -First 50
        $diffLines | ForEach-Object { Write-Host $_ }
        $totalLines = ($diff | Measure-Object).Count
        if ($totalLines -gt 50) {
            Write-Host "`n  ... ($($totalLines - 50) lignes supplémentaires tronquées)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Erreur lors de la récupération du diff" -ForegroundColor Red
    }
    Write-Host ""
    
    # 6. Exporter vers fichier
    $outputFile = Join-Path $OutputDir "stash-$StashIndex-$(Split-Path $RepoPath -Leaf)-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    $output = @"
========================================
ANALYSE DÉTAILLÉE STASH
========================================
Dépôt: $RepoPath
Stash: $stashRef
Date analyse: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

========================================
INFORMATION DE BASE
========================================
$stashInfo

========================================
FICHIERS MODIFIÉS
========================================
$filesStatus

========================================
STATISTIQUES
========================================
$stats

========================================
FICHIERS NON SUIVIS
========================================
"@

    if ($LASTEXITCODE -eq 0 -and $hasUntracked) {
        $output += "`n$untrackedFiles"
    } else {
        $output += "`nAucun fichier non suivi"
    }

    $output += @"

========================================
DIFF COMPLET
========================================
$diff

"@
    
    $output | Out-File -FilePath $outputFile -Encoding UTF8
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Analyse exportée vers:" -ForegroundColor Green
    Write-Host "  $outputFile" -ForegroundColor White
    Write-Host "========================================`n" -ForegroundColor Cyan
    
    return @{
        StashRef = $stashRef
        FileCount = $fileCount
        HasUntracked = ($LASTEXITCODE -eq 0)
        OutputFile = $outputFile
    }
}
catch {
    Write-Host "`nErreur: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
finally {
    Pop-Location
}