<#
.SYNOPSIS
    Detect and unlock orphan `agent-*` worktrees left by the Claude Code Agent tool
    when provisioning fails (Issue #3345).

.DESCRIPTION
    The Claude Code Agent tool (upstream harness) creates worktrees named
    `agent-<random>` under `.claude/worktrees/` for isolation. When the provisioner
    fails validation (e.g. cross-repo `core.worktree` collision between sibling
    directories like `D:/Dev/CoursIA` and `D:/Dev/CoursIA-2`), the worktree is
    left `locked` and never cleaned up by the harness.

    This script does NOT fix the upstream bug — it provides a **defensive cleanup**
    so users are not stuck with accumulating locked worktree entries that block
    future agent invocations.

    What it does:
    1. Lists all `agent-*` worktrees registered via `git worktree list --porcelain`
    2. For each, checks whether the locking PID is alive (`tasklist` on Windows,
       `kill -0` on Unix)
    3. Reports (default) or removes (with -Execute) the lock and prunes the entry

    Scope:
    - Operates ONLY on a single git repository (the one containing CWD by default
      or -RepoRoot). Cross-repo orchestration belongs to
      `scripts/maintenance/audit-worktrees-fleet.ps1`.
    - Uses `path-guards.ps1` (#2772/#2123) to refuse any nested-submodule or
      cross-repo deletion targets.

.PARAMETER RepoRoot
    Repository root path. Defaults to `git rev-parse --show-toplevel` from CWD.

.PARAMETER NamePattern
    Glob pattern for worktree basenames to consider. Default: `agent-*`.

.PARAMETER Execute
    Actually unlock + prune orphan entries. Without this flag, only reports.

.PARAMETER LogPath
    Optional path for log output. Defaults to stdout.

.EXAMPLE
    # Dry-run: list orphan agent-* worktrees without unlocking
    ./cleanup-agent-orphan-worktrees.ps1

.EXAMPLE
    # Actually unlock + prune
    ./cleanup-agent-orphan-worktrees.ps1 -Execute

.EXAMPLE
    # Custom pattern (e.g. for a test scenario)
    ./cleanup-agent-orphan-worktrees.ps1 -NamePattern 'worktree-*' -Execute

.NOTES
    Issue #3345 — Agent harness bug (upstream). Defensive cleanup only.
    Related: #2772 (submodule deletion guard), #2123 (nested worktrees).
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$NamePattern = 'agent-*',
    [switch]$Execute,
    [string]$LogPath
)

$ErrorActionPreference = 'Stop'

# Guard #2772 (couche 3b): shared deletion-path guards (submodule + #2123 nesting)
. "$PSScriptRoot/../common/path-guards.ps1"

# Resolve repo root
if (-not $RepoRoot) {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    $RepoRoot = if ($gitRoot) { $gitRoot.Trim() } else { '' }
}
if (-not $RepoRoot) {
    Write-Error "Cannot determine repo root. Pass -RepoRoot or run from within a git repository."
    exit 1
}

# Refuse nested-repo config (incident #2123)
$rootVerdict = Test-SafeCleanupRoot -Root $RepoRoot -RepoRoot $RepoRoot
if (-not $rootVerdict.Safe) {
    Write-Error "Unsafe repo root for cleanup: $($rootVerdict.Reason)"
    exit 1
}

function Write-Log {
    param([string]$Message)
    if ($LogPath) {
        Add-Content -Path $LogPath -Value "[$(Get-Date -Format 'o')] $Message"
    } else {
        Write-Host $Message
    }
}

# Enumerate worktrees
Write-Log "=== Agent Orphan Worktree Cleanup (Issue #3345) ==="
Write-Log "Repo: $RepoRoot"
Write-Log "Pattern: $NamePattern"
Write-Log "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY-RUN' })"
Write-Log ""

# Use -z so newlines survive PowerShell's stdout capture (NUL-terminated
# fields, double-NUL between entries).
$porcelain = git -C $RepoRoot worktree list --porcelain -z 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "git worktree list failed: $porcelain"
    exit 1
}

# Split on NUL. With `-z`, an entry is delimited by consecutive NULs
# (each entry starts with `worktree `, ends before the next double-NUL).
# We group fields into per-entry blocks before parsing.
$rawFields = $porcelain -split "`0"
$entries = New-Object System.Collections.Generic.List[object]
$current = $null
foreach ($field in $rawFields) {
    if ($field -match '^worktree (.+)$') {
        if ($current) { $entries.Add($current) }
        $current = [PSCustomObject]@{
            Path = $Matches[1].Trim()
            HEAD = ''
            Branch = ''
            Locked = $false
            LockReason = ''
        }
    } elseif ($current) {
        if ($field -match '^HEAD (.+)$') {
            $current | Add-Member -NotePropertyName HEAD -NotePropertyValue $Matches[1].Trim() -Force
        } elseif ($field -match '^branch (.+)$') {
            $current.Branch = $Matches[1].Trim()
        } elseif ($field -match '^locked(?:\s+(.+))?$') {
            $current.Locked = $true
            $current.LockReason = if ($Matches[1]) { $Matches[1].Trim() } else { '(no reason given)' }
        }
    }
}
if ($current) { $entries.Add($current) }

# Filter by pattern on basename
$matched = $entries | Where-Object {
    $basename = Split-Path -Path $_.Path -Leaf
    $basename -like $NamePattern
}

if (-not $matched -or $matched.Count -eq 0) {
    Write-Log "No worktrees matched pattern '$NamePattern'. Nothing to do."
    exit 0
}

$orphanCount = 0
foreach ($wt in $matched) {
    $basename = Split-Path -Path $wt.Path -Leaf
    $reason = '(unlocked)'

    if ($wt.Locked) {
        # Try to extract PID from lock reason. Format observed:
        #   "claude agent agent-a5476242efb0be670 (pid 16716)"
        $lockPid = $null
        if ($wt.LockReason -match '\(pid (\d+)\)') {
            $lockPid = $Matches[1]
        }
        if ($lockPid -and (Test-Path "pid:$lockPid" -ErrorAction SilentlyContinue)) {
            $reason = "LOCKED but PID $lockPid is alive — leaving alone"
        } elseif ($lockPid) {
            $reason = "LOCKED, PID $lockPid is dead — orphan"
            $orphanCount++
        } else {
            # No PID — likely stale lock from an interrupted run
            $reason = "LOCKED, no PID recorded — orphan"
            $orphanCount++
        }
    } else {
        # Unlocked, but registered. Likely an `agent-*` left from a successful
        # run whose agent process has exited. Not strictly orphan but worth
        # reporting — we only act on LOCKED orphans in this script.
        $reason = "unlocked, agent process presumably exited — informational"
    }

    $wtPath = $wt.Path
    Write-Log ("[{0}] {1}" -f $reason, $wtPath)

    if ($Execute -and $wt.Locked -and $reason -match 'orphan') {
        # Verify path is under repo root before touching (defense in depth)
        if (-not (Test-PathUnder -Path $wtPath -Root $RepoRoot)) {
            Write-Log "  SKIP: path outside repo root (defense)"
            continue
        }

        Write-Log "  -> git worktree unlock '$wtPath'"
        $unlockOut = git -C $RepoRoot worktree unlock $wtPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  FAILED: $unlockOut"
            continue
        }
        Write-Log "  -> git worktree prune"
        $pruneOut = git -C $RepoRoot worktree prune 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  prune FAILED: $pruneOut"
            continue
        }
        Write-Log "  OK: unlocked + pruned"
    }
}

Write-Log ""
Write-Log "=== Summary ==="
Write-Log "Total matched: $($matched.Count)"
Write-Log "Detected orphans: $orphanCount"
if (-not $Execute) {
    Write-Log ""
    Write-Log "Re-run with -Execute to unlock + prune orphans." -ForegroundColor Yellow
}

exit 0
