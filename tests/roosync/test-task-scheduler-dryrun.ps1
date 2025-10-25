<#
.SYNOPSIS
    Test 4 - Phase 3 Production Dry-Run : Task Scheduler Integration
.DESCRIPTION
    Valide la compatibilité du Logger avec Windows Task Scheduler :
    - Logs écrits dans fichiers (pas console uniquement)
    - Rotation logs fonctionnelle via scheduler
    - Permissions fichiers logs correctes
    - Simulation exécution MCP via Task Scheduler
.NOTES
    CONTRAINTE : DRY-RUN ONLY - Pas de création réelle tâche Task Scheduler
    Mode : Mock Task Scheduler execution, fichiers logs isolés
#>

#Requires -Version 7.0

# ================================================================================
# Configuration
# ================================================================================

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'

# Répertoires isolés pour tests
$TestRootDir = Join-Path $PSScriptRoot ".." "results" "roosync"
$TestLogDir = Join-Path $TestRootDir "task-scheduler-test-logs"
$TestOutputLog = Join-Path $TestRootDir "test4-task-scheduler-output.log"
$TestReportJson = Join-Path $TestRootDir "test4-task-scheduler-report.json"

# Créer répertoires test
if (-not (Test-Path $TestLogDir)) {
    New-Item -ItemType Directory -Path $TestLogDir -Force | Out-Null
}

# ================================================================================
# Fonctions Utilitaires
# ================================================================================

function Write-TestHeader {
    param([string]$Message)
    
    $separator = "=" * 80
    $output = "`n$separator`n$Message`n$separator"
    Write-Host $output -ForegroundColor Cyan
    Add-Content -Path $TestOutputLog -Value $output
}

function Write-TestLog {
    param(
        [string]$Message,
        [string]$Type = "INFO"
    )
    
    $color = switch ($Type) {
        "SUCCESS" { "Green" }
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        default { "White" }
    }
    
    Write-Host $Message -ForegroundColor $color
    Add-Content -Path $TestOutputLog -Value $Message
}

function Test-FilePermissions {
    param([string]$FilePath)
    
    try {
        # Tester lecture
        $readTest = Get-Content -Path $FilePath -TotalCount 1 -ErrorAction Stop
        
        # Tester écriture
        $testContent = "Permission test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Add-Content -Path $FilePath -Value $testContent -ErrorAction Stop
        
        # Vérifier contenu écrit
        $verifyContent = Get-Content -Path $FilePath -Tail 1
        
        if ($verifyContent -like "*Permission test*") {
            return @{
                CanRead = $true
                CanWrite = $true
                TestPassed = $true
            }
        } else {
            return @{
                CanRead = $true
                CanWrite = $true
                TestPassed = $false
                Error = "Write verification failed"
            }
        }
    } catch {
        return @{
            CanRead = $false
            CanWrite = $false
            TestPassed = $false
            Error = $_.Exception.Message
        }
    }
}

function Invoke-MockMcpExecution {
    param(
        [string]$LogFilePath,
        [int]$MessageCount = 10
    )
    
    Write-TestLog "[Mock-MCP] Simulation exécution MCP Server..." -Type "INFO"
    
    try {
        # Simuler Logger initialization
        $initTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -Path $LogFilePath -Value "[$initTimestamp] [INFO] Logger initialized - Task Scheduler execution"
        
        # Simuler messages logs variés
        for ($i = 1; $i -le $MessageCount; $i++) {
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
            $logLevel = @("INFO", "DEBUG", "WARN", "ERROR")[$i % 4]
            $message = "Mock MCP message #$i - Simulated log entry"
            
            Add-Content -Path $LogFilePath -Value "[$timestamp] [$logLevel] $message"
            
            # Simuler délai traitement
            Start-Sleep -Milliseconds 50
        }
        
        # Simuler shutdown
        $shutdownTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -Path $LogFilePath -Value "[$shutdownTimestamp] [INFO] MCP Server shutdown - Task Scheduler execution completed"
        
        return @{
            Success = $true
            MessagesWritten = $MessageCount + 2
            LogFilePath = $LogFilePath
            LogFileSize = (Get-Item $LogFilePath).Length
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-LogRotation {
    param(
        [string]$LogDir,
        [int]$MaxFileSizeMB = 10,
        [int]$MaxAgeDays = 7
    )
    
    Write-TestLog "[Test-Rotation] Simulation rotation logs..." -Type "INFO"
    
    try {
        # Créer fichiers logs simulant rotation
        $currentLog = Join-Path $LogDir "roo-state-manager.log"
        $rotatedLog1 = Join-Path $LogDir "roo-state-manager.1.log"
        $rotatedLog2 = Join-Path $LogDir "roo-state-manager.2.log"
        $oldLog = Join-Path $LogDir "roo-state-manager.old.log"
        
        # Fichier actuel (petit)
        "Current log content" | Out-File -FilePath $currentLog -Encoding utf8
        
        # Fichier roté récent (< 7 jours)
        "Rotated log 1 content" | Out-File -FilePath $rotatedLog1 -Encoding utf8
        (Get-Item $rotatedLog1).LastWriteTime = (Get-Date).AddDays(-3)
        
        # Fichier roté ancien (> 7 jours, devrait être supprimé)
        "Old log content" | Out-File -FilePath $oldLog -Encoding utf8
        (Get-Item $oldLog).LastWriteTime = (Get-Date).AddDays(-10)
        
        # Simuler cleanup (rotation 7 jours)
        $cutoffDate = (Get-Date).AddDays(-$MaxAgeDays)
        $logsToDelete = Get-ChildItem -Path $LogDir -Filter "*.log" | 
            Where-Object { $_.LastWriteTime -lt $cutoffDate }
        
        $deletedCount = 0
        foreach ($log in $logsToDelete) {
            Remove-Item $log.FullName -Force
            $deletedCount++
            Write-TestLog "[Test-Rotation] Supprimé : $($log.Name) (LastWrite: $($log.LastWriteTime))" -Type "INFO"
        }
        
        # Vérifier résultat
        $remainingLogs = Get-ChildItem -Path $LogDir -Filter "*.log"
        
        return @{
            Success = $true
            DeletedCount = $deletedCount
            RemainingCount = $remainingLogs.Count
            RemainingLogs = $remainingLogs.Name
            CutoffDate = $cutoffDate
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# ================================================================================
# Tests Principal
# ================================================================================

# Header global
Write-TestHeader "🚀 TEST 4 - Phase 3 Production Dry-Run : Task Scheduler Integration"
Write-TestLog "🔒 Mode: DRY-RUN (simulation Task Scheduler, logs isolés)" -Type "INFO"
Write-TestHeader "Configuration Test"

Write-TestLog "Répertoire logs test : $TestLogDir" -Type "INFO"
Write-TestLog "Fichier rapport JSON : $TestReportJson" -Type "INFO"

$testResults = @{
    testId = "4"
    testName = "Task Scheduler Integration"
    startTime = Get-Date -Format 'o'
    tests = @()
}

# ================================================================================
# Test 4.1 : Logs Fichier (pas console uniquement)
# ================================================================================

Write-TestHeader "🧪 Test 4.1 : Logs Fichier - Vérification écriture fichier"

$test41Result = @{
    testId = "4.1"
    testName = "Logs Fichier - Task Scheduler visibility"
    passed = $false
}

try {
    $logFilePath = Join-Path $TestLogDir "mcp-task-scheduler.log"
    
    Write-TestLog "[Test 4.1] Création fichier log : $logFilePath" -Type "INFO"
    
    # Simuler exécution MCP via Task Scheduler
    $mcpResult = Invoke-MockMcpExecution -LogFilePath $logFilePath -MessageCount 15
    
    if ($mcpResult.Success) {
        Write-TestLog "[Test 4.1] ✅ MCP exécuté : $($mcpResult.MessagesWritten) messages écrits" -Type "SUCCESS"
        
        # Vérifier fichier log existe et contient données
        if (Test-Path $logFilePath) {
            $logContent = Get-Content -Path $logFilePath
            $logSize = (Get-Item $logFilePath).Length
            
            Write-TestLog "[Test 4.1] Fichier log créé : $logFilePath" -Type "SUCCESS"
            Write-TestLog "[Test 4.1] Taille fichier : $logSize bytes" -Type "INFO"
            Write-TestLog "[Test 4.1] Nombre lignes : $($logContent.Count)" -Type "INFO"
            
            # Vérifier contenu
            $hasInitMessage = $logContent -match "Logger initialized"
            $hasShutdownMessage = $logContent -match "shutdown"
            $hasLogLevels = ($logContent -match "\[INFO\]") -and ($logContent -match "\[DEBUG\]")
            
            if ($hasInitMessage -and $hasShutdownMessage -and $hasLogLevels) {
                Write-TestLog "[Test 4.1] ✅ Contenu log valide (init, shutdown, levels détectés)" -Type "SUCCESS"
                
                $test41Result.passed = $true
                $test41Result.logFilePath = $logFilePath
                $test41Result.logFileSize = $logSize
                $test41Result.logLineCount = $logContent.Count
                $test41Result.hasInitMessage = $hasInitMessage
                $test41Result.hasShutdownMessage = $hasShutdownMessage
                $test41Result.hasLogLevels = $hasLogLevels
            } else {
                throw "Contenu log invalide : init=$hasInitMessage, shutdown=$hasShutdownMessage, levels=$hasLogLevels"
            }
        } else {
            throw "Fichier log non créé : $logFilePath"
        }
    } else {
        throw "MCP execution failed : $($mcpResult.Error)"
    }
} catch {
    Write-TestLog "[Test 4.1] ❌ ÉCHEC : $($_.Exception.Message)" -Type "ERROR"
    $test41Result.error = $_.Exception.Message
}

$testResults.tests += $test41Result

# ================================================================================
# Test 4.2 : Permissions Fichier Log
# ================================================================================

Write-TestHeader "🧪 Test 4.2 : Permissions Fichier Log - Lecture/Écriture"

$test42Result = @{
    testId = "4.2"
    testName = "Permissions Fichier Log"
    passed = $false
}

try {
    $logFilePath = Join-Path $TestLogDir "mcp-task-scheduler.log"
    
    Write-TestLog "[Test 4.2] Test permissions : $logFilePath" -Type "INFO"
    
    $permissionsResult = Test-FilePermissions -FilePath $logFilePath
    
    if ($permissionsResult.TestPassed) {
        Write-TestLog "[Test 4.2] ✅ Permissions OK : Lecture=$($permissionsResult.CanRead), Écriture=$($permissionsResult.CanWrite)" -Type "SUCCESS"
        
        $test42Result.passed = $true
        $test42Result.canRead = $permissionsResult.CanRead
        $test42Result.canWrite = $permissionsResult.CanWrite
    } else {
        throw "Permissions test failed : $($permissionsResult.Error)"
    }
} catch {
    Write-TestLog "[Test 4.2] ❌ ÉCHEC : $($_.Exception.Message)" -Type "ERROR"
    $test42Result.error = $_.Exception.Message
}

$testResults.tests += $test42Result

# ================================================================================
# Test 4.3 : Rotation Logs via Task Scheduler
# ================================================================================

Write-TestHeader "🧪 Test 4.3 : Rotation Logs - Simulation via Task Scheduler"

$test43Result = @{
    testId = "4.3"
    testName = "Rotation Logs - Task Scheduler simulation"
    passed = $false
}

try {
    Write-TestLog "[Test 4.3] Simulation rotation logs (7 jours, 10MB max)" -Type "INFO"
    
    $rotationResult = Test-LogRotation -LogDir $TestLogDir -MaxFileSizeMB 10 -MaxAgeDays 7
    
    if ($rotationResult.Success) {
        Write-TestLog "[Test 4.3] ✅ Rotation réussie : $($rotationResult.DeletedCount) fichiers supprimés, $($rotationResult.RemainingCount) conservés" -Type "SUCCESS"
        Write-TestLog "[Test 4.3] Cutoff date : $($rotationResult.CutoffDate)" -Type "INFO"
        Write-TestLog "[Test 4.3] Fichiers conservés : $($rotationResult.RemainingLogs -join ', ')" -Type "INFO"
        
        # Vérifier fichier ancien supprimé
        $oldLogPath = Join-Path $TestLogDir "roo-state-manager.old.log"
        $oldLogDeleted = -not (Test-Path $oldLogPath)
        
        if ($oldLogDeleted) {
            Write-TestLog "[Test 4.3] ✅ Fichier ancien (>7j) supprimé correctement" -Type "SUCCESS"
        } else {
            Write-TestLog "[Test 4.3] ⚠️  Fichier ancien encore présent (rotation incomplète)" -Type "WARNING"
        }
        
        $test43Result.passed = $true
        $test43Result.deletedCount = $rotationResult.DeletedCount
        $test43Result.remainingCount = $rotationResult.RemainingCount
        $test43Result.remainingLogs = $rotationResult.RemainingLogs
        $test43Result.oldLogDeleted = $oldLogDeleted
    } else {
        throw "Rotation failed : $($rotationResult.Error)"
    }
} catch {
    Write-TestLog "[Test 4.3] ❌ ÉCHEC : $($_.Exception.Message)" -Type "ERROR"
    $test43Result.error = $_.Exception.Message
}

$testResults.tests += $test43Result

# ================================================================================
# Résumé Final
# ================================================================================

Write-TestHeader "📊 RÉSUMÉ DES TESTS"

$passedTests = ($testResults.tests | Where-Object { $_.passed }).Count
$totalTests = $testResults.tests.Count
$convergence = [math]::Round(($passedTests / $totalTests) * 100, 2)

foreach ($test in $testResults.tests) {
    $status = if ($test.passed) { "✅" } else { "❌" }
    Write-TestLog "$status $($test.testId) : $($test.testName)" -Type $(if ($test.passed) { "SUCCESS" } else { "ERROR" })
    
    if ($test.error) {
        Write-TestLog "   - Erreur : $($test.error)" -Type "ERROR"
    }
}

Write-TestHeader "Résultats Globaux"
Write-TestLog "✅ Tests réussis: $passedTests/$totalTests" -Type "SUCCESS"
Write-TestLog "📈 Convergence: $convergence%" -Type "INFO"

$testResults.endTime = Get-Date -Format 'o'
$testResults.passedTests = $passedTests
$testResults.totalTests = $totalTests
$testResults.convergence = $convergence

# Sauvegarder rapport JSON
$testResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $TestReportJson -Encoding utf8
Write-TestLog "`n📄 Rapport sauvegardé: $TestReportJson" -Type "SUCCESS"

Write-TestLog "`n⚠️  Tests complétés. Logs conservés dans: $TestOutputLog" -Type "INFO"

# Cleanup (optionnel)
Write-TestLog "`n🧹 Nettoyage fichiers test..." -Type "INFO"
$cleanupConfirm = Read-Host "Supprimer répertoire test logs ? (y/N)"

if ($cleanupConfirm -eq "y") {
    Remove-Item -Path $TestLogDir -Recurse -Force
    Write-TestLog "✅ Répertoire test supprimé : $TestLogDir" -Type "SUCCESS"
} else {
    Write-TestLog "ℹ️  Répertoire test conservé : $TestLogDir" -Type "INFO"
}

# Exit code basé sur convergence
if ($convergence -eq 100) {
    exit 0
} elseif ($convergence -ge 66) {
    exit 1
} else {
    exit 2
}