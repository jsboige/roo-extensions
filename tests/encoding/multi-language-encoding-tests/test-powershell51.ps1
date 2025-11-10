#!/usr/bin/env powershell.exe
# ==============================================================================
# Script: test-powershell51.ps1
# Description: Tests d'encodage pour PowerShell 5.1 (Windows Legacy)
# Auteur: Roo Debug Mode
# Date: 2025-10-29
# ==============================================================================

# Configuration UTF-8 explicite pour PowerShell 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Fonction de diagnostic
function Get-DiagnosticInfo {
    param([string]$TestName)
    
    return @{
        TestName = $TestName
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
        CodePage = &{chcp} 2>$null; Write-Output $LASTEXITCODE}
        ConsoleOutputEncoding = [Console]::OutputEncoding.ToString()
        ConsoleInputEncoding = [Console]::InputEncoding.ToString()
        OutputEncoding = $OutputEncoding.ToString()
        DefaultParameterEncoding = $PSDefaultParameterValues['*:Encoding']
        OSVersion = [System.Environment]::OSVersion.ToString()
        IsWindows = $IsWindows
        IsCore = $IsCoreCLR
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    }
}

# Fonction de test d'affichage
function Test-ConsoleDisplay {
    param([string]$TestName, [string]$Content)
    
    $diag = Get-DiagnosticInfo $TestName
    Write-Host "=== $TestName ====" -ForegroundColor Cyan
    Write-Host "PowerShell: $($diag.PowerShellVersion)" -ForegroundColor Gray
    Write-Host "Code Page: $($diag.CodePage)" -ForegroundColor Gray
    
    try {
        Write-Host "Affichage: $Content" -ForegroundColor Green
        return @{ Success = $true; Diagnostic = $diag; Result = "Affiché correctement" }
    } catch {
        return @{ Success = $false; Diagnostic = $diag; Error = $_.Exception.Message }
    }
}

# Fonction de test d'écriture de fichier
function Test-FileWrite {
    param([string]$TestName, [string]$Content, [string]$FileName)
    
    $diag = Get-DiagnosticInfo $TestName
    $filePath = "results\$FileName"
    
    try {
        # Créer le répertoire results si nécessaire
        if (-not (Test-Path "results")) {
            New-Item -ItemType Directory -Path "results" -Force | Out-Null
        }
        
        # Écrire avec différents encodages
        $Content | Out-File -FilePath $filePath -Encoding UTF8 -NoNewline
        $writtenContent = Get-Content $filePath -Encoding UTF8 -Raw
        
        if ($writtenContent -eq $Content) {
            return @{ Success = $true; Diagnostic = $diag; Result = "Écriture réussie" }
        } else {
            return @{ Success = $false; Diagnostic = $diag; Error = "Contenu différent après écriture" }
        }
    } catch {
        return @{ Success = $false; Diagnostic = $diag; Error = $_.Exception.Message }
    }
}

# Fonction de test de lecture de fichier
function Test-FileRead {
    param([string]$TestName, [string]$FileName)
    
    $diag = Get-DiagnosticInfo $TestName
    $filePath = "test-data\$FileName"
    
    try {
        if (-not (Test-Path $filePath)) {
            return @{ Success = $false; Diagnostic = $diag; Error = "Fichier non trouvé: $filePath" }
        }
        
        $content = Get-Content $filePath -Encoding UTF8 -Raw
        return @{ Success = $true; Diagnostic = $diag; Result = $content }
    } catch {
        return @{ Success = $false; Diagnostic = $diag; Error = $_.Exception.Message }
    }
}

# Fonction de test de transmission entre processus
function Test-ProcessTransmission {
    param([string]$TestName, [string]$Content)
    
    $diag = Get-DiagnosticInfo $TestName
    
    try {
        # Test avec pipe
        $pipeResult = echo $Content | powershell.exe -Command "Write-Host '$Content'" 2>&1
        
        # Test avec redirection
        $tempFile = "results\pipe-test-$TestName.txt"
        $Content | powershell.exe -Command "Out-File -FilePath '$tempFile' -Encoding UTF8" 2>$null
        
        if (Test-Path $tempFile) {
            $redirectedContent = Get-Content $tempFile -Encoding UTF8 -Raw
            Remove-Item $tempFile -Force
            
            if ($redirectedContent -eq $Content) {
                return @{ Success = $true; Diagnostic = $diag; Result = "Transmission réussie" }
            } else {
                return @{ Success = $false; Diagnostic = $diag; Error = "Contenu altéré après transmission" }
            }
        } else {
            return @{ Success = $false; Diagnostic = $diag; Error = "Échec de la redirection" }
        }
    } catch {
        return @{ Success = $false; Diagnostic = $diag; Error = $_.Exception.Message }
    }
}

# Fonction de test de variables d'environnement
function Test-EnvironmentVariables {
    param([string]$TestName, [string]$Content)
    
    $diag = Get-DiagnosticInfo $TestName
    
    try {
        # Définir une variable d'environnement avec emojis
        [System.Environment]::SetEnvironmentVariable("TEST_EMOJI_PS51", $Content)
        
        # Lire la variable
        $envValue = [System.Environment]::GetEnvironmentVariable("TEST_EMOJI_PS51")
        
        if ($envValue -eq $Content) {
            return @{ Success = $true; Diagnostic = $diag; Result = "Variable d'environnement préservée" }
        } else {
            return @{ Success = $false; Diagnostic = $diag; Error = "Variable d'environnement altérée" }
        }
    } catch {
        return @{ Success = $false; Diagnostic = $diag; Error = $_.Exception.Message }
    }
}

# Collection des résultats
$testResults = @()

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  TESTS D'ENCODAGE - POWERSHELL 5.1 (WINDOWS LEGACY)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Test 1: Caractères accentués simples
$accentedText = "é è à ù ç œ æ â ê î ô û"
$result = Test-ConsoleDisplay "PS51-Accented" $accentedText
$testResults += $result

$result = Test-FileWrite "PS51-Accented-File" $accentedText "accented-ps51.txt"
$testResults += $result

$result = Test-FileRead "PS51-Accented-Read" "sample-accented.txt"
$testResults += $result

# Test 2: Emojis simples
$simpleEmojis = "✅ ❌ ⚠️ ℹ️"
$result = Test-ConsoleDisplay "PS51-SimpleEmojis" $simpleEmojis
$testResults += $result

$result = Test-FileWrite "PS51-SimpleEmojis-File" $simpleEmojis "simple-emojis-ps51.txt"
$testResults += $result

$result = Test-FileRead "PS51-SimpleEmojis-Read" "sample-emojis.txt"
$testResults += $result

# Test 3: Emojis complexes
$complexEmojis = "🚀 💻 ⚙️ 🪲 📁 📄 📦 🔍 📊 📋 🔬 🎯 📈 💡 💾 🔄 🏗️ 📝 🔧 ✨"
$result = Test-ConsoleDisplay "PS51-ComplexEmojis" $complexEmojis
$testResults += $result

$result = Test-FileWrite "PS51-ComplexEmojis-File" $complexEmojis "complex-emojis-ps51.txt"
$testResults += $result

# Test 4: Transmission entre processus
$transmissionTest = "Test transmission: ✅ 🚀 💻"
$result = Test-ProcessTransmission "PS51-Transmission" $transmissionTest
$testResults += $result

# Test 5: Variables d'environnement
$envTest = "Variable env: ✅ 🚀 💻"
$result = Test-EnvironmentVariables "PS51-Environment" $envTest
$testResults += $result

# Test 6: Option système UTF-8 worldwide language support
Write-Host "=== Test option système UTF-8 ===" -ForegroundColor Yellow
try {
    $systemInfo = Get-CimInstance -ClassName Win32_OperatingSystem
    $unicodeSupport = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage
    
    Write-Host "Culture actuelle: $([System.Globalization.CultureInfo]::CurrentCulture.Name)" -ForegroundColor Gray
    Write-Host "Page de codes ANSI: $unicodeSupport" -ForegroundColor Gray
    Write-Host "Support Unicode: $([System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ANSICodePage -eq 65001)" -ForegroundColor Gray
    
    $testResults += @{
        Success = $unicodeSupport -eq 65001
        Diagnostic = Get-DiagnosticInfo "PS51-SystemSupport"
        Result = if ($unicodeSupport -eq 65001) { "Support UTF-8 activé" } else { "Support UTF-8 désactivé (Code: $unicodeSupport)" }
    }
} catch {
    $testResults += @{
        Success = $false
        Diagnostic = Get-DiagnosticInfo "PS51-SystemSupport"
        Error = $_.Exception.Message
    }
}

# Sauvegarder les résultats
$resultsJson = $testResults | ConvertTo-Json -Depth 10
$resultsJson | Out-File -FilePath "results\powershell51-results.json" -Encoding UTF8

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RÉSUMÉ DES TESTS POWERSHELL 5.1" -ForegroundColor Cyan
Write-Host "═════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$successCount = ($testResults | Where-Object { $_.Success }).Count
$failureCount = ($testResults | Where-Object { -not $_.Success }).Count

Write-Host "Tests exécutés: $($testResults.Count)" -ForegroundColor White
Write-Host "Réussis: $successCount" -ForegroundColor Green
Write-Host "Échecs: $failureCount" -ForegroundColor Red
Write-Host "Taux de succès: $([math]::Round(($successCount / $testResults.Count) * 100, 2))%" -ForegroundColor Yellow

Write-Host ""
Write-Host "Résultats détaillés sauvegardés dans: results\powershell51-results.json" -ForegroundColor Cyan
Write-Host "Tests PowerShell 5.1 terminés" -ForegroundColor Green