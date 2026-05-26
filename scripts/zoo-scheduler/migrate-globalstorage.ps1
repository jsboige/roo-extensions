<#
.SYNOPSIS
    Migrates globalStorage configs from Roo Code to Zoo Code.
.DESCRIPTION
    Copies settings, tasks, and other config files from the Roo Code
    globalStorage directory to the Zoo Code equivalent. Preserves existing
    Zoo files (skip if already present). Does NOT delete source files.

    Issue: #2379 — Migrate globalStorage configs Roo -> Zoo.
.PARAMETER WhatIf
    Dry run — show what would be done without executing.
.EXAMPLE
    .\migrate-globalstorage.ps1
    .\migrate-globalstorage.ps1 -WhatIf
#>
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$AppData = $env:APPDATA
if (-not $AppData) {
    Write-Error "APPDATA not set"
    exit 1
}

$RooId = "rooveterinaryinc.roo-cline"
$ZooId = "zoocodeorganization.zoo-code"
$CodePath = "$AppData\Code\User\globalStorage"

$RooGS = Join-Path $CodePath $RooId
$ZooGS = Join-Path $CodePath $ZooId

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "--- $msg ---" -ForegroundColor Cyan
}

# --- Pre-checks ---
if (-not (Test-Path $RooGS)) {
    Write-Error "Roo globalStorage not found: $RooGS"
    exit 1
}

$zooExt = code --list-extensions 2>$null | Where-Object { $_ -eq $ZooId }
if (-not $zooExt) {
    Write-Error "Zoo Code ($ZooId) not installed"
    exit 1
}

Write-Host "Source: $RooGS"
Write-Host "Target: $ZooGS"

# Ensure Zoo globalStorage exists
if (-not (Test-Path $ZooGS)) {
    if ($WhatIf) {
        Write-Host "[WHATIF] New-Item -ItemType Directory -Path $ZooGS"
    } else {
        New-Item -ItemType Directory -Path $ZooGS -Force | Out-Null
    }
}

$copiedFiles = 0
$skippedFiles = 0
$copiedTasks = 0

# --- Step 1: Migrate settings/ ---
Write-Step "Step 1: Migrate settings/"

$rooSettings = Join-Path $RooGS "settings"
$zooSettings = Join-Path $ZooGS "settings"

if (Test-Path $rooSettings) {
    if (-not (Test-Path $zooSettings)) {
        if ($WhatIf) {
            Write-Host "[WHATIF] New-Item -ItemType Directory -Path $zooSettings"
        } else {
            New-Item -ItemType Directory -Path $zooSettings -Force | Out-Null
        }
    }

    $settingsFiles = @("mcp_settings.json", "custom_modes.yaml")
    foreach ($file in $settingsFiles) {
        $src = Join-Path $rooSettings $file
        $dst = Join-Path $zooSettings $file
        if (Test-Path $src) {
            if (Test-Path $dst) {
                Write-Host "[SKIP] $file already exists in Zoo (preserving)" -ForegroundColor Yellow
                $skippedFiles++
            } else {
                if ($WhatIf) {
                    Write-Host "[WHATIF] Copy $src -> $dst"
                } else {
                    Copy-Item $src $dst -Force
                    Write-Host "[OK] Copied $file" -ForegroundColor Green
                }
                $copiedFiles++
            }
        }
    }
} else {
    Write-Host "[SKIP] No settings/ directory in Roo"
}

# --- Step 2: Migrate tasks/ ---
Write-Step "Step 2: Migrate tasks/"

$rooTasks = Join-Path $RooGS "tasks"
$zooTasks = Join-Path $ZooGS "tasks"

if (Test-Path $rooTasks) {
    if (-not (Test-Path $zooTasks)) {
        if ($WhatIf) {
            Write-Host "[WHATIF] New-Item -ItemType Directory -Path $zooTasks"
        } else {
            New-Item -ItemType Directory -Path $zooTasks -Force | Out-Null
        }
    }

    $rooDirs = Get-ChildItem $rooTasks -Directory -ErrorAction SilentlyContinue
    $zooExisting = if (Test-Path $zooTasks) {
        (Get-ChildItem $zooTasks -Directory -ErrorAction SilentlyContinue).Name
    } else { @() }

    foreach ($dir in $rooDirs) {
        if ($zooExisting -contains $dir.Name) {
            # Skip - already exists in Zoo
        } else {
            if ($WhatIf) {
                Write-Host "[WHATIF] Copy $($dir.Name)"
            } else {
                Copy-Item $dir.FullName (Join-Path $zooTasks $dir.Name) -Recurse -Force
            }
            $copiedTasks++
        }
    }
    $rooCount = ($rooDirs | Measure-Object).Count
    $zooCount = ($zooExisting | Measure-Object).Count
    Write-Host "[INFO] Roo tasks: $rooCount | Zoo tasks (existing): $zooCount | Migrated: $copiedTasks"
} else {
    Write-Host "[SKIP] No tasks/ directory in Roo"
}

# --- Step 3: Verify ---
Write-Step "Step 3: Verify migration"

if (-not $WhatIf) {
    $zooSettingsFiles = @()
    if (Test-Path $zooSettings) {
        $zooSettingsFiles = Get-ChildItem $zooSettings -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
    }
    $zooTaskCount = 0
    if (Test-Path $zooTasks) {
        $zooTaskCount = (Get-ChildItem $zooTasks -Directory -ErrorAction SilentlyContinue | Measure-Object).Count
    }

    Write-Host @"
Settings files: $($zooSettingsFiles -join ', ')
Task directories: $zooTaskCount

Verification:
"@

    foreach ($f in @("mcp_settings.json", "custom_modes.yaml")) {
        $p = Join-Path $zooSettings $f
        if (Test-Path $p) {
            Write-Host "  [OK] $f present" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $f not found" -ForegroundColor Red
        }
    }
} else {
    Write-Host "[WHATIF] Would verify migration"
}

# --- Summary ---
Write-Step "Summary"
if ($WhatIf) {
    Write-Host "[WHATIF MODE — no changes made]" -ForegroundColor Yellow
}
Write-Host @"
Files copied:    $copiedFiles
Files skipped:   $skippedFiles (already in Zoo)
Task dirs copied: $copiedTasks

Source preserved: YES (Roo globalStorage untouched)
Rollback: Delete Zoo settings/tasks dirs that were copied

Next: Restart VS Code to reload Zoo Code with migrated configs.
"@
