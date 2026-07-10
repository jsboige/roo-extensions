<#
.SYNOPSIS
    Cleanup orphan worktree directories from .claude/worktrees/

.DESCRIPTION
    Identifies and removes filesystem directories under .claude/worktrees/ that are
    no longer tracked as active git worktrees. Supports dry-run (default), execute,
    and archive modes.

.PARAMETER RepoRoot
    Repository root path. Defaults to git rev-parse --show-toplevel from CWD.

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
    Issue #2772 (couche 3b) — submodule deletion guard
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$WorktreesPath,
    [int]$DaysThreshold = 7,
    [switch]$Execute,
    [switch]$Archive,
    [string]$ArchivePath,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Guard #2772 (couche 3b): shared deletion-path guards (submodule + #2123 nesting)
. "$PSScriptRoot/../common/path-guards.ps1"

# Resolve repo root: explicit parameter takes priority, then git rev-parse from CWD
if (-not $RepoRoot) {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    $RepoRoot = if ($gitRoot) { $gitRoot.Trim() } else { '' }
}
if (-not $RepoRoot) {
    Write-Error "Cannot determine repo root. Pass -RepoRoot or run from within a git repository."
    exit 1
}

if (-not $WorktreesPath) {
    $WorktreesPath = "$RepoRoot/.claude/worktrees"
}

# Guard #2772/#2123: vet the cleanup container once — refuse to operate on a
# worktrees dir inside a submodule working tree, or from a repo nested in a
# superproject (nested-repo configuration of incident #2123).
$rootVerdict = Test-SafeCleanupRoot -Root $WorktreesPath -RepoRoot $RepoRoot
if (-not $rootVerdict.Safe) {
    # Write-Host + exit 1 (NOT Write-Error): under $ErrorActionPreference='Stop',
    # Write-Error terminates before reaching `exit 1` and -File returns exit code 0
    Write-Host "REFUSED (#2772): $($rootVerdict.Reason)" -ForegroundColor Red
    exit 1
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
$activeWorktrees = @(git -C $RepoRoot worktree list --porcelain 2>$null |
    Where-Object { $_ -match '^worktree ' } |
    ForEach-Object { $wt = $_ -replace '^worktree ', ''; if ($wt) { $wt.Trim() } })

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
$maxRetries = 3
$retryDelay = 2  # secondes

# Helper: process-aware delete with retry (fixes Windows file locking #2251)
function Remove-ItemWithRetry {
    param(
        [string]$Path,
        [int]$MaxRetries = $maxRetries,
        [int]$RetryDelay = $retryDelay
    )

    # Guard #2772: refuse recursive force-delete on any path resolving inside a
    # submodule working tree (would destroy gitignored .env), containing one, or
    # escaping the worktrees container. Runs BEFORE any deletion attempt.
    $verdict = Test-SafeDeletionPath -Path $Path -RepoRoot $RepoRoot -AllowedRoot $WorktreesPath
    if (-not $verdict.Safe) {
        Write-Log "  REFUSED (#2772): $($verdict.Reason)"
        return $false
    }

    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            if ($i -lt $MaxRetries) {
                # Check for holding processes
                $lockedFiles = @()
                try {
                    # Try to find what's holding the file open (Handle.exe from Sysinternals if available)
                    $handleResult = & handle.exe -a $Path 2>&1
                    if ($LASTEXITCODE -eq 0 -and $handleResult) {
                        $lockedFiles = $handleResult | Where-Object { $_ -match 'pid:' }
                    }
                } catch {
                    # handle.exe not available, skip process detection
                }
                
                $lockInfo = if ($lockedFiles -and $lockedFiles[0]) {
                    " (locked by: $($lockedFiles[0].Trim()))"
                } else {
                    " (file locked by another process)"
                }
                
                Write-Log "  RETRY ${i}/${MaxRetries}: Failed to remove $Path$lockInfo - $_"
                Start-Sleep -Seconds $RetryDelay
            } else {
                Write-Log "  ERROR: Failed to remove $Path after $MaxRetries retries: $_"
                return $false
            }
        }
    }
    return $false
}

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
    if ($Archive) {
        Write-Log "  ARCHIVED+DELETE: $($o.Name)"
    } else {
        Write-Log "  DELETING: $($o.Name)"
    }
    
    $success = Remove-ItemWithRetry -Path $o.FullName -MaxRetries $maxRetries -RetryDelay $retryDelay
    if ($success) {
        $processed++
    } else {
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
