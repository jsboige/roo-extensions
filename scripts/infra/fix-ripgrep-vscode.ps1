<#
.SYNOPSIS
    Diagnose and fix ripgrep binary for VS Code extensions (Roo Code / Zoo Code).

.DESCRIPTION
    VS Code 1.122+ renamed the ripgrep package from @vscode/ripgrep to
    @vscode/ripgrep-universal. Roo Code 3.54.0 cannot find the binary.
    Zoo Code 3.57+ includes the fix (PR #248).

    This script:
    1. Detects VS Code version and ripgrep binary locations
    2. Checks which extension is installed (Roo Code vs Zoo Code)
    3. Verifies if the fix is present in Zoo Code
    4. Optionally copies rg.exe as workaround (requires elevation for Program Files)
    5. Reports collection code status on Qdrant

.PARAMETER Fix
    Apply the workaround (copy rg.exe to the old path). Requires admin elevation.

.PARAMETER MachineId
    Machine identifier for reporting. Defaults to $env:ROOSYNC_MACHINE_ID or hostname.

.EXAMPLE
    ./fix-ripgrep-vscode.ps1
    # Diagnose only

.EXAMPLE
    ./fix-ripgrep-vscode.ps1 -Fix
    # Diagnose and apply workaround (requires elevation)

.NOTES
    Issue #2455 — codebase_search vide fleet-wide
    Zoo Code PR #248 — fix: resolve ripgrep from @vscode/ripgrep-universal
#>

[CmdletBinding()]
param(
    [switch]$Fix,
    [string]$MachineId = $(if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID } else { $env:COMPUTERNAME })
)

$ErrorActionPreference = 'Continue'

# === VS Code Detection ===
Write-Host "=== Ripgrep Diagnostic for VS Code ==="
Write-Host "Machine: $MachineId"
Write-Host ""

$vscodeRoot = "C:\Program Files\Microsoft VS Code"
if (-not (Test-Path $vscodeRoot)) {
    Write-Host "ERROR: VS Code not found at $vscodeRoot"
    exit 1
}

# Find versioned app directory
$versionDirs = Get-ChildItem $vscodeRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { Test-Path (Join-Path $_.FullName "resources\app\node_modules") } |
    Sort-Object LastWriteTime -Descending

if ($versionDirs.Count -eq 0) {
    Write-Host "ERROR: No VS Code version directory found"
    exit 1
}

$versionDir = $versionDirs[0]
$appDir = Join-Path $versionDir.FullName "resources\app"
$vscodeVersion = $versionDir.Name
Write-Host "VS Code version hash: $vscodeVersion"
Write-Host "App dir: $appDir"

# === Check ripgrep paths ===
Write-Host ""
Write-Host "--- Ripgrep Binary Paths ---"

$oldRgPath = Join-Path $appDir "node_modules\@vscode\ripgrep\bin\rg.exe"
$newRgPath = Join-Path $appDir "node_modules\@vscode\ripgrep-universal\bin\win32-x64\rg.exe"

$oldExists = Test-Path $oldRgPath
$newExists = Test-Path $newRgPath

Write-Host "  Old path (Roo Code expects): $oldExists"
Write-Host "    $oldRgPath"
Write-Host "  New path (VS Code 1.122+):   $newExists"
Write-Host "    $newRgPath"

if ($newExists) {
    $rgSize = (Get-Item $newRgPath).Length
    Write-Host "  rg.exe size: $([math]::Round($rgSize / 1MB, 2)) MB"
}

# === Extension Detection ===
Write-Host ""
Write-Host "--- Extension Detection ---"

$extBase = "$env:USERPROFILE\.vscode\extensions"
$rooExt = Get-ChildItem $extBase -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^rooveterinaryinc\.roo-cline-' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

$zooExt = Get-ChildItem $extBase -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^zoocodeorganization\.zoo-code-' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($rooExt) {
    $rooVersion = ($rooExt.Name -split '-')[-1]
    Write-Host "  Roo Code: $rooVersion (AFFECTED — no fix for ripgrep-universal)"
    Write-Host "    Path: $($rooExt.FullName)"
    $hasRooFix = $false
} else {
    Write-Host "  Roo Code: NOT INSTALLED"
    $hasRooFix = $false
}

if ($zooExt) {
    $zooVersion = ($zooExt.Name -split '-')[-1]
    Write-Host "  Zoo Code: $zooVersion"
    Write-Host "    Path: $($zooExt.FullName)"

    # Check if fix PR #248 is present
    $bundlePath = Join-Path $zooExt.FullName "dist\extension.js"
    if (Test-Path $bundlePath) {
        $hasFix = Select-String -Path $bundlePath -Pattern 'ripgrep-universal' -Quiet
        if ($hasFix) {
            Write-Host "    Fix PR #248: PRESENT (ripgrep-universal supported)"
        } else {
            Write-Host "    Fix PR #248: MISSING (needs update)"
        }
    } else {
        Write-Host "    Fix PR #248: UNKNOWN (extension.js not found)"
    }
} else {
    Write-Host "  Zoo Code: NOT INSTALLED"
    Write-Host "    RECOMMENDATION: Install Zoo Code (Roo Code successor with fix)"
}

# === Diagnosis ===
Write-Host ""
Write-Host "--- Diagnosis ---"

if ($zooExt -and -not $rooExt) {
    Write-Host "  STATUS: MIGRATED to Zoo Code (fix should be active)"
    Write-Host "  ACTION: Codebase indexing should work — trigger via VS Code or reload window"
} elseif ($rooExt -and -not $zooExt) {
    Write-Host "  STATUS: AFFECTED (Roo Code without fix)"
    Write-Host "  ACTION: Either (a) migrate to Zoo Code, or (b) apply workaround"
} elseif ($rooExt -and $zooExt) {
    Write-Host "  STATUS: BOTH installed — Roo Code still affected, Zoo Code OK"
    Write-Host "  ACTION: Uninstall Roo Code, use Zoo Code"
}

if (-not $oldExists -and $newExists -and $rooExt) {
    Write-Host ""
    Write-Host "  ROOT CAUSE CONFIRMED: rg.exe only at new path, Roo Code can't find it"
}

# === Workaround (requires elevation) ===
if ($Fix -and -not $oldExists -and $newExists) {
    Write-Host ""
    Write-Host "--- Applying Workaround ---"

    $targetDir = Split-Path $oldRgPath
    try {
        New-Item -ItemType Directory -Path $targetDir -Force -ErrorAction Stop | Out-Null
        Copy-Item $newRgPath $oldRgPath -Force -ErrorAction Stop
        Write-Host "  SUCCESS: rg.exe copied to old path"
        Write-Host "  $oldRgPath"
        Write-Host "  NOTE: This fix is FRAGILE — breaks on VS Code update (version hash changes)"
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)"
        Write-Host "  Requires admin elevation. Re-run from elevated PowerShell."
        exit 1
    }
}

# === Summary ===
Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Machine: $MachineId"
Write-Host "VS Code hash: $vscodeVersion"
Write-Host "rg.exe (old): $(if ($oldExists) { 'FOUND' } else { 'MISSING' })"
Write-Host "rg.exe (new): $(if ($newExists) { 'FOUND' } else { 'MISSING' })"
Write-Host "Roo Code: $(if ($rooExt) { $rooVersion } else { 'NOT INSTALLED' })"
Write-Host "Zoo Code: $(if ($zooExt) { $zooVersion } else { 'NOT INSTALLED' })"
if ($Fix) {
    Write-Host "Workaround: $(if ($oldExists) { 'APPLIED' } else { 'FAILED' })"
}
Write-Host "=== Done ==="
