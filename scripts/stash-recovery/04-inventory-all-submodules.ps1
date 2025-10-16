# ============================================================================
# Script: Inventaire Global des Stashs - Tous les Sous-Modules
# Date: 2025-10-16
# Description: Extension de Phase 3B à tous les sous-modules du dépôt
# ============================================================================

$ErrorActionPreference = "Continue"
$repoRoot = "d:/dev/roo-extensions"

# Liste des sous-modules (depuis .gitmodules)
$submodules = @(
    'roo-code',
    'mcps/external/win-cli/server',
    'mcps/internal',
    'mcps/forked/modelcontextprotocol-servers',
    'mcps/external/mcp-server-ftp',
    'mcps/external/markitdown/source',
    'mcps/external/playwright/source',
    'mcps/external/Office-PowerPoint-MCP-Server'
)

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  INVENTAIRE GLOBAL DES STASHS - TOUS LES SOUS-MODULES  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$globalResults = @()
$totalStashs = 0

foreach($sm in $submodules) {
    $fullPath = Join-Path $repoRoot $sm
    
    Write-Host "─────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "🔍 Analyse: $sm" -ForegroundColor Yellow
    
    if(-not (Test-Path $fullPath)) {
        Write-Host "   ⚠️  Chemin introuvable" -ForegroundColor Red
        $globalResults += [PSCustomObject]@{
            Submodule = $sm
            Status = 'NOT_FOUND'
            StashCount = 0
            Stashs = @()
        }
        continue
    }
    
    Push-Location $fullPath
    
    try {
        # Vérifier si c'est un dépôt git
        $isGitRepo = git rev-parse --git-dir 2>$null
        if(-not $isGitRepo) {
            Write-Host "   ⚠️  Pas un dépôt Git" -ForegroundColor Red
            $globalResults += [PSCustomObject]@{
                Submodule = $sm
                Status = 'NOT_GIT'
                StashCount = 0
                Stashs = @()
            }
            Pop-Location
            continue
        }
        
        # Lister les stashs
        $stashOutput = git stash list 2>&1
        $stashList = @()
        
        if($LASTEXITCODE -eq 0 -and $stashOutput) {
            $stashList = $stashOutput -split "`n" | Where-Object { $_.Trim() -ne "" }
        }
        
        $stashCount = $stashList.Count
        $totalStashs += $stashCount
        
        if($stashCount -eq 0) {
            Write-Host "   ✅ Aucun stash" -ForegroundColor Green
            $status = 'CLEAN'
        } else {
            Write-Host "   📦 $stashCount stash(s) trouvé(s)" -ForegroundColor Cyan
            $status = 'HAS_STASHS'
            
            # Afficher les stashs
            foreach($stash in $stashList) {
                Write-Host "      $stash" -ForegroundColor Gray
            }
        }
        
        $globalResults += [PSCustomObject]@{
            Submodule = $sm
            Status = $status
            StashCount = $stashCount
            Stashs = $stashList
        }
        
    } catch {
        Write-Host "   ❌ Erreur: $_" -ForegroundColor Red
        $globalResults += [PSCustomObject]@{
            Submodule = $sm
            Status = 'ERROR'
            StashCount = 0
            Stashs = @()
        }
    } finally {
        Pop-Location
    }
}

# ============================================================================
# RÉSUMÉ GLOBAL
# ============================================================================

Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    RÉSUMÉ GLOBAL                        ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

$submodulesWithStashs = ($globalResults | Where-Object { $_.StashCount -gt 0 }).Count
$submodulesClean = ($globalResults | Where-Object { $_.Status -eq 'CLEAN' }).Count
$submodulesError = ($globalResults | Where-Object { $_.Status -in @('NOT_FOUND', 'NOT_GIT', 'ERROR') }).Count

Write-Host "📊 Statistiques:" -ForegroundColor White
Write-Host "   • Sous-modules analysés: $($submodules.Count)" -ForegroundColor White
Write-Host "   • Sous-modules avec stashs: $submodulesWithStashs" -ForegroundColor $(if($submodulesWithStashs -gt 0){'Yellow'}else{'Green'})
Write-Host "   • Sous-modules propres: $submodulesClean" -ForegroundColor Green
Write-Host "   • Sous-modules en erreur: $submodulesError" -ForegroundColor $(if($submodulesError -gt 0){'Red'}else{'Gray'})
Write-Host "   • Total de stashs: $totalStashs" -ForegroundColor $(if($totalStashs -gt 0){'Yellow'}else{'Green'})

# ============================================================================
# PRIORITÉS
# ============================================================================

if($submodulesWithStashs -gt 0) {
    Write-Host "`n📋 SOUS-MODULES À ANALYSER (par priorité):" -ForegroundColor Cyan
    
    $withStashs = $globalResults | Where-Object { $_.StashCount -gt 0 } | Sort-Object -Property StashCount -Descending
    
    foreach($sm in $withStashs) {
        $priority = if($sm.StashCount -ge 5) { "🔴 HAUTE" } 
                    elseif($sm.StashCount -ge 3) { "🟡 MOYENNE" }
                    else { "🟢 BASSE" }
        
        Write-Host "   $priority - $($sm.Submodule): $($sm.StashCount) stash(s)" -ForegroundColor White
    }
    
    Write-Host "`n💡 RECOMMANDATION:" -ForegroundColor Yellow
    Write-Host "   Commencer par les sous-modules avec le plus de stashs (priorité haute)" -ForegroundColor White
    Write-Host "   Utiliser le script 05-analyze-submodule-stashs.ps1 pour chaque sous-module" -ForegroundColor White
} else {
    Write-Host "`n✅ EXCELLENTE NOUVELLE!" -ForegroundColor Green
    Write-Host "   Aucun stash trouvé dans les sous-modules" -ForegroundColor White
    Write-Host "   Le dépôt est dans un état propre" -ForegroundColor White
}

# ============================================================================
# EXPORT DES RÉSULTATS
# ============================================================================

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path $repoRoot "scripts/stash-recovery/results"
if(-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$jsonOutput = Join-Path $outputDir "inventory-all-submodules-$timestamp.json"
$globalResults | ConvertTo-Json -Depth 10 | Out-File $jsonOutput -Encoding UTF8

Write-Host "`n📄 Résultats exportés:" -ForegroundColor Cyan
Write-Host "   $jsonOutput" -ForegroundColor Gray

Write-Host "`n✅ Script terminé avec succès" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan