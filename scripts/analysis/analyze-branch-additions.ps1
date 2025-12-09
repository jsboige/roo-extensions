# Script d'analyse des ajouts de la branche final-recovery-complete
# Date: 2025-10-08
# Objectif: Identifier les fichiers ajoutés qui ont de la valeur

Write-Host "=== ANALYSE DES AJOUTS - Branche final-recovery-complete ===" -ForegroundColor Cyan
Write-Host ""

# Liste des fichiers ajoutés à vérifier (à la racine)
$rootFiles = @(
    'RAPPORT_RECUPERATION_REBASE_24092025.md',
    'recovery.patch',
    'repair-plan.md',
    'planning_refactoring_modes.md',
    'conversation-analysis-reset-qdrant-issue.md',
    'rapport-final-mission-sddd-jupyter-papermill-23092025.md'
)

Write-Host "1. FICHIERS À LA RACINE" -ForegroundColor Yellow
Write-Host "========================" -ForegroundColor Yellow
foreach ($file in $rootFiles) {
    if (Test-Path $file) {
        Write-Host "  ✅ EXISTE dans main: $file" -ForegroundColor Green
    } else {
        Write-Host "  ❌ ABSENT de main: $file" -ForegroundColor Red
        Write-Host "     → Potentiellement à récupérer" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "2. SCRIPTS ENCODING" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
if (Test-Path "scripts/encoding") {
    $encodingScripts = Get-ChildItem "scripts/encoding/*.ps1" -ErrorAction SilentlyContinue
    Write-Host "  ✅ Dossier existe: scripts/encoding/" -ForegroundColor Green
    Write-Host "  Nombre de scripts: $($encodingScripts.Count)" -ForegroundColor Cyan
} else {
    Write-Host "  ❌ Dossier absent: scripts/encoding/" -ForegroundColor Red
    Write-Host "     → Potentiellement à récupérer (15+ scripts)" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "3. ARCHIVES" -ForegroundColor Yellow
Write-Host "===========" -ForegroundColor Yellow

# Vérifier archives importantes
$archiveDirs = @(
    'archive/architecture-ecommerce',
    'archive/optimized-agents',
    'archive/tests-escalade'
)

foreach ($dir in $archiveDirs) {
    if (Test-Path $dir) {
        $fileCount = (Get-ChildItem $dir -Recurse -File).Count
        Write-Host "  ✅ EXISTE: $dir ($fileCount fichiers)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ ABSENT: $dir" -ForegroundColor Red
        Write-Host "     → Potentiellement à récupérer" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "4. PACKAGE-LOCK.JSON" -ForegroundColor Yellow
Write-Host "====================" -ForegroundColor Yellow
if (Test-Path "package-lock.json") {
    $size = (Get-Item "package-lock.json").Length
    Write-Host "  ✅ EXISTE: package-lock.json ($([math]::Round($size/1KB, 2)) KB)" -ForegroundColor Green
    Write-Host "     → Comparer versions si besoin" -ForegroundColor Cyan
} else {
    Write-Host "  ❌ ABSENT: package-lock.json" -ForegroundColor Red
}

Write-Host ""
Write-Host "5. ANALYSIS-REPORTS" -ForegroundColor Yellow
Write-Host "==================" -ForegroundColor Yellow
$reportFile = "analysis-reports/mission-securisation-pull-25-09-2025.md"
if (Test-Path $reportFile) {
    Write-Host "  ✅ EXISTE: $reportFile" -ForegroundColor Green
} else {
    Write-Host "  ❌ ABSENT: $reportFile" -ForegroundColor Red
    Write-Host "     → Valeur historique, à récupérer" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== RÉSUMÉ ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Catégories à récupérer potentiellement:" -ForegroundColor Yellow
Write-Host "  - Rapports racine (si absents)" -ForegroundColor White
Write-Host "  - Scripts encoding (si dossier absent)" -ForegroundColor White
Write-Host "  - Archives thématiques (si absentes)" -ForegroundColor White
Write-Host "  - Rapport mission-securisation (si absent)" -ForegroundColor White
Write-Host ""
Write-Host "AVERTISSEMENT: Ne récupérer que si VRAIMENT absents de main!" -ForegroundColor Red
Write-Host ""
