<#
.SYNOPSIS
    Rollback Zoo Scheduler → original Roo Scheduler.
.DESCRIPTION
    Uninstalls the Zoo Scheduler VSIX fork and reinstalls the original
    kylehoskins.roo-scheduler from the VS Code Marketplace.

    Issue: #2378 — Deploy Zoo Scheduler VSIX fleet-wide (rollback).
.PARAMETER Force
    Skip confirmation prompts.
.EXAMPLE
    .\rollback-to-roo-scheduler.ps1
.EXAMPLE
    .\rollback-to-roo-scheduler.ps1 -Force
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=== Zoo Scheduler Rollback Script ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Verify Zoo Scheduler installed ---
Write-Host "[1/4] Checking Zoo Scheduler..."
$zooScheduler = code --list-extensions 2>$null | Where-Object { $_ -match "zoo-scheduler" }
if (-not $zooScheduler) {
    Write-Host "  Zoo Scheduler not found. Nothing to rollback."
    exit 0
}
Write-Host "  Found: $zooScheduler"

# --- Step 2: Confirm rollback ---
if (-not $Force) {
    Write-Host ""
    Write-Host "WARNING: This will uninstall Zoo Scheduler and reinstall the original Roo Scheduler."
    $confirm = Read-Host "Continue with rollback? (y/N)"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Aborted."
        exit 0
    }
}

# --- Step 3: Uninstall Zoo Scheduler ---
Write-Host "[2/4] Uninstalling Zoo Scheduler..."
code --uninstall-extension $zooScheduler 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host "  Zoo Scheduler uninstalled."

# --- Step 4: Install original Roo Scheduler ---
Write-Host "[3/4] Installing original Roo Scheduler from marketplace..."
code --install-extension kylehoskins.roo-scheduler 2>&1 | ForEach-Object { Write-Host "  $_" }
Write-Host "  Roo Scheduler installed."

# --- Step 5: Restore schedules.json if needed ---
Write-Host "[4/4] Checking schedules.json..."
$rooStateDir = "$env:APPDATA\Code\User\globalStorage\kylehoskins.roo-scheduler"
$zooStateDir = "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code"
$rooSchedulesFile = Join-Path $rooStateDir "state\schedules.json"
$zooSchedulesFile = Join-Path $zooStateDir "state\schedules.json"

if (Test-Path $zooSchedulesFile) {
    if (-not (Test-Path $rooSchedulesFile)) {
        Write-Host "  Found schedules.json in Zoo state (not in Roo state). Restoring..."
        if (-not (Test-Path (Split-Path $rooSchedulesFile -Parent))) {
            New-Item -ItemType Directory -Path (Split-Path $rooSchedulesFile -Parent) -Force | Out-Null
        }
        Copy-Item $zooSchedulesFile $rooSchedulesFile -Force
        Write-Host "  schedules.json restored to Roo state."
    } else {
        Write-Host "  schedules.json already exists in Roo state (no restore needed)."
    }
} else {
    Write-Host "  No schedules.json found in Zoo state."
}

# --- Summary ---
Write-Host ""
Write-Host "=== Rollback Complete ===" -ForegroundColor Green
Write-Host "Extension: kylehoskins.roo-scheduler"
Write-Host ""
Write-Host "To verify: code --list-extensions | Select-String roo-scheduler"
Write-Host "Re-deploy: .\deploy-zoo-scheduler.ps1"
