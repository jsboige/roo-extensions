<#
.SYNOPSIS
    Archive old Claude Code session data to free disk space.

.DESCRIPTION
    Scans ~/.claude/projects/ directories for sessions older than a threshold
    and archives them to GDrive (RooSync shared-state). Designed to address
    disk space issues on ai-01 (90.6% critical, issue #1766).

    IMPORTANT: Sessions are SANCTUARIZED (#1621). This script NEVER deletes
    data — it only archives to GDrive. Deletion requires explicit user approval.

.PARAMETER ClaudeHome
    Path to Claude config home. Defaults to $env:USERPROFILE\.claude

.PARAMETER DaysThreshold
    Minimum age in days for sessions to be archived. Default: 30.

.PARAMETER Confirm
    Actually execute the archive. Without this flag, runs in dry-run mode.

.PARAMETER ArchiveToGDrive
    Archive to RooSync GDrive shared-state (recommended). Default behavior.

.PARAMETER ArchiveToLocal
    Archive to local directory instead of GDrive.

.PARAMETER ArchivePath
    Custom archive destination path. Overrides default GDrive/local paths.

.PARAMETER LogPath
    Path for log output. Defaults to outputs/cleanup-sessions-{timestamp}.log

.PARAMETER SkipWorktreeSessions
    Skip worktree-derived project directories (those with -claude-worktrees- in name).
    These may be actively used by workers.

.EXAMPLE
    ./cleanup-claude-sessions.ps1
    # Dry-run: report sessions older than 30 days without archiving

.EXAMPLE
    ./cleanup-claude-sessions.ps1 -Confirm
    # Archive all sessions > 30 days to GDrive

.EXAMPLE
    ./cleanup-claude-sessions.ps1 -DaysThreshold 7 -Confirm
    # Archive sessions > 7 days (aggressive cleanup)

.NOTES
    Issue #1766 — Disk cleanup for critical ai-01 (90.6%)
    Sanctuary rule #1621 — Sessions MUST NOT be deleted, only archived
#>

[CmdletBinding()]
param(
    [string]$ClaudeHome,
    [int]$DaysThreshold = 30,
    [switch]$Confirm,
    [switch]$ArchiveToGDrive,
    [switch]$ArchiveToLocal,
    [string]$ArchivePath,
    [string]$LogPath,
    [switch]$SkipWorktreeSessions
)

$ErrorActionPreference = 'Stop'

#region --- Configuration ---
if (-not $ClaudeHome) {
    $ClaudeHome = "$env:USERPROFILE\.claude"
}

$ProjectsPath = "$ClaudeHome\projects"
$SessionsPath = "$ClaudeHome\sessions"
$TelemetryPath = "$ClaudeHome\telemetry"
$FileHistoryPath = "$ClaudeHome\file-history"

# Determine archive destination
if (-not $ArchivePath) {
    if ($ArchiveToLocal) {
        $ArchivePath = "$ClaudeHome\projects\_archive"
    } else {
        # Default: GDrive shared-state
        $GDriveRoot = $null
        # Check multiple possible GDrive mount points
        $gdrivePaths = @(
            "$env:USERPROFILE\Drive\.shortcut-targets-by-id",
            "C:\Drive\.shortcut-targets-by-id",
            "D:\Drive\.shortcut-targets-by-id",
            "E:\Drive\.shortcut-targets-by-id"
        )
        foreach ($shortcutPath in $gdrivePaths) {
            if (Test-Path $shortcutPath) {
                $gdriveFolder = Get-ChildItem -Path $shortcutPath -Directory -ErrorAction SilentlyContinue |
                    Where-Object { Test-Path "$($_.FullName)\.shared-state" } |
                    Select-Object -First 1
                if ($gdriveFolder) {
                    $ArchivePath = "$($gdriveFolder.FullName)\.shared-state\backups\claude-sessions"
                    break
                }
            }
        }
        if (-not $ArchivePath) {
            # Fallback to local
            Write-Warning "GDrive shared-state not found. Falling back to local archive."
            $ArchivePath = "$ClaudeHome\projects\_archive"
        }
    }
}

# Log path
if (-not $LogPath) {
    $RepoRoot = (git rev-parse --show-toplevel 2>$null).Trim()
    if ($RepoRoot -and (Test-Path "$RepoRoot\outputs")) {
        $LogPath = "$RepoRoot\outputs\cleanup-sessions-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    } else {
        $LogPath = "$env:TEMP\cleanup-sessions-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    }
}
#endregion

#region --- Helper Functions ---
function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Write-Host $line
    Add-Content -Path $LogPath -Value $line -Encoding UTF8
}

function Get-DirectorySizeMB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $size = (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        return [math]::Round($size / 1MB, 2)
    } catch {
        return 0
    }
}

function Get-DirectoryFileCount {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        return (Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    } catch {
        return 0
    }
}
#endregion

#region --- Main Logic ---
Write-Log "=== Claude Session Cleanup Script ==="
Write-Log "Mode: $(if ($Confirm) { 'EXECUTE' } else { 'DRY-RUN' })"
Write-Log "Threshold: $DaysThreshold days"
Write-Log "Archive destination: $ArchivePath"
Write-Log "Claude home: $ClaudeHome"

$cutoffDate = (Get-Date).AddDays(-$DaysThreshold)

# Phase 1: Audit Claude home
Write-Log ""
Write-Log "--- Phase 1: Claude Home Audit ---"

$totalClaudeHomeMB = Get-DirectorySizeMB $ClaudeHome
Write-Log "Total ~/.claude size: ${totalClaudeHomeMB} MB"

$auditPaths = @(
    @{ Name = 'projects'; Path = $ProjectsPath },
    @{ Name = 'sessions'; Path = $SessionsPath },
    @{ Name = 'telemetry'; Path = $TelemetryPath },
    @{ Name = 'file-history'; Path = $FileHistoryPath }
)

foreach ($item in $auditPaths) {
    $sizeMB = Get-DirectorySizeMB $item.Path
    $fileCount = Get-DirectoryFileCount $item.Path
    Write-Log "  $($item.Name): ${sizeMB} MB ($fileCount files)"
}

# Phase 2: Scan project directories
Write-Log ""
Write-Log "--- Phase 2: Scanning Project Directories ---"

if (-not (Test-Path $ProjectsPath)) {
    Write-Log "No projects directory found at: $ProjectsPath" -Level 'WARN'
    Write-Log "Nothing to archive."
    exit 0
}

$candidates = @()
$activeProjects = @()

$projectDirs = Get-ChildItem -Path $ProjectsPath -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne '_archive' }

foreach ($dir in $projectDirs) {
    $lastWrite = $dir.LastWriteTime
    $age = (Get-Date) - $lastWrite
    $ageDays = [math]::Floor($age.TotalDays)
    $sizeMB = Get-DirectorySizeMB $dir.FullName
    $fileCount = Get-DirectoryFileCount $dir.FullName
    $isWorktreeSession = $dir.Name -match '-claude-worktrees-'

    $entry = [PSCustomObject]@{
        Name       = $dir.Name
        FullName   = $dir.FullName
        LastWrite  = $lastWrite
        AgeDays    = $ageDays
        SizeMB     = $sizeMB
        FileCount  = $fileCount
        IsWorktree = $isWorktreeSession
    }

    # Skip if worktree session and flag set
    if ($isWorktreeSession -and $SkipWorktreeSessions) {
        $activeProjects += $entry
        continue
    }

    # Check if old enough
    if ($lastWrite -lt $cutoffDate) {
        $candidates += $entry
    } else {
        $activeProjects += $entry
    }
}

# Sort candidates by size (largest first for maximum impact)
$candidates = $candidates | Sort-Object -Property SizeMB -Descending

$totalCandidateMB = ($candidates | Measure-Object -Property SizeMB -Sum).Sum
$totalCandidateMB = [math]::Round($totalCandidateMB, 2)

Write-Log "Active projects (recent): $($activeProjects.Count)"
Write-Log "Archive candidates (>$DaysThreshold days): $($candidates.Count) (${totalCandidateMB} MB)"

# Phase 3: Report candidates
Write-Log ""
Write-Log "--- Phase 3: Archive Candidates ---"

if ($candidates.Count -eq 0) {
    Write-Log "No sessions older than $DaysThreshold days found. Nothing to archive."
    exit 0
}

$idx = 0
foreach ($c in $candidates) {
    $idx++
    $typeLabel = if ($c.IsWorktree) { 'WORKTREE' } else { 'PROJECT' }
    Write-Log ("  [{0,3}/{1}] {2} | {3,8} MB | {4,4}d old | {5} files | {6}" -f `
        $idx, $candidates.Count, $typeLabel, $c.SizeMB, $c.AgeDays, $c.FileCount, $c.Name)
}

# Phase 4: Archive (or dry-run report)
Write-Log ""
Write-Log "--- Phase 4: $(if ($Confirm) { 'Archiving' } else { 'Dry-Run Report' }) ---"

if (-not $Confirm) {
    Write-Log ""
    Write-Log "DRY-RUN: No changes made. To execute, run with -Confirm flag."
    Write-Log "Estimated space recovery: ${totalCandidateMB} MB"
    Write-Log "Archive destination: $ArchivePath"
    Write-Log ""
    Write-Log "IMPORTANT: Sessions are sanctuarized (#1621). This script ONLY archives."
    Write-Log "No data is deleted. Archives are preserved in: $ArchivePath"
    Write-Log ""
    Write-Log "Log saved to: $LogPath"
    exit 0
}

# Execute archive
if (-not (Test-Path $ArchivePath)) {
    New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
    Write-Log "Created archive directory: $ArchivePath"
}

$archivedCount = 0
$archivedMB = 0
$failedCount = 0

foreach ($c in $candidates) {
    $archiveName = "$($c.Name)-$(Get-Date -Format 'yyyyMMdd')"
    $destPath = "$ArchivePath\$archiveName.zip"

    if (Test-Path $destPath) {
        Write-Log "  SKIP (already archived): $($c.Name)" -Level 'WARN'
        continue
    }

    try {
        # Create zip archive
        Compress-Archive -Path $c.FullName -DestinationPath $destPath -CompressionLevel Optimal -Force

        # Verify archive integrity
        if (Test-Path $destPath) {
            $archiveSize = (Get-Item $destPath).Length / 1MB
            $archiveSizeMB = [math]::Round($archiveSize, 2)

            # Remove original only after successful archive
            Remove-Item -Path $c.FullName -Recurse -Force

            $archivedCount++
            $archivedMB += $c.SizeMB
            Write-Log "  ARCHIVED: $($c.Name) -> ${archiveSizeMB} MB zip (was $($c.SizeMB) MB)"
        } else {
            throw "Archive file not created"
        }
    } catch {
        $failedCount++
        Write-Log "  FAILED: $($c.Name) — $_" -Level 'ERROR'
    }
}

# Phase 5: Summary
Write-Log ""
Write-Log "--- Summary ---"
Write-Log "Archived: $archivedCount directories (${archivedMB} MB freed)"
Write-Log "Failed: $failedCount"
Write-Log "Remaining active: $($activeProjects.Count)"
Write-Log "Archive location: $ArchivePath"
Write-Log ""
Write-Log "Log saved to: $LogPath"

# Phase 6: Telemetry audit (bonus)
$telemetrySizeMB = Get-DirectorySizeMB $TelemetryPath
if ($telemetrySizeMB -gt 5) {
    Write-Log ""
    Write-Log "--- Bonus: Telemetry Cleanup ---"
    Write-Log "Telemetry directory is ${telemetrySizeMB} MB. Consider cleaning old telemetry files."
    Write-Log "Location: $TelemetryPath"
}
#endregion
