#!/usr/bin/env pwsh
# ==============================================================================
# Script: diagnostic-encoding-analysis.ps1
# Description: Diagnostic technique de l'encodage des fichiers avec emojis
# Auteur: Roo Debug Mode
# Date: 2025-10-28
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  DIAGNOSTIC TECHNIQUE - ENCODAGE EMOJIS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🔍 Analyse de l'encodage actuel du système:" -ForegroundColor Yellow
Write-Host ""

# Informations système
$systemInfo = @{
    PowerShellVersion = $PSVersionTable.PSVersion
    OS = [System.Environment]::OSVersion
    Culture = [System.Globalization.CultureInfo]::CurrentCulture
    ConsoleEncoding = [Console]::OutputEncoding
    InputEncoding = [Console]::InputEncoding
    CodePage = (chcp).Trim()
}

Write-Host "  • PowerShell: $($systemInfo.PowerShellVersion)" -ForegroundColor Gray
Write-Host "  • OS: $($systemInfo.OS)" -ForegroundColor Gray
Write-Host "  • Culture: $($systemInfo.Culture.Name)" -ForegroundColor Gray
Write-Host "  • Console Encoding: $($systemInfo.ConsoleEncoding.EncodingName)" -ForegroundColor Gray
Write-Host "  • Input Encoding: $($systemInfo.InputEncoding.EncodingName)" -ForegroundColor Gray
Write-Host "  • Code Page: $($systemInfo.CodePage)" -ForegroundColor Gray
Write-Host ""

Write-Host "🔍 Test des encodages disponibles:" -ForegroundColor Yellow
Write-Host ""

# Test différents encodages
$encodings = @(
    @{ Name = "UTF-8"; Encoding = [System.Text.Encoding]::UTF8 },
    @{ Name = "UTF-8 sans BOM"; Encoding = New-Object System.Text.UTF8Encoding $false },
    @{ Name = "UTF-16"; Encoding = [System.Text.Encoding]::Unicode },
    @{ Name = "ASCII"; Encoding = [System.Text.Encoding]::ASCII },
    @{ Name = "Windows-1252"; Encoding = [System.Text.Encoding]::GetEncoding(1252) }
)

$testString = "Test avec emojis: 🏆✅❌⚠️ℹ️🚀💻⚙️🪲"

Write-Host "  Chaîne de test: $testString" -ForegroundColor White
Write-Host ""

foreach ($enc in $encodings) {
    Write-Host "  🧪 Test $($enc.Name):" -ForegroundColor Cyan
    
    try {
        # Test 1: Conversion en bytes
        $bytes = $enc.GetBytes($testString)
        Write-Host "    • Bytes: $($bytes.Length) octets" -ForegroundColor Gray
        
        # Test 2: Reconversion depuis bytes
        $reconstructed = $enc.GetString($bytes)
        Write-Host "    • Reconverti: $reconstructed" -ForegroundColor Gray
        
        # Test 3: Écriture dans fichier temporaire
        $tempFile = [System.IO.Path]::GetTempFileName()
        $enc.GetBytes($testString) | Set-Content -Path $tempFile -Encoding Byte
        $readBack = Get-Content $tempFile -Encoding Byte
        Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        
        Write-Host "    • Fichier temporaire: $readBack" -ForegroundColor Gray
        
        # Validation
        if ($testString -eq $readBack) {
            Write-Host "    ✅ Succès complet" -ForegroundColor Green
        } else {
            Write-Host "    ❌ Échec de reconstruction" -ForegroundColor Red
            Write-Host "    • Attendu: $testString" -ForegroundColor Red
            Write-Host "    • Obtenu: $readBack" -ForegroundColor Red
        }
    } catch {
        Write-Host "    ❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "🔍 Analyse des fichiers problématiques:" -ForegroundColor Yellow
Write-Host ""

# Analyser les scripts identifiés comme problématiques
$problematicFiles = @(
    "scripts/analyze-stashs.ps1",
    "scripts/backup-all-stashs.ps1",
    "scripts/git/compare-sync-stashs.ps1",
    "scripts/git/02-phase2-verify-checksums-20251022.ps1",
    "scripts/git/03-phase2-examine-stash-content-20251022.ps1",
    "scripts/git/04-phase2-compare-sync-checksums-20251022.ps1",
    "scripts/git/05-phase2-final-analysis-20251022.ps1",
    "scripts/git/06-phase2-verify-migration-20251022.ps1",
    "scripts/git/07-phase2-classify-corrections-20251022.ps1",
    "scripts/git/08-phase2-extract-corrections-20251022.ps1"
)

foreach ($file in $problematicFiles) {
    if (Test-Path $file) {
        Write-Host "  📄 Analyse: $file" -ForegroundColor Cyan
        
        # Lire le fichier en mode binaire pour détecter l'encodage réel
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $content = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        # Détecter le BOM
        $hasBom = $false
        if ($bytes.Length -ge 3) {
            $hasBom = ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }
        
        # Analyser les caractères problématiques
        $emojiPattern = '[\u{1F600}-\u{1F64F}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F300}-\u{1F5FF}]|[\u{1F900}-\u{1F9FF}]|[\u{1F600}-\u{1F64F}]'
        $emojis = [System.Text.RegularExpressions.Regex]::Matches($content, $emojiPattern)
        
        Write-Host "    • Taille: $($bytes.Length) octets" -ForegroundColor Gray
        Write-Host "    • BOM UTF-8: $hasBom" -ForegroundColor Gray
        Write-Host "    • Emojis détectés: $($emojis.Count)" -ForegroundColor Yellow
        Write-Host "    • Encodage probable: UTF-8" -ForegroundColor Gray
        
        # Test de lecture avec différents encodages
        $encodingTests = @()
        
        foreach ($enc in $encodings) {
            try {
                $testContent = [System.Text.Encoding]::UTF8.GetString($bytes)
                if ($hasBom -and $enc.Name -eq "UTF-8") {
                    # Retirer le BOM pour le test
                    $testContent = $enc.GetString($bytes, 3, $bytes.Length - 3)
                }
                
                $reconstructed = $enc.GetString($enc.GetBytes($testContent))
                $success = $testContent -eq $reconstructed
                
                $encodingTests += [PSCustomObject]@{
                    Encoding = $enc.Name
                    Success = $success
                    Error = if ($success) { $null } else { "Reconstruction échouée" }
                }
            } catch {
                $encodingTests += [PSCustomObject]@{
                    Encoding = $enc.Name
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        }
        
        # Afficher les résultats des tests d'encodage
        Write-Host "    🧪 Tests d'encodage:" -ForegroundColor Cyan
        foreach ($test in $encodingTests) {
            $status = if ($test.Success) { "✅" } else { "❌" }
            $errorInfo = if ($test.Error) { " ($($test.Error))" } else { "" }
            Write-Host "      $($status) $($test.Encoding): $errorInfo" -ForegroundColor $(if ($test.Success) { "Green" } else { "Red" })
        }
    } else {
        Write-Host "  ❌ Fichier non trouvé: $file" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "🔍 Test de l'encodage du script actuel:" -ForegroundColor Yellow
Write-Host ""

# Tester l'encodage de ce script lui-même
try {
    $currentScriptBytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
    $currentScriptContent = [System.Text.Encoding]::UTF8.GetString($currentScriptBytes)
    
    Write-Host "  📄 Fichier: $PSCommandPath" -ForegroundColor Cyan
    Write-Host "  • Taille: $($currentScriptBytes.Length) octets" -ForegroundColor Gray
    Write-Host "  • BOM: $(if ($currentScriptBytes.Length -ge 3 -and $currentScriptBytes[0] -eq 0xEF -and $currentScriptBytes[1] -eq 0xBB -and $currentScriptBytes[2] -eq 0xBF) { "Oui" } else { "Non" })" -ForegroundColor Gray
    
    # Compter les emojis dans ce script
    $currentEmojis = [System.Text.RegularExpressions.Regex]::Matches($currentScriptContent, $emojiPattern)
    Write-Host "  • Emojis dans ce script: $($currentEmojis.Count)" -ForegroundColor Yellow
    
} catch {
    Write-Host "  ❌ Erreur analyse script actuel: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RECOMMANDATIONS TECHNIQUES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Solutions identifiées:" -ForegroundColor White
Write-Host ""

Write-Host "1. 🎯 CAUSE RACINE:" -ForegroundColor Yellow
Write-Host "   • PowerShell utilise Windows-1252 par défaut sur Windows 11" -ForegroundColor Gray
Write-Host "   • Les emojis nécessitent UTF-8 complet" -ForegroundColor Gray
Write-Host "   • Incohérence entre l'encodage du fichier et celui de l'interpréteur" -ForegroundColor Gray
Write-Host ""

Write-Host "2. 🔧 SOLUTIONS TECHNIQUES:" -ForegroundColor Yellow
Write-Host "   • Forcer UTF-8 en début de script: [Console]::OutputEncoding = [System.Text.Encoding]::UTF8" -ForegroundColor Gray
Write-Host "   • Utiliser UTF-8 sans BOM pour les fichiers: New-Object System.Text.UTF8Encoding `$false" -ForegroundColor Gray
Write-Host "   • Remplacer les emojis par des alternatives textuelles" -ForegroundColor Gray
Write-Host "   • Configurer \$PSDefaultParameterValues pour l'encodage par défaut" -ForegroundColor Gray
Write-Host ""

Write-Host "3. 📝 GUIDELINES:" -ForegroundColor Yellow
Write-Host "   • Toujours configurer l'encodage UTF-8 explicite" -ForegroundColor Gray
Write-Host "   • Tester les scripts sur différents environnements" -ForegroundColor Gray
Write-Host "   • Éviter les emojis dans les scripts PowerShell critiques" -ForegroundColor Gray
Write-Host "   • Utiliser des séquences d'échappement si nécessaire" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Diagnostic technique terminé!" -ForegroundColor Green
Write-Host ""