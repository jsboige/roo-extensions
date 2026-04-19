<#
.SYNOPSIS
    Scan repository for parasite files and stale artifacts.

.DESCRIPTION
    Audit script for #1526 Volet 3 — detects files that should not be committed:
    - Files <5 bytes (empty/redirect artifacts like 'D')
    - git-archaeology-*.md at repo root (should be in docs/archaeology/)
    - .shared-state-test-*/ orphan directories
    - win_cli_config.json at repo root
    - Stale worktrees (>14 days without activity)
    - Stale branches (wt/* older than 14 days with no open PR)

.PARAMETER Path
    Root path to scan (default: script parent's parent = repo root)

.PARAMETER StaleDays
    Days threshold for stale worktrees/branches (default: 14)

.PARAMETER Fix
    If set, delete found parasites (default: dry-run report only)

.PARAMETER Dashboard
    If set, post results to RooSync dashboard as [CLEANUP-AUDIT]

.EXAMPLE
    .\audit-parasite.ps1                    # Dry-run audit
    .\audit-parasite.ps1 -Fix               # Delete found parasites
    .\audit-parasite.ps1 -Dashboard         # Post to dashboard
#>

param(
    [string]$Path = '',
    [int]$StaleDays = 14,
    [switch]$Fix,
    [switch]$Dashboard
)

$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
    $Path = Split-Path (Split-Path $scriptDir -Parent) -Parent
}

$Findings = [System.Collections.Generic.List[PSObject]]::new()

function Add-Finding {
    param([string]$Category, [string]$Item, [string]$Action, [long]$SizeBytes = 0)
    $Findings.Add([PSCustomObject]@{
        Category   = $Category
        Item       = $Item
        SizeBytes  = $SizeBytes
        Action     = $Action
    })
}

# --- 1. Tiny files (<5 bytes) ---
Write-Host "=== Scanning tiny files (<5 bytes) ===" Cyan
$tinyFiles = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Length -lt 5 -and
        $_.FullName -notmatch '[/\\]\.git[/\\]' -and
        $_.FullName -notmatch '[/\\]node_modules[/\\]' -and
        $_.FullName -notmatch '[/\\]\.claude[/\\]worktrees[/\\]'
    }

foreach ($file in $tinyFiles) {
    $rel = $file.FullName.Substring($Path.Length).TrimStart('\', '/')
    Add-Finding -Category 'TinyFile' -Item $rel -Action 'delete' -SizeBytes $file.Length
    Write-Host "  [TinyFile] $rel ($($file.Length) bytes)" Yellow
}

# --- 2. Misplaced git-archaeology at root ---
Write-Host "`n=== Scanning misplaced archaeology docs ===" Cyan
$archFiles = Get-ChildItem -Path $Path -Filter 'git-archaeology-*.md' -File -ErrorAction SilentlyContinue
foreach ($file in $archFiles) {
    Add-Finding -Category 'MisplacedArchaeology' -Item $file.Name -Action 'move-to-docs/archaeology' -SizeBytes $file.Length
    Write-Host "  [Misplaced] $($file.Name)" Yellow
}

# --- 3. Orphan .shared-state-test-* directories ---
Write-Host "`n=== Scanning orphan test directories ===" Cyan
$testDirs = Get-ChildItem -Path $Path -Directory -Filter '.shared-state-test-*' -ErrorAction SilentlyContinue
foreach ($dir in $testDirs) {
    $rel = $dir.FullName.Substring($Path.Length).TrimStart('\', '/')
    Add-Finding -Category 'OrphanTestDir' -Item $rel -Action 'delete'
    Write-Host "  [OrphanTestDir] $rel" Yellow
}

# --- 4. Root-level win_cli_config.json ---
Write-Host "`n=== Scanning root config artifacts ===" Cyan
$rootConfig = Join-Path $Path 'win_cli_config.json'
if (Test-Path $rootConfig) {
    $size = (Get-Item $rootConfig).Length
    Add-Finding -Category 'RootConfigArtifact' -Item 'win_cli_config.json' -Action 'delete' -SizeBytes $size
    Write-Host "  [RootConfig] win_cli_config.json ($size bytes)" Yellow
}

# --- 5. Stale worktrees (>14 days) ---
Write-Host "`n=== Scanning stale worktrees (>${StaleDays}d) ===" Cyan
$worktreeDir = "$Path/.claude/worktrees"
if (Test-Path $worktreeDir) {
    $cutoff = (Get-Date).AddDays(-$StaleDays)
    $worktrees = Get-ChildItem -Path $worktreeDir -Directory -ErrorAction SilentlyContinue
    foreach ($wt in $worktrees) {
        $lastWrite = $wt.LastWriteTime
        if ($lastWrite -lt $cutoff) {
            $age = [math]::Floor(((Get-Date) - $lastWrite).TotalDays)
            Add-Finding -Category 'StaleWorktree' -Item ".claude/worktrees/$($wt.Name)" -Action 'remove'
            Write-Host "  [StaleWorktree] $($wt.Name) (${age}d old)" Yellow
        }
    }
}

# --- 6. Stale wt/* branches with no open PR ---
Write-Host "`n=== Scanning stale branches (wt/*, >${StaleDays}d, no PR) ===" Cyan
try {
    $branches = git branch --list 'wt/*' --format='%(refname:short) %(creatordate:iso)' 2>$null
    foreach ($line in $branches) {
        if (-not $line.Trim()) { continue }
        $parts = $line -split '\s+', 2
        $branch = $parts[0]
        $date = [datetime]::Parse($parts[1].Substring(0, 19))
        if ($date -lt (Get-Date).AddDays(-$StaleDays)) {
            $prCheck = gh pr list --state open --head $branch --repo jsboige/roo-extensions --json number 2>$null
            $hasPR = ($prCheck | ConvertFrom-Json).Count -gt 0
            if (-not $hasPR) {
                $age = [math]::Floor(((Get-Date) - $date).TotalDays)
                Add-Finding -Category 'StaleBranch' -Item $branch -Action 'delete'
                Write-Host "  [StaleBranch] $branch (${age}d, no PR)" Yellow
            }
        }
    }
} catch {
    Write-Host "  [SKIP] Could not check branches: $_" DarkGray
}

# --- Summary ---
Write-Host "`n=== Summary ===" Cyan
$total = $Findings.Count
if ($total -eq 0) {
    Write-Host "  No parasite files found. Repository is clean." Green
} else {
    $byCategory = $Findings | Group-Object Category | Sort-Object Count -Descending
    foreach ($group in $byCategory) {
        Write-Host "  $($group.Count)x $($group.Name)" Yellow
    }
    Write-Host "`n  Total: $total findings" White
    if ($Fix) {
        Write-Host "  Mode: FIX (deleting/moving)" Red
    } else {
        Write-Host "  Mode: DRY-RUN (use -Fix to apply)" DarkGray
    }
}

# --- Fix mode ---
if ($Fix -and $total -gt 0) {
    Write-Host "`n=== Applying fixes ===" Yellow
    foreach ($f in $Findings) {
        $fullPath = Join-Path $Path ($f.Item -replace '[/\\]', [System.IO.Path]::DirectorySeparatorChar)
        switch ($f.Category) {
            'TinyFile' {
                Remove-Item -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue
                Write-Host "  [DELETED] $($f.Item)" DarkGray
            }
            'MisplacedArchaeology' {
                $dest = "$Path/docs/archaeology"
                if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
                Move-Item -LiteralPath $fullPath -Destination "$dest/$(Split-Path $fullPath -Leaf)" -Force -ErrorAction SilentlyContinue
                Write-Host "  [MOVED] $($f.Item) → docs/archaeology/" DarkGray
            }
            'OrphanTestDir' {
                Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [DELETED] $($f.Item)/" DarkGray
            }
            'RootConfigArtifact' {
                Remove-Item -LiteralPath $fullPath -Force -ErrorAction SilentlyContinue
                Write-Host "  [DELETED] $($f.Item)" DarkGray
            }
            'StaleWorktree' {
                try {
                    git worktree remove $fullPath --force 2>$null
                    Write-Host "  [REMOVED WT] $($f.Item)" DarkGray
                } catch {
                    Write-Host "  [FAILED WT] $($f.Item): $_" Red
                }
            }
            'StaleBranch' {
                try {
                    git branch -D $f.Item 2>$null
                    Write-Host "  [DELETED BRANCH] $($f.Item)" DarkGray
                } catch {
                    Write-Host "  [FAILED BRANCH] $($f.Item): $_" Red
                }
            }
        }
    }
}

# --- Dashboard report ---
# Note: Dashboard posting requires MCP roo-state-manager, which cannot be called
# from a standalone PowerShell script. Use the -Dashboard switch to print the
# report body, then manually post via Claude Code or Roo.
if ($Dashboard -and $total -gt 0) {
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("### [CLEANUP-AUDIT] $($env:COMPUTERNAME.ToLower())")
    [void]$sb.AppendLine("- Findings: $total")
    foreach ($group in ($Findings | Group-Object Category | Sort-Object Count -Descending)) {
        [void]$sb.AppendLine("- $($group.Count)x $($group.Name)")
    }
    [void]$sb.AppendLine("- Mode: $(if ($Fix) { 'FIX applied' } else { 'Dry-run' })")
    [void]$sb.AppendLine("- Script: scripts/maintenance/audit-parasite.ps1")
    Write-Host "`n=== Dashboard Report (copy to Claude/Roo) ===" Cyan
    Write-Host $sb.ToString()
}
