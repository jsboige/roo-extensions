#Requires -Version 5.1

<#
.SYNOPSIS
    Rebuild roo-state-manager MCP + sync alwaysAllow configuration

.DESCRIPTION
    Complete rebuild pipeline for roo-state-manager:
    1. Clean old build
    2. npm install + npm run build
    3. Verify the compiled entry exists (build-out/, legacy build/ fallback)
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

# --- Pre-op guard (#3712) : empeche la destruction silencieuse d'un chemin protege. ---
# Le rebuild detruit volontairement build/ ; le guard est appele en mode Backup pour
# preserver un snapshot pre-destruction dans %USERPROFILE%\.roo-state-manager\preop-backup\.
$guardScript = Join-Path $PSScriptRoot "deploy-preop-guard.ps1"
if (Test-Path -LiteralPath $guardScript) {
    . $guardScript
} else {
    Write-Host "WARN: deploy-preop-guard.ps1 introuvable, pre-op guard desactive." -ForegroundColor Yellow
}

Write-Host "=== Rebuild roo-state-manager ===" -ForegroundColor Cyan
Write-Host "Repo root: $repoRoot"
Write-Host "MCP dir:   $mcpDir"
Write-Host ""

# Step 1: Clean (avec garde-fou pre-op)
Write-Host "[1/4] Cleaning old build..." -ForegroundColor Yellow
# #3713: tsc emits to build-out/ (scratch); publish-build.mjs copies it into
# immutable build-<sha>/ vintages behind the build-current marker. Clean the
# scratch dir here; the legacy frozen build/ is deliberately untouched.
$buildDir = Join-Path $mcpDir "build-out"
if (Test-Path $buildDir) {
    # #3712 : backup pre-destruction (build-out est regenerable ; les
    # millésimes #3713 ne sont jamais detruits ici — la rétention publish les gère).
    if (Get-Command Invoke-DeployPreOpGuard -ErrorAction SilentlyContinue) {
        $guardResult = Invoke-DeployPreOpGuard -Operation "Remove-Item build (rebuild)" -LiteralPath $buildDir -Mode Backup -RepoRoot $repoRoot
        Write-Host "  [guard] Action=$($guardResult.Action) BackupDir=$($guardResult.BackupDir)" -ForegroundColor DarkGray
        if ($guardResult.Action -eq 'Blocked') {
            Write-Host "  ABORT: pre-op guard refuse la suppression de $buildDir" -ForegroundColor Red
            exit 3
        }
    }
    Remove-Item -Recurse -Force $buildDir
    Write-Host "  Removed $buildDir" -ForegroundColor Gray
} else {
    Write-Host "  No build directory to clean" -ForegroundColor Gray
}

# Step 2: Install + Build
Write-Host "[2/4] npm install..." -ForegroundColor Yellow
Push-Location $mcpDir
try {
    # cmd-layer stderr merge (#3731 class): PS 5.1 `2>&1` on a native + EAP=Stop
    # turns stderr warnings into a terminating NativeCommandError
    & cmd /c "npm install 2>&1" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: npm install failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  npm install OK" -ForegroundColor Green

    Write-Host "[3/4] npm run build..." -ForegroundColor Yellow
    & cmd /c "npm run build 2>&1" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: npm run build failed" -ForegroundColor Red
        exit 1
    }

    # Verify output — scratch dir first, legacy fixed path second (pre-#3713
    # submodule on a not-yet-upgraded checkout still emits build/).
    $indexJs = Join-Path $buildDir "index.js"
    if (-not (Test-Path $indexJs)) {
        $indexJs = Join-Path $mcpDir "build" "index.js"
    }
    if (Test-Path $indexJs) {
        $size = (Get-Item $indexJs).Length
        Write-Host "  Build OK - $indexJs ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "  ERROR: no index.js found after build (neither build-out/ nor legacy build/)" -ForegroundColor Red
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
        # #3639: the sync refuses (exit 2) when no active seat is determinable
        # and fails post-write verification with exit 3. Swallowing those here
        # would report "Rebuild complete" over a sync that wrote nothing.
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: alwaysAllow sync failed (exit $LASTEXITCODE)" -ForegroundColor Red
            exit $LASTEXITCODE
        }
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
Write-Host "IMPORTANT (pre-#3713 legacy path): restart VS Code to load the new build." -ForegroundColor Magenta
Write-Host "Vintage pipeline (#3713, marker present): live v5 wrappers hot-swap on publish - no restart owed." -ForegroundColor DarkGray
