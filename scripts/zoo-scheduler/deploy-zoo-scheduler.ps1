<#
.SYNOPSIS
    Deploys Zoo Scheduler VSIX, replacing the original Roo Scheduler.
.DESCRIPTION
    Builds (if needed) and installs the forked Zoo Scheduler VSIX,
    uninstalls the original Roo Scheduler, and migrates schedules.json
    from .roo/ to .zoo/ for the current workspace.

    Issue: #2378 — Deploy Zoo Scheduler VSIX fleet-wide.
.PARAMETER VsixPath
    Path to the zoo-scheduler VSIX file. If omitted, builds it via patch-scheduler.ps1.
.PARAMETER WorkspacePath
    Path to the workspace root (for schedules.json migration).
    Default: git repo root or current directory.
.PARAMETER SkipBuild
    Skip building the VSIX (use existing file).
.PARAMETER WhatIf
    Dry run — show what would be done without executing.
.EXAMPLE
    .\deploy-zoo-scheduler.ps1
    .\deploy-zoo-scheduler.ps1 -WhatIf
    .\deploy-zoo-scheduler.ps1 -VsixPath D:\packages\zoo-scheduler-0.0.11-zoo.1.vsix -SkipBuild
#>
param(
    [string]$VsixPath = "",
    [string]$WorkspacePath = "",
    [switch]$SkipBuild,
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$ZooExtId = "zoocodeorganization.zoo-code"
$RooSchedulerId = "kylehoskins.roo-scheduler"
$ZooSchedulerId = "jsboige.zoo-scheduler"
$VsixName = "zoo-scheduler-0.0.11-zoo.1.vsix"

function Write-Step([string]$msg) {
    Write-Host ""
    Write-Host "--- $msg ---" -ForegroundColor Cyan
}

function Test-VsixExists {
    if ($VsixPath -and (Test-Path $VsixPath)) {
        return $true
    }
    # Check outputs/ in repo root
    $repoRoot = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if ($repoRoot) {
        $candidate = Join-Path (Join-Path $repoRoot "outputs") $VsixName
        if (Test-Path $candidate) {
            $script:VsixPath = $candidate
            return $true
        }
    }
    return $false
}

# --- Step 1: Verify Zoo Code installed ---
Write-Step "Step 1: Verify Zoo Code extension"

$installed = code --list-extensions 2>$null | Where-Object { $_ -eq $ZooExtId }
if (-not $installed) {
    Write-Error "Zoo Code ($ZooExtId) is not installed. Install it first: code --install-extension $ZooExtId"
    exit 1
}
Write-Host "[OK] Zoo Code extension installed: $ZooExtId"

# --- Step 2: Build or locate VSIX ---
Write-Step "Step 2: Build/locate Zoo Scheduler VSIX"

if (-not (Test-VsixExists)) {
    if ($SkipBuild) {
        Write-Error "VSIX not found and -SkipBuild specified. Provide -VsixPath or remove -SkipBuild."
        exit 1
    }
    Write-Host "Building VSIX via patch-scheduler.ps1..."
    $patchScript = Join-Path $PSScriptRoot "patch-scheduler.ps1"
    if (-not (Test-Path $patchScript)) {
        Write-Error "patch-scheduler.ps1 not found at $patchScript"
        exit 1
    }
    & $patchScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "VSIX build failed"
        exit 1
    }
    if (-not (Test-VsixExists)) {
        Write-Error "VSIX build succeeded but file not found"
        exit 1
    }
}
Write-Host "[OK] VSIX ready: $VsixPath ($('{0:N1}' -f ((Get-Item $VsixPath).Length / 1MB)) MB)"

# --- Step 3: Uninstall original Roo Scheduler ---
Write-Step "Step 3: Uninstall original Roo Scheduler"

$rooScheduler = code --list-extensions 2>$null | Where-Object { $_ -eq $RooSchedulerId }
if ($rooScheduler) {
    Write-Host "Uninstalling $RooSchedulerId..."
    if ($WhatIf) {
        Write-Host "[WHATIF] code --uninstall-extension $RooSchedulerId"
    } else {
        code --uninstall-extension $RooSchedulerId 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "[OK] Uninstalled $RooSchedulerId"
    }
} else {
    Write-Host "[SKIP] $RooSchedulerId not installed"
}

# --- Step 4: Install Zoo Scheduler VSIX ---
Write-Step "Step 4: Install Zoo Scheduler VSIX"

$zooScheduler = code --list-extensions 2>$null | Where-Object { $_ -match "zoo-scheduler" }
if ($zooScheduler) {
    Write-Host "[SKIP] Zoo Scheduler already installed: $zooScheduler"
} else {
    Write-Host "Installing $VsixPath..."
    if ($WhatIf) {
        Write-Host "[WHATIF] code --install-extension `"$VsixPath`""
    } else {
        code --install-extension $VsixPath 2>&1 | ForEach-Object { Write-Host $_ }
    }
}

# --- Step 5: Verify installation ---
Write-Step "Step 5: Verify installation"

if (-not $WhatIf) {
    $allExts = code --list-extensions 2>$null
    $found = $allExts | Where-Object { $_ -match "zoo-scheduler" }
    if (-not $found) {
        Write-Error "Zoo Scheduler not found after install"
        exit 1
    }
    Write-Host "[OK] Zoo Scheduler installed: $found"

    # Verify patches in installed extension
    $extDir = Get-ChildItem "$env:USERPROFILE\.vscode\extensions" -Directory -Filter "jsboige.zoo-scheduler-*" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if ($extDir) {
        $extJs = Join-Path $extDir.FullName "dist\extension.js"
        if (Test-Path $extJs) {
            $content = [System.IO.File]::ReadAllText($extJs)
            $oldRefs = ([regex]::Matches($content, "rooveterinaryinc\.roo-cline")).Count
            $oldActivity = ([regex]::Matches($content, "roo-cline-ActivityBar")).Count
            $newRefs = ([regex]::Matches($content, "zoocodeorganization\.zoo-code")).Count
            $newActivity = ([regex]::Matches($content, "zoo-code-ActivityBar")).Count

            if ($oldRefs -gt 0 -or $oldActivity -gt 0) {
                Write-Host "[WARN] Old Roo references still present: $oldRefs ext, $oldActivity activity" -ForegroundColor Yellow
            } else {
                Write-Host "[OK] Patch verification: $newRefs ext refs, $newActivity activity refs (all Zoo)" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "[WHATIF] Would verify installation"
}

# --- Step 6: Migrate schedules.json ---
Write-Step "Step 6: Migrate schedules.json"

if (-not $WorkspacePath) {
    $WorkspacePath = git -C $PSScriptRoot rev-parse --show-toplevel 2>$null
    if (-not $WorkspacePath) {
        $WorkspacePath = Get-Location
    }
}

$rooSchedules = Join-Path (Join-Path $WorkspacePath ".roo") "schedules.json"
$zooSchedules = Join-Path (Join-Path $WorkspacePath ".zoo") "schedules.json"

if (Test-Path $rooSchedules) {
    if (Test-Path $zooSchedules) {
        Write-Host "[SKIP] .zoo/schedules.json already exists (not overwriting)"
    } else {
        $zooDir = Join-Path $WorkspacePath ".zoo"
        if (-not (Test-Path $zooDir)) {
            if ($WhatIf) {
                Write-Host "[WHATIF] New-Item -ItemType Directory -Path $zooDir"
            } else {
                New-Item -ItemType Directory -Path $zooDir -Force | Out-Null
            }
        }
        if ($WhatIf) {
            Write-Host "[WHATIF] Copy $rooSchedules -> $zooSchedules"
        } else {
            Copy-Item $rooSchedules $zooSchedules -Force
            Write-Host "[OK] Migrated schedules.json: .roo/ -> .zoo/" -ForegroundColor Green
        }
    }
} else {
    Write-Host "[SKIP] No .roo/schedules.json found (nothing to migrate)"
}

# --- Summary ---
Write-Step "Summary"
if ($WhatIf) {
    Write-Host "[WHATIF MODE — no changes made]" -ForegroundColor Yellow
}
Write-Host @"
Zoo Code:        $ZooExtId (installed)
Zoo Scheduler:   $(if ($WhatIf) { 'would install' } else { $VsixPath })
Roo Scheduler:   $(if ($rooScheduler) { 'uninstalled' } else { 'not present' })
Schedules:       $(if (Test-Path $rooSchedules) { 'migrated .roo -> .zoo' } else { 'none found' })

Next: Restart VS Code to activate the new scheduler.
"@
