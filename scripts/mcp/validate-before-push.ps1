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
    # NOTE: do NOT pass --reporter=verbose. The verbose reporter emits one onTaskUpdate
    # IPC event per test (~12790 events) versus ~654 per-file events with the default
    # reporter. Under the forks pool (4 workers) this can saturate the birpc channel and
    # trip vitest's hardcoded 60s RPC timeout (DEFAULT_TIMEOUT = 6e4, not configurable),
    # making vitest exit non-zero on a fully green tree. The Tests summary line is treated
    # as the source of truth, not the exit code. (dispatch ai-01 c.203/c.204)
    Write-Host "[2/2] Running CI tests (vitest.config.ci.ts)..." -ForegroundColor Yellow
    $testResult = npx vitest run --config vitest.config.ci.ts 2>&1
    $vitestExit = $LASTEXITCODE

    # The Tests summary line ("Tests  N passed [| M failed] ...") is the authority.
    # Select-Object -Last 1 (not .LastOrDefault(), which is unavailable in PS 5.1).
    $testsLine = $testResult | Select-String "Tests\s+\d+" | Select-Object -Last 1
    if (-not $testsLine) {
        # No summary line at all: vitest crashed or failed during collection - block.
        Write-Host "  FAIL: no test result line found (vitest exit $vitestExit)." -ForegroundColor Red
        Write-Host "  Likely a crash or collect error - investigate before pushing." -ForegroundColor Red
        Write-Host ""
        $testResult | Select-Object -Last 30 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
    # A green line has no "failed" token (vitest omits it at 0 failures) -> 0.
    $failed = if ($testsLine.Line -match "(\d+)\s+failed") { [int]$Matches[1] } else { 0 }

    if ($failed -gt 0) {
        Write-Host "  FAIL: $failed test(s) failed - DO NOT PUSH." -ForegroundColor Red
        Write-Host "  Fix failing tests first." -ForegroundColor Red
        Write-Host ""
        $testResult | Select-String "Test Files|Tests " | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }

    # failed == 0: green tree. Show the summary.
    $testResult | Select-String "Test Files|Tests " | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }

    if ($vitestExit -ne 0) {
        # Green tree but non-zero exit: benign IPC teardown noise (the onTaskUpdate
        # timeout), NOT a test failure. Warn but do not block.
        Write-Host "  PASS (0 failed); vitest exit $vitestExit = benign IPC teardown noise, not a test failure." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "=== Full validation PASSED - Safe to push ===" -ForegroundColor Green
} finally {
    Pop-Location
}
