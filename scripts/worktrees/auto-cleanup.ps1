# Auto-Cleanup Protocol - Worktree Garbage Collection
# Description: Cleanup automatique des worktrees orphelins et branches stales
# Integre au scheduler executor workflow
# Issue: #856, #895
# Usage: .\scripts\worktrees\auto-cleanup.ps1 [-WhatIf] [-StaleDays 30]

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Force,
    [int]$StaleDays = 30,
    [int]$MaxWorktrees = 2,
    [string]$WorktreePath = ".claude/worktrees"
)

$ErrorActionPreference = "Continue"

# Configuration
$script:RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $script:RepoRoot) {
    Write-Error "Not in a git repository"
    exit 1
}

$script:WorktreesDir = Join-Path $script:RepoRoot $WorktreePath

# Colors for output
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Get all git worktrees
function Get-GitWorktrees {
    $output = git worktree list --porcelain 2>$null
    $worktrees = @()
    $current = @{}

    foreach ($line in $output) {
        if ($line -match "^worktree (.+)$") {
            if ($current.Count -gt 0) { $worktrees += $current }
            $current = @{ Path = $matches[1] }
        }
        elseif ($line -match "^HEAD ([a-f0-9]+)$") {
            $current.Head = $matches[1]
        }
        elseif ($line -match "^branch (.+)$") {
            $current.Branch = $matches[1]
        }
    }
    if ($current.Count -gt 0) { $worktrees += $current }

    return $worktrees
}

# Get all wt/ branches with their last commit date
function Get-StaleBranches {
    param([int]$DaysOld)

    $staleDate = (Get-Date).AddDays(-$DaysOld)
    $branches = @()

    # Get all branches matching wt/ or feature/ pattern
    $allBranches = git branch -a --format="%(refname:short) %(objectname:short)" 2>$null |
                   Where-Object { $_ -match "^(wt/|feature/|remotes/origin/wt/|remotes/origin/feature/)" }

    foreach ($branchLine in $allBranches) {
        $branchName = ($branchLine -split '\s+')[0]

        # Skip remote tracking branches for local check
        if ($branchName -match "^remotes/") { continue }

        # Get last commit date
        try {
            $commitDateStr = git log -1 --format="%ci" $branchName 2>$null
            if ($commitDateStr) {
                $commitDate = [datetime]::Parse($commitDateStr.Substring(0, 19))
                $daysSince = [math]::Floor(((Get-Date) - $commitDate).TotalDays)

                if ($commitDate -lt $staleDate) {
                    $branches += @{
                        Name = $branchName
                        LastCommit = $commitDate
                        DaysSince = $daysSince
                    }
                }
            }
        }
        catch {
            # Branch might be corrupted or inaccessible
        }
    }

    return $branches
}

# Check for orphan worktree directories
function Get-OrphanWorktreeDirs {
    param([string]$WorktreesDir, [array]$ActiveWorktrees)

    $orphans = @()

    if (-not (Test-Path $WorktreesDir)) {
        return $orphans
    }

    $dirs = Get-ChildItem -Path $WorktreesDir -Directory -ErrorAction SilentlyContinue

    foreach ($dir in $dirs) {
        $isActive = $false
        foreach ($wt in $ActiveWorktrees) {
            if ($wt.Path -eq $dir.FullName) {
                $isActive = $true
                break
            }
        }

        if (-not $isActive) {
            # Check if it has .git file (worktree marker)
            $gitFile = Join-Path $dir.FullName ".git"
            $hasGit = Test-Path $gitFile

            $orphans += @{
                Path = $dir.FullName
                Name = $dir.Name
                HasGitMarker = $hasGit
            }
        }
    }

    return $orphans
}

# Remove orphan worktree directory
function Remove-OrphanWorktreeDir {
    param([string]$Path, [bool]$WhatIf)

    if ($WhatIf) {
        Write-Info "[WHATIF] Would remove: $Path"
        return
    }

    try {
        Remove-Item -Path $Path -Recurse -Force
        Write-Success "Removed orphan directory: $Path"
    }
    catch {
        Write-Err "Failed to remove $Path : $_"
    }
}

# Delete stale branch
function Remove-StaleBranch {
    param([string]$BranchName, [bool]$WhatIf)

    if ($WhatIf) {
        Write-Info "[WHATIF] Would delete branch: $BranchName"
        return
    }

    try {
        git branch -D $BranchName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Deleted branch: $BranchName"
        }
        else {
            Write-Warn "Could not delete branch $BranchName (may have unmerged changes)"
        }
    }
    catch {
        Write-Err "Failed to delete branch $BranchName : $_"
    }
}

# Run git garbage collection
function Invoke-GitGarbageCollection {
    param([bool]$WhatIf)

    if ($WhatIf) {
        Write-Info "[WHATIF] Would run 'git gc --prune=now'"
        return
    }

    try {
        Write-Info "Running git garbage collection..."
        git gc --prune=now 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git garbage collection complete"
        }
        else {
            Write-Warn "Git garbage collection returned non-zero exit code"
        }
    }
    catch {
        Write-Err "Failed to run git gc : $_"
    }
}

# Main execution
function Invoke-AutoCleanup {
    Write-Host ""
    Write-Host "=== Auto-Cleanup Report ===" -ForegroundColor White
    Write-Host "Repository: $script:RepoRoot"
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "Stale threshold: $StaleDays days"
    Write-Host "Max worktrees: $MaxWorktrees"
    Write-Host ""

    # Get active worktrees
    $activeWorktrees = Get-GitWorktrees
    Write-Info "Active worktrees: $($activeWorktrees.Count)"

    # Check for orphan directories
    $orphanDirs = Get-OrphanWorktreeDirs -WorktreesDir $script:WorktreesDir -ActiveWorktrees $activeWorktrees
    Write-Info "Orphan directories: $($orphanDirs.Count)"

    # Check for stale branches
    $staleBranches = Get-StaleBranches -DaysOld $StaleDays
    Write-Info "Stale branches (>$StaleDays days): $($staleBranches.Count)"

    # Check if we exceed max worktrees
    $exceedsMax = ($activeWorktrees.Count -gt $MaxWorktrees)
    if ($exceedsMax) {
        Write-Warn "Worktree count ($($activeWorktrees.Count)) exceeds max ($MaxWorktrees)"
    }

    Write-Host ""

    # Report orphan directories
    if ($orphanDirs.Count -gt 0) {
        Write-Host "--- Orphan Directories ---" -ForegroundColor Yellow
        foreach ($orphan in $orphanDirs) {
            Write-Host "  $($orphan.Name) - HasGit: $($orphan.HasGitMarker)"
        }
        Write-Host ""
    }

    # Report stale branches
    if ($staleBranches.Count -gt 0) {
        Write-Host "--- Stale Branches ---" -ForegroundColor Yellow
        foreach ($branch in $staleBranches | Sort-Object DaysSince -Descending) {
            Write-Host "  $($branch.Name) - Last commit: $($branch.LastCommit.ToString('yyyy-MM-dd')) ($($branch.DaysSince) days ago)"
        }
        Write-Host ""
    }

    # Determine if cleanup needed
    $needsCleanup = ($orphanDirs.Count -gt 0 -or $staleBranches.Count -gt 0 -or $exceedsMax)

    if (-not $needsCleanup) {
        Write-Success "No cleanup needed. All worktrees are valid."
        return @{ Status = "clean"; Orphans = 0; StaleBranches = 0; GarbageCollected = $false }
    }

    # Perform cleanup
    $cleanedOrphans = 0
    $cleanedBranches = 0

    if ($orphanDirs.Count -gt 0) {
        Write-Host "Cleaning orphan directories..." -ForegroundColor Cyan
        foreach ($orphan in $orphanDirs) {
            Remove-OrphanWorktreeDir -Path $orphan.Path -WhatIf $WhatIf
            if (-not $WhatIf) { $cleanedOrphans++ }
        }
    }

    if ($staleBranches.Count -gt 0) {
        Write-Host "Cleaning stale branches..." -ForegroundColor Cyan
        foreach ($branch in $staleBranches) {
            Remove-StaleBranch -BranchName $branch.Name -WhatIf $WhatIf
            if (-not $WhatIf) { $cleanedBranches++ }
        }
    }

    # Run garbage collection
    Invoke-GitGarbageCollection -WhatIf $WhatIf

    Write-Host ""
    if ($WhatIf) {
        Write-Info "Dry run complete. Run without -WhatIf to apply changes."
    }
    else {
        Write-Success "Cleanup complete: $cleanedOrphans directories, $cleanedBranches branches"
    }

    return @{
        Status = "cleaned"
        Orphans = $cleanedOrphans
        StaleBranches = $cleanedBranches
        WhatIf = $WhatIf
        GarbageCollected = -not $WhatIf
    }
}

# Execute
$result = Invoke-AutoCleanup
exit 0
