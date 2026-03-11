#Requires -Version 5.1

<#
.SYNOPSIS
    Validate roo-state-manager build + tests before pushing

.DESCRIPTION
    GUARDRAIL: This script MUST be run before pushing changes to the
    roo-state-manager submodule. It ensures:
    1. TypeScript builds without errors
    2. CI-compatible tests pass (vitest.config.ci.ts)

    If this script fails, DO NOT PUSH.

    This prevents CI breakage that has occurred multiple times
    (issues #626, #636, jest.setup.js mock removal incident).

.PARAMETER Quick
    Run only the build check, skip tests (for documentation-only changes)

.EXAMPLE
    .\validate-before-push.ps1
    Full validation (build + CI tests)

.EXAMPLE
    .\validate-before-push.ps1 -Quick
    Quick validation (build only)
#>

param(
    [switch]$Quick
)

$ErrorActionPreference = "Stop"

$repoRoot = (Get-Item "$PSScriptRoot\..\..").FullName
$mcpDir = Join-Path $repoRoot "mcps\internal\servers\roo-state-manager"

Write-Host "=== Pre-Push Validation ===" -ForegroundColor Cyan
Write-Host "Directory: $mcpDir"
Write-Host ""

Push-Location $mcpDir
try {
    # Step 1: Build
    Write-Host "[1/2] Building TypeScript..." -ForegroundColor Yellow
    npm run build 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: TypeScript build failed!" -ForegroundColor Red
        Write-Host "  DO NOT PUSH. Fix build errors first." -ForegroundColor Red
        exit 1
    }
    $indexJs = Join-Path $mcpDir "build\index.js"
    if (-not (Test-Path $indexJs)) {
        Write-Host "  FAIL: build/index.js not found!" -ForegroundColor Red
        exit 1
    }
    Write-Host "  PASS: Build OK" -ForegroundColor Green

    if ($Quick) {
        Write-Host "[2/2] Skipping tests (-Quick)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "=== Quick validation PASSED ===" -ForegroundColor Green
        exit 0
    }

    # Step 2: Tests (CI config)
    Write-Host "[2/2] Running CI tests (vitest.config.ci.ts)..." -ForegroundColor Yellow
    $testResult = npx vitest run --config vitest.config.ci.ts --reporter=verbose 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAIL: Tests failed!" -ForegroundColor Red
        Write-Host "  DO NOT PUSH. Fix failing tests first." -ForegroundColor Red
        Write-Host ""
        # Show summary
        $testResult | Select-String "Test Files|Tests " | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
    # Show summary
    $testResult | Select-String "Test Files|Tests " | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    Write-Host ""
    Write-Host "=== Full validation PASSED - Safe to push ===" -ForegroundColor Green
} finally {
    Pop-Location
}
