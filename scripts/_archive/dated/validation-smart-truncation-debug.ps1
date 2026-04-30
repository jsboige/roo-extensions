#!/usr/bin/env powershell
# DIAGNOSTIC SMART TRUNCATION - Phase 2 Validation SDDD
# Validation des hypothèses sur les tests 300K et configuration Jest

Write-Host "=== DIAGNOSTIC SMART TRUNCATION ENGINE ===" -ForegroundColor Yellow
Write-Host ""

$baseDir = "mcps\internal\servers\roo-state-manager"
$srcTests = "$baseDir\src\tools\smart-truncation\__tests__"
$jestTests = "$baseDir\tests"

# HYPOTHÈSE 1 - Tests 300K manquants
Write-Host "🔍 HYPOTHÈSE 1 - Tests 300K manquants" -ForegroundColor Cyan
Write-Host "Recherche de références à '300' dans les tests Smart Truncation..."

if (Test-Path $srcTests) {
    $test300K = Get-ChildItem -Path $srcTests -Filter "*.test.ts" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match "300") {
            Write-Host "  ✅ Trouvé références '300' dans $($_.Name)" -ForegroundColor Green
            $content | Select-String "300" | ForEach-Object { Write-Host "    -> $($_.Line)" }
        } else {
            Write-Host "  ❌ AUCUNE référence '300' dans $($_.Name)" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ❌ RÉPERTOIRE TESTS MANQUANT: $srcTests" -ForegroundColor Red
}

Write-Host ""

# HYPOTHÈSE 2 - Configuration Jest cassée
Write-Host "🔍 HYPOTHÈSE 2 - Configuration Jest cassée" -ForegroundColor Cyan
Write-Host "Vérification configuration Jest et détection tests..."

$jestConfig = "$baseDir\jest.config.js"
if (Test-Path $jestConfig) {
    Write-Host "  ✅ Fichier jest.config.js trouvé" -ForegroundColor Green
    
    $config = Get-Content $jestConfig -Raw
    if ($config -match "testMatch.*tests") {
        Write-Host "  ⚠️  Jest configuré pour chercher dans 'tests/' uniquement" -ForegroundColor Yellow
        Write-Host "  ❌ Smart Truncation tests dans 'src/' - NON DÉTECTÉS" -ForegroundColor Red
    }
    
    if ($config -match "src.*tools") {
        Write-Host "  ❓ Configuration 'src/tools' détectée mais pattern incorrect" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ FICHIER JEST CONFIG MANQUANT" -ForegroundColor Red
}

Write-Host ""

# VALIDATION CAPACITÉ 300K - Configuration par défaut
Write-Host "🎯 VALIDATION CAPACITÉ 300K - Configuration par défaut" -ForegroundColor Cyan
$configFile = "$baseDir\src\tools\smart-truncation\index.ts"
if (Test-Path $configFile) {
    $configContent = Get-Content $configFile -Raw
    if ($configContent -match "maxOutputLength.*300") {
        Write-Host "  ✅ Configuration 300K trouvée dans index.ts" -ForegroundColor Green
    } elseif ($configContent -match "300000") {
        Write-Host "  ✅ Configuration 300000 trouvée dans index.ts" -ForegroundColor Green
    } else {
        Write-Host "  ❌ AUCUNE configuration 300K dans index.ts" -ForegroundColor Red
        Write-Host "  🔍 Recherche configurations maxOutputLength..." -ForegroundColor Yellow
        $configContent | Select-String "maxOutputLength" | ForEach-Object { 
            Write-Host "    -> $($_.Line)" 
        }
    }
} else {
    Write-Host "  ❌ FICHIER CONFIG SMART TRUNCATION MANQUANT" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== RÉSUMÉ DIAGNOSTIC ===" -ForegroundColor Yellow
Write-Host "1. Tests 300K: Vérification complète ci-dessus" -ForegroundColor White
Write-Host "2. Jest Config: Analyse pattern de détection" -ForegroundColor White
Write-Host "3. Capacité 300K: Validation configuration par défaut" -ForegroundColor White
Write-Host ""
Write-Host "📋 PROCHAINES ÉTAPES RECOMMANDÉES:" -ForegroundColor Cyan
Write-Host "   - Confirmer diagnostic avec utilisateur" -ForegroundColor White
Write-Host "   - Créer tests 300K manquants si nécessaire" -ForegroundColor White
Write-Host "   - Corriger configuration Jest pour détecter tests src/" -ForegroundColor White
Write-Host "   - Re-exécuter validation complète" -ForegroundColor White
