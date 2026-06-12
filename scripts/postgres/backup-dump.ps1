<#
.SYNOPSIS
    Postgres Backup Layer 1 — daily pg_dump to GDrive shared folder.

.DESCRIPTION
    Daily pg_dump (custom format, compressed) of the unified_store database
    on ai-01. Output pushed to a cloud-only GDrive path (sibling of .shared-state,
    same convention as qdrant-backups per jsboige/jsboige-mcp-servers#608).
    Retention: 7 daily + 4 weekly (Mondays). Idempotent per day.

    Mirrors scripts/qdrant/backup-snapshot.ps1 — see #2553 step 6.

.PARAMETER PgHost
    Postgres host. Default: $env:PGHOST or 'localhost'. Use pg.myia.io for
    remote backup (rare; daily schtask runs on ai-01 where the DB lives).

.PARAMETER PgPort
    Postgres port. Default: $env:PGPORT or 5432.

.PARAMETER PgDatabase
    Database name. Default: $env:PGDATABASE or 'unified_store'.

.PARAMETER PgUser
    Postgres user. Default: $env:PGUSER or 'postgres'.

.PARAMETER PgPassword
    Postgres password. If empty, reads $env:PGPASSWORD then
    ./.env (POSTGRES_PASSWORD key) in the submodule. NEVER echoed.

.PARAMETER SslMode
    sslmode connection parameter. Default: 'require' (per #2553 step 4 TLS decision).

.PARAMETER MachineId
    Machine identifier for the dump path. Default: $env:COMPUTERNAME (lowercased).

.PARAMETER SharedPath
    Override for $env:ROOSYNC_SHARED_PATH. Used to derive the backup path parent.

.PARAMETER BackupPath
    Override for the backup storage root. Default: parent of $ROOSYNC_SHARED_PATH
    + "/pg-backups". Set $env:PG_BACKUP_PATH as persistent alternative.

.PARAMETER PgDumpExe
    Override pg_dump executable path. Default: pg_dump from PATH.

.PARAMETER WhatIf
    Dry-run: print intended actions but do not dump or delete.

.PARAMETER LogDir
    Directory for log files. Default: ./outputs/pg-backup

.EXAMPLE
    .\backup-dump.ps1
    .\backup-dump.ps1 -PgDatabase unified_store -WhatIf

.NOTES
    Issue #2553 (Epic #2191).
    Sister install script: install-backup-schtask.ps1.
    Runs on ai-01 ONLY (executors have no local Postgres).
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { 'localhost' }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgDatabase = $(if ($env:PGDATABASE) { $env:PGDATABASE } else { 'unified_store' }),
    [string]$PgUser = $(if ($env:PGUSER) { $env:PGUSER } else { 'postgres' }),
    [string]$PgPassword = '',
    [string]$SslMode = 'require',
    [string]$MachineId = '',
    [string]$SharedPath = '',
    [string]$BackupPath = '',
    [string]$PgDumpExe = 'pg_dump',
    [string]$LogDir = './outputs/pg-backup'
)

$ErrorActionPreference = 'Stop'

# ========== RESOLVE INPUTS ==========

if ([string]::IsNullOrWhiteSpace($SharedPath)) { $SharedPath = $env:ROOSYNC_SHARED_PATH }
if ([string]::IsNullOrWhiteSpace($SharedPath)) {
    [Console]::Error.WriteLine('ERROR: $env:ROOSYNC_SHARED_PATH not set and -SharedPath not provided.')
    exit 1
}

# Resolve backup path: outside .shared-state to avoid GDrive offline pin
if ([string]::IsNullOrWhiteSpace($BackupPath)) { $BackupPath = $env:PG_BACKUP_PATH }
if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $rooSyncRoot = (Resolve-Path $SharedPath -ErrorAction SilentlyContinue)
    if ($rooSyncRoot) {
        $BackupPath = "$($rooSyncRoot.Parent.FullName)/pg-backups"
    } else {
        $BackupPath = "$SharedPath/../pg-backups"
    }
}

if ([string]::IsNullOrWhiteSpace($MachineId)) {
    $MachineId = if ($env:COMPUTERNAME) { $env:COMPUTERNAME.ToLowerInvariant() } else { (hostname).ToLowerInvariant() }
}

# Resolve password: param > env > .env (never echo)
if ([string]::IsNullOrWhiteSpace($PgPassword)) {
    $PgPassword = $env:PGPASSWORD
    if ([string]::IsNullOrWhiteSpace($PgPassword)) {
        $envFile = Join-Path $PSScriptRoot '../../mcps/internal/servers/roo-state-manager/.env'
        if (Test-Path $envFile) {
            $line = (Get-Content $envFile | Where-Object { $_ -match '^POSTGRES_PASSWORD=' })
            if ($line) { $PgPassword = $line -replace '^POSTGRES_PASSWORD=', '' }
        }
    }
}

if ([string]::IsNullOrWhiteSpace($PgPassword)) {
    [Console]::Error.WriteLine('ERROR: Postgres password not provided (param, $env:PGPASSWORD, or .env POSTGRES_PASSWORD).')
    exit 1
}

# ========== VERIFY pg_dump AVAILABLE ==========

$pgDumpResolved = $null
try {
    $pgDumpResolved = (Get-Command $PgDumpExe -ErrorAction Stop).Source
} catch {
    [Console]::Error.WriteLine("ERROR: pg_dump not found in PATH. Install PostgreSQL client tools (>= 16) or pass -PgDumpExe.")
    exit 1
}

# ========== PATHS ==========

$today = Get-Date -Format 'yyyy-MM-dd'
$dateStamp = Get-Date -Format 'yyyyMMdd'
$dumpRoot = "$BackupPath/$MachineId/$PgDatabase"
$dumpDayDir = "$dumpRoot/$today"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$logFile = "$LogDir/backup-$dateStamp.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    $line = "[$ts] [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Information $line -InformationAction Continue
}

Write-Log "Backup start: machine=$MachineId db=$PgDatabase host=$PgHost`:$PgPort ssl=$SslMode backupRoot=$dumpRoot"

# ========== IDEMPOTENCY CHECK ==========

$existingToday = @()
if (Test-Path $dumpDayDir) {
    $existingToday = @(Get-ChildItem -Path $dumpDayDir -Filter '*.dump' -File -ErrorAction SilentlyContinue)
}

if ($existingToday.Count -gt 0) {
    Write-Log "Idempotent skip: $($existingToday.Count) dump(s) already exist for $today in $dumpDayDir"
} else {
    if (-not (Test-Path $dumpDayDir)) { New-Item -ItemType Directory -Path $dumpDayDir -Force | Out-Null }

    $dumpFile = "$dumpDayDir/${PgDatabase}-${dateStamp}.dump"

    # Connection string with sslmode; PGPASSWORD env avoids leaking in process args
    if ($PSCmdlet.ShouldProcess("$PgHost`:$PgPort/$PgDatabase", "pg_dump (custom format) -> $dumpFile")) {
        $env:PGPASSWORD = $PgPassword
        try {
            $args = @(
                '-Fc',
                '--no-owner',
                '--no-privileges',
                '-h', $PgHost,
                '-p', "$PgPort",
                '-U', $PgUser,
                '-d', $PgDatabase,
                '--option=sslmode=' + $SslMode,
                '-f', $dumpFile
            )
            Write-Log "Invoking: $pgDumpResolved $($args -join ' ')"
            $process = Start-Process -FilePath $pgDumpResolved -ArgumentList $args -NoNewWindow -Wait -PassThru -ErrorAction Stop
            if ($process.ExitCode -ne 0) {
                Write-Log "FATAL: pg_dump exit code $($process.ExitCode)" 'ERROR'
                [Console]::Error.WriteLine("pg_dump failed with exit code $($process.ExitCode)")
                exit 1
            }
        } catch {
            Write-Log "FATAL: pg_dump invocation failed: $($_.Exception.Message)" 'ERROR'
            [Console]::Error.WriteLine("pg_dump invocation failed: $($_.Exception.Message)")
            exit 1
        } finally {
            # Clear credential from env ASAP
            Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
        }

        if (-not (Test-Path $dumpFile)) {
            Write-Log "FATAL: dump file not created at $dumpFile" 'ERROR'
            exit 1
        }
        $dumpSize = (Get-Item $dumpFile).Length
        Write-Log "Dump created: path=$dumpFile size=$dumpSize bytes"
    } else {
        Write-Log "WhatIf: would pg_dump $PgDatabase into $dumpFile"
    }
}

# ========== RETENTION ==========

if (-not (Test-Path $dumpRoot)) {
    Write-Log "No dump root yet ($dumpRoot); retention skipped"
    Write-Log 'Backup done'
    exit 0
}

$dayDirs = Get-ChildItem -Path $dumpRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' }

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
        if ($PSCmdlet.ShouldProcess($d.FullName, 'Remove old dump directory')) {
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
