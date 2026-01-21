# ============================================================================
# Script de Test pour l'Orchestration Quotidienne Intelligente Roo
# Version: 1.0.0
# Description: Tests complets du système d'orchestration avec auto-amélioration
# ============================================================================

param(
    [switch]$RunFullTest = $false,
    [switch]$TestConfiguration = $true,
    [switch]$TestOrchestrationEngine = $true,
    [switch]$TestSelfImprovement = $true,
    [switch]$GenerateTestData = $false,
    [switch]$Verbose = $false,
    [string]$BasePath = ""  # Chemin racine du dépôt (auto-détecté si vide)
)

# Auto-détection du chemin racine si non spécifié
if (-not $BasePath) {
    $BasePath = (Resolve-Path (Join-Path $PSScriptRoot "..\..\")).Path.TrimEnd('\', '/')
}

# Configuration globale
$Global:TestConfig = @{
    BasePath = $BasePath
    TestId = [System.Guid]::NewGuid().ToString()
    StartTime = Get-Date
    Verbose = $Verbose
    TestResults = @()
}

Set-Location $Global:TestConfig.BasePath

# ============================================================================
# FONCTIONS UTILITAIRES DE TEST
# ============================================================================

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$TestName = "SYSTEM"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    
    if ($Global:TestConfig.Verbose -or $Level -in @("WARN", "ERROR", "PASS", "FAIL")) {
        $color = switch ($Level) {
            "DEBUG" { "Gray" }
            "INFO" { "White" }
            "WARN" { "Yellow" }
            "ERROR" { "Red" }
            "PASS" { "Green" }
            "FAIL" { "Red" }
            default { "White" }
        }
        Write-Host "[$timestamp] [$TestName] $Message" -ForegroundColor $color
    }
}

function Test-FileExists {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    $testResult = @{
        test_name = "file_existence"
        description = $Description
        file_path = $FilePath
        status = "unknown"
        message = ""
        timestamp = Get-Date
    }
    
    if (Test-Path $FilePath) {
        $testResult.status = "pass"
        $testResult.message = "Fichier trouvé"
        Write-TestLog "✓ $Description : $FilePath" -Level "PASS" -TestName "FILE_CHECK"
    }
    else {
        $testResult.status = "fail"
        $testResult.message = "Fichier non trouvé"
        Write-TestLog "✗ $Description : $FilePath" -Level "FAIL" -TestName "FILE_CHECK"
    }
    
    $Global:TestConfig.TestResults += $testResult
    return $testResult.status -eq "pass"
}

function Test-JsonSyntax {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    $testResult = @{
        test_name = "json_syntax"
        description = $Description
        file_path = $FilePath
        status = "unknown"
        message = ""
        timestamp = Get-Date
    }
    
    try {
        if (Test-Path $FilePath) {
            Get-Content -Raw $FilePath | ConvertFrom-Json | Out-Null
            $testResult.status = "pass"
            $testResult.message = "JSON valide"
            Write-TestLog "✓ $Description : JSON valide" -Level "PASS" -TestName "JSON_CHECK"
        }
        else {
            $testResult.status = "fail"
            $testResult.message = "Fichier non trouvé"
            Write-TestLog "✗ $Description : Fichier non trouvé" -Level "FAIL" -TestName "JSON_CHECK"
        }
    }
    catch {
        $testResult.status = "fail"
        $testResult.message = "Erreur JSON: $($_.Exception.Message)"
        Write-TestLog "✗ $Description : $($_.Exception.Message)" -Level "FAIL" -TestName "JSON_CHECK"
    }
    
    $Global:TestConfig.TestResults += $testResult
    return $testResult.status -eq "pass"
}

function Test-PowerShellSyntax {
    param(
        [string]$FilePath,
        [string]$Description
    )
    
    $testResult = @{
        test_name = "powershell_syntax"
        description = $Description
        file_path = $FilePath
        status = "unknown"
        message = ""
        timestamp = Get-Date
    }
    
    try {
        if (Test-Path $FilePath) {
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content -Raw $FilePath), [ref]$null)
            $testResult.status = "pass"
            $testResult.message = "Syntaxe PowerShell valide"
            Write-TestLog "✓ $Description : Syntaxe valide" -Level "PASS" -TestName "PS_SYNTAX"
        }
        else {
            $testResult.status = "fail"
            $testResult.message = "Fichier non trouvé"
            Write-TestLog "✗ $Description : Fichier non trouvé" -Level "FAIL" -TestName "PS_SYNTAX"
        }
    }
    catch {
        $testResult.status = "fail"
        $testResult.message = "Erreur syntaxe: $($_.Exception.Message)"
        Write-TestLog "✗ $Description : $($_.Exception.Message)" -Level "FAIL" -TestName "PS_SYNTAX"
    }
    
    $Global:TestConfig.TestResults += $testResult
    return $testResult.status -eq "pass"
}

# ============================================================================
# TESTS DE CONFIGURATION
# ============================================================================

function Test-OrchestrationConfiguration {
    Write-TestLog "=== TEST DE LA CONFIGURATION D'ORCHESTRATION ===" -Level "INFO" -TestName "CONFIG"
    
    $configTests = @()
    
    # Test de présence des fichiers de configuration
    $configTests += Test-FileExists -FilePath ".roo/schedules.json" -Description "Fichier de planification principal"
    $configTests += Test-FileExists -FilePath "roo-config/scheduler/daily-orchestration.json" -Description "Configuration d'orchestration détaillée"
    $configTests += Test-FileExists -FilePath "roo-config/scheduler/config.json" -Description "Configuration du scheduler existant"
    
    # Test de syntaxe JSON
    $configTests += Test-JsonSyntax -FilePath ".roo/schedules.json" -Description "Syntaxe du fichier de planification"
    $configTests += Test-JsonSyntax -FilePath "roo-config/scheduler/daily-orchestration.json" -Description "Syntaxe de la configuration d'orchestration"
    $configTests += Test-JsonSyntax -FilePath "roo-config/scheduler/config.json" -Description "Syntaxe de la configuration scheduler"
    
    # Test de la présence de la tâche d'orchestration quotidienne
    try {
        $schedules = Get-Content -Raw ".roo/schedules.json" | ConvertFrom-Json
        $orchestrationTask = $schedules.schedules | Where-Object { $_.name -eq "Daily-Roo-Environment-Orchestration" }
        
        if ($orchestrationTask) {
            Write-TestLog "✓ Tâche d'orchestration quotidienne trouvée" -Level "PASS" -TestName "CONFIG"
            $configTests += $true
            
            # Vérification des propriétés essentielles
            $requiredProperties = @("mode", "scheduleType", "timeInterval", "active")
            foreach ($prop in $requiredProperties) {
                if ($orchestrationTask.PSObject.Properties.Name -contains $prop) {
                    Write-TestLog "✓ Propriété '$prop' présente" -Level "PASS" -TestName "CONFIG"
                }
                else {
                    Write-TestLog "✗ Propriété '$prop' manquante" -Level "FAIL" -TestName "CONFIG"
                    $configTests += $false
                }
            }
        }
        else {
            Write-TestLog "✗ Tâche d'orchestration quotidienne non trouvée" -Level "FAIL" -TestName "CONFIG"
            $configTests += $false
        }
    }
    catch {
        Write-TestLog "✗ Erreur lors de la vérification de la tâche: $($_.Exception.Message)" -Level "FAIL" -TestName "CONFIG"
        $configTests += $false
    }
    
    $passedTests = ($configTests | Where-Object { $_ -eq $true }).Count
    $totalTests = $configTests.Count
    
    Write-TestLog "Tests de configuration: $passedTests/$totalTests réussis" -Level "INFO" -TestName "CONFIG"
    
    return $passedTests -eq $totalTests
}

# ============================================================================
# TESTS DU MOTEUR D'ORCHESTRATION
# ============================================================================

function Test-OrchestrationEngine {
    Write-TestLog "=== TEST DU MOTEUR D'ORCHESTRATION ===" -Level "INFO" -TestName "ENGINE"
    
    $engineTests = @()
    
    # Test de présence du script principal
    $engineTests += Test-FileExists -FilePath "roo-config/scheduler/orchestration-engine.ps1" -Description "Script du moteur d'orchestration"
    
    # Test de syntaxe PowerShell
    $engineTests += Test-PowerShellSyntax -FilePath "roo-config/scheduler/orchestration-engine.ps1" -Description "Syntaxe du moteur d'orchestration"
    
    # Test d'exécution en mode dry-run
    try {
        Write-TestLog "Test d'exécution en mode dry-run..." -Level "INFO" -TestName "ENGINE"
        
        # Création d'un fichier de configuration de test minimal
        $testConfig = @{
            system = @{
                name = "Test Configuration"
                version = "1.0.0"
            }
            orchestration = @{
                phases = @{
                    diagnostic = @{
                        name = "Test Diagnostic"
                        mode = "debug"
                        timeout_minutes = 5
                        retry_attempts = 1
                        retry_delay_seconds = 10
                        critical = $false
                        tasks = @()
                    }
                }
            }
        }
        
        $testConfigPath = "roo-config/scheduler/test-orchestration-config.json"
        $testConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $testConfigPath
        
        # Test de chargement de la configuration
        $loadTest = & "roo-config/scheduler/orchestration-engine.ps1" -ConfigPath $testConfigPath -DryRun -Verbose 2>&1
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-TestLog "✓ Moteur d'orchestration exécutable" -Level "PASS" -TestName "ENGINE"
            $engineTests += $true
        }
        else {
            Write-TestLog "✗ Erreur d'exécution du moteur (code: $LASTEXITCODE)" -Level "FAIL" -TestName "ENGINE"
            $engineTests += $false
        }
        
        # Nettoyage
        if (Test-Path $testConfigPath) {
            Remove-Item -Path $testConfigPath -Force
        }
    }
    catch {
        Write-TestLog "✗ Erreur lors du test d'exécution: $($_.Exception.Message)" -Level "FAIL" -TestName "ENGINE"
        $engineTests += $false
    }
    
    $passedTests = ($engineTests | Where-Object { $_ -eq $true }).Count
    $totalTests = $engineTests.Count
    
    Write-TestLog "Tests du moteur d'orchestration: $passedTests/$totalTests réussis" -Level "INFO" -TestName "ENGINE"
    
    return $passedTests -eq $totalTests
}

# ============================================================================
# TESTS DU SYSTÈME D'AUTO-AMÉLIORATION
# ============================================================================

function Test-SelfImprovementSystem {
    Write-TestLog "=== TEST DU SYSTÈME D'AUTO-AMÉLIORATION ===" -Level "INFO" -TestName "IMPROVEMENT"
    
    $improvementTests = @()
    
    # Test de présence du script d'auto-amélioration
    $improvementTests += Test-FileExists -FilePath "roo-config/scheduler/scripts/modules/self-improvement.ps1" -Description "Script d'auto-amélioration"
    
    # Test de syntaxe PowerShell
    $improvementTests += Test-PowerShellSyntax -FilePath "roo-config/scheduler/scripts/modules/self-improvement.ps1" -Description "Syntaxe du script d'auto-amélioration"
    
    # Test de création des répertoires nécessaires
    $requiredDirs = @(
        "roo-config/scheduler/logs",
        "roo-config/scheduler/metrics",
        "roo-config/scheduler/history"
    )
    
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-TestLog "✓ Répertoire créé: $dir" -Level "PASS" -TestName "IMPROVEMENT"
                $improvementTests += $true
            }
            catch {
                Write-TestLog "✗ Impossible de créer le répertoire: $dir" -Level "FAIL" -TestName "IMPROVEMENT"
                $improvementTests += $false
            }
        }
        else {
            Write-TestLog "✓ Répertoire existant: $dir" -Level "PASS" -TestName "IMPROVEMENT"
            $improvementTests += $true
        }
    }
    
    $passedTests = ($improvementTests | Where-Object { $_ -eq $true }).Count
    $totalTests = $improvementTests.Count
    
    Write-TestLog "Tests du système d'auto-amélioration: $passedTests/$totalTests réussis" -Level "INFO" -TestName "IMPROVEMENT"
    
    return $passedTests -eq $totalTests
}

# ============================================================================
# GÉNÉRATION DE DONNÉES DE TEST
# ============================================================================

function Generate-TestMetrics {
    Write-TestLog "=== GÉNÉRATION DE DONNÉES DE TEST ===" -Level "INFO" -TestName "TEST_DATA"
    
    $metricsDir = "roo-config/scheduler/metrics"
    if (-not (Test-Path $metricsDir)) {
        New-Item -ItemType Directory -Path $metricsDir -Force | Out-Null
    }
    
    # Génération de métriques de test pour les 7 derniers jours
    for ($i = 7; $i -gt 0; $i--) {
        $testDate = (Get-Date).AddDays(-$i)
        $metricsFile = Join-Path $metricsDir "daily-metrics-$($testDate.ToString('yyyyMMdd')).json"
        
        # Génération de données de test réalistes
        $testMetrics = @{
            date = $testDate.ToString("yyyy-MM-dd")
            executions = @()
        }
        
        # Génération de 1-3 exécutions par jour
        $executionCount = Get-Random -Minimum 1 -Maximum 4
        
        for ($j = 0; $j -lt $executionCount; $j++) {
            $execution = @{
                execution_id = [System.Guid]::NewGuid().ToString()
                start_time = $testDate.AddHours((Get-Random -Minimum 6 -Maximum 22))
                total_duration_ms = Get-Random -Minimum 120000 -Maximum 1800000  # 2-30 minutes
                status = if ((Get-Random -Minimum 1 -Maximum 10) -gt 2) { "success" } else { "partial_success" }
                phases = @{
                    diagnostic = @{
                        duration_ms = Get-Random -Minimum 30000 -Maximum 300000
                        status = "success"
                    }
                    synchronization = @{
                        duration_ms = Get-Random -Minimum 60000 -Maximum 600000
                        status = "success"
                    }
                    testing = @{
                        duration_ms = Get-Random -Minimum 120000 -Maximum 900000
                        status = if ((Get-Random -Minimum 1 -Maximum 10) -gt 1) { "success" } else { "warning" }
                    }
                    cleanup = @{
                        duration_ms = Get-Random -Minimum 10000 -Maximum 120000
                        status = "success"
                    }
                }
            }
            
            $testMetrics.executions += $execution
        }
        
        $testMetrics | ConvertTo-Json -Depth 10 | Set-Content -Path $metricsFile
        Write-TestLog "✓ Métriques de test générées pour $($testDate.ToString('yyyy-MM-dd'))" -Level "PASS" -TestName "TEST_DATA"
    }
    
    Write-TestLog "Génération de données de test terminée" -Level "INFO" -TestName "TEST_DATA"
}

# ============================================================================
# FONCTION PRINCIPALE DE TEST
# ============================================================================

function Start-OrchestrationTests {
    Write-TestLog "=== DÉBUT DES TESTS D'ORCHESTRATION QUOTIDIENNE ===" -Level "INFO" -TestName "MAIN"
    
    $testResults = @{
        start_time = $Global:TestConfig.StartTime
        test_id = $Global:TestConfig.TestId
        configuration_tests = $false
        engine_tests = $false
        improvement_tests = $false
        overall_status = "unknown"
        summary = @{
            total_tests = 0
            passed_tests = 0
            failed_tests = 0
        }
    }
    
    try {
        # Génération de données de test si demandé
        if ($GenerateTestData) {
            Generate-TestMetrics
        }
        
        # Tests de configuration
        if ($TestConfiguration) {
            $testResults.configuration_tests = Test-OrchestrationConfiguration
        }
        
        # Tests du moteur d'orchestration
        if ($TestOrchestrationEngine) {
            $testResults.engine_tests = Test-OrchestrationEngine
        }
        
        # Tests du système d'auto-amélioration
        if ($TestSelfImprovement) {
            $testResults.improvement_tests = Test-SelfImprovementSystem
        }
        
        # Calcul des statistiques globales
        $allTestResults = $Global:TestConfig.TestResults
        $testResults.summary.total_tests = $allTestResults.Count
        $testResults.summary.passed_tests = ($allTestResults | Where-Object { $_.status -eq "pass" }).Count
        $testResults.summary.failed_tests = ($allTestResults | Where-Object { $_.status -eq "fail" }).Count
        
        # Détermination du statut global
        if ($testResults.summary.failed_tests -eq 0) {
            $testResults.overall_status = "success"
        }
        elseif ($testResults.summary.passed_tests -gt 0) {
            $testResults.overall_status = "partial_success"
        }
        else {
            $testResults.overall_status = "failure"
        }
        
        # Sauvegarde du rapport de test
        $reportPath = "roo-config/scheduler/test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $testResults | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath
        
        Write-TestLog "=== RÉSUMÉ DES TESTS ===" -Level "INFO" -TestName "MAIN"
        Write-TestLog "Tests totaux: $($testResults.summary.total_tests)" -Level "INFO" -TestName "MAIN"
        Write-TestLog "Tests réussis: $($testResults.summary.passed_tests)" -Level "INFO" -TestName "MAIN"
        Write-TestLog "Tests échoués: $($testResults.summary.failed_tests)" -Level "INFO" -TestName "MAIN"
        Write-TestLog "Statut global: $($testResults.overall_status)" -Level "INFO" -TestName "MAIN"
        Write-TestLog "Rapport sauvegardé: $reportPath" -Level "INFO" -TestName "MAIN"
        Write-TestLog "=== FIN DES TESTS ===" -Level "INFO" -TestName "MAIN"
        
        return $testResults
    }
    catch {
        Write-TestLog "Erreur critique dans les tests: $($_.Exception.Message)" -Level "ERROR" -TestName "MAIN"
        $testResults.overall_status = "error"
        return $testResults
    }
}

# ============================================================================
# POINT D'ENTRÉE PRINCIPAL
# ============================================================================

if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-OrchestrationTests
    
    switch ($result.overall_status) {
        "success" { exit 0 }
        "partial_success" { exit 1 }
        "failure" { exit 2 }
        "error" { exit 3 }
        default { exit 4 }
    }
}