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
    2. For each, checks whether the locking PID is alive (`Get-Process` under
       pwsh — works on Windows and Unix)
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
    Actually unlock + remove + prune orphan entries. Without this flag, only
    reports.

.PARAMETER AllowCrossRepo
    Incident #3345 class: the admin entry lives in this repo's
    `.git/worktrees/` registry but the physical tree sits OUTSIDE the repo
    root (e.g. under a path-prefix sibling like `D:/Dev/CoursIA` while the
    registry belongs to `D:/Dev/CoursIA-2`). Without this switch such orphans
    are detected and reported but always SKIPped by -Execute. With it, they
    are cleaned too — only if their path sits under a `.claude/worktrees/`
    directory (never an arbitrary outside path).

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

.EXAMPLE
    # Cross-repo orphans (registry here, physical tree under a sibling repo)
    ./cleanup-agent-orphan-worktrees.ps1 -Execute -AllowCrossRepo

.NOTES
    Issue #3345 — Agent harness bug (upstream). Defensive cleanup only.
    Related: #2772 (submodule deletion guard), #2123 (nested worktrees).
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$NamePattern = 'agent-*',
    [switch]$Execute,
    [switch]$AllowCrossRepo,
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

# There is no `pid:` PowerShell provider — Test-Path cannot probe a PID
# (review finding on #3349: `Test-Path "pid:<n>"` returns $false for every
# PID, so the alive-branch was dead code). Get-Process works cross-platform
# under pwsh.
function Test-PidAlive {
    param([string]$PidString)
    $procId = 0
    if (-not [int]::TryParse($PidString, [ref]$procId)) { return $false }
    return [bool](Get-Process -Id $procId -ErrorAction SilentlyContinue)
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
$crossRepoSkipped = 0
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
        if ($lockPid -and (Test-PidAlive $lockPid)) {
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
        $inRoot = Test-PathUnder -Path $wtPath -Root $RepoRoot

        # Cross-repo target (incident #3345 class): the admin entry belongs to
        # this repo's registry but the physical tree lives outside the repo
        # root. Registry operations below write only inside $RepoRoot/.git,
        # but `worktree remove` deletes the physical tree — cross-repo removal
        # therefore needs explicit consent AND must target a worktree under a
        # `.claude/worktrees/` directory, never an arbitrary outside path.
        if (-not $inRoot) {
            if (-not $AllowCrossRepo) {
                Write-Log "  SKIP: path outside repo root (defense) — re-run with -AllowCrossRepo to clean registry-owned cross-repo orphans"
                $crossRepoSkipped++
                continue
            }
            $normalizedWt = ($wtPath -replace '\\', '/')
            if ($normalizedWt -notmatch '/\.claude/worktrees/[^/]+/?$') {
                Write-Log "  SKIP: cross-repo target is not under a .claude/worktrees/ directory (defense)"
                continue
            }
            Write-Log "  NOTE: cross-repo orphan (-AllowCrossRepo) — physical tree is outside the repo root"
        }

        Write-Log "  -> git worktree unlock '$wtPath'"
        $unlockOut = git -C $RepoRoot worktree unlock $wtPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  FAILED: $unlockOut"
            continue
        }

        # Remove the physical tree + the admin entry. Deliberately NO --force:
        # git refuses to remove a worktree holding modified or untracked
        # files, so a dirty orphan (possible uncommitted work of a crashed
        # agent) is retained for manual review instead of destroyed.
        Write-Log "  -> git worktree remove '$wtPath'"
        $removeOut = git -C $RepoRoot worktree remove $wtPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  -> git worktree prune"
            $pruneOut = git -C $RepoRoot worktree prune 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "  prune FAILED: $pruneOut"
                continue
            }
            Write-Log "  OK: unlocked; tree RETAINED (not clean or not removable: $removeOut) — manual review"
            continue
        }

        Write-Log "  -> git worktree prune"
        $pruneOut = git -C $RepoRoot worktree prune 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "  prune FAILED: $pruneOut"
            continue
        }
        Write-Log "  OK: unlocked + removed + pruned"
    }
}

Write-Log ""
Write-Log "=== Summary ==="
Write-Log "Total matched: $($matched.Count)"
Write-Log "Detected orphans: $orphanCount"
if ($crossRepoSkipped -gt 0) {
    Write-Log "Cross-repo orphans skipped (defense): $crossRepoSkipped — re-run with -AllowCrossRepo to clean them"
}
if (-not $Execute) {
    Write-Log ""
    Write-Log "Re-run with -Execute to unlock + remove + prune orphans."
}

exit 0
