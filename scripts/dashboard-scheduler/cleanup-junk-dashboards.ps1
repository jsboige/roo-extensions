<#
.SYNOPSIS
    Cleanup junk/orphan workspace dashboards from GDrive shared state.

.DESCRIPTION
    Identifies and archives stale workspace dashboard files:
    - Orphaned worktree dashboards (wt-* patterns from dead worktrees)
    - Typo dashboards (malformed names)
    - Stale dashboards (workspaces no longer active)

    Archives to _archive/<date>/ instead of deleting (no-deletion-without-proof rule).
    Runs in DryRun mode by default — use -Execute to actually archive.

.PARAMETER SharedPath
    Override ROOSYNC_SHARED_PATH. Defaults to $env:ROOSYNC_SHARED_PATH.

.PARAMETER Execute
    Actually perform archive operations. Default: DryRun (list only).

.PARAMETER DaysThreshold
    Minimum age in days to consider a dashboard as junk. Default: 7.

.EXAMPLE
    .\cleanup-junk-dashboards.ps1
    Dry run — lists candidates without archiving.

.EXAMPLE
    .\cleanup-junk-dashboards.ps1 -Execute
    Archives identified junk dashboards.

.NOTES
    Part of issue #1931 Phase 1.b (dashboard-watcher fix).
#>

param(
    [string]$SharedPath = $env:ROOSYNC_SHARED_PATH,
    [switch]$Execute = $false,
    [int]$DaysThreshold = 7
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrEmpty($SharedPath)) {
    Write-Host "[ERROR] ROOSYNC_SHARED_PATH not set. Provide -SharedPath." -ForegroundColor Red
    exit 1
}

$dashboardDir = Join-Path $SharedPath "dashboards"
if (-not (Test-Path $dashboardDir)) {
    Write-Host "[ERROR] Dashboards directory not found: $dashboardDir" -ForegroundColor Red
    exit 1
}

# Known junk candidates from coordinator investigation (issue #1931)
# These are orphaned worktree dashboards, typos, and stale entries
$junkPatterns = @(
    # Orphaned worktree dashboards
    "workspace-wt-715-myia-web1-20260419-200747.md",
    "workspace-wt-worker-myia-web1-20260419-140815.md",
    "workspace-wt-worker-myia-web1-20260421-140750.md",
    # Typos / malformed names
    "workspace-jsboi.md",
    "workspace-workspace-Argumentum.md",
    # Stale / obsolete
    "workspace-internal.md"
)

# Protected — NEVER archive without explicit user approval
$protectedPatterns = @(
    "workspace-Michelle.md",
    "workspace-Musique.md",
    "workspace-Embeddings.md",
    "workspace-.claude.md"
)

# Active workspace whitelist (from DASHBOARD_WATCHER_WORKSPACES coordinator spec)
$activeWorkspaces = @(
    "roo-extensions", "CoursIA", "hermes-agent", "nanoclaw", "Maintenance",
    "roo-state-manager", "2025-Epitaf-Intelligence-Symbolique", "Argumentum",
    "vllm", "myia-open-webui", "IISManagement", "g--Mon-Drive-Maintenance"
)

$cutoffDate = (Get-Date).AddDays(-$DaysThreshold)

function Write-Status($icon, $msg) {
    Write-Host "  $icon $msg"
}

# Scan all workspace dashboards
$allDashboards = Get-ChildItem -Path $dashboardDir -Filter "workspace-*.md" -File

Write-Host "`n=== Dashboard Cleanup Scan ===" -ForegroundColor Cyan
Write-Host "Directory: $dashboardDir"
Write-Host "Total dashboards: $($allDashboards.Count)"
Write-Host "Mode: $(if ($Execute) { 'EXECUTE' } else { 'DRY RUN' })"
Write-Host ""

$toArchive = @()
$protected = @()
$active = @()
$unknown = @()

foreach ($db in $allDashboards) {
    $wsName = $db.BaseName -replace '^workspace-', ''

    # Check protected list
    if ($protectedPatterns -contains $db.Name) {
        $protected += $db
        Write-Status "[PROTECTED]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB)"
        continue
    }

    # Check known junk
    if ($junkPatterns -contains $db.Name) {
        $toArchive += $db
        Write-Status "[JUNK]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB) — known junk candidate"
        continue
    }

    # Check worktree pattern (wt-* in name)
    if ($wsName -match '^wt-') {
        if ($db.LastWriteTime -lt $cutoffDate) {
            $toArchive += $db
            Write-Status "[ORPHAN-WT]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB, last modified $($db.LastWriteTime.ToString('yyyy-MM-dd')))"
        } else {
            $unknown += $db
            Write-Status "[RECENT-WT]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB, recent)"
        }
        continue
    }

    # Check duplicate prefix (workspace-workspace-*)
    if ($wsName -match '^workspace-') {
        $toArchive += $db
        Write-Status "[DUPLICATE-PREFIX]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB)"
        continue
    }

    # Check if active
    if ($activeWorkspaces -contains $wsName) {
        $active += $db
        continue  # Don't list active ones
    }

    # Unknown workspace — list if stale
    if ($db.LastWriteTime -lt $cutoffDate) {
        $unknown += $db
        Write-Status "[STALE-UNKNOWN]" "$($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB, last modified $($db.LastWriteTime.ToString('yyyy-MM-dd')))"
    }
}

Write-Host ""
Write-Host "--- Summary ---" -ForegroundColor Yellow
Write-Host "  Active workspaces: $($active.Count)"
Write-Host "  Junk to archive: $($toArchive.Count)"
Write-Host "  Protected (untouchable): $($protected.Count)"
Write-Host "  Unknown/stale (review): $($unknown.Count)"

$totalSize = ($toArchive | Measure-Object -Property Length -Sum).Sum
Write-Host "  Space to reclaim: $([Math]::Round($totalSize / 1KB, 1)) KB"

if ($toArchive.Count -eq 0) {
    Write-Host "`nNo junk dashboards found. Nothing to do." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "--- Junk Candidates ---" -ForegroundColor Yellow
foreach ($db in $toArchive) {
    Write-Host "  $($db.Name) ($([Math]::Round($db.Length / 1KB, 1)) KB)"
}

if (-not $Execute) {
    Write-Host "`n[DRY RUN] No files archived. Use -Execute to archive." -ForegroundColor Cyan
    exit 0
}

# Archive
$archiveDir = Join-Path $dashboardDir "_archive/$(Get-Date -Format 'yyyyMMdd')"
if (-not (Test-Path $archiveDir)) {
    New-Item -ItemType Directory -Path $archiveDir -Force | Out-Null
}

Write-Host ""
Write-Host "--- Archiving ---" -ForegroundColor Green
foreach ($db in $toArchive) {
    $dest = Join-Path $archiveDir $db.Name
    Move-Item -Path $db.FullName -Destination $dest -Force
    Write-Host "  [ARCHIVED] $($db.Name) → _archive/$(Get-Date -Format 'yyyyMMdd')/"
}

Write-Host "`nDone. $($toArchive.Count) dashboards archived to $archiveDir" -ForegroundColor Green
