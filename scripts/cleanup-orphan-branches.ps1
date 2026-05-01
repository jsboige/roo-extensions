<#
.SYNOPSIS
    Audit and cleanup orphan branches (no open PR, older than threshold)
.DESCRIPTION
    Scans all remote branches in jsboige/roo-extensions, cross-references with
    open PRs, and categorizes branches as safe-to-delete, need-review, or recent.
.PARAMETER DaysThreshold
    Branches older than this many days are considered for cleanup (default: 30)
.PARAMETER DryRun
    If set, only generates the report without deleting anything
.PARAMETER DeleteSafe
    If set, deletes branches categorized as safe-to-delete
.EXAMPLE
    ./cleanup-orphan-branches.ps1 -DaysThreshold 30 -DryRun
#>
param(
    [int]$DaysThreshold = 30,
    [switch]$DryRun = $true,
    [switch]$DeleteSafe = $false
)

$ErrorActionPreference = 'Stop'
$Repo = 'jsboige/roo-extensions'
$cutoff = (Get-Date).AddDays(-$DaysThreshold)

Write-Host "=== Orphan Branch Audit ===" -ForegroundColor Cyan
Write-Host "Repo: $Repo"
Write-Host "Cutoff: $($cutoff.ToString('yyyy-MM-dd')) ($DaysThreshold days ago)"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE - will delete safe branches' })"
Write-Host ""

# Get all open PR branches
Write-Host "Fetching open PRs..." -ForegroundColor Yellow
$prBranches = @()
try {
    $prBranches = gh pr list --state open --json headRefName --jq '.[].headRefName' --repo $Repo 2>$null
} catch {
    Write-Host "Warning: Could not fetch PRs" -ForegroundColor Yellow
}
$prBranchSet = @{}
foreach ($b in $prBranches) {
    $prBranchSet[$b] = $true
}
Write-Host "  Open PRs: $($prBranches.Count)"

# Protected branches (never delete)
$protectedPatterns = @('^main$', '^master$', '^develop$', '^release/', '^hotfix/')
$protectedExact = @('main', 'master', 'develop')

# Categories
$safeToDelete = @()
$needReview = @()
$recent = @()
$protected = @()

# Get all remote branches with dates
Write-Host "Scanning branches..." -ForegroundColor Yellow
$branches = git branch -r --format='%(refname:short)|%(creatordate:iso8601)|%(authorname)'

foreach ($line in $branches) {
    if (-not $line -or $line -notmatch '\|') { continue }
    $parts = $line -split '\|', 3
    $branch = $parts[0].Trim()
    $dateStr = $parts[1].Trim()
    $author = $parts[2].Trim()

    # Parse date
    try {
        $branchDate = [DateTime]::Parse($dateStr)
    } catch {
        $branchDate = [DateTime]::MinValue
    }

    $isRecent = $branchDate -gt $cutoff
    $hasPR = $prBranchSet.ContainsKey($branch)

    # Check protected
    $isProtected = $false
    foreach ($p in $protectedExact) {
        if ($branch -eq "origin/$p") { $isProtected = $true; break }
    }
    foreach ($p in $protectedPatterns) {
        if ($branch -match "origin/$p") { $isProtected = $true; break }
    }

    $shortName = $branch -replace '^origin/', ''

    if ($isProtected) {
        $protected += @{ name = $shortName; date = $branchDate; author = $author }
    } elseif ($hasPR) {
        $recent += @{ name = $shortName; date = $branchDate; author = $author; hasPR = $true }
    } elseif ($isRecent) {
        $recent += @{ name = $shortName; date = $branchDate; author = $author; hasPR = $false }
    } else {
        # Old branch with no PR - categorize by pattern
        if ($shortName -match '^wt/worker-') {
            # Worker branches are always safe to delete after PR merge/close
            $safeToDelete += @{ name = $shortName; date = $branchDate; author = $author; reason = 'worker branch (>30d, no PR)' }
        } elseif ($shortName -match '^(fix|feat|chore|docs|test|refactor)/' -and -not $hasPR) {
            # Feature/fix branches without PR - could have been merged
            $safeToDelete += @{ name = $shortName; date = $branchDate; author = $author; reason = 'feature branch (>30d, no PR)' }
        } elseif ($shortName -match '^wt/' -and -not $hasPR) {
            $safeToDelete += @{ name = $shortName; date = $branchDate; author = $author; reason = 'worktree branch (>30d, no PR)' }
        } elseif ($shortName -match '^(pr|sub)/') {
            $safeToDelete += @{ name = $shortName; date = $branchDate; author = $author; reason = 'PR/sub branch (>30d, no PR)' }
        } else {
            $needReview += @{ name = $shortName; date = $branchDate; author = $author; reason = 'unknown pattern (>30d, no PR)' }
        }
    }
}

# Report
Write-Host ""
Write-Host "=== RESULTS ===" -ForegroundColor Cyan
Write-Host "Protected: $($protected.Count)"
Write-Host "Recent (<$DaysThreshold days or has PR): $($recent.Count)"
Write-Host "Safe to delete: $($safeToDelete.Count)"
Write-Host "Need review: $($needReview.Count)"
Write-Host ""

# Safe to delete details
if ($safeToDelete.Count -gt 0) {
    Write-Host "--- SAFE TO DELETE ($($safeToDelete.Count)) ---" -ForegroundColor Green
    $safeToDelete | Sort-Object { $_.date } | ForEach-Object {
        Write-Host ("  {0,-55} {1}  {2}" -f $_.name, $_.date.ToString('yyyy-MM-dd'), $_.reason)
    }
    Write-Host ""
}

# Need review details
if ($needReview.Count -gt 0) {
    Write-Host "--- NEED REVIEW ($($needReview.Count)) ---" -ForegroundColor Yellow
    $needReview | Sort-Object { $_.date } | ForEach-Object {
        Write-Host ("  {0,-55} {1}  {2}" -f $_.name, $_.date.ToString('yyyy-MM-dd'), $_.reason)
    }
    Write-Host ""
}

# Recent with PR
$withPR = $recent | Where-Object { $_.hasPR }
if ($withPR.Count -gt 0) {
    Write-Host "--- HAS OPEN PR ($($withPR.Count)) ---" -ForegroundColor Blue
    $withPR | Sort-Object { $_.date } | ForEach-Object {
        Write-Host ("  {0,-55} {1}" -f $_.name, $_.date.ToString('yyyy-MM-dd'))
    }
    Write-Host ""
}

# Delete if requested
if ($DeleteSafe -and -not $DryRun -and $safeToDelete.Count -gt 0) {
    Write-Host "DELETING $($safeToDelete.Count) safe branches..." -ForegroundColor Red
    foreach ($b in $safeToDelete) {
        $remoteBranch = "origin/$($b.name)"
        Write-Host "  Deleting $remoteBranch..." -NoNewline
        try {
            git push origin --delete $b.name 2>$null
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
        }
    }
} elseif ($safeToDelete.Count -gt 0 -and $DryRun) {
    Write-Host "Dry run - no branches deleted. Use -DeleteSafe -DryRun:`$false to delete." -ForegroundColor Yellow
}

# Summary for report
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total branches: $(($protected.Count + $recent.Count + $safeToDelete.Count + $needReview.Count))"
Write-Host "Safe to delete: $($safeToDelete.Count)"
Write-Host "Need review: $($needReview.Count)"
Write-Host "Branches with open PRs: $(($recent | Where-Object { $_.hasPR }).Count)"
