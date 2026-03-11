#Requires -Version 5.1

<#
.SYNOPSIS
    Rebuild roo-state-manager MCP + sync alwaysAllow configuration

.DESCRIPTION
    Complete rebuild pipeline for roo-state-manager:
    1. Clean old build
    2. npm install + npm run build
    3. Verify build/index.js exists
    4. Sync alwaysAllow from reference to Roo mcp_settings.json

    This script should be run after git pull when the MCP has changed,
    or after any schema change that invalidates Roo's auto-approval cache.

.PARAMETER SkipAlwaysAllow
    Skip the alwaysAllow sync step (build only)

.PARAMETER DryRun
    Show what would be done without making changes (passed to Sync-AlwaysAllow)

.EXAMPLE
    .\rebuild-roo-state-manager.ps1
    Full rebuild + alwaysAllow sync

.EXAMPLE
    .\rebuild-roo-state-manager.ps1 -SkipAlwaysAllow
    Build only, no alwaysAllow sync
#>

param(
    [switch]$SkipAlwaysAllow,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$mcpDir = Join-Path $repoRoot "mcps\internal\servers\roo-state-manager"
$syncScript = Join-Path $repoRoot "roo-config\scripts\Sync-AlwaysAllow.ps1"

Write-Host "=== Rebuild roo-state-manager ===" -ForegroundColor Cyan
Write-Host "Repo root: $repoRoot"
Write-Host "MCP dir:   $mcpDir"
Write-Host ""

# Step 1: Clean
Write-Host "[1/4] Cleaning old build..." -ForegroundColor Yellow
$buildDir = Join-Path $mcpDir "build"
if (Test-Path $buildDir) {
    Remove-Item -Recurse -Force $buildDir
    Write-Host "  Removed $buildDir" -ForegroundColor Gray
} else {
    Write-Host "  No build directory to clean" -ForegroundColor Gray
}

# Step 2: Install + Build
Write-Host "[2/4] npm install..." -ForegroundColor Yellow
Push-Location $mcpDir
try {
    npm install 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: npm install failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  npm install OK" -ForegroundColor Green

    Write-Host "[3/4] npm run build..." -ForegroundColor Yellow
    npm run build 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: npm run build failed" -ForegroundColor Red
        exit 1
    }

    # Verify output
    $indexJs = Join-Path $buildDir "index.js"
    if (Test-Path $indexJs) {
        $size = (Get-Item $indexJs).Length
        Write-Host "  Build OK - build/index.js ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: build/index.js not found after build" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}

# Step 4: Sync alwaysAllow
if (-not $SkipAlwaysAllow) {
    Write-Host "[4/4] Syncing alwaysAllow..." -ForegroundColor Yellow
    if (Test-Path $syncScript) {
        $syncArgs = @()
        if ($DryRun) { $syncArgs += "-DryRun" }
        & $syncScript @syncArgs
        Write-Host "  alwaysAllow sync complete" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Sync-AlwaysAllow.ps1 not found at $syncScript" -ForegroundColor Yellow
        Write-Host "  Skipping alwaysAllow sync. Run manually after restart." -ForegroundColor Yellow
    }
} else {
    Write-Host "[4/4] Skipping alwaysAllow sync (--SkipAlwaysAllow)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== Rebuild complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Restart VS Code for Roo to load the new MCP tools." -ForegroundColor Magenta
