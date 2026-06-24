# Archive Large Claude Code Sessions (#2577)
# Diagnostic + non-destructive archive for context explosion mitigation.
#
# SANCTUARY MANDATE (user 2026-06-19): Agent traces are NEVER deleted.
# This script COPIES sessions to an archive location with byte-count verification.
# Source sessions remain intact on disk — only the archive copy is external.
#
# Usage:
#   .\scripts\claude\archive-large-sessions.ps1                            # Report only (default)
#   .\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 80            # Lower threshold
#   .\scripts\claude\archive-large-sessions.ps1 -ArchivePath "D:\Archive"  # Enable copy mode
#   .\scripts\claude\archive-large-sessions.ps1 -DryRun                    # Report + simulate
#   .\scripts\claude\archive-large-sessions.ps1 -MaxSessions 5             # Limit to top 5
#   .\scripts\claude\archive-large-sessions.ps1 -DetectDuplicates          # Scan for dup sessions

param(
    [int]$ThresholdMB = 100,
    [int]$MaxSessions = 0,
    [string]$ArchivePath = "",
    [switch]$DryRun,
    [switch]$DetectDuplicates
)

$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code Session Diagnostic & Archiver (#2577) ===" -ForegroundColor Cyan
Write-Host "Threshold: $ThresholdMB MB" -ForegroundColor Yellow
Write-Host "Max Sessions: $(if ($MaxSessions -gt 0) { $MaxSessions } else { 'All' })" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host "Archive Path: $(if ($ArchivePath) { $ArchivePath } else { '(report only)' })" -ForegroundColor Yellow
Write-Host "Detect Duplicates: $DetectDuplicates" -ForegroundColor Yellow
Write-Host ""

# Get Claude projects path
$projectsPath = Join-Path $env:USERPROFILE ".claude\projects"
if (-not (Test-Path $projectsPath)) {
    Write-Host "ERROR: Claude projects path not found: $projectsPath" -ForegroundColor Red
    exit 1
}

# Scan ALL sessions (not just large ones) for duplicate detection
Write-Host "Scanning sessions..." -ForegroundColor Cyan
$allSessions = @()

Get-ChildItem -Path $projectsPath -Directory | ForEach-Object {
    $projectDir = $_
    $projectSessions = Get-ChildItem -Path $projectDir.FullName -Directory -ErrorAction SilentlyContinue

    foreach ($sessionDir in $projectSessions) {
        # Calculate session size
        $sizeBytes = (Get-ChildItem -Path $sessionDir.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

        if ($sizeBytes) {
            $sizeMB = [math]::Round($sizeBytes / 1MB, 1)

            # Compute a fingerprint for dedup: hash the names of files in the session
            # (not the full content — too slow for 400MB sessions). Sessions with
            # identical file sets + similar sizes are candidates for dedup review.
            $fileHashes = Get-ChildItem -Path $sessionDir.FullName -Recurse -File -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty Name | Sort-Object
            $fingerprint = ($fileHashes -join "|")

            $allSessions += [PSCustomObject]@{
                Project = $projectDir.Name
                Session = $sessionDir.Name
                SizeMB = $sizeMB
                Path = $sessionDir.FullName
                Fingerprint = $fingerprint
                FileCount = $fileHashes.Count
            }
        }
    }
}

# Filter large sessions
$largeSessions = $allSessions | Where-Object { $_.SizeMB -ge $ThresholdMB } | Sort-Object SizeMB -Descending

Write-Host "Total sessions found: $($allSessions.Count)" -ForegroundColor Green
Write-Host "Sessions >= ${ThresholdMB}MB: $($largeSessions.Count)" -ForegroundColor Yellow
Write-Host ""

# --- Duplicate detection (#2577 item 2: coordinator doublons) ---
if ($DetectDuplicates) {
    Write-Host "=== Duplicate Session Detection ===" -ForegroundColor Cyan
    Write-Host "Scanning $($allSessions.Count) sessions for duplicates..." -ForegroundColor Yellow

    # Group by fingerprint to find sessions with identical file structures
    $dupGroups = $allSessions | Group-Object -Property Fingerprint | Where-Object { $_.Count -gt 1 }

    if ($dupGroups.Count -eq 0) {
        Write-Host "No duplicate sessions detected (by file structure)." -ForegroundColor Green
    } else {
        Write-Host "Found $($dupGroups.Count) duplicate group(s):" -ForegroundColor Yellow
        Write-Host ""
        foreach ($group in $dupGroups) {
            $totalSize = [math]::Round(($group.Group | Measure-Object SizeMB -Sum).Sum, 1)
            $groupSize = $group.Group[0].SizeMB
            Write-Host "  Group: $($group.Count) sessions, ~${groupSize}MB each, ${totalSize}MB total" -ForegroundColor Cyan
            $group.Group | Format-Table Project, Session, SizeMB, FileCount -AutoSize
            Write-Host ""
        }
        Write-Host "NOTE: Duplicates are detected by file structure similarity." -ForegroundColor Yellow
        Write-Host "Manual review needed — some 'duplicates' may be legitimate parallel sessions." -ForegroundColor Yellow
        Write-Host "SANCTUARY MANDATE: NEVER delete sessions. Archive (copy) if externalization is needed." -ForegroundColor Red
    }
    Write-Host ""
}

if ($largeSessions.Count -eq 0) {
    Write-Host "No large sessions found. Nothing to archive." -ForegroundColor Green
    exit 0
}

# Display top 10 largest sessions
Write-Host "Top 10 largest sessions:" -ForegroundColor Cyan
$largeSessions | Select-Object -First 10 | Format-Table Project, Session, SizeMB, FileCount -AutoSize

# Apply max sessions limit
$sessionsToArchive = if ($MaxSessions -gt 0) {
    $largeSessions | Select-Object -First $MaxSessions
} else {
    $largeSessions
}

Write-Host ""
Write-Host "Sessions to archive: $($sessionsToArchive.Count)" -ForegroundColor Yellow

# --- Non-destructive archive (#2577 item 1: split/externalize WITHOUT LOSS) ---
if ($ArchivePath) {
    if ($DryRun) {
        Write-Host ""
        Write-Host "DRY RUN: Would copy $($sessionsToArchive.Count) sessions to $ArchivePath" -ForegroundColor Yellow
        Write-Host "Source sessions would remain INTACT on disk (sanctuary mandate)." -ForegroundColor Green
    } else {
        # Create archive root if it doesn't exist
        if (-not (Test-Path $ArchivePath)) {
            New-Item -ItemType Directory -Path $ArchivePath -Force | Out-Null
            Write-Host "Created archive directory: $ArchivePath" -ForegroundColor Green
        }

        $archived = 0
        $failed = 0

        foreach ($session in $sessionsToArchive) {
            $destName = "$($session.Project)_$($session.Session)"
            $destPath = Join-Path $ArchivePath $destName

            Write-Host ""
            Write-Host "Archiving: $($session.Project)\$($session.Session) ($($session.SizeMB) MB)" -ForegroundColor Cyan

            # Check if already archived
            if (Test-Path $destPath) {
                Write-Host "  SKIP: Already exists at $destPath" -ForegroundColor Yellow
                continue
            }

            try {
                # Copy (NEVER move — sanctuary mandate)
                Write-Host "  Copying to $destPath ..." -ForegroundColor Yellow
                Copy-Item -Path $session.Path -Destination $destPath -Recurse -Force

                # Verify: byte-count comparison
                $srcBytes = (Get-ChildItem $session.Path -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
                $dstBytes = (Get-ChildItem $destPath -Recurse -File -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum

                if ($srcBytes -eq $dstBytes) {
                    $archived++
                    Write-Host "  VERIFIED: $srcBytes bytes match ($($session.SizeMB) MB)" -ForegroundColor Green
                } else {
                    $failed++
                    Write-Host "  MISMATCH: src=$srcBytes dst=$dstBytes — source NOT deleted (investigate)" -ForegroundColor Red
                }
            } catch {
                $failed++
                Write-Host "  ERROR: $_" -ForegroundColor Red
            }
        }

        Write-Host ""
        Write-Host "=== Archive Summary ===" -ForegroundColor Cyan
        Write-Host "Archived (verified): $archived" -ForegroundColor Green
        Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Green" })
        Write-Host "Source sessions remain INTACT on disk (sanctuary mandate 2026-06-19)." -ForegroundColor Green
    }
} elseif ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN: No archiving performed." -ForegroundColor Yellow
    Write-Host "To enable non-destructive archive: -ArchivePath 'D:\Archive\claude-sessions'" -ForegroundColor Cyan
    Write-Host ""
}

# Output summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total sessions scanned: $($allSessions.Count)" -ForegroundColor Green
Write-Host "Sessions >= ${ThresholdMB}MB: $($largeSessions.Count)" -ForegroundColor Green
if ($DetectDuplicates) {
    Write-Host "Duplicate groups: $(if ($dupGroups) { $dupGroups.Count } else { 0 })" -ForegroundColor Green
}
Write-Host "Total large-session size: $([math]::Round(($largeSessions | Measure-Object SizeMB -Sum).Sum, 1)) MB" -ForegroundColor Green
Write-Host ""
Write-Host "REMEMBER: Traces are SANCTUARY. This script copies, never deletes." -ForegroundColor Cyan
