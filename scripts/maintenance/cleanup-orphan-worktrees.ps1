<#
.SYNOPSIS
    Cleanup orphan worktree directories from .claude/worktrees/

.DESCRIPTION
    Identifies and removes filesystem directories under .claude/worktrees/ that are
    no longer tracked as active git worktrees. Supports dry-run (default), execute,
    and archive modes.

.PARAMETER WorktreesPath
    Path to the worktrees directory. Defaults to .claude/worktrees/ relative to repo root.

.PARAMETER DaysThreshold
    Minimum age in days for a directory to be considered orphan. Default: 7.

.PARAMETER Execute
    Actually delete/archive orphan directories. Without this flag, only reports.

.PARAMETER Archive
    Archive orphan directories as .tar.gz instead of deleting them.

.PARAMETER ArchivePath
    Path for archive output. Defaults to .claude/worktrees/_archive/

.PARAMETER LogPath
    Path for log output. Defaults to outputs/cleanup-worktrees-{timestamp}.log

.EXAMPLE
    ./cleanup-orphan-worktrees.ps1
    # Dry-run: list all orphans without deleting

.EXAMPLE
    ./cleanup-orphan-worktrees.ps1 -Execute
    # Delete all orphans older than 7 days

.EXAMPLE
    ./cleanup-orphan-worktrees.ps1 -Archive -Execute
    # Archive orphans instead of deleting

.NOTES
    Issue #1753 — Cleanup script worktrees orphelins
#>

[CmdletBinding()]
param(
    [string]$WorktreesPath,
    [int]$DaysThreshold = 7,
    [switch]$Execute,
    [switch]$Archive,
    [string]$ArchivePath,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Resolve repo root from current working directory (not script location)
$RepoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
if (-not $RepoRoot) {
    Write-Error "Cannot determine repo root. Run from within a git repository."
    exit 1
}

if (-not $WorktreesPath) {
    $WorktreesPath = "$RepoRoot/.claude/worktrees"
}
if (-not $ArchivePath) {
    $ArchivePath = "$WorktreesPath/_archive"
}
if (-not $LogPath) {
    $OutputsDir = "$RepoRoot/outputs"
    if (-not (Test-Path $OutputsDir)) { New-Item -ItemType Directory -Path $OutputsDir -Force | Out-Null }
    $LogPath = "$OutputsDir/cleanup-worktrees-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
}

# Get active git worktrees
$activeWorktrees = git -C $RepoRoot worktree list --porcelain 2>$null |
    Where-Object { $_ -match '^worktree ' } |
    ForEach-Object { ($_ -replace '^worktree ', '').Trim() }

$activeSet = @{}
foreach ($wt in $activeWorktrees) {
    try {
        $resolved = (Resolve-Path $wt -ErrorAction Stop).Path
        $activeSet[$resolved] = $true
    } catch {
        # Path doesn't exist, skip
    }
}

# Collect orphan candidates
$cutoffDate = (Get-Date).AddDays(-$DaysThreshold)
$orphans = @()
$protected = @()

if (-not (Test-Path $WorktreesPath)) {
    Write-Host "No worktrees directory found at: $WorktreesPath"
    exit 0
}

$dirs = Get-ChildItem -Path $WorktreesPath -Directory | Where-Object {
    $_.Name -ne '_archive' -and $_.Name -ne 'wt'
}

foreach ($dir in $dirs) {
    try {
        $resolvedPath = (Resolve-Path $dir.FullName -ErrorAction Stop).Path
    } catch {
        $resolvedPath = $null
    }
    if ($resolvedPath -and $activeSet.ContainsKey($resolvedPath)) {
        $protected += $dir
        continue
    }

    $lastWrite = $dir.LastWriteTime
    $age = (Get-Date) - $lastWrite
    $isOldEnough = $lastWrite -lt $cutoffDate

    $orphans += [PSCustomObject]@{
        Name       = $dir.Name
        FullName   = $dir.FullName
        LastWrite  = $lastWrite
        AgeDays    = [math]::Floor($age.TotalDays)
        IsOldEnough = $isOldEnough
        SizeMB     = [math]::Round(
            (Get-ChildItem $dir.FullName -Recurse -File -ErrorAction SilentlyContinue |
             Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    }
}

# Logging helper
function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

Write-Log "=== Orphan Worktrees Cleanup ==="
Write-Log "Mode: $(if ($Execute) { if ($Archive) { 'ARCHIVE' } else { 'EXECUTE' } } else { 'DRY-RUN' })"
Write-Log "Days threshold: $DaysThreshold"
Write-Log "Active worktrees: $($activeWorktrees.Count)"
Write-Log "Protected dirs (skipped): $($protected.Count)"
Write-Log "Orphan candidates: $($orphans.Count)"
Write-Log ""

$oldOrphans = $orphans | Where-Object { $_.IsOldEnough }
$youngOrphans = $orphans | Where-Object { -not $_.IsOldEnough }

if ($youngOrphans.Count -gt 0) {
    Write-Log "--- Young orphans (skipped, < $DaysThreshold days) ---"
    foreach ($o in $youngOrphans) {
        Write-Log ("  {0} ({1}d old, {2} MB)" -f $o.Name, $o.AgeDays, $o.SizeMB)
    }
    Write-Log ""
}

if ($oldOrphans.Count -eq 0) {
    Write-Log "No orphans older than $DaysThreshold days found. Nothing to do."
    exit 0
}

$totalSizeMB = ($oldOrphans | Measure-Object -Property SizeMB -Sum).Sum
Write-Log "--- Old orphans ($($oldOrphans.Count) dirs, ~$([math]::Round($totalSizeMB, 1)) MB) ---"
foreach ($o in $oldOrphans | Sort-Object AgeDays -Descending) {
    Write-Log ("  {0} ({1}d old, {2} MB)" -f $o.Name, $o.AgeDays, $o.SizeMB)
}
Write-Log ""

if (-not $Execute) {
    Write-Log "DRY-RUN: No changes made. Re-run with -Execute to delete, or -Execute -Archive to archive."
    Write-Log "Log saved to: $LogPath"
    exit 0
}

# Execute mode
$processed = 0
$failed = 0

if ($Archive) {
    if (-not (Test-Path $ArchivePath)) {
        New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
    }
    $archiveFile = Join-Path $ArchivePath "orphans-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz"
    Write-Log "Archiving to: $archiveFile"

    # Create tar.gz of all orphan dirs
    $oldOrphanPaths = $oldOrphans | ForEach-Object { $_.FullName }
    $tempBase = Split-Path $WorktreesPath

    Push-Location $tempBase
    try {
        $relativePaths = $oldOrphanPaths | ForEach-Object {
            $_.Substring("$tempBase\".Length).Replace('\', '/')
        }
        $tarResult = & tar -czf $archiveFile @relativePaths 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Archive created: $archiveFile ($([math]::Round((Get-Item $archiveFile).Length / 1MB, 2)) MB)"
        } else {
            Write-Log "ERROR: tar failed: $tarResult"
            $failed += $oldOrphans.Count
            Pop-Location
            exit 1
        }
    } finally {
        Pop-Location
    }
}

foreach ($o in $oldOrphans) {
    try {
        if ($Archive) {
            Write-Log "  ARCHIVED+DELETE: $($o.Name)"
        } else {
            Write-Log "  DELETING: $($o.Name)"
        }
        Remove-Item -Path $o.FullName -Recurse -Force -ErrorAction Stop
        $processed++
    } catch {
        Write-Log "  ERROR: Failed to remove $($o.Name): $_"
        $failed++
    }
}

# Cleanup stale git worktree references
Write-Log ""
Write-Log "Pruning stale git worktree references..."
git -C $RepoRoot worktree prune 2>&1 | ForEach-Object { Write-Log "  $_" }

Write-Log ""
Write-Log "=== Summary ==="
Write-Log "Processed: $processed / $($oldOrphans.Count)"
Write-Log "Failed: $failed"
Write-Log "Freed: ~$([math]::Round($totalSizeMB, 1)) MB"
if ($Archive) {
    Write-Log "Archive: $archiveFile"
}
Write-Log "Log: $LogPath"
Write-Log "=== Done ==="
