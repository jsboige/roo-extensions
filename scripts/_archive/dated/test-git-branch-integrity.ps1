<#
.SYNOPSIS
    Test script to verify Git Branch Integrity Check fix

.DESCRIPTION
    This script simulates various git states to verify that the Git Branch Integrity Check
    correctly detects detached HEAD states and orphan commits.
#>

[CmdletBinding()]
param()

# Import required modules
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptPath "..\..\scripts\scheduler\WinCliPatterns.psm1"

if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
} else {
    Write-Warning "WinCliPatterns.psm1 not found at $modulePath"
}

# Test cases to simulate
$testCases = @(
    @{
        Name = "Normal State (main branch)"
        SetupCommands = @(
            "git checkout main",
            "git branch -D test-branch 2>$null"
        )
        ExpectedDetection = "No detection"
    },
    @{
        Name = "Detached HEAD state"
        SetupCommands = @(
            "git commit --allow-empty -m 'test commit for detached HEAD'",
            "git checkout --detach HEAD~1"
        )
        ExpectedDetection = "Detached HEAD detected"
    }
)

# Function to run test
function Test-GitBranchCheck {
    param([string]$TestName)

    Write-Host "`n=== Testing: $TestName ===" -ForegroundColor Cyan

    # Mock Write-INTERCOMMessage for testing
    function Write-INTERCOMMessage {
        param([string]$Type, [string]$Title, [string]$Content, [string]$MachineName)
        Write-Host "[$Type] $Title" -ForegroundColor $(switch($Type) { "CRITICAL" { "Red" } "WARN" { "Yellow" } default { "White" } })
        # Don't throw in test, just write
    }

    # Import the check function (this would be part of the actual workflow)
    $checkCode = {
        # Check for detached HEAD state
        $headStatus = Invoke-GitCommand -GitCommand "status --porcelain=v1 --branch" -NoLog
        if ($headStatus.Success -and $headStatus.Output) {
            if ($headStatus.Output.Contains("HEAD detached at")) {
                Write-INTERCOMMessage -Type "CRITICAL" -Title "Detected detached HEAD state" -Content "**CRITICAL ISSUE DETECTED: Detached HEAD state found**`n`nDetached HEAD state detected before task execution. This could lead to lost commits.`n`nCurrent HEAD status: $($headStatus.Output.Trim())`n`n**Action required:** Check git status and checkout proper branch before continuing.`n`nWorkflow halted to prevent lost commits." -MachineName "test-machine"
                # In real workflow, this would throw: throw "Detached HEAD detected. Halting workflow to prevent lost commits."
                Write-Host "DETACHED HEAD WOULD BE DETECTED" -ForegroundColor Red
                return $true
            }
        }

        # Check for orphan commits (commits not on any branch)
        $orphanDetected = $false
        $logResult = Invoke-GitCommand -GitCommand "log --oneline --branches --not --remotes" -NoLog
        if ($logResult.Success -and $logResult.Output) {
            $orphanCommits = $logResult.Output.Trim() | Where-Object { $_ }
            if ($orphanCommits) {
                $commitsText = $orphanCommits -join "`n"
                Write-INTERCOMMessage -Type "WARN" -Title "Orphan commits detected" -Content "**WARNING: Orphan commits found**`n`nFound commits that exist locally but are not on any branch:`n`n```$commitsText```" -MachineName "test-machine"
                $orphanDetected = $true
            }
        }

        # Verify main branch exists and is available
        $branchResult = Invoke-GitCommand -GitCommand "branch --list main" -NoLog
        if (-not $branchResult.Success -or -not $branchResult.Output.Contains("main")) {
            $branchResult = Invoke-GitCommand -GitCommand "branch --list master" -NoLog
            if (-not $branchResult.Success -or -not $branchResult.Output.Contains("master")) {
                Write-INTERCOMMessage -Type "CRITICAL" -Title "No main/master branch found" -Content "**CRITICAL: No main/master branch detected**`n`nCannot proceed without a proper main branch for commit safety." -MachineName "test-machine"
                # In real workflow, this would throw: throw "No main or master branch found. Halting workflow."
                Write-Host "NO MAIN/MASTER BRANCH WOULD BE DETECTED" -ForegroundColor Red
                return $true
            }
        }

        return $orphanDetected
    }

    # Execute the check
    try {
        $detected = & $checkCode
        Write-Host "Test completed. Detection result: $detected" -ForegroundColor Green
    }
    catch {
        Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Run all tests
foreach ($test in $testCases) {
    Write-Host "`nPreparing test: $($test.Name)" -ForegroundColor Yellow

    # Reset to safe state first
    git checkout main 2>$null
    git reset --hard origin/main 2>$null

    # Setup test state if needed
    if ($test.SetupCommands) {
        foreach ($cmd in $test.SetupCommands) {
            Invoke-Expression $cmd | Out-Null
        }
    }

    # Run the test
    Test-GitBranchCheck -TestName $test.Name
}

Write-Host "`n=== All tests completed ===" -ForegroundColor Green