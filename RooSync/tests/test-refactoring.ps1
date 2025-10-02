# test-refactoring.ps1
# Test de validation de la refactorisation RooSync
# Vérifie que tous les modules se chargent correctement depuis leur nouvelle structure

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$testResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Message = ""
    )
    
    $testResults.Total++
    
    if ($Success) {
        $testResults.Passed++
        Write-Host "✅ PASS: $TestName" -ForegroundColor Green
        if ($Message) { Write-Host "   → $Message" -ForegroundColor Gray }
    } else {
        $testResults.Failed++
        $testResults.Errors += "$TestName : $Message"
        Write-Host "❌ FAIL: $TestName" -ForegroundColor Red
        if ($Message) { Write-Host "   → $Message" -ForegroundColor Yellow }
    }
}

Write-Host "`n🧪 Test de Validation de la Refactorisation RooSync" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Cyan

# Test 1: Vérification de la structure des répertoires
Write-Host "`n📁 Test 1: Structure des Répertoires" -ForegroundColor Yellow

$requiredDirs = @(
    "RooSync/src",
    "RooSync/src/modules",
    "RooSync/.config",
    "RooSync/docs",
    "RooSync/tests"
)

foreach ($dir in $requiredDirs) {
    $exists = Test-Path $dir -PathType Container
    Write-TestResult "Répertoire existe: $dir" $exists
}

# Test 2: Vérification de l'existence des fichiers clés
Write-Host "`n📄 Test 2: Fichiers Clés" -ForegroundColor Yellow

$requiredFiles = @(
    "RooSync/src/sync-manager.ps1",
    "RooSync/src/modules/Core.psm1",
    "RooSync/src/modules/Actions.psm1",
    "RooSync/.config/sync-config.json"
)

foreach ($file in $requiredFiles) {
    $exists = Test-Path $file -PathType Leaf
    Write-TestResult "Fichier existe: $file" $exists
}

# Test 3: Test d'importation des modules
Write-Host "`n🔌 Test 3: Importation des Modules" -ForegroundColor Yellow

try {
    # Détermine le chemin du script de base
    $scriptRoot = Split-Path -Parent $PSScriptRoot
    $srcPath = Join-Path $scriptRoot "src"
    
    # Test d'importation de Core.psm1
    $coreModulePath = Join-Path $srcPath "modules/Core.psm1"
    Import-Module $coreModulePath -Force -ErrorAction Stop
    Write-TestResult "Import de Core.psm1" $true "Module chargé avec succès"
    
    # Vérifie que les fonctions sont disponibles
    $coreFunction = Get-Command -Name "Get-LocalContext" -ErrorAction SilentlyContinue
    Write-TestResult "Fonction Get-LocalContext disponible" ($null -ne $coreFunction)
    
    $invokeSyncManager = Get-Command -Name "Invoke-SyncManager" -ErrorAction SilentlyContinue
    Write-TestResult "Fonction Invoke-SyncManager disponible" ($null -ne $invokeSyncManager)
    
    # Vérifie que Actions.psm1 a été chargé via Core.psm1
    $compareConfigFunc = Get-Command -Name "Compare-Config" -ErrorAction SilentlyContinue
    Write-TestResult "Fonction Compare-Config disponible" ($null -ne $compareConfigFunc)
    
} catch {
    Write-TestResult "Import des modules" $false $_.Exception.Message
}

# Test 4: Vérification des chemins relatifs dans le code
Write-Host "`n🔗 Test 4: Chemins Relatifs" -ForegroundColor Yellow

try {
    # Vérifie que sync-manager.ps1 utilise les bons chemins
    $syncManagerContent = Get-Content "RooSync/src/sync-manager.ps1" -Raw
    
    $correctCoreImport = $syncManagerContent -match 'Import-Module\s+"\$PSScriptRoot\\modules\\Core\.psm1"'
    Write-TestResult "sync-manager.ps1 importe Core.psm1 correctement" $correctCoreImport
    
    $correctConfigPath = $syncManagerContent -match '\$PSScriptRoot/\.\./\.config/sync-config\.json'
    Write-TestResult "sync-manager.ps1 référence .config correctement" $correctConfigPath
    
    # Vérifie que Core.psm1 importe Actions.psm1 correctement
    $coreContent = Get-Content "RooSync/src/modules/Core.psm1" -Raw
    $correctActionsImport = $coreContent -match 'Import-Module\s+"\$PSScriptRoot\\Actions\.psm1"'
    Write-TestResult "Core.psm1 importe Actions.psm1 correctement" $correctActionsImport
    
    # Vérifie que Actions.psm1 utilise les bons chemins
    $actionsContent = Get-Content "RooSync/src/modules/Actions.psm1" -Raw
    $correctLocalConfigPath = $actionsContent -match '\$PSScriptRoot/\.\./\.\./\.config/sync-config\.json'
    Write-TestResult "Actions.psm1 référence .config correctement" $correctLocalConfigPath
    
} catch {
    Write-TestResult "Vérification des chemins relatifs" $false $_.Exception.Message
}

# Test 5: Test d'exécution basique
Write-Host "`n▶️  Test 5: Exécution du Script" -ForegroundColor Yellow

try {
    # Test avec Compare-Config qui ne nécessite pas de paramètres complexes
    $output = & "$PSScriptRoot/../src/sync-manager.ps1" -Action Compare-Config 2>&1
    $success = $LASTEXITCODE -eq 0
    
    if ($success) {
        Write-TestResult "Exécution de Compare-Config" $true "Script exécuté sans erreur"
    } else {
        Write-TestResult "Exécution de Compare-Config" $false "Code de sortie: $LASTEXITCODE"
    }
    
    # Vérifie que les messages attendus sont présents
    $outputStr = $output | Out-String
    $hasActionMessage = $outputStr -match "Action demandée\s*:\s*Compare-Config"
    Write-TestResult "Message d'action présent" $hasActionMessage
    
    $hasConfigMessage = $outputStr -match "Configuration chargée"
    Write-TestResult "Message de configuration présent" $hasConfigMessage
    
} catch {
    Write-TestResult "Exécution du script" $false $_.Exception.Message
}

# Résumé des résultats
Write-Host "`n" + ("=" * 70) -ForegroundColor Cyan
Write-Host "📊 Résumé des Tests" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "Total de tests  : $($testResults.Total)" -ForegroundColor White
Write-Host "Tests réussis   : $($testResults.Passed)" -ForegroundColor Green
Write-Host "Tests échoués   : $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -eq 0) { "Green" } else { "Red" })

if ($testResults.Failed -gt 0) {
    Write-Host "`n❌ Erreurs détectées:" -ForegroundColor Red
    foreach ($error in $testResults.Errors) {
        Write-Host "   • $error" -ForegroundColor Yellow
    }
    exit 1
} else {
    Write-Host "`n✅ Tous les tests sont passés avec succès!" -ForegroundColor Green
    Write-Host "   La refactorisation est validée fonctionnellement." -ForegroundColor Gray
    exit 0
}