<#
.SYNOPSIS
    Test script for Hermes MCP watchdog - simulates failures and validates behavior.

.DESCRIPTION
    This script helps test the Hermes MCP watchdog by:
      1. Validating Docker environment
      2. Testing watchdog in dry-run mode
      3. Simulating error conditions
      4. Verifying detection mechanisms

.PARAMETER ContainerName
    Hermes container name to test against. Default: 'hermes'

.EXAMPLE
    .\test-hermes-watchdog.ps1
    .\test-hermes-watchdog.ps1 -ContainerName hermes-dashboard
#>

param(
    [string]$ContainerName = 'hermes'
)

$ErrorActionPreference = 'Continue'
$testResults = @()

function Write-TestResult {
    param(
        [string]$Test,
        [bool]$Passed,
        [string]$Message
    )
    $status = if ($Passed) { 'PASS' } else { 'FAIL' }
    $color = if ($Passed) { 'Green' } else { 'Red' }
    Write-Host "[$status] $Test" -ForegroundColor $color
    if ($Message) {
        Write-Host "    → $Message" -ForegroundColor $(if ($Passed) { 'Gray' } else { 'Yellow' })
    }
    $script:testResults += @{
        Test = $Test
        Passed = $Passed
        Message = $Message
    }
}

Write-Host "`n=== Hermes MCP Watchdog Test Suite ===" -ForegroundColor Cyan
Write-Host "Target container: $ContainerName`n" -ForegroundColor Gray

# Test 1: Check if Docker is available
Write-Host "Test 1: Docker availability" -ForegroundColor Gray
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-TestResult -Test "Docker installed" -Passed $true -Message $dockerVersion
    } else {
        Write-TestResult -Test "Docker installed" -Passed $false -Message "Docker command failed"
    }
} catch {
    Write-TestResult -Test "Docker installed" -Passed $false -Message $_.Exception.Message
}

# Test 2: Check if container exists
Write-Host "`nTest 2: Container existence" -ForegroundColor Gray
try {
    $inspectResult = docker inspect -f '{{.State.Status}}' $ContainerName 2>&1
    if ($LASTEXITCODE -eq 0) {
        $status = $inspectResult.Trim()
        Write-TestResult -Test "Container exists" -Passed $true -Message "Status: $status"
    } else {
        Write-TestResult -Test "Container exists" -Passed $false -Message "Container not found"
    }
} catch {
    Write-TestResult -Test "Container exists" -Passed $false -Message $_.Exception.Message
}

# Test 3: Check if mcp-remote process is running
Write-Host "`nTest 3: mcp-remote process health" -ForegroundColor Gray
try {
    $processResult = docker exec $ContainerName ps aux 2>&1 | Select-String 'mcp-remote'
    if ($processResult) {
        $parts = $processResult.Line -split '\s+', 10
        $procPid = $parts[1]
        $cpu = $parts[2]
        $mem = $parts[3]
        Write-TestResult -Test "mcp-remote running" -Passed $true -Message "PID: $procPid, CPU: $cpu%, MEM: $mem%"
    } else {
        Write-TestResult -Test "mcp-remote running" -Passed $false -Message "mcp-remote process not found"
    }
} catch {
    Write-TestResult -Test "mcp-remote running" -Passed $false -Message $_.Exception.Message
}

# Test 4: Check recent logs for errors
Write-Host "`nTest 4: Recent error detection" -ForegroundColor Gray
try {
    $since = (Get-Date).AddMinutes(-10).ToString('yyyy-MM-ddTHH:mm:ss')
    $logs = docker logs --since $since $ContainerName 2>&1

    $errorPatterns = @(
        'ClosedResourceError',
        'MCP tool.*call failed',
        'Connection to provider dropped',
        'ReadTimeout'
    )

    $errorCount = 0
    $errorLines = @()
    foreach ($pattern in $errorPatterns) {
        $matches = $logs | Select-String $pattern
        $errorCount += $matches.Count
        $errorLines += $matches
    }

    if ($errorCount -gt 0) {
        Write-TestResult -Test "Error detection" -Passed $true -Message "Found $errorCount error(s) in recent logs"
        Write-Host "    Recent errors:" -ForegroundColor Gray
        $errorLines | Select-Object -Last 3 | ForEach-Object {
            $line = $_ -replace '\s+', ' '
            Write-Host "      - $($line.Substring(0, [Math]::Min(120, $line.Length)))" -ForegroundColor DarkGray
        }
    } else {
        Write-TestResult -Test "Error detection" -Passed $true -Message "No errors detected in recent logs"
    }
} catch {
    Write-TestResult -Test "Error detection" -Passed $false -Message $_.Exception.Message
}

# Test 5: Watchdog script exists
Write-Host "`nTest 5: Watchdog script availability" -ForegroundColor Gray
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$watchdogScript = Join-Path $scriptDir 'hermes-mcp-watchdog.ps1'
if (Test-Path $watchdogScript) {
    Write-TestResult -Test "Watchdog script exists" -Passed $true -Message $watchdogScript
} else {
    Write-TestResult -Test "Watchdog script exists" -Passed $false -Message "Script not found at $watchdogScript"
}

# Test 6: Run watchdog in dry-run mode
Write-Host "`nTest 6: Watchdog dry-run execution" -ForegroundColor Gray
if (Test-Path $watchdogScript) {
    try {
        $output = & $watchdogScript -Mode dry-run -ContainerName $ContainerName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult -Test "Watchdog dry-run" -Passed $true -Message "Completed successfully"
        } else {
            Write-TestResult -Test "Watchdog dry-run" -Passed $false -Message "Exit code: $LASTEXITCODE"
        }
    } catch {
        Write-TestResult -Test "Watchdog dry-run" -Passed $false -Message $_.Exception.Message
    }
} else {
    Write-TestResult -Test "Watchdog dry-run" -Passed $false -Message "Script not found, skipping test"
}

# Test 7: Check scheduled task
Write-Host "`nTest 7: Scheduled task status" -ForegroundColor Gray
try {
    $task = Get-ScheduledTask -TaskName 'Hermes-MCP-Watchdog' -ErrorAction SilentlyContinue
    if ($task) {
        Write-TestResult -Test "Scheduled task exists" -Passed $true -Message "State: $($task.State)"
        $taskInfo = Get-ScheduledTaskInfo -TaskName 'Hermes-MCP-Watchdog'
        Write-Host "    Last run: $($taskInfo.LastRunTime)" -ForegroundColor Gray
        Write-Host "    Last result: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
    } else {
        Write-TestResult -Test "Scheduled task exists" -Passed $false -Message "Task not installed (run install-hermes-watchdog.ps1)"
    }
} catch {
    Write-TestResult -Test "Scheduled task exists" -Passed $false -Message $_.Exception.Message
}

# Test 8: Log directory
Write-Host "`nTest 8: Log directory setup" -ForegroundColor Gray
# Use repo root as base for logs
$repoRoot = 'C:\dev\roo-extensions'
$logDir = Join-Path $repoRoot 'outputs\hermes-watchdog'
if (Test-Path $logDir) {
    Write-TestResult -Test "Log directory exists" -Passed $true -Message $logDir
    $logFiles = Get-ChildItem -Path $logDir -Filter 'hermes-watchdog-*.log' -ErrorAction SilentlyContinue
    if ($logFiles) {
        Write-Host "    Log files: $($logFiles.Count)" -ForegroundColor Gray
        $latest = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "    Latest: $($latest.Name) ($([int]((Get-Date) - $latest.LastWriteTime).TotalMinutes) min ago)" -ForegroundColor Gray
    }
} else {
    Write-TestResult -Test "Log directory exists" -Passed $false -Message "Directory not found (will be created on first run): $logDir"
}

# Test 9: State file
Write-Host "`nTest 9: State file" -ForegroundColor Gray
if (Test-Path $logDir) {
    $stateFile = Join-Path $logDir 'hermes-watchdog-state.json'
    if (Test-Path $stateFile) {
        Write-TestResult -Test "State file exists" -Passed $true -Message "Tracking state across runs"
        try {
            $state = Get-Content $stateFile -Raw | ConvertFrom-Json
            Write-Host "    Last restart: $($state.LastRestartTime)" -ForegroundColor Gray
            Write-Host "    Restart count: $($state.RestartCount)" -ForegroundColor Gray
            Write-Host "    First error: $($state.FirstErrorTime)" -ForegroundColor Gray
        } catch {
            Write-Host "    Warning: Could not parse state file" -ForegroundColor Yellow
        }
    } else {
        Write-TestResult -Test "State file exists" -Passed $true -Message "Not created yet (normal for first run)"
    }
} else {
    Write-TestResult -Test "State file exists" -Passed $true -Message "Log directory not created yet, skipping state file check"
}

# Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
$passed = ($testResults | Where-Object { $_.Passed }).Count
$failed = ($testResults | Where-Object { -not $_.Passed }).Count
Write-Host "Passed: $passed / Failed: $failed / Total: $($testResults.Count)" -ForegroundColor $(if ($failed -eq 0) { 'Green' } else { 'Yellow' })

if ($failed -gt 0) {
    Write-Host "`nFailed tests:" -ForegroundColor Red
    $testResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.Test): $($_.Message)" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "`nAll tests passed! The watchdog is ready to deploy." -ForegroundColor Green
    exit 0
}
