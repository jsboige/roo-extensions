<#
.SYNOPSIS
    Qdrant Backup Layer 1 — daily snapshots to GDrive shared folder.

.DESCRIPTION
    Triggers a Qdrant snapshot via REST API, downloads the binary .snapshot file,
    and pushes it to a cloud-only GDrive path (sibling of .shared-state).
    Applies retention: 7 daily + 4 weekly (Mondays). Idempotent per day.

    Snapshot path resolution (first match wins):
      1. -BackupPath parameter
      2. $env:QDRANT_BACKUP_PATH
      3. Parent of $ROOSYNC_SHARED_PATH + "/qdrant-backups"
         (e.g. "G:\...\RooSync\qdrant-backups\" — cloud-only, NOT pinned offline)

.PARAMETER QdrantUrl
    Qdrant API URL. Default: $env:QDRANT_URL or http://localhost:6333

.PARAMETER ApiKey
    Qdrant API key. If empty, reads $env:QDRANT_API_KEY then submodule .env.

.PARAMETER Collection
    Collection name. Default: roo_tasks_semantic_index

.PARAMETER MachineId
    Machine identifier for the snapshot path. Default: $env:COMPUTERNAME (lowercased).

.PARAMETER SharedPath
    Override for $env:ROOSYNC_SHARED_PATH. Used only to derive the backup path parent
    when -BackupPath is not set. Snapshots are NOT stored inside .shared-state (#608).

.PARAMETER BackupPath
    Override for the snapshot storage root. Default: parent of $ROOSYNC_SHARED_PATH
    + "/qdrant-backups". Set $env:QDRANT_BACKUP_PATH as persistent alternative.

.PARAMETER WhatIf
    Dry-run: print intended actions but do not create or delete snapshots.

.PARAMETER LogDir
    Directory for log files. Default: ./outputs/qdrant-backup

.EXAMPLE
    .\backup-snapshot.ps1
    .\backup-snapshot.ps1 -Collection roo_tasks_semantic_index -WhatIf

.NOTES
    Approved by user 2026-05-18 (Qdrant Backup Layer 1).
    Sister: restore-snapshot.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$QdrantUrl = $(if ($env:QDRANT_URL) { $env:QDRANT_URL } else { 'http://localhost:6333' }),
    [string]$ApiKey = '',
    [string]$Collection = 'roo_tasks_semantic_index',
    [string]$MachineId = '',
    [string]$SharedPath = '',
    [string]$BackupPath = '',
    [string]$LogDir = './outputs/qdrant-backup'
)

$ErrorActionPreference = 'Stop'

# ========== RESOLVE INPUTS ==========

if ([string]::IsNullOrWhiteSpace($SharedPath)) { $SharedPath = $env:ROOSYNC_SHARED_PATH }
if ([string]::IsNullOrWhiteSpace($SharedPath)) {
    [Console]::Error.WriteLine('ERROR: $env:ROOSYNC_SHARED_PATH not set and -SharedPath not provided.')
    exit 1
}

# Resolve backup path: outside .shared-state to avoid GDrive offline pin (#608)
if ([string]::IsNullOrWhiteSpace($BackupPath)) { $BackupPath = $env:QDRANT_BACKUP_PATH }
if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    # Derive from ROOSYNC_SHARED_PATH parent: .shared-state -> ../qdrant-backups
    $rooSyncRoot = (Resolve-Path $SharedPath -ErrorAction SilentlyContinue)
    if ($rooSyncRoot) {
        $BackupPath = "$($rooSyncRoot.Parent.FullName)/qdrant-backups"
    } else {
        # Fallback: strip .shared-state suffix
        $BackupPath = "$SharedPath/../qdrant-backups"
    }
}

if ([string]::IsNullOrWhiteSpace($MachineId)) {
    $MachineId = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLowerInvariant() } else { (hostname).ToLowerInvariant() }
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    $ApiKey = $env:QDRANT_API_KEY
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $envFile = Join-Path $PSScriptRoot '../../mcps/internal/servers/roo-state-manager/.env'
        if (Test-Path $envFile) {
            $line = (Get-Content $envFile | Where-Object { $_ -match '^QDRANT_API_KEY=' })
            if ($line) { $ApiKey = $line -replace '^QDRANT_API_KEY=', '' }
        }
    }
}

$headers = @{ 'Content-Type' = 'application/json' }
if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $headers['api-key'] = $ApiKey }

# ========== PATHS ==========

$today = Get-Date -Format 'yyyy-MM-dd'
$dateStamp = Get-Date -Format 'yyyyMMdd'
$snapshotRoot = "$BackupPath/$MachineId/$Collection"
$snapshotDayDir = "$snapshotRoot/$today"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$logFile = "$LogDir/backup-$dateStamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Information $line -InformationAction Continue
}

Write-Log "Backup start: machine=$MachineId collection=$Collection qdrant=$QdrantUrl backupRoot=$snapshotRoot"

# ========== IDEMPOTENCY CHECK ==========

$existingToday = @()
if (Test-Path $snapshotDayDir) {
    $existingToday = @(Get-ChildItem -Path $snapshotDayDir -Filter '*.snapshot' -File -ErrorAction SilentlyContinue)
}

if ($existingToday.Count -gt 0) {
    Write-Log "Idempotent skip: $($existingToday.Count) snapshot(s) already exist for $today in $snapshotDayDir"
} else {
    if ($PSCmdlet.ShouldProcess("$QdrantUrl/collections/$Collection/snapshots", 'POST create snapshot')) {
        try {
            $createResp = Invoke-RestMethod -Uri "$QdrantUrl/collections/$Collection/snapshots" -Headers $headers -Method Post -TimeoutSec 600
        } catch {
            Write-Log "FATAL: snapshot creation failed: $($_.Exception.Message)" 'ERROR'
            [Console]::Error.WriteLine("Snapshot creation failed: $($_.Exception.Message)")
            exit 1
        }

        $snapName = $createResp.result.name
        $snapSize = $createResp.result.size
        if ([string]::IsNullOrWhiteSpace($snapName)) {
            Write-Log "FATAL: snapshot response missing name field" 'ERROR'
            [Console]::Error.WriteLine('Snapshot response did not include a name')
            exit 1
        }
        Write-Log "Snapshot created on server: name=$snapName size=$snapSize bytes"

        if (-not (Test-Path $snapshotDayDir)) { New-Item -ItemType Directory -Path $snapshotDayDir -Force | Out-Null }
        $destPath = "$snapshotDayDir/$snapName"

        try {
            $downloadHeaders = @{}
            if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $downloadHeaders['api-key'] = $ApiKey }
            Invoke-WebRequest -Uri "$QdrantUrl/collections/$Collection/snapshots/$snapName" -Headers $downloadHeaders -OutFile $destPath -TimeoutSec 1800
        } catch {
            Write-Log "FATAL: download failed: $($_.Exception.Message)" 'ERROR'
            [Console]::Error.WriteLine("Snapshot download failed: $($_.Exception.Message)")
            exit 1
        }

        $localSize = (Get-Item $destPath).Length
        Write-Log "Snapshot downloaded: path=$destPath size=$localSize bytes"

        try {
            $null = Invoke-RestMethod -Uri "$QdrantUrl/collections/$Collection/snapshots/$snapName" -Headers $headers -Method Delete -TimeoutSec 120
            Write-Log "Server-side snapshot cleaned: $snapName"
        } catch {
            Write-Log "WARN: server-side cleanup failed (non-fatal): $($_.Exception.Message)" 'WARN'
        }
    } else {
        Write-Log "WhatIf: would create + download snapshot for $Collection into $snapshotDayDir"
    }
}

# ========== RETENTION ==========

if (-not (Test-Path $snapshotRoot)) {
    Write-Log "No snapshot root yet ($snapshotRoot); retention skipped"
    Write-Log 'Backup done'
    exit 0
}

$dayDirs = Get-ChildItem -Path $snapshotRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }

$keep = New-Object System.Collections.Generic.HashSet[string]
$now = Get-Date

# Last 7 daily
$daily = $dayDirs | Sort-Object Name -Descending | Select-Object -First 7
foreach ($d in $daily) { [void]$keep.Add($d.Name) }

# Last 4 weekly Mondays
$mondays = $dayDirs | Where-Object {
    try { ([DateTime]::ParseExact($_.Name, 'yyyy-MM-dd', $null)).DayOfWeek -eq [DayOfWeek]::Monday } catch { $false }
} | Sort-Object Name -Descending | Select-Object -First 4
foreach ($m in $mondays) { [void]$keep.Add($m.Name) }

$deleted = 0
foreach ($d in $dayDirs) {
    if (-not $keep.Contains($d.Name)) {
        if ($PSCmdlet.ShouldProcess($d.FullName, 'Remove old snapshot directory')) {
            try {
                Remove-Item -Path $d.FullName -Recurse -Force
                Write-Log "Retention deleted: $($d.Name)"
                $deleted++
            } catch {
                Write-Log "WARN: failed to delete $($d.Name): $($_.Exception.Message)" 'WARN'
            }
        } else {
            Write-Log "WhatIf: would delete $($d.Name)"
        }
    }
}

Write-Log "Retention complete: kept=$($keep.Count) deleted=$deleted"
Write-Log 'Backup done'
exit 0
