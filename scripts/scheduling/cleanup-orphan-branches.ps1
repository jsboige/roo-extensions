<#
.SYNOPSIS
    Cleanup orphan local branches whose associated PR is merged/closed or has no PR.

.DESCRIPTION
    No-LLM branch cleanup script. Identifies local branches (wt/*, worker/*, fix/*)
    that are no longer needed because:
    - Their associated PR is MERGED or CLOSED
    - They have no PR and no unmerged commits (stale worker branches)

    Called from start-claude-worker.ps1 finally block to clean up after each run,
    replacing the idle-worktree-cleanup and idle-stale-branches LLM-powered tasks.

.PARAMETER RepoRoot
    Repository root path. Defaults to git rev-parse --show-toplevel.

.PARAMETER BranchPrefixes
    Branch prefixes to check. Default: 'wt/', 'worker/'

.PARAMETER DryRun
    Report only, don't delete.

.PARAMETER MinAgeHours
    Minimum age in hours for a branch to be considered orphan. Default: 1.
    Prevents deleting branches just created by a concurrent worker.

.EXAMPLE
    ./cleanup-orphan-branches.ps1
    # Report orphan branches without deleting

.EXAMPLE
    ./cleanup-orphan-branches.ps1 -DryRun:$false
    # Delete orphan branches

.NOTES
    Issue #1417 redesign — Replaces LLM-powered idle-worktree-cleanup.
    Branch cleanup = script responsibility, not idle task.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string[]]$BranchPrefixes = @('wt/', 'worker/'),
    [switch]$DryRun = $true,
    [int]$MinAgeHours = 1
)

$ErrorActionPreference = 'Continue'

# Resolve repo root
if (-not $RepoRoot) {
    $gitRoot = git rev-parse --show-toplevel 2>$null
    $RepoRoot = if ($gitRoot) { $gitRoot.Trim() } else { '' }
    if (-not $RepoRoot) {
        Write-Host "Cannot determine repo root. Run from within a git repository."
        exit 1
    }
}

# Ensure we're on main before deleting branches
$CurrentBranch = git -C $RepoRoot branch --show-current 2>$null
if ($CurrentBranch -ne 'main') {
    Write-Host "Not on main (on '$CurrentBranch'). Skipping branch cleanup for safety."
    exit 0
}

Write-Host "=== Orphan Branch Cleanup ==="
Write-Host "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'EXECUTE' })"
Write-Host "Prefixes: $($BranchPrefixes -join ', ')"

# Get all PRs (open + recently closed/merged) to check branch associations
# Fetch up to 200 PRs — covers recent activity
$AllPRs = @()
try {
    $PrJson = & gh pr list --state all --json headRefName,state,number --limit 200 --repo jsboige/roo-extensions 2>$null
    if ($LASTEXITCODE -eq 0 -and $PrJson) {
        $AllPRs = $PrJson | ConvertFrom-Json
    }
} catch {
    Write-Host "WARN: Could not fetch PR list from GitHub: $_"
}

# Build a lookup: branchName -> PR info
$PrLookup = @{}
foreach ($pr in $AllPRs) {
    $PrLookup[$pr.headRefName] = $pr
}

# Collect candidate branches
$Candidates = @()
foreach ($prefix in $BranchPrefixes) {
    $branches = git -C $RepoRoot branch --list "$prefix*" 2>$null
    if ($branches) {
        foreach ($line in $branches) {
            if (-not $line) { continue }
            $branchName = $line.TrimStart().TrimStart('*').Trim()
            if ($branchName -and $branchName -ne $CurrentBranch) {
                $Candidates += $branchName
            }
        }
    }
}

if ($Candidates.Count -eq 0) {
    Write-Host "No candidate branches found. Nothing to do."
    exit 0
}

Write-Host "Candidates: $($Candidates.Count) branches"

$Deleted = 0
$Skipped = 0
$TooYoung = 0

foreach ($branch in $Candidates) {
    # Check PR association
    $Pr = $PrLookup[$branch]

    if ($Pr) {
        # Has a PR — check state
        if ($Pr.state -eq 'OPEN') {
            Write-Host "  SKIP (PR #$($Pr.number) OPEN): $branch"
            $Skipped++
            continue
        }
        # MERGED or CLOSED — safe to delete
        $Reason = "PR #$($Pr.number) $($Pr.state)"
    } else {
        # No PR — check if branch has unmerged commits
        $Unmerged = git -C $RepoRoot log "main..$branch" --oneline 2>$null
        if ($Unmerged) {
            # Has unmerged commits — check age
            $LastCommit = git -C $RepoRoot log "$branch" -1 --format='%ci' 2>$null
            if ($LastCommit) {
                $CommitAge = (Get-Date) - (Get-Date $LastCommit)
                if ($CommitAge.TotalHours -lt $MinAgeHours) {
                    Write-Host "  SKIP (too young, $([math]::Round($CommitAge.TotalHours, 1))h): $branch"
                    $TooYoung++
                    continue
                }
            }
            # Old branch with unmerged commits but no PR — skip (might be WIP)
            Write-Host "  SKIP (unmerged commits, no PR): $branch"
            $Skipped++
            continue
        }
        # No unmerged commits, no PR — stale worker branch
        $Reason = "no PR, no unmerged commits"
    }

    # Delete
    if ($DryRun) {
        Write-Host "  WOULD DELETE ($Reason): $branch"
    } else {
        $result = git -C $RepoRoot branch -d $branch 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  DELETED ($Reason): $branch"
            $Deleted++
        } else {
            Write-Host "  FAILED: $branch — $result"
            $Skipped++
        }
    }
}

# Prune remote-tracking references
if (-not $DryRun) {
    git -C $RepoRoot remote prune origin 2>$null | ForEach-Object { Write-Host "  prune: $_" }
}

$Total = $Deleted + $Skipped + $TooYoung
Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Checked: $Total | Deleted: $Deleted | Skipped: $Skipped | Too young: $TooYoung"
if ($DryRun) {
    Write-Host "DRY-RUN — re-run with -DryRun:`$false to execute"
}
Write-Host "=== Done ==="
