#Requires -Version 5.1
<#
.SYNOPSIS
    Cleanup orphan worktrees from .claude/worktrees/

.DESCRIPTION
    Removes worktrees that are:
    1. Registered but no longer needed (prune)
    2. Physical directories without git registration (orphans)

.PARAMETER Force
    Force removal without confirmation

.PARAMETER DryRun
    Show what would be removed without actually removing

.EXAMPLE
    .\worktree-cleanup.ps1 -DryRun
    Show orphan worktrees without removing

.EXAMPLE
    .\worktree-cleanup.ps1 -Force
    Remove all orphan worktrees without prompting

.NOTES
    Issue: #856
    Created: 2026-03-25
#>

param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$worktreeDir = ".claude/worktrees"
$removedCount = 0
$warningCount = 0

Write-Host "=== Worktree Cleanup Protocol ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Prune registered but stale worktrees
Write-Host "[1/3] Pruning stale worktree registrations..." -ForegroundColor Yellow
$pruneOutput = git worktree prune -v 2>&1
if ($pruneOutput) {
    Write-Host $pruneOutput
}

# Step 2: Check worktree directory
if (-not (Test-Path $worktreeDir)) {
    Write-Host "[2/3] Worktree directory does not exist: $worktreeDir" -ForegroundColor Green
    Write-Host "[3/3] Nothing to clean." -ForegroundColor Green
    exit 0
}

# Step 3: Get current state
Write-Host "[2/3] Analyzing worktree state..." -ForegroundColor Yellow

# Registered worktrees (skip main repo)
$registeredRaw = git worktree list 2>$null
$registeredPaths = @()
foreach ($line in $registeredRaw) {
    $path = ($line -split '\s+')[0]
    # Skip main repo (doesn't contain worktrees in path)
    if ($path -notmatch '\.git\\modules' -and $path -match 'worktrees') {
        $registeredPaths += $path
    }
}

# Physical directories
$physicalDirs = Get-ChildItem $worktreeDir -Directory -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName }

# Find orphans
$orphans = @()
foreach ($dir in $physicalDirs) {
    $isRegistered = $false
    foreach ($reg in $registeredPaths) {
        if ($dir -eq $reg -or $dir.StartsWith($reg)) {
            $isRegistered = $true
            break
        }
    }
    if (-not $isRegistered) {
        $orphans += $dir
    }
}

# Report
Write-Host ""
Write-Host "State:" -ForegroundColor Cyan
Write-Host "  Registered worktrees: $($registeredPaths.Count)"
Write-Host "  Physical directories: $($physicalDirs.Count)"
Write-Host "  Orphans found:        $($orphans.Count)"
Write-Host ""

if ($orphans.Count -eq 0) {
    Write-Host "[3/3] No orphan worktrees found. Clean!" -ForegroundColor Green
    exit 0
}

# Step 4: Remove orphans
Write-Host "[3/3] Processing orphan worktrees..." -ForegroundColor Yellow

foreach ($orphan in $orphans) {
    $dirName = Split-Path $orphan -Leaf

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would remove: $dirName" -ForegroundColor Gray
        $warningCount++
        continue
    }

    # Try graceful removal first
    $removeResult = git worktree remove $orphan 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] Removed (graceful): $dirName" -ForegroundColor Green
        $removedCount++
        continue
    }

    # Force removal
    if ($Force -or $PSCmdlet.ShouldContinue("Force remove orphan: $dirName?", "Worktree Cleanup")) {
        try {
            Remove-Item -Path $orphan -Recurse -Force -ErrorAction Stop
            Write-Host "  [OK] Removed (forced): $dirName" -ForegroundColor Green
            $removedCount++
        } catch {
            Write-Host "  [FAIL] Could not remove: $dirName" -ForegroundColor Red
            Write-Host "         Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "         Try closing VS Code and retrying." -ForegroundColor Yellow
            $warningCount++
        }
    }
}

# Summary
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "  Would remove: $warningCount worktrees (dry-run)" -ForegroundColor Yellow
} else {
    Write-Host "  Removed: $removedCount worktrees" -ForegroundColor Green
    if ($warningCount -gt 0) {
        Write-Host "  Warnings: $warningCount" -ForegroundColor Yellow
    }
}

# Exit code
if ($warningCount -gt 0) { exit 1 }
exit 0
