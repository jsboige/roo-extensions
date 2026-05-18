<#
.SYNOPSIS
    Purge accumulated artifacts from GDrive .shared-state/ (#2121 Phase 2)
.DESCRIPTION
    One-shot cleanup of 3 artifact categories:
    1. configs/ci-test-machine/     — Full purge (CI test residuals)
    2. configs/test-machine-custom/ — Full purge (integration test residuals)
    3. reports/PHASE3A-ANALYSE-*    — Purge older than 7 days (meta-analyst output)

    Approved by user mandate 2026-05-17 ~21:30Z.
.PARAMETER DryRun
    Show what would be deleted without actually deleting.
.PARAMETER SharedStatePath
    Override the shared-state path (default: auto-detected from GDrive sync).
.EXAMPLE
    .\purge-shared-state-artifacts.ps1 -DryRun
    .\purge-shared-state-artifacts.ps1
#>
param(
    [switch]$DryRun,
    [string]$SharedStatePath
)

$ErrorActionPreference = 'Stop'

# Auto-detect shared-state path
if (-not $SharedStatePath) {
    $gdrivePaths = @(
        'G:\Mon Drive\Synchronisation\RooSync\.shared-state',
        'D:\Mon Drive\Synchronisation\RooSync\.shared-state'
    )
    foreach ($p in $gdrivePaths) {
        if (Test-Path $p) {
            $SharedStatePath = $p
            break
        }
    }
    if (-not $SharedStatePath) {
        Write-Error "Cannot find GDrive .shared-state/ directory. Pass -SharedStatePath explicitly."
        exit 1
    }
}

if (-not (Test-Path $SharedStatePath)) {
    Write-Error "Shared-state path not found: $SharedStatePath"
    exit 1
}

$totalDeleted = 0
$totalSize = 0
$retentionDays = 7
$cutoffDate = (Get-Date).AddDays(-$retentionDays)

Write-Host "=== GDrive .shared-state/ Purge (#2121 Phase 2) ==="
Write-Host "Path: $SharedStatePath"
Write-Host "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' })"
Write-Host "Reports retention: $retentionDays days (before $($cutoffDate.ToString('yyyy-MM-dd')))"
Write-Host ""

# --- Category 1: configs/ci-test-machine/ (FULL PURGE) ---
$ciTestPath = Join-Path $SharedStatePath 'configs\ci-test-machine'
if (Test-Path $ciTestPath) {
    $items = Get-ChildItem $ciTestPath -Recurse -File -ErrorAction SilentlyContinue
    $count = ($items | Measure-Object).Count
    $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Write-Host "[1/3] configs/ci-test-machine/ — $count files, $([math]::Round($size / 1MB, 2)) MB (FULL PURGE)"

    if ($count -gt 0) {
        if ($DryRun) {
            Write-Host "       DRY-RUN: Would delete $count files"
        } else {
            Get-ChildItem $ciTestPath -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
            Get-ChildItem $ciTestPath -File -Exclude 'desktop.ini' -ErrorAction SilentlyContinue | Remove-Item -Force
            Write-Host "       DELETED $count files"
        }
        $totalDeleted += $count
        $totalSize += $size
    }
} else {
    Write-Host "[1/3] configs/ci-test-machine/ — NOT FOUND (skip)"
}

# --- Category 2: configs/test-machine-custom/ (FULL PURGE) ---
$testCustomPath = Join-Path $SharedStatePath 'configs\test-machine-custom'
if (Test-Path $testCustomPath) {
    $items = Get-ChildItem $testCustomPath -Recurse -File -ErrorAction SilentlyContinue
    $count = ($items | Measure-Object).Count
    $size = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    Write-Host "[2/3] configs/test-machine-custom/ — $count files, $([math]::Round($size / 1MB, 2)) MB (FULL PURGE)"

    if ($count -gt 0) {
        if ($DryRun) {
            Write-Host "       DRY-RUN: Would delete $count files"
        } else {
            Get-ChildItem $testCustomPath -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
            Get-ChildItem $testCustomPath -File -Exclude 'desktop.ini','latest.json' -ErrorAction SilentlyContinue | Remove-Item -Force
            Write-Host "       DELETED $count files"
        }
        $totalDeleted += $count
        $totalSize += $size
    }
} else {
    Write-Host "[2/3] configs/test-machine-custom/ — NOT FOUND (skip)"
}

# --- Category 3: reports/PHASE3A-ANALYSE-* (7-day retention) ---
$reportsPath = Join-Path $SharedStatePath 'reports'
if (Test-Path $reportsPath) {
    $oldReports = Get-ChildItem $reportsPath -Filter 'PHASE3A-ANALYSE-*.md' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoffDate }

    $count = ($oldReports | Measure-Object).Count
    $size = ($oldReports | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

    $allReports = Get-ChildItem $reportsPath -Filter 'PHASE3A-ANALYSE-*.md' -File -ErrorAction SilentlyContinue
    $totalCount = ($allReports | Measure-Object).Count
    $keepCount = $totalCount - $count

    Write-Host "[3/3] reports/PHASE3A-ANALYSE-* — $totalCount total, $count older than $retentionDays days ($keepCount kept)"

    if ($count -gt 0) {
        if ($DryRun) {
            Write-Host "       DRY-RUN: Would delete $count files, keep $keepCount"
        } else {
            $oldReports | Remove-Item -Force
            Write-Host "       DELETED $count files, kept $keepCount"
        }
        $totalDeleted += $count
        $totalSize += $size
    }
} else {
    Write-Host "[3/3] reports/ — NOT FOUND (skip)"
}

# --- Summary ---
Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Total files $(if ($DryRun) { 'would be ' } else { '' })deleted: $totalDeleted"
$sizeWord = if ($DryRun) { 'would be freed' } else { 'freed' }
Write-Host "Total size $sizeWord`: $([math]::Round($totalSize / 1MB, 2)) MB"
Write-Host "Mode: $(if ($DryRun) { 'DRY-RUN (no changes made)' } else { 'EXECUTED' })"
