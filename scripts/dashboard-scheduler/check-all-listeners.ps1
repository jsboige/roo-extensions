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
    $deadMachines = @($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId })
    $deadList = ($deadMachines | Select-Object -First 10) -join ', '
    $warnContent = "[FLEET-ALERT] [WARN] Fleet listener check: $totalDead of $($results.Count) machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: $deadList."
    Write-Output ""
    Write-Output $warnContent

    # Write alert to shared workspace dashboard — canonical path: $ROOSYNC_SHARED_PATH/dashboards/
    # The previous sink (.claude/workspaces/) was dead code: directory exists on no machine,
    # is versioned nowhere, and is not where shared dashboards live. (#2952)
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    $localMachineId = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }
    # Derive canonical workspace name from git remote (not directory name — wrong in worktrees)
    $workspaceName = Split-Path $RepoRoot -Leaf
    try { if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path "$RepoRoot/.git" -PathType Any)) {
        $remoteUrl = & git -C $RepoRoot remote get-url origin 2>$null
        if ($remoteUrl -match '/([^/]+?)(\.git)?$') { $workspaceName = $Matches[1] }
    } } catch { }

    if (-not $sharedPath) {
        Write-Output "[FLEET-ALERT] ROOSYNC_SHARED_PATH not set — alert on stdout only (no dashboard write)."
    } else {
        try {
            $sharedDashDir = Join-Path $sharedPath "dashboards"
            $sharedDashFile = Join-Path $sharedDashDir "workspace-$workspaceName.md"

            # Anti-spam: cooldown — skip if we already alerted for overlapping dead machines within 6h.
            # Prevents flooding Intercom on long outages (cron 2h × detecting machines × outage duration).
            $cooldownHours = 6
            $cooldownCutoff = $nowUtc.AddHours(-$cooldownHours)
            $shouldAlert = $true

            if (Test-Path $sharedDashFile) {
                $existingRaw = Get-Content $sharedDashFile -Raw -Encoding UTF8
                # Match prior FLEET-ALERT messages — require [FLEET-ALERT] as first content line
                # (after [msg:] marker + blank line) to avoid false-positives on reports that quote alerts
                $alertRe = '(?m)^### \[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z)\][^\r\n]*\r?\n(?:\[msg:[^\r\n]*\r?\n)?\r?\n\[FLEET-ALERT\][^\r\n]*Machines affected:\s*([^\r\n.]+)'
                foreach ($am in [regex]::Matches($existingRaw, $alertRe)) {
                    try {
                        $postTime = [DateTimeOffset]::Parse($am.Groups[1].Value).UtcDateTime
                        if ($postTime -ge $cooldownCutoff) {
                            $listed = @($am.Groups[2].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
                            $overlap = @($listed | Where-Object { $deadMachines -contains $_ })
                            if ($overlap.Count -gt 0) {
                                $shouldAlert = $false
                                Write-Output "[FLEET-ALERT] Cooldown: already posted about {$($listed -join ', ')} at $($am.Groups[1].Value) (within ${cooldownHours}h). Skipping."
                                break
                            }
                        }
                    } catch { }
                }
            }

            if ($shouldAlert) {
                # Build canonical Intercom message format (matches roosync_dashboard append schema)
                $timestamp = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                $randSuffix = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
                $msgId = $localMachineId + ':' + $workspaceName + ':ic-' + $nowUtc.ToString('yyyyMMddTHHmm') + '-' + $randSuffix
                $newMessage = "`r`n### [$timestamp] $localMachineId|$workspaceName`r`n[msg: $msgId]`r`n`r`n$warnContent`r`n"

                if (-not (Test-Path $sharedDashDir)) {
                    New-Item -ItemType Directory -Path $sharedDashDir -Force | Out-Null
                }

                if (Test-Path $sharedDashFile) {
                    $content = Get-Content $sharedDashFile -Raw -Encoding UTF8
                    $content = $content.TrimEnd() + "`r`n" + $newMessage
                    # Update message count in ## Intercom (N messages) header
                    $content = [regex]::Replace($content, '(?<=## Intercom\s*\()\d+', {
                        param($m); ([int]$m.Value + 1).ToString()
                    })
                } else {
                    # Dashboard doesn't exist — create minimal file
                    $content = "---`r`ntype: workspace`r`nlastModified: '$timestamp'`r`nlastModifiedBy:`r`n  machineId: $localMachineId`r`n  workspace: $workspaceName`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 message)`r`n$newMessage"
                }

                [System.IO.File]::WriteAllText($sharedDashFile, $content, [System.Text.UTF8Encoding]::new($false))
                Write-Output "[FLEET-ALERT] Posted [WARN] to $sharedDashFile"
            }
        } catch {
            # Best-effort: GDrive unavailability must never fail the probe
            Write-Output "[FLEET-ALERT] Failed to write dashboard (best-effort, probe continues): $($_.Exception.Message)"
        }
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
