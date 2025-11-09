#!/usr/bin/env pwsh
# ==============================================================================
# Script: test-emoji-encoding-reproduction.ps1
# Description: Test de reproduction des problèmes d'encodage d'emojis sur Windows 11
# Auteur: Roo Debug Mode
# Date: 2025-10-28
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TEST DE REPRODUCTION - ENCODAGE EMOJIS WINDOWS 11" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 Test 1: Emojis dans les chaînes de caractères" -ForegroundColor Yellow
Write-Host ""

# Test avec différents types d'emojis
$emojiTests = @(
    @{ Name = "Trophy"; Emoji = "🏆"; Description = "Emoji trophée simple" },
    @{ Name = "Check"; Emoji = "✅"; Description = "Check mark vert" },
    @{ Name = "Cross"; Emoji = "❌"; Description = "Croix rouge" },
    @{ Name = "Warning"; Emoji = "⚠️"; Description = "Triangle d'avertissement" },
    @{ Name = "Info"; Emoji = "ℹ️"; Description = "Cercle d'information" },
    @{ Name = "Rocket"; Emoji = "🚀"; Description = "Fusée" },
    @{ Name = "Computer"; Emoji = "💻"; Description = "Ordinateur portable" },
    @{ Name = "Gear"; Emoji = "⚙️"; Description = "Engrenage" },
    @{ Name = "Bug"; Emoji = "🪲"; Description = "Insecte debug" }
)

Write-Host "Tests des emojis individuels:" -ForegroundColor White
foreach ($test in $emojiTests) {
    Write-Host "  • $($test.Name): $($test.Emoji) - $($test.Description)" -ForegroundColor Gray
    
    # Test 1: Affichage direct
    try {
        Write-Host "    Affichage: $($test.Emoji)" -ForegroundColor Green
    } catch {
        Write-Host "    ❌ Erreur affichage: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 2: Stockage dans variable
    try {
        $var = "Test avec $($test.Emoji)"
        Write-Host "    Variable: $var" -ForegroundColor Green
    } catch {
        Write-Host "    ❌ Erreur variable: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 3: Écriture dans fichier
    try {
        $testFile = "test-emoji-$($test.Name).txt"
        $test.Emoji | Out-File -FilePath $testFile -Encoding UTF8
        $content = Get-Content $testFile -Encoding UTF8
        Write-Host "    Fichier: $content" -ForegroundColor Green
    } catch {
        Write-Host "    ❌ Erreur fichier: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "🔍 Test 2: Emojis dans les messages Write-Host" -ForegroundColor Yellow
Write-Host ""

# Test avec Write-Host et couleurs
$hostTests = @(
    @{ Message = "Succès: ✅ Opération terminée"; Color = "Green" },
    @{ Message = "Erreur: ❌ Échec de l'opération"; Color = "Red" },
    @{ Message = "Attention: ⚠️ Vérification requise"; Color = "Yellow" },
    @{ Message = "Info: ℹ️ Traitement en cours"; Color = "Cyan" },
    @{ Message = "Debug: 🪲 Analyse en cours"; Color = "Magenta" }
)

foreach ($test in $hostTests) {
    try {
        Write-Host $test.Message -ForegroundColor $test.Color
    } catch {
        Write-Host "❌ Erreur Write-Host: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🔍 Test 3: Emojis dans les noms de fichiers et chemins" -ForegroundColor Yellow
Write-Host ""

# Test avec noms de fichiers contenant des emojis
try {
    $emojiDir = "test-emojis-🏆✅❌"
    New-Item -ItemType Directory -Path $emojiDir -Force | Out-Null
    Write-Host "  ✅ Répertoire créé: $emojiDir" -ForegroundColor Green
    
    $emojiFile = Join-Path $emojiDir "fichier-🪲.ps1"
    "# Test avec emoji dans nom de fichier" | Out-File -FilePath $emojiFile -Encoding UTF8
    Write-Host "  ✅ Fichier créé: $emojiFile" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Erreur création fichiers: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔍 Test 4: Encodage JSON avec emojis" -ForegroundColor Yellow
Write-Host ""

# Test avec JSON contenant des emojis
$jsonTests = @(
    @{ Name = "Simple"; Content = @{ "status": "✅", "message": "Opération réussie avec 🏆" } },
    @{ Name = "Complexe"; Content = @{ "result": "🪲 Debug", "data": @{ "items": @("🚀", "💻", "⚙️"), "status": "⚠️" } },
    @{ Name = "Unicode"; Content = @{ "unicode": "🏆✅❌⚠️ℹ️🚀💻⚙️🪲", "description": "Test Unicode complet" } }
)

foreach ($test in $jsonTests) {
    try {
        $jsonFile = "test-json-$($test.Name).json"
        $test.Content | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
        
        # Lecture et validation
        $readBack = Get-Content $jsonFile -Encoding UTF8 | ConvertFrom-Json
        Write-Host "  ✅ JSON $($test.Name): $($readBack.status)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ JSON $($test.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🔍 Test 5: Détection de l'encodage actuel" -ForegroundColor Yellow
Write-Host ""

Write-Host "Informations sur l'encodage actuel:" -ForegroundColor White
Write-Host "  • Console Output Encoding: $([Console]::OutputEncoding)" -ForegroundColor Gray
Write-Host "  • Console Input Encoding: $([Console]::InputEncoding)" -ForegroundColor Gray
Write-Host "  • \$OutputEncoding: $OutputEncoding" -ForegroundColor Gray
Write-Host "  • Code page actuel: $(chcp)" -ForegroundColor Gray
Write-Host "  • PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray

Write-Host ""
Write-Host "🔍 Test 6: Scripts problématiques identifiés" -ForegroundColor Yellow
Write-Host ""

# Test des scripts identifiés comme problématiques
$problematicScripts = @(
    "scripts/analyze-stashs.ps1",
    "scripts/backup-all-stashs.ps1", 
    "scripts/git/compare-sync-stashs.ps1",
    "scripts/git/02-phase2-verify-checksums-20251022.ps1"
    "scripts/git/03-phase2-examine-stash-content-20251022.ps1",
    "scripts/git/04-phase2-compare-sync-checksums-20251022.ps1",
    "scripts/git/05-phase2-final-analysis-20251022.ps1",
    "scripts/git/06-phase2-verify-migration-20251022.ps1"
    "scripts/git/07-phase2-classify-corrections-20251022.ps1",
    "scripts/git/08-phase2-extract-corrections-20251022.ps1"
)

foreach ($script in $problematicScripts) {
    if (Test-Path $script) {
        Write-Host "  📄 Analyse: $script" -ForegroundColor Cyan
        
        # Compter les emojis dans le fichier
        $content = Get-Content $script -Encoding UTF8
        $emojiCount = 0
        $lines = $content -split "`n"
        
        foreach ($line in $lines) {
            # Compter les emojis Unicode (plages communes)
            $emojiCount += ($line | Select-String '[\u{1F600}-\u{1F64F}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F300}-\u{1F5FF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F600}-\u{1F64F}]' -AllMatches).Count
        }
        
        Write-Host "    • Emojis détectés: $emojiCount" -ForegroundColor Yellow
        Write-Host "    • Lignes totales: $lines.Count" -ForegroundColor Gray
        Write-Host "    • Ratio: $([math]::Round(($emojiCount / $lines.Count) * 100, 2))%" -ForegroundColor Magenta
    } else {
        Write-Host "  ❌ Script non trouvé: $script" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ DES TESTS" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "✅ Tests de reproduction terminés!" -ForegroundColor Green
Write-Host "💡 Vérifiez la console pour les erreurs d'encodage" -ForegroundColor Cyan
Write-Host ""