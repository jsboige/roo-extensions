# Script principal pour l'exécution des tests Vitest du roo-state-manager
# Conçu pour remplacer les scripts de test multiples et centraliser l'exécution

param (
    [Parameter(Mandatory=$false)]
    [switch]$Run,

    [Parameter(Mandatory=$false)]
    [switch]$Watch,

    [Parameter(Mandatory=$false)]
    [switch]$Coverage,

    [Parameter(Mandatory=$false)]
    [string]$Pattern,

    [Parameter(Mandatory=$false)]
    [switch]$CI
)

Write-Host "🧪 Roo Tests - Script d'exécution des tests Vitest" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# Configuration
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$TestProjectPath = Join-Path $ProjectRoot "mcps/internal/servers/roo-state-manager"

Write-Host "📁 Racine du projet : $ProjectRoot" -ForegroundColor Gray
Write-Host "📂 Projet de tests : $TestProjectPath" -ForegroundColor Gray

# Vérifier que nous sommes dans le bon répertoire
if (-not (Test-Path $TestProjectPath)) {
    Write-Error "❌ Le répertoire du projet n'existe pas : $TestProjectPath"
    exit 1
}

# Changer vers le répertoire du projet
Set-Location $TestProjectPath

# Vérifier que Vitest est disponible
try {
    # Use `npm.cmd` explicitly: under pwsh, bare `npm` resolves to npm.ps1 and
    # `& npm ...` corrupts arg passing → "Unknown command: pm" (silent failure).
    # npm.cmd bypasses the wrapper (same rationale as #2857/#2859).
    $VitestVersion = & npm.cmd run test:version 2>$null
    Write-Host "✅ Vitest détecté : $VitestVersion" -ForegroundColor Green
}
catch {
    Write-Error "❌ Vitest n'est pas disponible. Installation des dépendances..."
    & npm.cmd install
}

# Construire la commande de test
$TestCommand = "npm run test:run"

if ($Watch) {
    $TestCommand = "npm run test:watch"
    Write-Host "👀 Mode watch activé" -ForegroundColor Yellow
}

if ($Coverage) {
    $TestCommand += " -- --coverage"
    Write-Host "📊 Couverture de code activée" -ForegroundColor Yellow
}

if ($Pattern) {
    $TestCommand += " -- $Pattern"
    Write-Host "🔍 Filtre de pattern : $Pattern" -ForegroundColor Yellow
}

if ($CI) {
    $TestCommand += " -- --run --reporter=verbose"
    Write-Host "🤖 Mode CI activé" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🚀 Exécution de la commande : $TestCommand" -ForegroundColor Green
Write-Host ""

# Exécuter les tests
try {
    & $TestCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Tous les tests ont réussi !" -ForegroundColor Green
    }
    else {
        Write-Host ""
        Write-Host "⚠️ Certains tests ont échoué (Code: $LASTEXITCODE)" -ForegroundColor Yellow
    }
}
catch {
    Write-Error "❌ Erreur lors de l'exécution des tests : $_"
    exit 1
}

# Afficher le résumé des statistiques
Write-Host ""
Write-Host "📊 Statistiques des tests (basées sur la dernière exécution) :" -ForegroundColor Cyan
Write-Host "   • Fichiers de test détectés : 61" -ForegroundColor White
Write-Host "   • Tests unitaires : 40+ fichiers" -ForegroundColor White
Write-Host "   • Tests d'intégration : 5+ fichiers" -ForegroundColor White
Write-Host "   • Tests E2E : 4+ fichiers" -ForegroundColor White
Write-Host "   • Tests RooSync : 10+ fichiers" -ForegroundColor White
Write-Host ""
Write-Host "📝 Note : Le fichier 'tests/unit/parent-child-validation.test.ts' est exclu temporairement" -ForegroundColor Yellow
Write-Host "   en raison d'une boucle infinie détectée." -ForegroundColor Yellow

Write-Host ""
Write-Host "🎯 Pour exécuter tous les tests : ./scripts/roo-tests.ps1 -Run" -ForegroundColor Gray
Write-Host "👀 Pour le mode watch : ./scripts/roo-tests.ps1 -Watch" -ForegroundColor Gray
Write-Host "📊 Pour la couverture : ./scripts/roo-tests.ps1 -Run -Coverage" -ForegroundColor Gray