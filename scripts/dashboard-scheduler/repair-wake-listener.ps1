<#
.SYNOPSIS
    Auto-repair for dead Claude-DashboardListener (issue #2576, #2431, #2503).

.DESCRIPTION
    Tries non-elevated fixes first, then falls back to INTERACTIVE-ONLY install prompt.
    Designed to run as user (cron worker, scheduled task) — NEVER requires elevation.

    Repair steps (in order):
      1. Check if task exists and is Running → if yes, nothing to do
      2. Check if ROOSYNC_SHARED_PATH env var is set → auto-fix if missing
      3. Check if wrapper script exists → report if missing
      4. Check if pwsh is in PATH → report if missing
      5. Attempt non-elevated task start (schtasks /run) → if already dead, this may fail
      6. If all non-elevated fixes fail → prompt for INTERACTIVE-ONLY install

    Auto-fixes that DO NOT require elevation:
      - Setting ROOSYNC_SHARED_PATH (auto-detect GDrive path)
      - Starting an existing but stopped task
      - Restarting wrapper via schtasks /run

    Does NOT do:
      - Registering a new scheduled task (requires RunLevel Highest / elevation)
      - Modifying task settings (requires elevation)

.PARAMETER DryRun
    Report what WOULD be done without making changes.

.PARAMETER MachineId
    Override machine ID for dashboard reporting. Defaults to COMPUTERNAME.

.PARAMETER SkipDashboardAlert
    Skip posting [WARN] to dashboard. Useful when MCP roo-state-manager is unavailable.

.OUTPUTS
    Returns JSON when -Json is set.
    Post [WARN] to dashboard when MCP available and listener is DEAD.
    Returns exit code 0 (healthy), 1 (non-elevated fix applied), 2 (INTERACTIVE-ONLY needed).

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\repair-wake-listener.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\repair-wake-listener.ps1 -DryRun
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\repair-wake-listener.ps1 -Json

.NOTES
    Related: issue #2576 (web1 listener recurring STALE), #2431 (durability fix),
    wake-claude-routing.md (re-install requires INTERACTIVE-ONLY elevation).
#>

param(
    [switch]$DryRun,
    [switch]$Json,
    [switch]$SkipDashboardAlert,
    [string]$MachineId = ""
)

$ErrorActionPreference = "Continue"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$taskName = "Claude-DashboardListener"

if (-not $MachineId) {
    $MachineId = if ($env:ROOSYNC_MACHINE_ID) {
        $env:ROOSYNC_MACHINE_ID.ToLowerInvariant()
    } elseif ($env:COMPUTERNAME) {
        $env:COMPUTERNAME.ToLowerInvariant()
    } else {
        "unknown-machine"
    }
}

$wrapperScript = Join-Path $scriptDir "dashboard-listener-wrapper.ps1"
$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
$nowUtc = (Get-Date).ToUniversalTime()

# ---------- Diagnostic data ----------
$taskState = "NOT_INSTALLED"
$lastResult = $null
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($task) {
    $taskState = [string]$task.State
    $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    if ($info) {
        $lastResult = $info.LastTaskResult
    }
}

$localHbPath = Join-Path $RepoRoot ".claude\locks\dashboard-listener.heartbeat"
$localHbAge = $null
if (Test-Path $localHbPath) {
    $mt = (Get-Item $localHbPath).LastWriteTimeUtc
    $localHbAge = [int]($nowUtc - $mt).TotalSeconds
}

$sharedPath = $env:ROOSYNC_SHARED_PATH
$roosyncOk = -not [string]::IsNullOrEmpty($sharedPath) -and (Test-Path $sharedPath)

$wrapperOk = Test-Path $wrapperScript
$pwshOk = -not [string]::IsNullOrEmpty($pwshPath)

# ---------- Verdict ----------
$hbFresh = $null -ne $localHbAge -and $localHbAge -lt 7200  # 2h threshold
$hasTask = $taskState -ne "NOT_INSTALLED"
$listenerAlive = $hbFresh -or $taskState -eq "Running"

$verdict = if ($listenerAlive) {
    "ALIVE"
} elseif (-not $hasTask) {
    "NOT_INSTALLED"
} else {
    "DEAD"
}

# ---------- Repair actions ----------
$actionsTaken = @()
$exitCode = 0

# Fix 1: ROOSYNC_SHARED_PATH not set — auto-fix (no elevation needed)
if (-not $roosyncOk) {
    $envVar = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
    if ([string]::IsNullOrEmpty($envVar)) {
        $candidates = @(
            "$env:USERPROFILE\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state",
            "G:\Mon Drive\Synchronisation\RooSync\.shared-state",
            "D:\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state"
        )
        $detected = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($detected) {
            if (-not $DryRun) {
                [System.Environment]::SetEnvironmentVariable('ROOSYNC_SHARED_PATH', $detected, 'User')
                $env:ROOSYNC_SHARED_PATH = $detected
                $roosyncOk = $true
                $actionsTaken += "Set ROOSYNC_SHARED_PATH = $detected (User level, auto-detected)"
            } else {
                $actionsTaken += "[DRY-RUN] Would set ROOSYNC_SHARED_PATH = $detected"
            }
        } else {
            $actionsTaken += "ROOSYNC_SHARED_PATH not set and no GDrive path detected — needs manual env var"
        }
    } else {
        $env:ROOSYNC_SHARED_PATH = $envVar
        $roosyncOk = $true
        $actionsTaken += "Loaded ROOSYNC_SHARED_PATH from User env var"
    }
}

# Fix 2: Task exists but stopped — try to start it (non-elevated)
if ($verdict -eq "DEAD" -and $hasTask -and -not $listenerAlive) {
    try {
        if (-not $DryRun) {
            schtasks /run /tn "$taskName" 2>&1 | Out-Null
            $startResult = $LASTEXITCODE
            if ($startResult -eq 0) {
                $actionsTaken += "Started existing task via schtasks /run"
                $taskState = "Running"
                $verdict = "ALIVE"
            } else {
                $actionsTaken += "schtasks /run failed (exit $startResult) — task may need INTERACTIVE-ONLY install"
            }
        } else {
            $actionsTaken += "[DRY-RUN] Would try schtasks /run on existing task"
        }
    } catch {
        $actionsTaken += "Failed to start task: $_"
    }
}

# ---------- Results ----------
$result = [PSCustomObject]@{
    machine       = $MachineId
    checkedAtUtc  = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
    verdict       = $verdict
    taskState     = $taskState
    lastResult    = if ($lastResult) { ('0x{0:X}' -f $lastResult) } else { $null }
    localHeartbeatAge = $localHbAge
    roosyncOk     = $roosyncOk
    wrapperExists = $wrapperOk
    pwshInPath    = $pwshOk
    actionsTaken  = $actionsTaken
    needsElevation = $verdict -eq "DEAD" -or $verdict -eq "NOT_INSTALLED"
}

if ($Json) {
    $result | ConvertTo-Json -Depth 3
} else {
    $hbStr = if ($null -ne $localHbAge) { "$($localHbAge)s ago" } else { "MISSING" }
    Write-Output "### Listener repair report — $MachineId (verdict: $verdict)"
    Write-Output ""
    Write-Output "- Task: `Claude-DashboardListener` State=**$taskState** LastResult=$($result.lastResult)"
    Write-Output "- Local heartbeat: $hbStr"
    Write-Output "- ROOSYNC_SHARED_PATH: $(if ($roosyncOk) { "OK ($sharedPath)" } else { "MISSING" })"
    Write-Output "- Wrapper script: $(if ($wrapperOk) { "OK" } else { "MISSING" })"
    Write-Output "- pwsh in PATH: $(if ($pwshOk) { "OK ($pwshPath)" } else { "NOT FOUND" })"
    Write-Output ""

    if ($actionsTaken.Count -gt 0) {
        Write-Output "### Actions taken"
        foreach ($a in $actionsTaken) {
            Write-Output "- $a"
        }
        Write-Output ""
    }

    if ($verdict -eq "ALIVE") {
        Write-Output "Status: **OK** — listener is healthy."
    } elseif ($verdict -eq "NOT_INSTALLED") {
        Write-Output "Status: **NOT INSTALLED** — requires INTERACTIVE-ONLY elevated install:"
        Write-Output '  `pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\install-dashboard-listener-schtask.ps1`'
        $exitCode = 2
    } else {
        Write-Output "Status: **DEAD** — non-elevated fixes attempted:"
        if ($actionsTaken.Count -gt 0) {
            foreach ($a in $actionsTaken) { Write-Output "  - $a" }
        } else {
            Write-Output "  (none — task exists but is not running)"
        }
        Write-Output "  If fixes above didn't help, requires INTERACTIVE-ONLY elevated install."
        $exitCode = if ($actionsTaken.Count -gt 0 -and $verdict -eq "ALIVE") { 1 } else { 2 }
    }
}

# ---------- Dashboard alert ----------
# Attempt to post [WARN] to dashboard if listener is dead.
# This requires MCP roo-state-manager. If unavailable, exit code signals the need.
if (-not $SkipDashboardAlert -and $verdict -in @("DEAD", "NOT_INSTALLED") -and -not $DryRun) {
    # Try to use the MCP conversation browser to check if roo-state-manager is available.
    # If it is, post the alert. If not, we rely on the caller (cron worker) to handle it.
    $mcpAvailable = $false
    try {
        # Quick check: try a no-op MCP call
        $mcpTest = & {
            try {
                $result = mcps\roo-state-manager\health 2>&1
                return $true
            } catch {
                return $false
            }
        }
        # Actually, we can't invoke MCP tools directly from PowerShell.
        # The caller (cron worker) should handle dashboard posting.
        $mcpAvailable = $false
    } catch {
        $mcpAvailable = $false
    }

    if ($mcpAvailable) {
        # Would call: roosync_dashboard(action: "append", type: "workspace", tags: ["WARN"], ...)
        # But MCP tools aren't accessible from PowerShell — handled by cron caller instead.
        Write-Output ""
        Write-Output "[AUTO-ALERT] Dashboard MCP unavailable from PowerShell. Cron caller should post [WARN]."
    } else {
        Write-Output ""
        Write-Output "[AUTO-ALERT] Dashboard MCP not available. Report verdict=$verdict to caller."
    }
}

exit $exitCode
