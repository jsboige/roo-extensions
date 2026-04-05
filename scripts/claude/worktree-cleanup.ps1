# Worktree Cleanup Protocol
# Description: Automated cleanup of orphan worktrees, stale local branches, and dead remote branches
# Author: Claude Code (myia-po-2025)
# Issue: #856, #1076
# Usage: worktree-cleanup.ps1 [-WhatIf] [-Force] [-Remote] [-SkipRemote]

[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$Remote,
    [switch]$SkipRemote,
    [int]$StaleDays = 30,
    [string]$WorktreePath = ".claude/worktrees"
)

$ErrorActionPreference = "Stop"

# Configuration
$script:RepoRoot = (git rev-parse --show-toplevel 2>$null)
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

# Check if VS Code is running
function Test-VSCodeRunning {
    $processes = Get-Process -Name "Code" -ErrorAction SilentlyContinue
    return ($processes.Count -gt 0)
}

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

    # Get all branches matching wt/ pattern
    $allBranches = git branch -a --format="%(refname:short) %(objectname:short)" 2>$null |
                   Where-Object { $_ -match "^(wt/|remotes/origin/wt/)" }

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

# Remove orphan worktree directory (Windows-safe: handles long paths and locked files)
function Remove-OrphanWorktreeDir {
    param([string]$Path, [bool]$WhatIf)

    if ($WhatIf) {
        Write-Info "[WHATIF] Would remove: $Path"
        return
    }

    # Strategy 1: Standard Remove-Item
    try {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Success "Removed orphan directory: $Path"
        return
    }
    catch {
        Write-Warn "Standard remove failed for $Path : $_"
    }

    # Strategy 2: Long path prefix (Windows MAX_PATH workaround)
    $longPath = if ($Path -notmatch '^\\\\\?\\') { "\\?\$Path" } else { $Path }
    try {
        Remove-Item -LiteralPath $longPath -Recurse -Force -ErrorAction Stop
        Write-Success "Removed orphan directory (long path): $Path"
        return
    }
    catch {
        Write-Warn "Long path remove failed: $_"
    }

    # Strategy 3: cmd.exe rmdir (handles some locked cases better)
    try {
        $escapedPath = $Path -replace '"', '\"'
        $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "rmdir", "/s", "/q", "`"$escapedPath`"" -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Write-Success "Removed orphan directory (cmd.exe): $Path"
            return
        }
        Write-Warn "cmd.exe rmdir exited with code $($proc.ExitCode)"
    }
    catch {
        Write-Warn "cmd.exe rmdir failed: $_"
    }

    # Strategy 4: robocopy empty mirror (nuclear option for stubborn dirs)
    try {
        $emptyDir = Join-Path $env:TEMP "worktree-cleanup-empty-$(Get-Random)"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $proc = Start-Process -FilePath "robocopy.exe" -ArgumentList $emptyDir, $Path, "/MIR", "/R:0", "/W:0" -NoNewWindow -Wait -PassThru
        # robocopy returns 0-7 for success, 8+ for errors
        if ($proc.ExitCode -le 7) {
            Remove-Item -Path $Path -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item -Path $emptyDir -Force -Recurse -ErrorAction SilentlyContinue
            if (-not (Test-Path $Path)) {
                Write-Success "Removed orphan directory (robocopy mirror): $Path"
                return
            }
        }
        Remove-Item -Path $emptyDir -Force -Recurse -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warn "robocopy mirror failed: $_"
    }

    Write-Err "All removal strategies failed for: $Path"
    Write-Info "  Manual cleanup: Close VS Code, then: cmd /c 'rmdir /s /q `"$Path`"'"
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

# Get remote wt/ branches with their PR status
function Get-RemoteWtBranches {
    $branches = @()
    $remoteBranches = git branch -r --list 'origin/wt/*' 2>$null |
                      ForEach-Object { $_.Trim() -replace '^origin/', '' }

    foreach ($branch in $remoteBranches) {
        if (-not $branch) { continue }

        # Check PR status via gh CLI
        $prInfo = gh pr list --repo jsboige/roo-extensions --head $branch --state all --json number,state --limit 1 2>$null
        $prState = "NO-PR"
        $prNumber = ""

        if ($prInfo -and $prInfo -ne "[]") {
            try {
                $parsed = $prInfo | ConvertFrom-Json
                if ($parsed) {
                    $prState = $parsed[0].state
                    $prNumber = $parsed[0].number
                }
            }
            catch { }
        }

        $branches += @{
            Name = $branch
            PRState = $prState
            PRNumber = $prNumber
        }
    }

    return $branches
}

# Delete dead remote branches (MERGED, CLOSED, or NO-PR worker artifacts)
function Remove-DeadRemoteBranches {
    param([bool]$WhatIf)

    $deleted = 0
    $kept = 0
    $errors = 0

    $branches = Get-RemoteWtBranches

    if ($branches.Count -eq 0) {
        Write-Success "No remote wt/ branches found"
        return @{ Deleted = 0; Kept = 0; Errors = 0 }
    }

    Write-Info "Remote wt/ branches: $($branches.Count)"

    foreach ($branch in $branches) {
        $shouldDelete = $false
        $reason = ""

        switch ($branch.PRState) {
            "OPEN" {
                $reason = "PR #$($branch.PRNumber) is OPEN"
                $shouldDelete = $false
            }
            "MERGED" {
                $reason = "PR #$($branch.PRNumber) MERGED"
                $shouldDelete = $true
            }
            "CLOSED" {
                $reason = "PR #$($branch.PRNumber) CLOSED"
                $shouldDelete = $true
            }
            default {
                # NO-PR branch — delete if it's a worker artifact (wt/worker-*)
                if ($branch.Name -match '^worker-') {
                    $reason = "NO-PR worker artifact"
                    $shouldDelete = $true
                }
                else {
                    $reason = "NO-PR (manual review)"
                    $shouldDelete = $false
                }
            }
        }

        if ($shouldDelete) {
            if ($WhatIf) {
                Write-Info "[WHATIF] Would delete: origin/$($branch.Name) ($reason)"
            }
            else {
                $result = git push origin --delete $branch.Name 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Deleted: origin/$($branch.Name) ($reason)"
                    $deleted++
                }
                else {
                    Write-Warn "Failed: origin/$($branch.Name) — $result"
                    $errors++
                }
            }
        }
        else {
            Write-Info "Keeping: origin/$($branch.Name) ($reason)"
            $kept++
        }
    }

    return @{ Deleted = $deleted; Kept = $kept; Errors = $errors }
}

# Main execution
function Invoke-WorktreeCleanup {
    Write-Host ""
    Write-Host "=== Worktree Cleanup Report ===" -ForegroundColor White
    Write-Host "Repository: $script:RepoRoot"
    Write-Host "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host ""

    $vsCodeRunning = Test-VSCodeRunning
    Write-Info "VS Code running: $vsCodeRunning"

    # Get active worktrees
    $activeWorktrees = Get-GitWorktrees
    Write-Info "Active worktrees: $($activeWorktrees.Count)"

    # Check for orphan directories
    $orphanDirs = Get-OrphanWorktreeDirs -WorktreesDir $script:WorktreesDir -ActiveWorktrees $activeWorktrees
    Write-Info "Orphan directories: $($orphanDirs.Count)"

    # Check for stale branches
    $staleBranches = Get-StaleBranches -DaysOld $StaleDays
    Write-Info "Stale branches (>$StaleDays days): $($staleBranches.Count)"

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
    $needsCleanup = ($orphanDirs.Count -gt 0 -or $staleBranches.Count -gt 0)

    if (-not $needsCleanup) {
        Write-Success "No cleanup needed. All worktrees are valid."
        return @{ Status = "clean"; Orphans = 0; StaleBranches = 0 }
    }

    # Warning if VS Code is running
    if ($vsCodeRunning -and -not $WhatIf -and -not $Force) {
        Write-Warn "VS Code is running. Use -Force to proceed or -WhatIf for dry run."
        return @{ Status = "aborted"; Reason = "VS Code running" }
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

    # Run git worktree prune to clean stale administrative records
    if (-not $WhatIf) {
        Write-Host ""
        Write-Info "Running git worktree prune..."
        git worktree prune 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "git worktree prune completed"
        }
        else {
            Write-Warn "git worktree prune returned non-zero exit code"
        }
    }
    else {
        Write-Info "[WHATIF] Would run: git worktree prune"
    }

    Write-Host ""
    if ($WhatIf) {
        Write-Info "Dry run complete. Run without -WhatIf to apply changes."
    }
    else {
        Write-Success "Cleanup complete: $cleanedOrphans directories, $cleanedBranches branches"

        # Run git gc if cleanup happened
        if ($cleanedOrphans -gt 0 -or $cleanedBranches -gt 0) {
            Write-Host ""
            Write-Info "Running git gc --prune=now..."
            git gc --prune=now 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "git gc completed"
            }
            else {
                Write-Warn "git gc returned non-zero exit code"
            }
            Write-Info "VS Code restart recommended if worktrees were removed"
        }
    }

    # Remote branch cleanup (optional, controlled by -Remote flag)
    $remoteResult = $null
    if (-not $SkipRemote) {
        Write-Host ""
        Write-Host "--- Remote Branch Cleanup ---" -ForegroundColor Cyan
        $remoteResult = Remove-DeadRemoteBranches -WhatIf $WhatIf

        if (-not $WhatIf -and $remoteResult.Deleted -gt 0) {
            Write-Host ""
            Write-Info "Running git fetch --prune..."
            git fetch --prune origin 2>$null
        }
    }

    return @{
        Status = "cleaned"
        Orphans = $cleanedOrphans
        StaleBranches = $cleanedBranches
        RemoteDeleted = if ($remoteResult) { $remoteResult.Deleted } else { 0 }
        WhatIf = $WhatIf
    }
}

# Execute
$result = Invoke-WorktreeCleanup
exit 0
