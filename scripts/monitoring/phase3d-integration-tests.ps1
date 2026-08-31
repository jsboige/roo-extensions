#Requires -Version 5.1
<#
.SYNOPSIS
    Script d'intégration finaux pour la Phase 3D SDDD

.DESCRIPTION
    Ce script exécute les tests d'intégration finaux end-to-end pour valider
    la complétion de la Phase 3D et préparer la transition vers la Phase 4.

.PARAMETER Comprehensive
    Exécute tous les tests de manière complète

.PARAMETER Quick
    Exécute uniquement les tests critiques

.PARAMETER Report
    Génère un rapport détaillé des résultats

.EXAMPLE
    .\phase3d-integration-tests.ps1 -Comprehensive -Report
    Exécute tous les tests et génère un rapport complet

.NOTES
    Auteur: Roo Extensions Team
    Version: 1.0.0 - Phase 3D
    Date: 2025-12-04
#>

param (
    [switch]$Comprehensive,
    [switch]$Quick,
    [switch]$Report,
    [string]$OutputPath = "reports"
)

# Configuration globale
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Variables globales
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ReportPath = "$OutputPath\phase3d-integration-$Timestamp"
$TestResults = @{}
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Création des répertoires
if (-not (Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
}

Write-Host "🚀 DÉMARRAGE DES TESTS D'INTÉGRATION PHASE 3D" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "Timestamp: $Timestamp" -ForegroundColor Gray
Write-Host "Mode: $(if ($Comprehensive) { 'Complet' } elseif ($Quick) { 'Rapide' } else { 'Standard' })" -ForegroundColor Gray
Write-Host ""

# Fonction pour logger les résultats
function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = "",
        [object]$Details = $null
    )
    
    $script:TotalTests++
    if ($Passed) {
        $script:PassedTests++
        Write-Host "✅ $TestName" -ForegroundColor Green
    } else {
        $script:FailedTests++
        Write-Host "❌ $TestName" -ForegroundColor Red
        if ($Message) {
            Write-Host "   $Message" -ForegroundColor Yellow
        }
    }
    
    $script:TestResults[$TestName] = @{
        Passed = $Passed
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
}

# Fonction pour tester les composants système
function Test-SystemComponents {
    Write-Host "🔍 TEST DES COMPOSANTS SYSTÈME" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Yellow
    
    # Test 1: Vérification des scripts de monitoring
    Write-Host "Test des scripts de monitoring..." -ForegroundColor Gray
    $monitoringScripts = @(
        "advanced-monitoring.ps1",
        "performance-optimizer.ps1", 
        "error-handler.ps1",
        "alert-system.ps1",
        "dashboard-generator.ps1"
    )
    
    $allScriptsExist = $true
    foreach ($script in $monitoringScripts) {
        $scriptPath = "scripts\monitoring\$script"
        if (Test-Path $scriptPath) {
            Write-Host "  ✓ $script trouvé" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $script manquant" -ForegroundColor Red
            $allScriptsExist = $false
        }
    }
    
    Write-TestResult -TestName "Scripts Monitoring Présents" -Passed $allScriptsExist
    
    # Test 2: Vérification des dépendances PowerShell
    Write-Host "Test des dépendances PowerShell..." -ForegroundColor Gray
    $requiredModules = @("PSScheduledJob", "Microsoft.PowerShell.Utility")
    $modulesOk = $true
    
    foreach ($module in $requiredModules) {
        if (Get-Module -Name $module -ListAvailable) {
            Write-Host "  ✓ Module $module disponible" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Module $module manquant" -ForegroundColor Red
            $modulesOk = $false
        }
    }
    
    Write-TestResult -TestName "Dépendances PowerShell" -Passed $modulesOk
    
    # Test 3: Vérification de l'espace disque
    Write-Host "Test de l'espace disque..." -ForegroundColor Gray
    $systemDrive = Get-PSDrive -Name C
    $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 2)
    $freeSpaceOk = $freeSpaceGB -gt 5
    
    Write-Host "  Espace libre: $freeSpaceGB GB" -ForegroundColor $(if ($freeSpaceOk) { "Green" } else { "Red" })
    Write-TestResult -TestName "Espace Disque Suffisant" -Passed $freeSpaceOk -Message "Espace libre: $freeSpaceGB GB"
    
    Write-Host ""
}

# Fonction pour tester les MCPs
function Test-MCPComponents {
    Write-Host "🔧 TEST DES COMPOSANTS MCP" -ForegroundColor Yellow
    Write-Host "----------------------------" -ForegroundColor Yellow
    
    # Test 1: Vérification des serveurs MCP critiques
    Write-Host "Test des serveurs MCP critiques..." -ForegroundColor Gray
    $criticalMCPs = @(
        "roo-state-manager",
        "quickfiles", 
        "jupyter-mcp-server",
        "jinavigator"
    )
    
    $mcpResults = @{}
    foreach ($mcp in $criticalMCPs) {
        try {
            # Vérification via processus
            $process = Get-Process -Name "*$mcp*" -ErrorAction SilentlyContinue
            if ($process) {
                Write-Host "  ✓ $mcp en cours d'exécution (PID: $($process.Id))" -ForegroundColor Green
                $mcpResults[$mcp] = $true
            } else {
                Write-Host "  ✗ $mcp non démarré" -ForegroundColor Red
                $mcpResults[$mcp] = $false
            }
        } catch {
            Write-Host "  ⚠ $mcp - Erreur de vérification: $($_.Exception.Message)" -ForegroundColor Yellow
            $mcpResults[$mcp] = $false
        }
    }
    
    $mcpSuccessRate = ($mcpResults.Values | Where-Object { $_ -eq $true }).Count / $mcpResults.Count * 100
    $mcpOk = $mcpSuccessRate -ge 75
    
    Write-TestResult -TestName "Serveurs MCP Critiques" -Passed $mcpOk -Message "Taux de succès: $mcpSuccessRate%" -Details $mcpResults
    
    # Test 2: Vérification des configurations MCP
    Write-Host "Test des configurations MCP..." -ForegroundColor Gray
    $mcpConfigPath = "mcps\internal\servers"
    $configOk = $true
    
    if (Test-Path $mcpConfigPath) {
        $serverDirs = Get-ChildItem -Path $mcpConfigPath -Directory
        Write-Host "  ✓ $($serverDirs.Count) serveurs MCP trouvés" -ForegroundColor Green
        
        foreach ($dir in $serverDirs) {
            $packageJson = Join-Path $dir.FullName "package.json"
            if (Test-Path $packageJson) {
                Write-Host "    ✓ $($dir.Name) - package.json trouvé" -ForegroundColor Green
            } else {
                Write-Host "    ✗ $($dir.Name) - package.json manquant" -ForegroundColor Red
                $configOk = $false
            }
        }
    } else {
        Write-Host "  ✗ Répertoire des serveurs MCP non trouvé" -ForegroundColor Red
        $configOk = $false
    }
    
    Write-TestResult -TestName "Configurations MCP" -Passed $configOk
    
    Write-Host ""
}

# Fonction pour tester RooSync
function Test-RooSyncComponents {
    Write-Host "🔄 TEST DES COMPOSANTS ROOSYNC" -ForegroundColor Yellow
    Write-Host "------------------------------" -ForegroundColor Yellow
    
    # Test 1: Vérification des scripts RooSync
    Write-Host "Test des scripts RooSync..." -ForegroundColor Gray
    $roosyncScripts = @(
        "scripts\roosync\roosync_export_baseline.ps1",
        "scripts\roosync\roosync_granular_diff.ps1",
        "scripts\roosync\roosync_update_baseline.ps1"
    )
    
    $scriptsOk = $true
    foreach ($script in $roosyncScripts) {
        if (Test-Path $script) {
            Write-Host "  ✓ $(Split-Path $script -Leaf) trouvé" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $(Split-Path $script -Leaf) manquant" -ForegroundColor Red
            $scriptsOk = $false
        }
    }
    
    Write-TestResult -TestName "Scripts RooSync" -Passed $scriptsOk
    
    # Test 2: Vérification de la configuration RooSync
    Write-Host "Test de la configuration RooSync..." -ForegroundColor Gray
    $roosyncConfig = "roo-config\sync-config.ref.json"
    
    if (Test-Path $roosyncConfig) {
        try {
            $config = Get-Content $roosyncConfig -Raw | ConvertFrom-Json
            Write-Host "  ✓ Configuration RooSync valide" -ForegroundColor Green
            Write-Host "    Machines: $($config.machines.Count)" -ForegroundColor Gray
            Write-TestResult -TestName "Configuration RooSync" -Passed $true -Details $config
        } catch {
            Write-Host "  ✗ Configuration RooSync invalide: $($_.Exception.Message)" -ForegroundColor Red
            Write-TestResult -TestName "Configuration RooSync" -Passed $false -Message "JSON invalide"
        }
    } else {
        Write-Host "  ✗ Fichier de configuration RooSync non trouvé" -ForegroundColor Red
        Write-TestResult -TestName "Configuration RooSync" -Passed $false -Message "Fichier manquant"
    }
    
    Write-Host ""
}

# Fonction pour tester la documentation
function Test-Documentation {
    Write-Host "📚 TEST DE LA DOCUMENTATION" -ForegroundColor Yellow
    Write-Host "---------------------------" -ForegroundColor Yellow
    
    # Test 1: Vérification des documents critiques
    Write-Host "Test des documents critiques..." -ForegroundColor Gray
    $criticalDocs = @(
        "docs\planning\PHASE3_SDDD_PLANIFICATION_AVEC_POINTS_VALIDATION.md",
        "sddd-tracking\50-CHECKPOINT-4-PHASE3C-ROBUSTESSE-PERFORMANCE-2025-12-04.md",
        "roo-config\specifications\README.md"
    )
    
    $docsOk = $true
    foreach ($doc in $criticalDocs) {
        if (Test-Path $doc) {
            $content = Get-Content $doc -Raw
            $lines = $content.Split("`n").Count
            Write-Host "  ✓ $(Split-Path $doc -Leaf) ($lines lignes)" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $(Split-Path $doc -Leaf) manquant" -ForegroundColor Red
            $docsOk = $false
        }
    }
    
    Write-TestResult -TestName "Documentation Critique" -Passed $docsOk
    
    # Test 2: Vérification de la cohérence SDDD
    Write-Host "Test de la cohérence SDDD..." -ForegroundColor Gray
    $sdddTrackingPath = "sddd-tracking"
    
    if (Test-Path $sdddTrackingPath) {
        $sdddFiles = Get-ChildItem -Path $sdddTrackingPath -Filter "*.md" | Sort-Object Name
        Write-Host "  ✓ $($sdddFiles.Count) documents SDDD trouvés" -ForegroundColor Green
        
        # Vérification de la numérotation
        $numberedFiles = $sdddFiles | Where-Object { $_.Name -match '^\d+-' }
        Write-Host "  ✓ $($numberedFiles.Count) documents numérotés" -ForegroundColor Green
        
        Write-TestResult -TestName "Cohérence SDDD" -Passed $true -Details @{
            TotalFiles = $sdddFiles.Count
            NumberedFiles = $numberedFiles.Count
        }
    } else {
        Write-Host "  ✗ Répertoire SDDD non trouvé" -ForegroundColor Red
        Write-TestResult -TestName "Cohérence SDDD" -Passed $false -Message "Répertoire manquant"
    }
    
    Write-Host ""
}

# Fonction pour tester les performances
function Test-Performance {
    Write-Host "⚡ TEST DES PERFORMANCES" -ForegroundColor Yellow
    Write-Host "------------------------" -ForegroundColor Yellow
    
    # Test 1: Mesure des temps de réponse système
    Write-Host "Test des temps de réponse système..." -ForegroundColor Gray
    
    $startTime = Get-Date
    $cpuUsage = (Get-Counter "\Processor(_Total)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
    $responseTime = (Get-Date) - $startTime
    
    $responseTimeMs = $responseTime.TotalMilliseconds
    $responseTimeOk = $responseTimeMs -lt 1000
    
    Write-Host "  Temps de réponse CPU: $([math]::Round($responseTimeMs, 2)) ms" -ForegroundColor $(if ($responseTimeOk) { "Green" } else { "Red" })
    Write-Host "  Utilisation CPU: $([math]::Round($cpuUsage, 2))%" -ForegroundColor Gray
    
    Write-TestResult -TestName "Temps de Réponse Système" -Passed $responseTimeOk -Message "$([math]::Round($responseTimeMs, 2)) ms"
    
    # Test 2: Test de mémoire disponible
    Write-Host "Test de la mémoire disponible..." -ForegroundColor Gray
    $memory = Get-Counter "\Memory\Available MBytes" -ErrorAction SilentlyContinue
    $availableMemoryGB = $memory.CounterSamples.CookedValue / 1024
    $memoryOk = $availableMemoryGB -gt 2
    
    Write-Host "  Mémoire disponible: $([math]::Round($availableMemoryGB, 2)) GB" -ForegroundColor $(if ($memoryOk) { "Green" } else { "Red" })
    Write-TestResult -TestName "Mémoire Disponible" -Passed $memoryOk -Message "$([math]::Round($availableMemoryGB, 2)) GB"
    
    Write-Host ""
}

# Fonction pour générer le rapport
function New-IntegrationReport {
    if (-not $Report) { return }
    
    Write-Host "📊 GÉNÉRATION DU RAPPORT D'INTÉGRATION" -ForegroundColor Yellow
    Write-Host "------------------------------------" -ForegroundColor Yellow
    
    $reportData = @{
        Timestamp = $Timestamp
        Summary = @{
            TotalTests = $TotalTests
            PassedTests = $PassedTests
            FailedTests = $FailedTests
            SuccessRate = if ($TotalTests -gt 0) { [math]::Round($PassedTests / $TotalTests * 100, 2) } else { 0 }
        }
        TestResults = $TestResults
        Environment = @{
            OSVersion = $PSVersionTable.PSVersion
            PowerShellVersion = $PSVersionTable.PSVersion
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
        }
    }
    
    # Génération du rapport JSON
    $jsonReport = $reportData | ConvertTo-Json -Depth 10
    $jsonPath = "$ReportPath\integration-report-$Timestamp.json"
    $jsonReport | Out-File -FilePath $jsonPath -Encoding UTF8
    
    # Génération du rapport HTML
    $htmlReport = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport d'Intégration Phase 3D</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .metric h3 { margin: 0 0 10px 0; font-size: 2em; }
        .metric p { margin: 0; opacity: 0.9; }
        .test-result { margin: 10px 0; padding: 15px; border-radius: 5px; border-left: 4px solid; }
        .test-passed { background-color: #d4edda; border-left-color: #28a745; }
        .test-failed { background-color: #f8d7da; border-left-color: #dc3545; }
        .success-rate { font-size: 1.5em; font-weight: bold; color: $(if ($reportData.Summary.SuccessRate -ge 90) { '#28a745' } elseif ($reportData.Summary.SuccessRate -ge 75) { '#ffc107' } else { '#dc3545' }); }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Rapport d'Intégration Phase 3D</h1>
        <p><strong>Date:</strong> $Timestamp</p>
        <p><strong>Mode:</strong> $(if ($Comprehensive) { 'Complet' } elseif ($Quick) { 'Rapide' } else { 'Standard' })</p>
        
        <div class="summary">
            <div class="metric">
                <h3>$($reportData.Summary.TotalTests)</h3>
                <p>Tests Total</p>
            </div>
            <div class="metric">
                <h3>$($reportData.Summary.PassedTests)</h3>
                <p>Tests Réussis</p>
            </div>
            <div class="metric">
                <h3>$($reportData.Summary.FailedTests)</h3>
                <p>Tests Échoués</p>
            </div>
            <div class="metric">
                <h3 class="success-rate">$($reportData.Summary.SuccessRate)%</h3>
                <p>Taux de Succès</p>
            </div>
        </div>
        
        <h2>📋 Résultats Détaillés</h2>
"@
    
    foreach ($test in $TestResults.GetEnumerator()) {
        $statusClass = if ($test.Value.Passed) { "test-passed" } else { "test-failed" }
        $statusIcon = if ($test.Value.Passed) { "✅" } else { "❌" }
        
        $htmlReport += @"
        <div class="test-result $statusClass">
            <h3>$statusIcon $($test.Key)</h3>
            <p><strong>Statut:</strong> $(if ($test.Value.Passed) { 'Réussi' } else { 'Échoué' })</p>
            $(if ($test.Value.Message) { "<p><strong>Message:</strong> $($test.Value.Message)</p>" } )
            <p><strong>Timestamp:</strong> $($test.Value.Timestamp)</p>
        </div>
"@
    }
    
    $htmlReport += @"
    </div>
</body>
</html>
"@
    
    $htmlPath = "$ReportPath\integration-report-$Timestamp.html"
    $htmlReport | Out-File -FilePath $htmlPath -Encoding UTF8
    
    Write-Host "  ✓ Rapport JSON généré: $jsonPath" -ForegroundColor Green
    Write-Host "  ✓ Rapport HTML généré: $htmlPath" -ForegroundColor Green
    Write-Host ""
}

# Exécution des tests
try {
    Test-SystemComponents
    
    if ($Comprehensive -or -not $Quick) {
        Test-MCPComponents
        Test-RooSyncComponents
        Test-Documentation
        Test-Performance
    }
    
    # Génération du rapport
    New-IntegrationReport
    
    # Affichage du résumé final
    Write-Host "📊 RÉSUMÉ FINAL DES TESTS" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "Tests totaux: $TotalTests" -ForegroundColor White
    Write-Host "Tests réussis: $PassedTests" -ForegroundColor Green
    Write-Host "Tests échoués: $FailedTests" -ForegroundColor Red
    
    $successRate = if ($TotalTests -gt 0) { [math]::Round($PassedTests / $TotalTests * 100, 2) } else { 0 }
    Write-Host "Taux de succès: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { "Green" } elseif ($successRate -ge 75) { "Yellow" } else { "Red" })
    
    Write-Host ""
    Write-Host "📁 Rapports générés dans: $ReportPath" -ForegroundColor Gray
    
    if ($Report) {
        Write-Host "🌐 Ouvrir le rapport HTML: start $htmlPath" -ForegroundColor Gray
    }
    
    # Code de sortie basé sur le succès
    if ($FailedTests -eq 0) {
        Write-Host "🎉 TOUS LES TESTS RÉUSSIS" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠️ CERTAINS TESTS ONT ÉCHOUÉ" -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host "❌ ERREUR CRITIQUE PENDANT L'EXÉCUTION DES TESTS" -ForegroundColor Red
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 2
}