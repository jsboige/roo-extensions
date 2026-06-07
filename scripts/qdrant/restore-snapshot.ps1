<#
.SYNOPSIS
    Qdrant Backup Layer 1 — restore a snapshot file into a collection.

.DESCRIPTION
    Uploads a .snapshot file to Qdrant via PUT /collections/{c}/snapshots/upload.
    Optionally drops the target collection first (-RecreateCollection).
    Confirms restored point count and writes to the same log directory as backup-snapshot.ps1.

.PARAMETER SnapshotPath
    Full path to the .snapshot file (cloud-only qdrant-backups path, sibling of .shared-state).
    See backup-snapshot.ps1 for path resolution (jsboige/jsboige-mcp-servers#608).

.PARAMETER Collection
    Target collection name.

.PARAMETER QdrantUrl
    Qdrant API URL. Default: $env:QDRANT_URL or http://localhost:6333

.PARAMETER ApiKey
    Qdrant API key. If empty, reads $env:QDRANT_API_KEY then submodule .env.

.PARAMETER RecreateCollection
    Drop the target collection (DELETE /collections/{c}) before upload. DESTRUCTIVE.

.PARAMETER Force
    Skip the interactive destructive-operation confirmation prompt.

.PARAMETER LogDir
    Directory for log files. Default: ./outputs/qdrant-backup

.EXAMPLE
    .\restore-snapshot.ps1 -SnapshotPath G:\Mon Drive\...\snap.snapshot -Collection roo_tasks_semantic_index
    .\restore-snapshot.ps1 -SnapshotPath .\snap.snapshot -Collection my_col -RecreateCollection -Force

.NOTES
    Approved by user 2026-05-18 (Qdrant Backup Layer 1).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)][string]$SnapshotPath,
    [Parameter(Mandatory = $true)][string]$Collection,
    [string]$QdrantUrl = $(if ($env:QDRANT_URL) { $env:QDRANT_URL } else { 'http://localhost:6333' }),
    [string]$ApiKey = '',
    [switch]$RecreateCollection,
    [switch]$Force,
    [string]$LogDir = './outputs/qdrant-backup'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SnapshotPath)) {
    [Console]::Error.WriteLine("ERROR: snapshot file not found: $SnapshotPath")
    exit 1
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

$jsonHeaders = @{ 'Content-Type' = 'application/json' }
if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $jsonHeaders['api-key'] = $ApiKey }

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$dateStamp = Get-Date -Format 'yyyyMMdd'
$logFile = "$LogDir/restore-$dateStamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Information $line -InformationAction Continue
}

$snapInfo = Get-Item $SnapshotPath
Write-Log "Restore start: snapshot=$($snapInfo.FullName) size=$($snapInfo.Length) collection=$Collection target=$QdrantUrl"

# ========== DESTRUCTIVE CONFIRMATION ==========

if ($RecreateCollection) {
    [Console]::Error.WriteLine('')
    [Console]::Error.WriteLine('  WARNING: THIS WILL DROP THE COLLECTION before restore.')
    [Console]::Error.WriteLine("  Target: $QdrantUrl / $Collection")
    [Console]::Error.WriteLine("  Source: $SnapshotPath")
    [Console]::Error.WriteLine('')

    if (-not $Force) {
        $answer = Read-Host 'Type DROP to continue, anything else to abort'
        if ($answer -ne 'DROP') {
            Write-Log 'User aborted destructive restore (no DROP confirmation)' 'WARN'
            [Console]::Error.WriteLine('Aborted.')
            exit 1
        }
    }

    if ($PSCmdlet.ShouldProcess("$QdrantUrl/collections/$Collection", 'DELETE collection')) {
        try {
            $null = Invoke-RestMethod -Uri "$QdrantUrl/collections/$Collection" -Headers $jsonHeaders -Method Delete -TimeoutSec 120
            Write-Log "Collection dropped: $Collection"
        } catch {
            Write-Log "WARN: collection drop failed (may not exist yet): $($_.Exception.Message)" 'WARN'
        }
    }
}

# ========== UPLOAD ==========

if (-not $PSCmdlet.ShouldProcess("$QdrantUrl/collections/$Collection/snapshots/upload", 'PUT upload snapshot')) {
    Write-Log 'WhatIf: would upload snapshot — exiting'
    exit 0
}

try {
    $uploadHeaders = @{}
    if (-not [string]::IsNullOrWhiteSpace($ApiKey)) { $uploadHeaders['api-key'] = $ApiKey }

    $uploadResp = Invoke-WebRequest -Uri "$QdrantUrl/collections/$Collection/snapshots/upload" `
        -Headers $uploadHeaders `
        -Method Post `
        -Form @{ snapshot = Get-Item -Path $SnapshotPath } `
        -TimeoutSec 3600
    Write-Log "Upload HTTP $($uploadResp.StatusCode)"
} catch {
    Write-Log "FATAL: upload failed: $($_.Exception.Message)" 'ERROR'
    [Console]::Error.WriteLine("Upload failed: $($_.Exception.Message)")
    exit 1
}

# ========== VERIFY ==========

Start-Sleep -Seconds 2
try {
    $info = Invoke-RestMethod -Uri "$QdrantUrl/collections/$Collection" -Headers $jsonHeaders -Method Get -TimeoutSec 60
    $pts = $info.result.points_count
    $status = $info.result.status
    Write-Log "Restored collection: status=$status points=$pts"
    Write-Output "Restore complete: $Collection points=$pts status=$status"
} catch {
    Write-Log "WARN: verification GET failed: $($_.Exception.Message)" 'WARN'
}

exit 0
