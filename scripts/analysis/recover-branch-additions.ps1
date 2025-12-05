# Script de récupération sélective des ajouts de la branche final-recovery-complete
# Date: 2025-10-08
# Objectif: Récupérer UNIQUEMENT les fichiers ajoutés (pas les suppressions)
# SÉCURITÉ: Ne touche PAS aux fichiers existants dans main

param(
    [switch]$DryRun = $false
)

Write-Host "=== RÉCUPÉRATION SÉLECTIVE - Branche final-recovery-complete ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "MODE DRY-RUN: Aucune modification ne sera effectuée" -ForegroundColor Yellow
    Write-Host ""
}

# Vérifier qu'on est sur main
$currentBranch = git branch --show-current
if ($currentBranch -ne "main") {
    Write-Host "ERREUR: Vous devez être sur la branche 'main'" -ForegroundColor Red
    Write-Host "Branche actuelle: $currentBranch" -ForegroundColor Red
    exit 1
}

# Vérifier que main est propre
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Host "ERREUR: Vous avez des modifications non commitées" -ForegroundColor Red
    Write-Host "Veuillez commit ou stash vos modifications" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Vérifications préliminaires OK" -ForegroundColor Green
Write-Host ""

# Créer branche de récupération
$recoveryBranch = "recovery-additions-final-recovery-20251008"
Write-Host "Création de la branche de récupération: $recoveryBranch" -ForegroundColor Cyan

if (-not $DryRun) {
    git checkout -b $recoveryBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERREUR: Impossible de créer la branche" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "=== PHASE 1: RAPPORTS RACINE ===" -ForegroundColor Yellow
Write-Host ""

$rootFiles = @(
    'RAPPORT_RECUPERATION_REBASE_24092025.md',
    'rapport-final-mission-sddd-jupyter-papermill-23092025.md',
    'conversation-analysis-reset-qdrant-issue.md',
    'planning_refactoring_modes.md',
    'repair-plan.md'
)

foreach ($file in $rootFiles) {
    Write-Host "Récupération: $file" -ForegroundColor Cyan
    if (-not $DryRun) {
        git checkout origin/final-recovery-complete -- $file
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Récupéré" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Échec" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== PHASE 2: RAPPORT MISSION SÉCURISATION ===" -ForegroundColor Yellow
Write-Host ""

$reportPath = "analysis-reports/mission-securisation-pull-25-09-2025.md"
Write-Host "Récupération: $reportPath" -ForegroundColor Cyan
if (-not $DryRun) {
    # Créer le dossier si nécessaire
    $reportDir = Split-Path $reportPath -Parent
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    git checkout origin/final-recovery-complete -- $reportPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Récupéré" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Échec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== PHASE 3: SCRIPTS ENCODING ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Récupération: scripts/encoding/" -ForegroundColor Cyan
if (-not $DryRun) {
    git checkout origin/final-recovery-complete -- scripts/encoding/
    if ($LASTEXITCODE -eq 0) {
        $count = (Get-ChildItem "scripts/encoding/*.ps1").Count
        Write-Host "  ✅ Récupéré ($count scripts)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Échec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== PHASE 4: ARCHIVES THÉMATIQUES ===" -ForegroundColor Yellow
Write-Host ""

$archiveDirs = @(
    'archive/architecture-ecommerce',
    'archive/optimized-agents',
    'archive/tests-escalade',
    'archive/divers',
    'archive/roo-modes-n5/backup'
)

foreach ($dir in $archiveDirs) {
    Write-Host "Récupération: $dir" -ForegroundColor Cyan
    if (-not $DryRun) {
        git checkout origin/final-recovery-complete -- $dir 2>$null
        if ($LASTEXITCODE -eq 0) {
            $count = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue).Count
            Write-Host "  ✅ Récupéré ($count fichiers)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️ Échec ou vide" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== PHASE 5: DOCS ARCHIVE ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Récupération: docs/archive/refactoring-plan-2025-08-21.md" -ForegroundColor Cyan
if (-not $DryRun) {
    git checkout origin/final-recovery-complete -- docs/archive/refactoring-plan-2025-08-21.md 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Récupéré" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Échec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== PHASE 6: RECOVERY.PATCH (référence historique) ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "Récupération: recovery.patch" -ForegroundColor Cyan
if (-not $DryRun) {
    git checkout origin/final-recovery-complete -- recovery.patch 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✅ Récupéré" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Échec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== RÉSUMÉ DES OPÉRATIONS ===" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Host "MODE DRY-RUN - Aucune modification effectuée" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pour effectuer la récupération réelle, lancez:" -ForegroundColor Cyan
    Write-Host "  .\scripts\analysis\recover-branch-additions.ps1" -ForegroundColor White
} else {
    Write-Host "Fichiers récupérés de origin/final-recovery-complete" -ForegroundColor Green
    Write-Host ""
    Write-Host "Prochaines étapes:" -ForegroundColor Yellow
    Write-Host "  1. Vérifier les fichiers récupérés: git status" -ForegroundColor White
    Write-Host "  2. Examiner le contenu: git diff --cached" -ForegroundColor White
    Write-Host "  3. Si OK, committer: git add . && git commit -m 'recover: ajouts de final-recovery-complete'" -ForegroundColor White
    Write-Host "  4. Merger dans main: git checkout main && git merge $recoveryBranch" -ForegroundColor White
    Write-Host ""
    Write-Host "AVERTISSEMENT:" -ForegroundColor Red
    Write-Host "  - Ne PAS merger la branche origin/final-recovery-complete elle-même" -ForegroundColor Red
    Write-Host "  - Uniquement les fichiers AJOUTÉS ont été récupérés" -ForegroundColor Red
    Write-Host "  - Les suppressions de la branche ont été IGNORÉES (SÉCURITÉ)" -ForegroundColor Red
}

Write-Host ""
