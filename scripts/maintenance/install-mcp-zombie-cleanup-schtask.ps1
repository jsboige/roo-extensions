<#
.SYNOPSIS
    Installe la scheduled task 'MCP-Stdio-Zombie-Cleanup' (utilisateur courant, daily 03:15).

.DESCRIPTION
    Runs cleanup-mcp-stdio-zombies.ps1 -Execute -MinAgeHours 18 automatically
    to prevent MCP stdio zombie accumulation (#2675) — the "phantom terminal
    windows" + locked orphan worktrees symptom on Windows.

    Cadence rationale (po-2024 c.92, 2026-06-24): zombie accumulation is SLOW
    (days, not hours — 0 spawned in 2h after a cleanup). A daily run is
    proportional; hourly would be overkill.

    - Account: current interactive user (the MCP stdio processes are spawned in
      the user's session context, so killing them from the same session avoids
      cross-session SeDebugPrivilege complications).
    - RunLevel: Highest (Stop-Process -Force on other processes in the session).
    - Trigger: Daily at 03:15 (configurable).
    - Execution time limit: 10 minutes.
    - Restart on failure: 3 attempts every 5 minutes.

.PARAMETER TaskName
    Default: MCP-Stdio-Zombie-Cleanup

.PARAMETER ScriptPath
    Default: <script dir>\cleanup-mcp-stdio-zombies.ps1

.PARAMETER MinAgeHours
    Minimum process age to consider killing. Default: 18.

.PARAMETER Hour
    Hour of the daily run. Default: 3 (03:15 — off-hours, after the worktree
    cleanup at 03:00, so a locked worktree can be removed right after).

.EXAMPLE
    # Run as the interactive user (elevation optional; Highest run level set in principal)
    .\install-mcp-zombie-cleanup-schtask.ps1
#>

param(
    [string]$TaskName    = 'MCP-Stdio-Zombie-Cleanup',
    [string]$ScriptPath  = (Join-Path $PSScriptRoot 'cleanup-mcp-stdio-zombies.ps1'),
    [double]$MinAgeHours = 18,
    [int]$Hour           = 3,
    [int]$Minute         = 15
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
    exit 1
}

# Current interactive user (MCP stdio procs live in this session)
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "=== Install scheduled task: $TaskName ==="
Write-Host "User:   $currentUser"
Write-Host "Script: $ScriptPath"
Write-Host "Cadence: Daily at $($Hour.ToString('00')):$($Minute.ToString('00'))"
Write-Host "Args:   -Execute -MinAgeHours $MinAgeHours"

# Remove existing
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Action: run cleanup script with -Execute flag
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -Execute -MinAgeHours $MinAgeHours" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Trigger: daily at specified time
$trigger = New-ScheduledTaskTrigger -Daily -At "$($Hour.ToString('00')):$($Minute.ToString('00'))"

# Principal: current user, highest run level (same session as the MCP processes)
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Highest

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -RestartCount 3 `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Daily cleanup of orphan MCP stdio zombie processes (node/cmd spawned via npx that outlived their VS Code host) — #2675. Runs cleanup-mcp-stdio-zombies.ps1 -Execute -MinAgeHours $MinAgeHours."

Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "=== Task installed ==="

$t = Get-ScheduledTask -TaskName $TaskName
Write-Host "State: $($t.State)"
Write-Host "Triggers:"
$t.Triggers | ForEach-Object {
    Write-Host ("  - {0} StartBoundary={1}" -f $_.CimClass.CimClassName, $_.StartBoundary)
}

Write-Host ""
Write-Host "To test immediately (dry-run first to preview):"
Write-Host "  pwsh -ExecutionPolicy Bypass -File `"$ScriptPath`"  # dry-run"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'          # execute (kills zombies > ${MinAgeHours}h)"
