<#
.SYNOPSIS
    Worktree Cleanup Protocol - Phase 1: Detection & Alerting
    
.DESCRIPTION
    Detects orphan worktrees and alerts if threshold exceeded.
    Part of Issue #856 implementation.
    
.PARAMETER Threshold
    Maximum allowed worktrees before alert (default: 2)
    
.PARAMETER Quiet
    Suppress output, return exit code only
    
.EXAMPLE
    ./check-worktrees.ps1
    ./check-worktrees.ps1 -Threshold 3 -Quiet
    
.EXITCODES
    0 = OK (within threshold, no orphans)
    1 = WARNING (orphans detected)
    2 = ALERT (threshold exceeded)
#>

param(
    [int]$Threshold = 2,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$worktreeDir = ".claude/worktrees"
$exitCode = 0

# 1. Get Git registered worktrees
$gitWorktreesRaw = git worktree list --porcelain 2>$null
$gitWorktrees = @()
$currentLine = ""
foreach ($line in $gitWorktreesRaw) {
    if ($line -match "^worktree (.+)$") {
        $currentLine = $Matches[1]
        $gitWorktrees += $currentLine
    }
}

# 2. Get physical worktree directories
$physicalWorktrees = @()
if (Test-Path $worktreeDir) {
    $physicalWorktrees = Get-ChildItem -Path $worktreeDir -Directory | ForEach-Object { 
        @{ Name = $_.Name; Path = $_.FullName; LastWriteTime = $_.LastWriteTime }
    }
}

# 3. Detect orphans (physical but not in git)
$orphans = @()
foreach ($wt in $physicalWorktrees) {
    $isRegistered = $gitWorktrees | Where-Object { $_ -like "*$($wt.Name)*" }
    if (-not $isRegistered) {
        $orphans += $wt
    }
}

# 4. Count and evaluate
$worktreeCount = $physicalWorktrees.Count
$orphanCount = $orphans.Count

# 5. Output
if (-not $Quiet) {
    Write-Host "=== Worktree Status ===" -ForegroundColor Cyan
    Write-Host "Git registered: $($gitWorktrees.Count)"
    Write-Host "Physical dirs:  $worktreeCount"
    Write-Host "Orphans:        $orphanCount"
    Write-Host "Threshold:      $Threshold"
    Write-Host ""
    
    if ($orphans.Count -gt 0) {
        Write-Host "=== Orphan Worktrees ===" -ForegroundColor Yellow
        $orphans | ForEach-Object {
            $age = (Get-Date) - $_.LastWriteTime
            Write-Host "  $($_.Name) - Age: $([math]::Round($age.TotalDays, 1)) days" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    if ($worktreeCount -gt $Threshold) {
        Write-Host "[ALERT] Worktree count ($worktreeCount) exceeds threshold ($Threshold)" -ForegroundColor Red
        Write-Host "Action: Run cleanup-worktrees.ps1 or manually remove orphans" -ForegroundColor Red
    } elseif ($orphanCount -gt 0) {
        Write-Host "[WARNING] Orphan worktrees detected" -ForegroundColor Yellow
    } else {
        Write-Host "[OK] Worktree status healthy" -ForegroundColor Green
    }
}

# 6. Set exit code
if ($worktreeCount -gt $Threshold) {
    $exitCode = 2
} elseif ($orphanCount -gt 0) {
    $exitCode = 1
}

# 7. Output JSON for programmatic use
$result = @{
    timestamp = Get-Date -Format "o"
    gitRegistered = $gitWorktrees.Count
    physicalDirs = $worktreeCount
    orphans = $orphanCount
    threshold = $Threshold
    status = if ($exitCode -eq 0) { "OK" } elseif ($exitCode -eq 1) { "WARNING" } else { "ALERT" }
    orphanDetails = $orphans | ForEach-Object { @{ name = $_.Name; age = [math]::Round(((Get-Date) - $_.LastWriteTime).TotalDays, 1) } }
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "JSON Output:" -ForegroundColor DarkGray
    $result | ConvertTo-Json -Depth 3
}

exit $exitCode
