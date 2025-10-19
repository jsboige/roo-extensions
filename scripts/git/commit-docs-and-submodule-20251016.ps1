#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Commit documentation SDDD et mise à jour référence sous-module
.DESCRIPTION
    Phase de commit sécurisée pour :
    - Rapports documentation Triple Grounding
    - Mise à jour référence mcps/internal (nouveau SHA: 7c0d751)
    Mission : Validation Fonctionnelle MCP et Push Final Sécurisé
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RootDir = "d:/Dev/roo-extensions"
Push-Location $RootDir

try {
    Write-Host "📝 COMMIT DOCUMENTATION + SOUS-MODULE" -ForegroundColor Cyan
    Write-Host ""

    # 1. Vérifier divergence avec origin
    Write-Host "🔍 VÉRIFICATION DIVERGENCE..." -ForegroundColor Cyan
    $branchInfo = git status --porcelain=v1 --branch | Select-Object -First 1
    Write-Host "  $branchInfo" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "🔍 Commits locaux non pushés:" -ForegroundColor Cyan
    git log origin/main..HEAD --oneline
    
    Write-Host ""
    Write-Host "🔍 Commits distants non pullés:" -ForegroundColor Cyan
    git log HEAD..origin/main --oneline

    # 2. Vérifier état sous-module
    Write-Host ""
    Write-Host "📦 ÉTAT SOUS-MODULE mcps/internal:" -ForegroundColor Cyan
    Push-Location mcps/internal
    $submoduleHead = git rev-parse HEAD
    $submoduleStatus = git status --short
    Pop-Location
    Write-Host "  SHA actuel: $submoduleHead" -ForegroundColor Gray
    if ($submoduleStatus) {
        Write-Host "  ⚠️ Modifications non commitées:" -ForegroundColor Yellow
        Write-Host $submoduleStatus -ForegroundColor Gray
    }

    # 3. Stage rapports documentation
    Write-Host ""
    Write-Host "➕ STAGING RAPPORTS DOCUMENTATION..." -ForegroundColor Cyan
    
    $docsToAdd = @(
        "docs/RAPPORT-MISSION-MERGE-MAIN-TRIPLE-GROUNDING-20251016.md",
        "docs/RAPPORT-MISSION-MERGE-SUBMODULE-TRIPLE-GROUNDING-20251016.md",
        "docs/RAPPORT-MISSION-STASH-ANALYSIS-TRIPLE-GROUNDING-20251016.md",
        "docs/git-merge-commits-analysis-20251016.md",
        "docs/git-merge-main-report-20251016.json",
        "docs/git-merge-submodule-report-20251016.json",
        "docs/git-operations-report-20251016-state-analysis.md",
        "docs/git-stash-analysis-20251016.json"
    )

    foreach ($doc in $docsToAdd) {
        if (Test-Path $doc) {
            git add $doc
            Write-Host "  + $doc" -ForegroundColor Gray
        } else {
            Write-Host "  ⚠️ Non trouvé: $doc" -ForegroundColor Yellow
        }
    }

    # 4. Stage mise à jour référence sous-module
    Write-Host ""
    Write-Host "➕ STAGING MISE À JOUR SOUS-MODULE..." -ForegroundColor Cyan
    git add mcps/internal
    Write-Host "  + mcps/internal (nouveau SHA: $submoduleHead)" -ForegroundColor Gray

    # 5. Vérifier fichiers stagés
    Write-Host ""
    Write-Host "📊 FICHIERS STAGÉS:" -ForegroundColor Cyan
    git diff --cached --name-status

    # 6. Commit
    Write-Host ""
    Write-Host "💾 COMMIT..." -ForegroundColor Cyan
    $commitMsg = @"
docs(git): Triple Grounding SDDD reports + update submodule

Documentation:
- Rapport mission merge main (SDDD protocol)
- Rapport mission merge submodule (conflict resolution)
- Rapport mission stash analysis (recovery strategy)
- Git operations state analysis
- JSON reports for merge operations

Submodule Update:
- mcps/internal: Update to 7c0d751
  * fix(build): Correct tsconfig.json rootDir
  * Server now starts successfully (build/index.js path fixed)
  * Added test-startup-20251016.ps1 for validation

Part of: Mission Validation Fonctionnelle MCP et Push Final Sécurisé
"@

    git commit -m $commitMsg
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Commit échoué" -ForegroundColor Red
        exit 1
    }

    # 7. Vérifier état après commit
    Write-Host ""
    Write-Host "📊 ÉTAT APRÈS COMMIT:" -ForegroundColor Cyan
    git log --oneline -1
    Write-Host ""
    git status --short

    # 8. Vérifier divergence mise à jour
    Write-Host ""
    Write-Host "📈 DIVERGENCE MISE À JOUR:" -ForegroundColor Cyan
    $branchStatus = git status --porcelain=v1 --branch
    if ($branchStatus -match "ahead (\d+)") {
        Write-Host "  Local ahead: $($Matches[1]) commits (prêt pour push)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "✅ COMMIT RÉUSSI" -ForegroundColor Green
    Write-Host "SHA: $(git rev-parse HEAD)" -ForegroundColor Gray

} catch {
    Write-Host ""
    Write-Host "❌ ERREUR: $_" -ForegroundColor Red
    exit 1
} finally {
    Pop-Location
}