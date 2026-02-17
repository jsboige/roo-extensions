#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleanup RooSync rollback directories older than specified days.

.DESCRIPTION
    Removes rollback directories from G:/Mon Drive/Synchronisation/RooSync/.shared-state/.rollback/
    that are older than the retention period. Safe by default (DryRun mode).

.PARAMETER OlderThanDays
    Minimum age in days for a rollback to be deleted. Default: 7

.PARAMETER ExcludePattern
    Glob pattern for rollbacks to exclude from deletion. Default: "CRITICAL_*"

.PARAMETER DryRun
    Show what would be deleted without actually deleting. Default: $true

.PARAMETER Force
    Actually delete the rollbacks (overrides DryRun)

.PARAMETER RollbackPath
    Path to the .rollback directory. Default: "G:/Mon Drive/Synchronisation/RooSync/.shared-state/.rollback"

.EXAMPLE
    .\cleanup-rollbacks.ps1
    # Dry run: show rollbacks older than 7 days

.EXAMPLE
    .\cleanup-rollbacks.ps1 -Force
    # Actually delete rollbacks older than 7 days

.EXAMPLE
    .\cleanup-rollbacks.ps1 -OlderThanDays 30 -Force
    # Delete rollbacks older than 30 days
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$OlderThanDays = 7,
    [string]$ExcludePattern = "CRITICAL_*",
    [switch]$DryRun = $true,
    [switch]$Force,
    [string]$RollbackPath = "G:/Mon Drive/Synchronisation/RooSync/.shared-state/.rollback"
)

if ($Force) {
    $DryRun = $false
}

$ErrorActionPreference = "Stop"
$cutoffDate = (Get-Date).AddDays(-$OlderThanDays)
$deletedCount = 0
$skippedCount = 0
$totalSizeBytes = 0

Write-Host "=== RooSync Rollback Cleanup ===" -ForegroundColor Cyan
Write-Host "Rollback Path: $RollbackPath"
Write-Host "Cutoff Date: $($cutoffDate.ToString('yyyy-MM-dd HH:mm:ss')) (older than $OlderThanDays days)"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE DELETION' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })
Write-Host ""

if (-not (Test-Path $RollbackPath)) {
    Write-Host "ERROR: Rollback path not found: $RollbackPath" -ForegroundColor Red
    exit 1
}

# Get all subdirectories in .rollback
$rollbacks = Get-ChildItem -Path $RollbackPath -Directory

Write-Host "Found $($rollbacks.Count) rollback directories" -ForegroundColor Cyan
Write-Host ""

foreach ($rollback in $rollbacks) {
    $name = $rollback.Name

    # Skip excluded patterns
    if ($name -like $ExcludePattern) {
        Write-Host "SKIP [EXCLUDED]: $name" -ForegroundColor DarkGray
        $skippedCount++
        continue
    }

    # Check age based on directory name (contains timestamp)
    # Expected format: PREFIX_YYYY-MM-DDTHH-MM-SS-...
    if ($name -match '(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})') {
        # Convert YYYY-MM-DDTHH-MM-SS to YYYY-MM-DD:HH:MM:SS for PowerShell 5.1
        $timestampStr = $matches[1] -replace 'T', ':' -replace '(?<=\d{4}-\d{2}-\d{2}):', '-'
        # The result will be YYYY-MM-DD:HH-MM-SS, then replace remaining '-' with ':'
        $timestampStr = $timestampStr -replace '(?<=\d{4}-\d{2}-\d{2}):', '-'
        # Simpler approach: split and reassemble
        $parts = $matches[1] -split '[T-]'
        # parts = [YYYY, MM, DD, HH, MM, SS]
        $timestampStr = "$($parts[0])-$($parts[1])-$($parts[2]):$($parts[3]):$($parts[4]):$($parts[5])"
        try {
            $rollbackDate = [DateTime]::ParseExact($timestampStr, 'yyyy-MM-dd:HH:mm:ss', $null)

            if ($rollbackDate -lt $cutoffDate) {
                # Calculate size
                $sizeResult = Get-ChildItem -Path $rollback.FullName -Recurse -File -ErrorAction SilentlyContinue |
                           Measure-Object -Property Length -Sum
                $size = if ($sizeResult -and $sizeResult.Sum) { $sizeResult.Sum } else { 0 }
                $totalSizeBytes += $size
                $sizeStr = if ($size -gt 1MB) { "{0:N1} MB" -f ($size / 1MB) }
                           elseif ($size -gt 1KB) { "{0:N1} KB" -f ($size / 1KB) }
                           else { "$size B" }

                if ($DryRun) {
                    Write-Host "WOULD DELETE: $name ($sizeStr, created $($rollbackDate.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Yellow
                } else {
                    try {
                        Remove-Item -Path $rollback.FullName -Recurse -Force
                        Write-Host "DELETED: $name ($sizeStr)" -ForegroundColor Green
                        $deletedCount++
                    } catch {
                        Write-Host "ERROR deleting $name`: $_" -ForegroundColor Red
                    }
                }
            } else {
                Write-Host "SKIP [TOO RECENT]: $name ($($rollbackDate.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray
                $skippedCount++
            }
        } catch {
            Write-Host "SKIP [PARSE ERROR]: $name" -ForegroundColor DarkGray
            $skippedCount++
        }
    } else {
        # No timestamp in name, use LastWriteTime
        if ($rollback.LastWriteTime -lt $cutoffDate) {
            if ($DryRun) {
                Write-Host "WOULD DELETE: $name (by LastWriteTime: $($rollback.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Yellow
            } else {
                try {
                    Remove-Item -Path $rollback.FullName -Recurse -Force
                    Write-Host "DELETED: $name" -ForegroundColor Green
                    $deletedCount++
                } catch {
                    Write-Host "ERROR deleting $name`: $_" -ForegroundColor Red
                }
            }
        } else {
            $skippedCount++
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($DryRun) {
    $actualDeleted = $rollbacks.Count | Where-Object {
        $name = $_.Name
        if ($name -like $ExcludePattern) { return $false }
        if ($name -match '(\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2})') {
            $parts = $matches[1] -split '[T-]'
            $timestampStr = "$($parts[0])-$($parts[1])-$($parts[2]):$($parts[3]):$($parts[4]):$($parts[5])"
            try {
                $rollbackDate = [DateTime]::ParseExact($timestampStr, 'yyyy-MM-dd:HH:mm:ss', $null)
                return $rollbackDate -lt $cutoffDate
            } catch { return $false }
        }
        return $_.LastWriteTime -lt $cutoffDate
    } | Measure-Object | Select-Object -ExpandProperty Count

    Write-Host "Would delete: $actualDeleted directories" -ForegroundColor Yellow
    $sizeStr = if ($totalSizeBytes -gt 1MB) { "{0:N1} MB" -f ($totalSizeBytes / 1MB) }
               elseif ($totalSizeBytes -gt 1KB) { "{0:N1} KB" -f ($totalSizeBytes / 1KB) }
               else { "$totalSizeBytes B" }
    Write-Host "Space to free: $sizeStr"
} else {
    Write-Host "Deleted: $deletedCount directories" -ForegroundColor Green
    $sizeStr = if ($totalSizeBytes -gt 1MB) { "{0:N1} MB" -f ($totalSizeBytes / 1MB) }
               elseif ($totalSizeBytes -gt 1KB) { "{0:N1} KB" -f ($totalSizeBytes / 1KB) }
               else { "$totalSizeBytes B" }
    Write-Host "Space freed: $sizeStr"
}
Write-Host "Skipped: $skippedCount directories"

exit 0
