<#
.SYNOPSIS
    Install Postgres-Dump-Daily Windows Task Scheduler entry.

.DESCRIPTION
    Validates pg_dump availability, ROOSYNC_SHARED_PATH writability, and
    Postgres reachability, then registers the schtask from the XML template
    with machine-specific placeholders substituted.

    Mirrors scripts/qdrant/install-backup-schtask.ps1 — see #2553 step 6.

.PARAMETER RepoRoot
    Absolute path to roo-extensions repo root. Default: 2 levels above this script.

.PARAMETER TaskName
    Scheduled task name. Default: Postgres-Dump-Daily

.PARAMETER UserId
    Principal UserId for the task. Default: $env:USERDOMAIN\$env:USERNAME.

.PARAMETER PgHost
    Postgres host. Default: $env:PGHOST or 'localhost'.

.PARAMETER PgPort
    Postgres port. Default: $env:PGPORT or 5432.

.PARAMETER PgDatabase
    Database name. Default: $env:PGDATABASE or 'unified_store'.

.PARAMETER Force
    Overwrite existing schtask of the same name.

.EXAMPLE
    .\install-backup-schtask.ps1
    .\install-backup-schtask.ps1 -Force

.NOTES
    Issue #2553 (Epic #2191). Runs on ai-01 ONLY.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$TaskName = 'Postgres-Dump-Daily',
    [string]$UserId = '',
    [string]$PgHost = $(if ($env:PGHOST) { $env:PGHOST } else { 'localhost' }),
    [int]$PgPort = $(if ($env:PGPORT) { [int]$env:PGPORT } else { 5432 }),
    [string]$PgDatabase = $(if ($env:PGDATABASE) { $env:PGDATABASE } else { 'unified_store' }),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path
}
$RepoRoot = $RepoRoot.TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($UserId)) {
    $UserId = if ($env:USERDOMAIN) { "$env:USERDOMAIN\$env:USERNAME" } else { $env:USERNAME }
}

Write-Output "Installing $TaskName"
Write-Output "  RepoRoot:   $RepoRoot"
Write-Output "  UserId:     $UserId"
Write-Output "  Postgres:   $PgHost`:$PgPort/$PgDatabase"

# ========== PREREQUISITES ==========

Write-Output ''
Write-Output 'Pre-flight checks:'

# Check 1: pg_dump available
$pgDump = $null
try {
    $pgDump = (Get-Command pg_dump -ErrorAction Stop).Source
    $version = (& pg_dump --version) 2>&1 | Select-Object -First 1
    Write-Output "  [OK] pg_dump present: $pgDump ($version)"
} catch {
    [Console]::Error.WriteLine("  [FAIL] pg_dump not in PATH: $($_.Exception.Message)")
    [Console]::Error.WriteLine('         Install PostgreSQL client tools (>= 16) on this machine.')
    exit 1
}

# Check 2: ROOSYNC_SHARED_PATH set + derive backup path
$shared = $env:ROOSYNC_SHARED_PATH
if ([string]::IsNullOrWhiteSpace($shared)) {
    [Console]::Error.WriteLine('  [FAIL] $env:ROOSYNC_SHARED_PATH not set')
    exit 1
}
if (-not (Test-Path $shared)) {
    [Console]::Error.WriteLine("  [FAIL] $shared does not exist")
    exit 1
}

# Derive cloud-only backup path (sibling of .shared-state)
$backupRoot = $env:PG_BACKUP_PATH
if ([string]::IsNullOrWhiteSpace($backupRoot)) {
    $sharedResolved = (Resolve-Path $shared -ErrorAction SilentlyContinue)
    if ($sharedResolved) {
        $backupRoot = "$($sharedResolved.Parent.FullName)\pg-backups"
    } else {
        $backupRoot = "$shared\..\pg-backups"
    }
}
if (-not (Test-Path $backupRoot)) {
    Write-Output "  [INFO] Creating backup directory: $backupRoot"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}
$probe = "$backupRoot/.pg-backup-probe-$([Guid]::NewGuid().ToString('N'))"
try {
    'probe' | Set-Content -Path $probe -Encoding utf8
    Remove-Item -Path $probe -Force
    Write-Output "  [OK] Backup path writable: $backupRoot"
} catch {
    [Console]::Error.WriteLine("  [FAIL] $backupRoot not writable: $($_.Exception.Message)")
    exit 1
}

# Check 3: backup script present
$backupScript = "$RepoRoot\scripts\postgres\backup-dump.ps1"
if (-not (Test-Path $backupScript)) {
    [Console]::Error.WriteLine("  [FAIL] backup script not found: $backupScript")
    exit 1
}
Write-Output "  [OK] backup script present"

# Check 4: POSTGRES_PASSWORD available (param > env > .env) — never echo
$pgPasswordSource = ''
$pgPassword = $env:PGPASSWORD
if (-not [string]::IsNullOrWhiteSpace($pgPassword)) {
    $pgPasswordSource = '$env:PGPASSWORD'
} else {
    $envFile = Join-Path $RepoRoot 'mcps/internal/servers/roo-state-manager/.env'
    if (Test-Path $envFile) {
        $line = (Get-Content $envFile | Where-Object { $_ -match '^POSTGRES_PASSWORD=' }) 2>$null
        if ($line) {
            $pgPassword = ($line -replace '^POSTGRES_PASSWORD=', '').Trim()
            $pgPasswordSource = ".env POSTGRES_PASSWORD ($envFile)"
        }
    }
}
if ([string]::IsNullOrWhiteSpace($pgPassword)) {
    [Console]::Error.WriteLine('  [FAIL] POSTGRES_PASSWORD not set (env, .env, or run via schtask env).')
    [Console]::Error.WriteLine('         The schtask will inherit $env:PGPASSWORD at register time;')
    [Console]::Error.WriteLine('         or set POSTGRES_PASSWORD in mcps/internal/.../roo-state-manager/.env')
    exit 1
}
Write-Output "  [OK] POSTGRES_PASSWORD present (source: $pgPasswordSource, value not echoed)"

# Check 5: Postgres reachable (TCP probe only — auth tested by schtask first run)
$tcpOpen = (Test-NetConnection -ComputerName $PgHost -Port $PgPort -WarningAction SilentlyContinue -InformationLevel Quiet)
if ($tcpOpen) {
    Write-Output "  [OK] TCP $PgHost`:$PgPort reachable"
} else {
    [Console]::Error.WriteLine("  [FAIL] TCP $PgHost`:$PgPort unreachable — Postgres must be running before schtask install")
    exit 1
}

# ========== EXISTING TASK CHECK ==========

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    if ($Force) {
        Write-Output ''
        Write-Output "Removing existing $TaskName (-Force)"
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    } else {
        [Console]::Error.WriteLine('')
        [Console]::Error.WriteLine("ERROR: task $TaskName already exists. Use -Force to overwrite.")
        exit 1
    }
}

# ========== RENDER XML ==========

$templatePath = "$PSScriptRoot\Postgres-Dump-Daily.xml"
if (-not (Test-Path $templatePath)) {
    [Console]::Error.WriteLine("ERROR: template not found: $templatePath")
    exit 1
}

$xml = [System.IO.File]::ReadAllText($templatePath, [System.Text.UnicodeEncoding]::new($false, $true))
$xml = $xml.Replace('{{MACHINE_USER}}', $UserId).Replace('{{REPO_ROOT}}', $RepoRoot)

$rendered = "$env:TEMP\$TaskName-$([Guid]::NewGuid().ToString('N')).xml"
[System.IO.File]::WriteAllText($rendered, $xml, [System.Text.UnicodeEncoding]::new($false, $true))

# ========== REGISTER ==========

Write-Output ''
Write-Output 'Registering task...'
try {
    $reg = Register-ScheduledTask -TaskName $TaskName -Xml ([System.IO.File]::ReadAllText($rendered, [System.Text.UnicodeEncoding]::new($false, $true))) -User $UserId -Force
    Write-Output "  [OK] Registered: $($reg.TaskName) (next run: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime))"
} catch {
    [Console]::Error.WriteLine("  [FAIL] Register failed: $($_.Exception.Message)")
    Remove-Item -Path $rendered -Force -ErrorAction SilentlyContinue
    exit 1
} finally {
    Remove-Item -Path $rendered -Force -ErrorAction SilentlyContinue
}

# ========== VERIFICATION INSTRUCTIONS ==========

Write-Output ''
Write-Output 'Verification:'
Write-Output "  Get-ScheduledTask -TaskName $TaskName"
Write-Output "  Get-ScheduledTaskInfo -TaskName $TaskName"
Write-Output "  Start-ScheduledTask -TaskName $TaskName   # trigger one immediate run"
Write-Output "  Get-Content $RepoRoot\outputs\pg-backup\backup-$(Get-Date -Format yyyyMMdd).log -Tail 30"
Write-Output ''
Write-Output 'Dumps will land in (cloud-only, NOT pinned offline):'
Write-Output "  $backupRoot\$($env:COMPUTERNAME.ToLowerInvariant())\<db>\YYYY-MM-DD\"
Write-Output ''
Write-Output 'NOTE: Postgres-Dump-Daily runs on ai-01 ONLY (executors have no local Postgres).'
Write-Output '  Do NOT install this schtask on executor machines (po-2023/24/25/26, web1).'

exit 0
