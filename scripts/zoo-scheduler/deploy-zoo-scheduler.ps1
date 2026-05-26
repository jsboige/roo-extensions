<#
.SYNOPSIS
    Deploy Zoo Scheduler VSIX fleet-wide — install + verify.
.DESCRIPTION
    Installs the Zoo Scheduler VSIX fork, uninstalls the original Roo Scheduler,
    verifies the 3 replacements post-install (ext ID, ActivityBar, config section),
    and migrates schedules.json from Roo globalStorage to Zoo globalStorage.

    Issue: #2378 — Deploy Zoo Scheduler VSIX fleet-wide.
.PARAMETER VSIXPath
    Path to the zoo-scheduler VSIX file.
    Default: ./outputs/zoo-scheduler-0.0.11-zoo.1.vsix (relative to repo root)
.PARAMETER DryRun
    Print actions without executing.
.PARAMETER Force
    Skip confirmation prompts.
.EXAMPLE
    .\deploy-zoo-scheduler.ps1
.EXAMPLE
    .\deploy-zoo-scheduler.ps1 -VSIXPath D:\packages\zoo-scheduler-0.0.11-zoo.1.vsix -Force
#>
param(
    [string]$VSIXPath = "",
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# --- Resolve VSIX path ---
if (-not $VSIXPath) {
    $repoRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        $VSIXPath = Join-Path $repoRoot "outputs\zoo-scheduler-0.0.11-zoo.1.vsix"
    } else {
        $VSIXPath = Join-Path $PSScriptRoot "..\..\outputs\zoo-scheduler-0.0.11-zoo.1.vsix"
    }
}

if (-not (Test-Path $VSIXPath)) {
    Write-Error "VSIX not found at: $VSIXPath"
    Write-Error "Run patch-scheduler.ps1 first to build it."
    exit 1
}

Write-Host "=== Zoo Scheduler Deploy Script ===" -ForegroundColor Cyan
Write-Host "VSIX: $VSIXPath"
Write-Host "Size: $((Get-Item $VSIXPath).Length / 1KB -as [int]) KB"
Write-Host ""

# --- Step 1: Verify Zoo Code installed ---
Write-Host "[1/5] Checking Zoo Code extension..."
$zooExt = code --list-extensions 2>$null | Where-Object { $_ -match "zoocodeorganization\.zoo-code" }
if (-not $zooExt) {
    Write-Error "Zoo Code extension not found. Install it first."
    exit 1
}
Write-Host "  OK: $zooExt found"

# --- Step 2: Check if Zoo Scheduler already installed ---
Write-Host "[2/5] Checking for existing Zoo Scheduler..."
$zooScheduler = code --list-extensions 2>$null | Where-Object { $_ -match "zoo-scheduler" }
if ($zooScheduler) {
    Write-Host "  Zoo Scheduler already installed: $zooScheduler"
    if (-not $Force) {
        $confirm = Read-Host "Reinstall? (y/N)"
        if ($confirm -ne "y" -and $confirm -ne "Y") {
            Write-Host "Aborted."
            exit 0
        }
    }
}

# --- Step 3: Uninstall original Roo Scheduler ---
Write-Host "[3/5] Uninstalling original Roo Scheduler..."
$rooScheduler = code --list-extensions 2>$null | Where-Object { $_ -match "kylehoskins\.roo-scheduler" }
if ($rooScheduler) {
    Write-Host "  Found: $rooScheduler"
    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would run: code --uninstall-extension $rooScheduler"
    } else {
        code --uninstall-extension $rooScheduler 2>&1 | ForEach-Object { Write-Host "  $_" }
        Write-Host "  Roo Scheduler uninstalled."
    }
} else {
    Write-Host "  Roo Scheduler not found (already uninstalled or never installed)."
}

# --- Step 4: Install Zoo Scheduler VSIX ---
Write-Host "[4/5] Installing Zoo Scheduler VSIX..."
if ($DryRun) {
    Write-Host "[DRY-RUN] Would run: code --install-extension `"$VSIXPath`""
} else {
    code --install-extension $VSIXPath 2>&1 | ForEach-Object { Write-Host "  $_" }
    Write-Host "  Zoo Scheduler VSIX installed."
}

# --- Step 5: Verify 3 replacements ---
Write-Host "[5/5] Verifying replacements in installed extension..."
$zooExtPath = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "jsboige.zoo-scheduler-*" 2>$null | Select-Object -First 1
if (-not $zooExtPath) {
    Write-Error "Zoo Scheduler extension directory not found after install."
    exit 1
}

$extJs = Join-Path $zooExtPath.FullName "dist\extension.js"
if (-not (Test-Path $extJs)) {
    Write-Error "dist/extension.js not found in $zooExtPath"
    exit 1
}

$content = [System.IO.File]::ReadAllText($extJs)

$replacements = @(
    @{ Name = "ext ID"; Pattern = "zoocodeorganization\.zoo-code"; OldPattern = "rooveterinaryinc\.roo-cline" },
    @{ Name = "ActivityBar"; Pattern = "zoo-code-ActivityBar"; OldPattern = "roo-cline-ActivityBar" },
    @{ Name = "config section"; Pattern = 'getConfiguration\("zoo-code"\)'; OldPattern = 'getConfiguration\("roo-cline"\)' }
)

$allOK = $true
foreach ($r in $replacements) {
    $newCount = ([regex]::Matches($content, $r.Pattern)).Count
    $oldCount = ([regex]::Matches($content, $r.OldPattern)).Count
    if ($oldCount -gt 0) {
        Write-Host "  FAIL: $r.Name — $oldCount old references remain" -ForegroundColor Red
        $allOK = $false
    } else {
        Write-Host "  OK: $r.Name — $newCount replacements verified" -ForegroundColor Green
    }
}

if (-not $allOK) {
    Write-Error "Patch verification failed. Extension may be corrupted."
    exit 1
}

# --- Step 6: Migrate schedules.json ---
Write-Host ""
Write-Host "=== Migrating schedules.json ==="
$rooStateDir = "$env:APPDATA\Code\User\globalStorage\kylehoskins.roo-scheduler"
$zooStateDir = "$env:APPDATA\Code\User\globalStorage\zoocodeorganization.zoo-code"
$schedulesFile = Join-Path $rooStateDir "state\schedules.json"

if (Test-Path $schedulesFile) {
    Write-Host "  Found schedules.json in Roo state."
    $schedulesContent = Get-Content $schedulesFile -Raw
    Write-Host "  Content length: $($schedulesContent.Length) chars"

    if (-not (Test-Path $zooStateDir)) {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $zooStateDir -Force | Out-Null
        }
        Write-Host "  Created Zoo state directory."
    }

    $zooSchedulesFile = Join-Path $zooStateDir "state\schedules.json"
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would copy schedules.json to: $zooSchedulesFile"
    } else {
        $schedulesContent | Set-Content $zooSchedulesFile -Encoding UTF8
        Write-Host "  schedules.json migrated to Zoo state."
    }
} else {
    Write-Host "  No schedules.json found in Roo state (no schedules to migrate)."
}

# --- Summary ---
Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Extension: $zooExtPath"
Write-Host "VSIX: $VSIXPath"
Write-Host ""
Write-Host "To verify: code --list-extensions | Select-String zoo-scheduler"
Write-Host "Rollback: .\rollback-to-roo-scheduler.ps1"
