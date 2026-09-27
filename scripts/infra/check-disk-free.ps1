<#
.SYNOPSIS
    Measures fixed-drive free space and warns/blocks on fleet thresholds (#3900).

.DESCRIPTION
    Fleet rule (po-203:Maintenance, 2026-09-27 14:21Z, IISManagement dashboard):
    measure C:/D: at every session start; <15% clean own artifacts; <5% stop + [WARN].
    This script MEASURES AND WARNS ONLY - it never deletes anything.

    G: (Google Drive FS) is excluded by default: DriveFS reports the Drive quota,
    which has its own tracking (#3893), not local disk health. DriveFS also masks
    as DriveType 3 (fixed), so the exclusion is by letter, not by type.

    Exit codes (consumed by scripts/claude/executor-preflight.ps1):
      0 - every measured drive is at or above the warn threshold (nominal)
      2 - at least one drive below -WarnPercent (warn: clean own artifacts)
      3 - at least one drive below -BlockPercent (block: worker must stop)
      1 - measurement itself failed (never silent; treated as warn by callers)

.PARAMETER Drive
    Drive letters to measure, e.g. @('C:','D:'). Default: every DriveType 3
    logical disk with a letter, minus G:.

.PARAMETER WarnPercent
    Percentage of free space under which a drive is in WARN state. Default 15.

.PARAMETER BlockPercent
    Percentage of free space under which a drive is in BLOCK state. Default 5.

.EXAMPLE
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/infra/check-disk-free.ps1
#>
[CmdletBinding()]
param(
    [string[]]$Drive,
    [int]$WarnPercent = 15,
    [int]$BlockPercent = 5
)

$ErrorActionPreference = 'Stop'

if (-not $Drive -or $Drive.Count -eq 0) {
    $Drive = @(Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3 AND DeviceID LIKE '%:'" |
        Where-Object { $_.DeviceID -ne 'G:' } |
        ForEach-Object { $_.DeviceID })
}

if ($Drive.Count -eq 0) {
    Write-Warning '[check-disk-free] No fixed drive found to measure.'
    exit 1
}

$worstState = 0   # 0 nominal, 2 warn, 3 block
$worstDrive = ''

foreach ($letter in $Drive) {
    $disk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $letter)
    if (-not $disk -or -not $disk.Size -or $disk.Size -eq 0) {
        Write-Warning ("[check-disk-free] {0}: unreadable or zero-sized - measurement failed." -f $letter)
        exit 1
    }

    $freeBytes = [double]$disk.FreeSpace
    $sizeBytes = [double]$disk.Size
    # Decide on the raw value, display rounded: a 4.96% drive must block even
    # though it renders as "5.0%" (review nit on #3908).
    $freePercentRaw = ($freeBytes / $sizeBytes) * 100
    $freePercent = [math]::Round($freePercentRaw, 1)
    $freeGB = [math]::Round($freeBytes / 1GB, 1)
    $sizeGB = [math]::Round($sizeBytes / 1GB, 1)

    if ($freePercentRaw -lt $BlockPercent) {
        Write-Output ("[BLOCK] {0} {1}% free ({2} GB / {3} GB) - below {4}% : worker must STOP and post [WARN] dashboard (fleet rule 27/09, #3900)" -f $letter, $freePercent, $freeGB, $sizeGB, $BlockPercent)
        if ($worstState -lt 3) { $worstState = 3; $worstDrive = $letter }
    } elseif ($freePercentRaw -lt $WarnPercent) {
        Write-Output ("[WARN] {0} {1}% free ({2} GB / {3} GB) - below {4}% : clean own artifacts this cycle (fleet rule 27/09, #3900)" -f $letter, $freePercent, $freeGB, $sizeGB, $WarnPercent)
        if ($worstState -lt 2) { $worstState = 2; $worstDrive = $letter }
    } else {
        Write-Output ("[OK] {0} {1}% free ({2} GB / {3} GB)" -f $letter, $freePercent, $freeGB, $sizeGB)
    }
}

if ($worstState -eq 3) {
    Write-Output ("[check-disk-free] BLOCK: {0} below {1}% free. Measure-only script - nothing was deleted. Remedy: free space (own artifacts first), then re-run." -f $worstDrive, $BlockPercent)
} elseif ($worstState -eq 2) {
    Write-Output ("[check-disk-free] WARN: {0} below {1}% free. Measure-only script - nothing was deleted." -f $worstDrive, $WarnPercent)
}

exit $worstState
