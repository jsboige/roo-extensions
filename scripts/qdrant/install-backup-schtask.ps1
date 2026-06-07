<#
.SYNOPSIS
    Install Qdrant-Snapshot-Daily Windows Task Scheduler entry.

.DESCRIPTION
    Validates Qdrant reachability and $ROOSYNC_SHARED_PATH writability, then registers
    the schtask from the XML template, substituting machine-specific placeholders.

.PARAMETER RepoRoot
    Absolute path to roo-extensions repo root. Default: 2 levels above this script.

.PARAMETER TaskName
    Scheduled task name. Default: Qdrant-Snapshot-Daily

.PARAMETER UserId
    Principal UserId for the task. Default: $env:USERDOMAIN\$env:USERNAME.

.PARAMETER QdrantUrl
    Qdrant URL used by the pre-flight check. Default: http://localhost:6333

.PARAMETER Force
    Overwrite existing schtask of the same name.

.EXAMPLE
    .\install-backup-schtask.ps1
    .\install-backup-schtask.ps1 -Force

.NOTES
    Approved by user 2026-05-18 (Qdrant Backup Layer 1).
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$TaskName = 'Qdrant-Snapshot-Daily',
    [string]$UserId = '',
    [string]$QdrantUrl = $(if ($env:QDRANT_URL) { $env:QDRANT_URL } else { 'http://localhost:6333' }),
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
Write-Output "  RepoRoot: $RepoRoot"
Write-Output "  UserId:   $UserId"
Write-Output "  Qdrant:   $QdrantUrl"

# ========== PREREQUISITES ==========

Write-Output ''
Write-Output 'Pre-flight checks:'

# Check 1: Qdrant reachable
try {
    $null = Invoke-RestMethod -Uri "$QdrantUrl/" -TimeoutSec 5
    Write-Output "  [OK] Qdrant reachable at $QdrantUrl"
} catch {
    [Console]::Error.WriteLine("  [FAIL] Qdrant unreachable at $QdrantUrl : $($_.Exception.Message)")
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

# Derive cloud-only backup path (sibling of .shared-state, #608)
$backupRoot = $env:QDRANT_BACKUP_PATH
if ([string]::IsNullOrWhiteSpace($backupRoot)) {
    $sharedResolved = (Resolve-Path $shared -ErrorAction SilentlyContinue)
    if ($sharedResolved) {
        $backupRoot = "$($sharedResolved.Parent.FullName)\qdrant-backups"
    } else {
        $backupRoot = "$shared\..\qdrant-backups"
    }
}
if (-not (Test-Path $backupRoot)) {
    Write-Output "  [INFO] Creating backup directory: $backupRoot"
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}
$probe = "$backupRoot/.qdrant-backup-probe-$([Guid]::NewGuid().ToString('N'))"
try {
    'probe' | Set-Content -Path $probe -Encoding utf8
    Remove-Item -Path $probe -Force
    Write-Output "  [OK] Backup path writable: $backupRoot"
} catch {
    [Console]::Error.WriteLine("  [FAIL] $backupRoot not writable: $($_.Exception.Message)")
    exit 1
}

# Check 3: backup script present
$backupScript = "$RepoRoot\scripts\qdrant\backup-snapshot.ps1"
if (-not (Test-Path $backupScript)) {
    [Console]::Error.WriteLine("  [FAIL] backup script not found: $backupScript")
    exit 1
}
Write-Output "  [OK] backup script present"

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

$templatePath = "$PSScriptRoot\Qdrant-Snapshot-Daily.xml"
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
Write-Output "  Get-Content $RepoRoot\outputs\qdrant-backup\backup-$(Get-Date -Format yyyyMMdd).log -Tail 30"
Write-Output ''
Write-Output 'Snapshots will land in (cloud-only, NOT pinned offline):'
Write-Output "  $backupRoot\$($env:COMPUTERNAME.ToLowerInvariant())\<collection>\YYYY-MM-DD\"
Write-Output ''
Write-Output 'NOTE: After first run, release the old .shared-state/qdrant-snapshots/ offline pin'
Write-Output '  via Google Drive Desktop UI (right-click → "Free up space") to reclaim ~62 GB.'

exit 0
