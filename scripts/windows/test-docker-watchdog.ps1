<#
.SYNOPSIS
    Test script for Docker/WSL Watchdog
.DESCRIPTION
    Simulates various failure conditions to test the watchdog behavior.
#>

param(
    [ValidateSet("docker-hang", "wsl-switch-lost", "both", "none")]
    [string]$Scenario = "none",
    [switch]$Cleanup = $false
)

# Import required modules
try {
    Import-Module VMware.PowerShell -ErrorAction Stop  # For VMSwitch commands
} catch {
    Write-Warning "VMware module not found. Using basic PowerShell for tests."
}

function New-TestDockerLog {
    param([string]$FilePath, [int]$Hours, [int]$Minutes)

    # Create test log file
    $content = @"
2026-04-14 10:00:00 [main.enginedependencies] Docker engine started
2026-04-14 10:30:15 [main.enginedependencies] init control API initialized
"@

    if ($Hours -gt 0 -or $Minutes -gt 0) {
        $content += "`n2026-04-14 10:00:00 [main.enginedependencies] still waiting for init control API to respond after $Hours h $Minutes m"
    }

    $content | Out-File -FilePath $FilePath -Encoding UTF8
    Write-Host "📄 Created test Docker log: $FilePath" -ForegroundColor Green
}

function Remove-TestVMSwitch {
    param([string]$SwitchName)

    # Check if switch exists and remove it
    $switch = Get-VMSwitch $SwitchName -ErrorAction SilentlyContinue
    if ($switch) {
        Write-Host "🔌 Removing test VM switch: $SwitchName" -ForegroundColor Yellow
        Remove-VMSwitch $SwitchName -Force -ErrorAction SilentlyContinue
        return $true
    }
    return $false
}

function Restore-TestVMSwitch {
    param([string]$SwitchName)

    # This is a simplified test - in real scenarios you'd need to recreate the switch properly
    Write-Host "🔌 Note: VM switch restoration requires manual setup in test environment" -ForegroundColor Yellow
}

# Test scenarios
if ($Cleanup) {
    # Clean up any test artifacts
    $testLogPath = "$env:TEMP\test-docker-monitor.log"
    if (Test-Path $testLogPath) {
        Remove-Item $testLogPath -Force
        Write-Host "🧹 Cleaned up test log file" -ForegroundColor Green
    }

    $testSwitch = "Test-WSL-Switch"
    Remove-TestVMSwitch -SwitchName $testSwitch

    Write-Host "✅ Cleanup completed" -ForegroundColor Green
    exit 0
}

Write-Host "🧪 Testing Docker/WSL Watchdog" -ForegroundColor Cyan
Write-Host "Scenario: $Scenario" -ForegroundColor Yellow

# Create test Docker log
$testLogPath = "$env:TEMP\test-docker-monitor.log"
$scriptPath = "$PSScriptRoot\docker-wsl-watchdog.ps1"

# Force remove existing test log to ensure clean test
if (Test-Path $testLogPath) {
    Remove-Item $testLogPath -Force
}

switch ($Scenario) {
    "docker-hang" {
        Write-Host "🐋 Simulating Docker init control API hang (6 minutes)" -ForegroundColor Yellow
        New-TestDockerLog -FilePath $testLogPath -Hours 0 -Minutes 6
    }

    "wsl-switch-lost" {
        Write-Host "🌐 Simulating WSL switch loss" -ForegroundColor Yellow
        New-TestDockerLog -FilePath $testLogPath -Hours 0 -Minutes 0

        # Note: Can't easily test VMSwitch removal in standard environment
        Write-Host "ℹ️ VMSwitch test requires elevated privileges and Hyper-V setup" -ForegroundColor Gray
    }

    "both" {
        Write-Host "🔄 Simulating both Docker hang and WSL switch loss" -ForegroundColor Yellow
        New-TestDockerLog -FilePath $testLogPath -Hours 0 -Minutes 6

        Write-Host "ℹ️ VMSwitch test requires elevated privileges and Hyper-V setup" -ForegroundColor Gray
    }

    "none" {
        Write-Host "🟢 Creating normal Docker log (no issues)" -ForegroundColor Green
        New-TestDockerLog -FilePath $testLogPath -Hours 0 -Minutes 0
    }
}

# Run the watchdog with test log
if (Test-Path $scriptPath) {
    Write-Host "`n🔍 Running watchdog with test scenario..." -ForegroundColor Cyan
    & $scriptPath -LogPath $testLogPath -Verbose
} else {
    Write-Error "Watchdog script not found: $scriptPath"
}

# Cleanup after test
if ($Scenario -ne "none") {
    Write-Host "`n🧹 Cleaning up test files..." -ForegroundColor Gray
    Start-Sleep -Seconds 2  # Allow log to be written

    if (Test-Path $testLogPath) {
        Remove-Item $testLogPath -Force
        Write-Host "✅ Test log removed" -ForegroundColor Green
    }
}

Write-Host "`n✅ Test completed!" -ForegroundColor Green