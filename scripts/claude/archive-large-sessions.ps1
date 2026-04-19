# Archive Large Claude Code Sessions
# Script to archive sessions larger than a threshold (default 100 MB)
# Usage: .\scripts\claude\archive-large-sessions.ps1 [-ThresholdMB <int>] [-MaxSessions <int>]

param(
    [int]$ThresholdMB = 100,
    [int]$MaxSessions = 0,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

Write-Host "=== Claude Code Session Archiver ===" -ForegroundColor Cyan
Write-Host "Threshold: $ThresholdMB MB" -ForegroundColor Yellow
Write-Host "Max Sessions: $(if ($MaxSessions -gt 0) { $MaxSessions } else { 'All' })" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Get Claude projects path
$projectsPath = Join-Path $env:USERPROFILE ".claude\projects"
if (-not (Test-Path $projectsPath)) {
    Write-Host "ERROR: Claude projects path not found: $projectsPath" -ForegroundColor Red
    exit 1
}

# Scan for large sessions
Write-Host "Scanning for large sessions..." -ForegroundColor Cyan
$largeSessions = @()

Get-ChildItem -Path $projectsPath -Directory | ForEach-Object {
    $projectDir = $_
    $projectSessions = Get-ChildItem -Path $projectDir.FullName -Directory -ErrorAction SilentlyContinue

    foreach ($sessionDir in $projectSessions) {
        # Calculate session size
        $sizeBytes = (Get-ChildItem -Path $sessionDir.FullName -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum

        if ($sizeBytes) {
            $sizeMB = [math]::Round($sizeBytes / 1MB, 1)
            if ($sizeMB -ge $ThresholdMB) {
                $largeSessions += [PSCustomObject]@{
                    Project = $projectDir.Name
                    Session = $sessionDir.Name
                    SizeMB = $sizeMB
                    Path = $sessionDir.FullName
                }
            }
        }
    }
}

# Sort by size (largest first)
$largeSessions = $largeSessions | Sort-Object SizeMB -Descending

Write-Host "Found $($largeSessions.Count) sessions >= ${ThresholdMB}MB" -ForegroundColor Yellow
Write-Host ""

if ($largeSessions.Count -eq 0) {
    Write-Host "No large sessions found. Nothing to archive." -ForegroundColor Green
    exit 0
}

# Display top 10 largest sessions
Write-Host "Top 10 largest sessions:" -ForegroundColor Cyan
$largeSessions | Select-Object -First 10 | Format-Table -AutoSize

# Apply max sessions limit
$sessionsToArchive = if ($MaxSessions -gt 0) {
    $largeSessions | Select-Object -First $MaxSessions
} else {
    $largeSessions
}

Write-Host ""
Write-Host "Sessions to archive: $($sessionsToArchive.Count)" -ForegroundColor Yellow

if ($DryRun) {
    Write-Host ""
    Write-Host "DRY RUN: No archiving performed. Use -DryRun:`$false to archive." -ForegroundColor Yellow
    exit 0
}

# Archive sessions using roo-state-manager
Write-Host ""
Write-Host "To archive these sessions, use the roosync_indexing MCP tool:" -ForegroundColor Yellow
Write-Host "  roosync_indexing(action: 'archive', claude_code_sessions: true, max_sessions: $($sessionsToArchive.Count))" -ForegroundColor Cyan
Write-Host ""

# Output summary
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Total sessions scanned: $($largeSessions.Count)" -ForegroundColor Green
Write-Host "Sessions to archive: $($sessionsToArchive.Count)" -ForegroundColor Green
Write-Host "Total size to free: $([math]::Round(($sessionsToArchive | Measure-Object SizeMB -Sum).Sum, 1)) MB" -ForegroundColor Green
