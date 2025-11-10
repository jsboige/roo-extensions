#!/usr/bin/env pwsh
# ==============================================================================
# Script: run-all-tests.ps1
# Description: Script d'exécution automatisée de tous les tests d'encodage
# Auteur: Roo Debug Mode
# Date: 2025-10-29
# ==============================================================================

# Configuration UTF-8 explicite
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# Fonction pour exécuter un test et capturer les résultats
function Invoke-TestWithCapture {
    param(
        [string]$TestName,
        [string]$Executable,
        [string[]]$Arguments,
        [string]$WorkingDirectory = "."
    )
    
    Write-Host "🔄 Exécution: $TestName" -ForegroundColor Yellow
    
    try {
        # Préparer le démarrage du processus
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $Executable
        $startInfo.Arguments = $Arguments -join " "
        $startInfo.WorkingDirectory = $WorkingDirectory
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.CreateNoWindow = $true
        $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
        
        # Démarrer le processus
        $process = [System.Diagnostics.Process]::Start($startInfo)
        
        # Lire la sortie et l'erreur
        $output = $process.StandardOutput.ReadToEnd()
        $error = $process.StandardError.ReadToEnd()
        
        # Attendre la fin du processus
        $process.WaitForExit()
        
        # Construire le résultat
        $result = @{
            TestName = $TestName
            Executable = $Executable
            ExitCode = $process.ExitCode
            Output = $output
            Error = $error
            Success = ($process.ExitCode -eq 0)
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Host "  ✅ $TestName terminé avec succès" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $TestName échoué (code: $($process.ExitCode))" -ForegroundColor Red
            if ($error) {
                Write-Host "  Erreur: $error" -ForegroundColor Red
            }
        }
        
        return $result
    } catch {
        Write-Host "  ❌ Erreur lors de l'exécution de $TestName : $($_.Exception.Message)" -ForegroundColor Red
        return @{
            TestName = $TestName
            Executable = $Executable
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
}

# Fonction pour vérifier si un exécutable est disponible
function Test-ExecutableAvailable {
    param([string]$Executable)
    
    try {
        $null = Get-Command $Executable -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Fonction principale
function Main {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  EXÉCUTION AUTOMATISÉE DES TESTS D'ENCODAGE MULTI-LANGAGES" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Créer le répertoire results si nécessaire
    if (-not (Test-Path "results")) {
        New-Item -ItemType Directory -Path "results" -Force | Out-Null
        Write-Host "📁 Répertoire results créé" -ForegroundColor Green
    }
    
    # Créer le répertoire diagnostic-logs si nécessaire
    if (-not (Test-Path "results\diagnostic-logs")) {
        New-Item -ItemType Directory -Path "results\diagnostic-logs" -Force | Out-Null
        Write-Host "📁 Répertoire diagnostic-logs créé" -ForegroundColor Green
    }
    
    $testResults = @()
    $testStartTime = Get-Date
    
    # Test 1: PowerShell 5.1 (Windows Legacy)
    Write-Host "🔍 Test 1: PowerShell 5.1 (Windows Legacy)" -ForegroundColor White
    if (Test-ExecutableAvailable "powershell.exe") {
        $result = Invoke-TestWithCapture "PowerShell-5.1" "powershell.exe" @("-ExecutionPolicy", "Bypass", "-File", "test-powershell51.ps1")
        $testResults += $result
    } else {
        Write-Host "  ⚠️ PowerShell 5.1 non disponible" -ForegroundColor Yellow
        $testResults += @{
            TestName = "PowerShell-5.1"
            Executable = "powershell.exe"
            ExitCode = -1
            Output = ""
            Error = "PowerShell 5.1 non disponible"
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
    
    # Test 2: PowerShell 7+ (Cross-platform)
    Write-Host "🔍 Test 2: PowerShell 7+ (Cross-platform)" -ForegroundColor White
    if (Test-ExecutableAvailable "pwsh") {
        $result = Invoke-TestWithCapture "PowerShell-7+" "pwsh" @("-File", "test-powershell7.ps1")
        $testResults += $result
    } else {
        Write-Host "  ⚠️ PowerShell 7+ non disponible" -ForegroundColor Yellow
        $testResults += @{
            TestName = "PowerShell-7+"
            Executable = "pwsh"
            ExitCode = -1
            Output = ""
            Error = "PowerShell 7+ non disponible"
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
    
    # Test 3: Python 3.x
    Write-Host "🔍 Test 3: Python 3.x" -ForegroundColor White
    if (Test-ExecutableAvailable "python") {
        $result = Invoke-TestWithCapture "Python-3.x" "python" @("test-python.py")
        $testResults += $result
    } elseif (Test-ExecutableAvailable "python3") {
        $result = Invoke-TestWithCapture "Python-3.x" "python3" @("test-python.py")
        $testResults += $result
    } else {
        Write-Host "  ⚠️ Python non disponible" -ForegroundColor Yellow
        $testResults += @{
            TestName = "Python-3.x"
            Executable = "python/python3"
            ExitCode = -1
            Output = ""
            Error = "Python non disponible"
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
    
    # Test 4: Node.js
    Write-Host "🔍 Test 4: Node.js" -ForegroundColor White
    if (Test-ExecutableAvailable "node") {
        $result = Invoke-TestWithCapture "Node.js" "node" @("test-node.js")
        $testResults += $result
    } else {
        Write-Host "  ⚠️ Node.js non disponible" -ForegroundColor Yellow
        $testResults += @{
            TestName = "Node.js"
            Executable = "node"
            ExitCode = -1
            Output = ""
            Error = "Node.js non disponible"
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
    
    # Test 5: TypeScript (via ts-node)
    Write-Host "🔍 Test 5: TypeScript (ts-node)" -ForegroundColor White
    if (Test-ExecutableAvailable "ts-node") {
        $result = Invoke-TestWithCapture "TypeScript" "ts-node" @("test-typescript.ts")
        $testResults += $result
    } else {
        Write-Host "  ⚠️ ts-node non disponible" -ForegroundColor Yellow
        $testResults += @{
            TestName = "TypeScript"
            Executable = "ts-node"
            ExitCode = -1
            Output = ""
            Error = "ts-node non disponible"
            Success = $false
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        }
    }
    
    # Analyser les résultats
    Write-Host ""
    Write-Host "📊 ANALYSE DES RÉSULTATS" -ForegroundColor White
    Write-Host ""
    
    $successCount = ($testResults | Where-Object { $_.Success }).Count
    $failureCount = ($testResults | Where-Object { -not $_.Success }).Count
    $totalDuration = (Get-Date) - $testStartTime
    
    # Créer le rapport détaillé
    $report = @{
        TestSummary = @{
            TotalTests = $testResults.Count
            SuccessfulTests = $successCount
            FailedTests = $failureCount
            SuccessRate = if ($testResults.Count -gt 0) { [math]::Round(($successCount / $testResults.Count) * 100, 2) } else { 0 }
            TotalDuration = $totalDuration.TotalSeconds
            TestStartTime = $testStartTime.ToString("yyyy-MM-dd HH:mm:ss")
            TestEndTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        TestResults = $testResults
        SystemInfo = @{
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            PowerShellEdition = $PSVersionTable.PSEdition
            OSVersion = [System.Environment]::OSVersion.ToString()
            IsWindows = $IsWindows
            IsCore = $IsCoreCLR
            CodePage = &{chcp} 2>$null; Write-Output $LASTEXITCODE}
        }
    }
    
    # Sauvegarder le rapport JSON
    $reportJson = $report | ConvertTo-Json -Depth 10
    $reportJson | Out-File -FilePath "results\encoding-test-report.json" -Encoding UTF8
    
    # Afficher le résumé
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RÉSUMÉ DE L'EXÉCUTION DES TESTS" -ForegroundColor Cyan
    Write-Host "═════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Tests exécutés: $($report.TestSummary.TotalTests)" -ForegroundColor White
    Write-Host "Réussis: $($report.TestSummary.SuccessfulTests)" -ForegroundColor Green
    Write-Host "Échecs: $($report.TestSummary.FailedTests)" -ForegroundColor Red
    Write-Host "Taux de succès: $($report.TestSummary.SuccessRate)%" -ForegroundColor Yellow
    Write-Host "Durée totale: $([math]::Round($totalDuration.TotalSeconds, 2)) secondes" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "Détails par test:" -ForegroundColor White
    foreach ($result in $testResults) {
        $status = if ($result.Success) { "✅ SUCCÈS" } else { "❌ ÉCHEC" }
        Write-Host "  $($result.TestName): $status (Code: $($result.ExitCode))" -ForegroundColor $(if ($result.Success) { "Green" } else { "Red" })
    }
    
    Write-Host ""
    Write-Host "Rapport détaillé sauvegardé dans: results\encoding-test-report.json" -ForegroundColor Cyan
    Write-Host "Logs individuels sauvegardés dans: results\diagnostic-logs\" -ForegroundColor Cyan
    
    # Créer les logs individuels
    foreach ($result in $testResults) {
        $logFile = "results\diagnostic-logs\$($result.TestName)-log.txt"
        $logContent = @"
Test: $($result.TestName)
Executable: $($result.Executable)
Exit Code: $($result.ExitCode)
Success: $($result.Success)
Timestamp: $($result.Timestamp)

=== OUTPUT ===
$($result.Output)

=== ERROR ===
$($result.Error)

=== SYSTEM INFO ===
PowerShell: $($report.SystemInfo.PowerShellVersion)
OS: $($report.SystemInfo.OSVersion)
Code Page: $($report.SystemInfo.CodePage)
Platform: Windows: $($report.SystemInfo.IsWindows)
Core: $($report.SystemInfo.IsCore)
"@
        
        $logContent | Out-File -FilePath $logFile -Encoding UTF8
    }
    
    Write-Host ""
    Write-Host "✅ Exécution des tests terminée" -ForegroundColor Green
}

# Vérifier si nous sommes dans le bon répertoire
if (-not (Test-Path "test-powershell51.ps1") -or 
    -not (Test-Path "test-powershell7.ps1") -or 
    -not (Test-Path "test-python.py") -or 
    -not (Test-Path "test-node.js") -or 
    -not (Test-Path "test-typescript.ts")) {
    Write-Host "❌ Erreur: Ce script doit être exécuté depuis le répertoire des tests" -ForegroundColor Red
    Write-Host "Répertoire actuel: $(Get-Location)" -ForegroundColor Red
    Write-Host "Répertoire attendu: tests/encoding/multi-language-encoding-tests/" -ForegroundColor Red
    exit 1
}

# Exécuter la fonction principale
Main