# ============================================================================
# Script: Examen Détaillé d'un Stash Spécifique
# Date: 2025-10-16
# Description: Affiche le contenu complet d'un stash pour décision de recovery
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [int]$StashIndex,
    
    [Parameter(Mandatory=$false)]
    [string]$SubmodulePath = "mcps/internal"
)

$ErrorActionPreference = "Continue"
$repoRoot = "d:/dev/roo-extensions"
$fullPath = Join-Path $repoRoot $SubmodulePath

if(-not (Test-Path $fullPath)) {
    Write-Host "❌ Erreur: Chemin introuvable - $fullPath" -ForegroundColor Red
    exit 1
}

Push-Location $fullPath

try {
    $stashRef = "stash@{$StashIndex}"
    
    Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          EXAMEN DÉTAILLÉ DU STASH @{$StashIndex}              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    # Obtenir le message du stash
    $stashMessage = git stash list | Select-String -Pattern "^stash@\{$StashIndex\}" | Select-Object -First 1
    Write-Host "📝 Message:" -ForegroundColor Yellow
    Write-Host "   $stashMessage" -ForegroundColor White
    Write-Host ""
    
    # Stats
    Write-Host "📊 Statistiques:" -ForegroundColor Yellow
    $stats = git stash show --stat $stashRef 2>&1
    foreach($line in ($stats -split "`n")) {
        if($line.Trim() -ne "") {
            Write-Host "   $line" -ForegroundColor White
        }
    }
    Write-Host ""
    
    # Diff complet
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "📄 CONTENU COMPLET DU DIFF:" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host ""
    
    $diff = git stash show -p $stashRef 2>&1
    
    # Coloriser le diff
    foreach($line in ($diff -split "`n")) {
        if($line -match '^diff --git') {
            Write-Host $line -ForegroundColor Cyan
        }
        elseif($line -match '^index |^---|\+\+\+') {
            Write-Host $line -ForegroundColor Gray
        }
        elseif($line -match '^@@') {
            Write-Host $line -ForegroundColor Magenta
        }
        elseif($line -match '^\+') {
            Write-Host $line -ForegroundColor Green
        }
        elseif($line -match '^-') {
            Write-Host $line -ForegroundColor Red
        }
        else {
            Write-Host $line -ForegroundColor White
        }
    }
    
    Write-Host "`n═══════════════════════════════════════════════════════════" -ForegroundColor DarkGray
    Write-Host "✅ Examen terminé" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════`n" -ForegroundColor Cyan
    
} catch {
    Write-Host "`n❌ Erreur: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}