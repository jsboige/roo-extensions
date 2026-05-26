<#
.SYNOPSIS
    Rolls back Zoo Scheduler to original Roo Scheduler.
.DESCRIPTION
    Uninstalls the forked Zoo Scheduler and reinstalls the original
    Roo Scheduler from the VS Code marketplace.

    Issue: #2378 — Deploy Zoo Scheduler VSIX fleet-wide (rollback script).
.PARAMETER WorkspacePath
    Path to the workspace root (for schedules.json rollback).
    Default: git repo root or current directory.
.PARAMETER WhatIf
    Dry run — show what would be done without executing.
.EXAMPLE
    .\rollback-to-roo-scheduler.ps1
    .\rollback-to-roo-scheduler.ps1 -WhatIf
#>
param(
    [string]$WorkspacePath = "",
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$RooSchedulerId = "kylehoskins.roo-scheduler"
$ZooSchedulerPattern = "zoo-scheduler"

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "--- $msg ---" -ForegroundColor Cyan
}

# --- Step 1: Uninstall Zoo Scheduler ---
Write-Step "Step 1: Uninstall Zoo Scheduler"

$zooScheduler = code --list-extensions 2>$null | Where-Object { $_ -match $ZooSchedulerPattern }
if ($zooScheduler) {
    Write-Host "Uninstalling $zooScheduler..."
    if ($WhatIf) {
        Write-Host "[WHATIF] code --uninstall-extension $zooScheduler"
    } else {
        code --uninstall-extension $zooScheduler 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "[OK] Uninstalled $zooScheduler"
    }
} else {
    Write-Host "[SKIP] Zoo Scheduler not installed"
}

# --- Step 2: Reinstall original Roo Scheduler ---
Write-Step "Step 2: Reinstall original Roo Scheduler"

$rooScheduler = code --list-extensions 2>$null | Where-Object { $_ -eq $RooSchedulerId }
if ($rooScheduler) {
    Write-Host "[SKIP] $RooSchedulerId already installed"
} else {
    Write-Host "Installing $RooSchedulerId from marketplace..."
    if ($WhatIf) {
        Write-Host "[WHATIF] code --install-extension $RooSchedulerId"
    } else {
        code --install-extension $RooSchedulerId 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "[OK] Installed $RooSchedulerId"
    }
}

# --- Step 3: Restore schedules.json (zoo -> roo if needed) ---
Write-Step "Step 3: Restore schedules.json"

if (-not $WorkspacePath) {
    $WorkspacePath = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if (-not $WorkspacePath) {
        $WorkspacePath = Get-Location
    }
}

$rooSchedules = Join-Path (Join-Path $WorkspacePath ".roo") "schedules.json"
$zooSchedules = Join-Path (Join-Path $WorkspacePath ".zoo") "schedules.json"

if ((Test-Path $zooSchedules) -and -not (Test-Path $rooSchedules)) {
    if ($WhatIf) {
        Write-Host "[WHATIF] Copy $zooSchedules -> $rooSchedules"
    } else {
        $rooDir = Join-Path $WorkspacePath ".roo"
        if (-not (Test-Path $rooDir)) {
            New-Item -ItemType Directory -Path $rooDir -Force | Out-Null
        }
        Copy-Item $zooSchedules $rooSchedules -Force
        Write-Host "[OK] Restored schedules.json: .zoo/ -> .roo/" -ForegroundColor Green
    }
} elseif ((Test-Path $rooSchedules)) {
    Write-Host "[SKIP] .roo/schedules.json already exists"
} else {
    Write-Host "[SKIP] No schedules.json to restore"
}

# --- Summary ---
Write-Step "Summary"
if ($WhatIf) {
    Write-Host "[WHATIF MODE — no changes made]" -ForegroundColor Yellow
}
Write-Host @"
Zoo Scheduler:   $(if ($zooScheduler) { 'uninstalled' } else { 'not present' })
Roo Scheduler:   $(if ($rooScheduler) { 'already installed' } else { 'reinstalled' })
Schedules:       $(if ((Test-Path $zooSchedules) -and -not (Test-Path $rooSchedules)) { 'restored .zoo -> .roo' } elseif (Test-Path $rooSchedules) { '.roo/ intact' } else { 'none found' })

Next: Restart VS Code to activate the original scheduler.
"@
