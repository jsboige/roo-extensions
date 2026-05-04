#Requires -Version 5.1

<#
.SYNOPSIS
    Simple test script for Invoke-RooStagedWorkflow wrapper

.DESCRIPTION
    Validates the staged workflow logging functionality by executing
    a simple task through all 4 stages (Étape 0-3).

.NOTES
    Author: Claude Code (myia-po-2023)
    Date: 2026-05-04
    Issue: #1887
#>

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path "$PSScriptRoot\..\.."

Write-Host "`n=== Testing Invoke-RooStagedWorkflow ===`n" -ForegroundColor Cyan
Write-Host "This test will execute 3 simple tasks to validate the wrapper.`n" -ForegroundColor White

# Test 1: Simple successful task
Write-Host "Test 1: Simple successful task" -ForegroundColor Yellow
& "$RepoRoot\scripts\scheduling\Invoke-RooStagedWorkflow.ps1" -TaskName "Test-Simple" -ScriptBlock {
    Write-Host "  → Executing simple task..."
    Start-Sleep -Milliseconds 500
    Write-Host "  → Task completed!"
}

Write-Host "`n" -ForegroundColor White

# Test 2: Task with git operations
Write-Host "Test 2: Task with git operations" -ForegroundColor Yellow
& "$RepoRoot\scripts\scheduling\Invoke-RooStagedWorkflow.ps1" -TaskName "Test-GitOps" -ScriptBlock {
    Write-Host "  → Checking git status..."
    $status = git status --short 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  → Git status retrieved successfully"
    }
}

Write-Host "`n" -ForegroundColor White

# Test 3: Task that simulates work
Write-Host "Test 3: Task with simulated work" -ForegroundColor Yellow
& "$RepoRoot\scripts\scheduling\Invoke-RooStagedWorkflow.ps1" -TaskName "Test-Work" -ScriptBlock {
    Write-Host "  → Processing items..."
    $items = 1..5
    foreach ($item in $items) {
        Write-Host "  → Processing item $item/5"
        Start-Sleep -Milliseconds 200
    }
    Write-Host "  → All items processed!"
}

Write-Host "`n" -ForegroundColor White

# Summary
Write-Host "`n=== Test Summary ===`n" -ForegroundColor Cyan
Write-Host "Total tests: 3" -ForegroundColor White
Write-Host "Completed: 3" -ForegroundColor Green
Write-Host "`nAll tests executed! Check the log files for detailed output.`n" -ForegroundColor Green

# Show log file location
$logDir = Join-Path $RepoRoot "outputs\scheduling\logs"
if (Test-Path $logDir) {
    $latestLog = Get-ChildItem $logDir -Filter "roo-staged-*.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if ($latestLog) {
        Write-Host "`nLatest log file: $($latestLog.FullName)" -ForegroundColor Cyan
        Write-Host "Last 20 log entries:" -ForegroundColor Cyan
        Get-Content $latestLog.FullName -Tail 20 | ForEach-Object { Write-Host "  $_" }
    }
}
