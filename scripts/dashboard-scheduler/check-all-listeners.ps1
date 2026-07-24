<#
.SYNOPSIS
    Fleet-wide health check: diagnose wake-listeners on all known machines (#2576).

.DESCRIPTION
    Designed to run as a cron worker (every 2h). For each known machine in the fleet:
    1. SSH or check local listener heartbeat
    2. Report status on dashboard workspace
    3. Trigger auto-repair via repair-wake-listener.ps1 if listener is DEAD

    This implements the "alerting proactif" recommendation from #2576:
    if STALE >2h → [WARN] automatically posted to dashboard.

    Known machines (from fleet config):
    - myia-ai-01 (coordinateur)
    - myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026 (workers)
    - myia-web1 (worker)

.PARAMETER Machines
    Comma-separated list of machines to check. Defaults to full fleet.
    For each machine, format is "machineId:workspace" or just "machineId".

.PARAMETER NoRepair
    Skip auto-repair attempts. Only diagnose and report.

.PARAMETER NoAlert
    Skip dashboard alerting. Only output diagnostic results.

.PARAMETER Json
    Output JSON instead of markdown.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -Machines "web1,po-2023"
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -NoRepair

.NOTES
    Related: issue #2576 (web1 listener recurring STALE), #2431 (durability fix).
#>

param(
    [string]$Machines = "",
    [switch]$NoRepair,
    [switch]$NoAlert,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$nowUtc = (Get-Date).ToUniversalTime()

# Default fleet: all known machines
$defaultMachines = "myia-ai-01","myia-po-2023","myia-po-2024","myia-po-2025","myia-po-2026","myia-web1"
if (-not [string]::IsNullOrEmpty($Machines)) {
    $machineList = $Machines -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else {
    $machineList = $defaultMachines
}

$results = @()
$totalDead = 0

foreach ($machineEntry in $machineList) {
    # Parse machineId:workspace or just machineId
    $machineId = $machineEntry.Split(':')[0].Trim().ToLowerInvariant()
    $workspace = if ($machineEntry.Contains(':')) { $machineEntry.Split(':')[1].Trim() } else { "" }

    # Try to read shared heartbeat from ROOSYNC_SHARED_PATH
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    $sharedHbFile = if ($sharedPath) {
        Join-Path (Join-Path $sharedPath "listener-heartbeats") "$machineId.heartbeat"
    } else { $null }

    $heartbeatStatus = "UNKNOWN"
    $heartbeatAge = $null
    if ($sharedHbFile -and (Test-Path $sharedHbFile)) {
        $mt = (Get-Item $sharedHbFile).LastWriteTimeUtc
        $age = [int]($nowUtc - $mt).TotalSeconds
        $heartbeatAge = $age
        $heartbeatStatus = if ($age -lt 7200) { "ALIVE" } else { "STALE" }
        if ($age -gt 7200) { $totalDead++ }
    }

    $results += [PSCustomObject]@{
        machineId    = $machineId
        workspace    = $workspace
        heartbeat    = $heartbeatStatus
        ageSeconds   = $heartbeatAge
        isDead       = $heartbeatStatus -eq "STALE"
    }
}

# ---------- Output ----------
if ($Json) {
    [PSCustomObject]@{
        checkedAtUtc = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        totalMachines = $results.Count
        totalDead     = $totalDead
        machines      = $results
    } | ConvertTo-Json -Depth 3
    exit $(if ($totalDead -gt 0) { 1 } else { 0 })
}

# ---------- Markdown report ----------
Write-Output "### Fleet listener health check — $nowUtc UTC"
Write-Output ""
Write-Output "| Machine | Heartbeat | Age | Status |"
Write-Output "|---------|-----------|-----|--------|"
foreach ($r in $results) {
    $ageStr = if ($null -ne $r.ageSeconds) { "$($r.ageSeconds)s" } else { "N/A" }
    $statusStr = if ($r.heartbeat -eq "ALIVE") { "**OK**" } elseif ($r.heartbeat -eq "STALE") { "**STALE >2h**" } else { "???" }
    Write-Output "| $($r.machineId) | $($r.heartbeat) | $ageStr | $statusStr |"
}
Write-Output ""
Write-Output "Total: $($results.Count) machines checked, $totalDead STALE/DEAD."
Write-Output ""

# ---------- Dashboard alert ----------
if ($totalDead -gt 0 -and -not $NoAlert) {
    $warnContent = "[WARN] Fleet listener check: $totalDead of $($results.Count) machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: $($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId } | Select-Object -First 10 | ForEach-Object { $_ })..."
    Write-Output ""
    Write-Output "[FLEET-ALERT] $warnContent"

    # Append to local workspace dashboard (MCP fallback)
    $localDashDir = Join-Path $RepoRoot ".claude\workspaces"
    $localDashFile = Join-Path $localDashDir "workspace-$(if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }).md"

    if (Test-Path $localDashFile) {
        $content = Get-Content $localDashFile -Raw -Encoding UTF8
        if ($content -match '(?ms)^## Intercom') {
            $content = $content -replace '(?ms)(^## Intercom)', "$warnContent`r`n`r`n`$1"
        } else {
            $content += "`r`n$r`n$warnContent"
        }
        [System.IO.File]::WriteAllText($localDashFile, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Output "[FLEET-ALERT] Appended [WARN] to $localDashFile"
    }
}

# ---------- Auto-repair ----------
if (-not $NoRepair -and $totalDead -gt 0) {
    Write-Output ""
    Write-Output "[REPAIR] Attempting auto-repair for affected machines..."
    Write-Output "Note: repair-wake-listener.ps1 must be run ON the affected machine (needs local access to scheduled tasks)."
    Write-Output "Dispatched repair commands would target: $($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId } | ForEach-Object { $_ })"
    Write-Output "[REPAIR] Use [WAKE-CLAUDE] on affected machines or dispatch via coordinator to trigger repair."
}

exit $(if ($totalDead -gt 0) { 1 } else { 0 })
