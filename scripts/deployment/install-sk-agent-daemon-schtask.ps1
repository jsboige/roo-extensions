# install-sk-agent-daemon-schtask.ps1 - keep the shared daemon alive across logons (#4149 F2)
#
# Registers a per-user logon task that runs start-sk-agent-daemon.ps1
# (idempotent, so a re-logon just confirms the port is listening). Registers
# WITHOUT elevation first: a current-user task at Limited run level needs no
# UAC window; on access denied it fails loud with the verbatim error instead
# of auto-elevating (UAC discipline: one window per lane, never unannounced).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\install-sk-agent-daemon-schtask.ps1 -WhatIf
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\install-sk-agent-daemon-schtask.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\install-sk-agent-daemon-schtask.ps1 -Remove
# Exit codes: 0 = registered/removed/already present, 1 = failure (verbatim error printed).

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$TaskName = 'Claude-SkAgent-Daemon',
    # NB: resolved in the body -- $PSScriptRoot is empty during param binding
    # under `powershell.exe -File` (PS 5.1).
    [string]$StartScript = '',
    [int]$Port = 8100,
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'
if (-not $StartScript) { $StartScript = Join-Path $PSScriptRoot 'start-sk-agent-daemon.ps1' }

if ($Remove) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existing) { Write-Output "[OK] task '$TaskName' not present - nothing to remove"; exit 0 }
    if (-not $PSCmdlet.ShouldProcess("scheduled task '$TaskName'", 'unregister')) { Write-Output '[WhatIf] would Unregister-ScheduledTask'; exit 0 }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Output "[OK] task '$TaskName' removed"
    exit 0
}

if (-not (Test-Path $StartScript)) { Write-Output "[FAIL] start script not found: $StartScript"; exit 1 }

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Output "[OK] task '$TaskName' already registered (State=$($existing.State)) - idempotent no-op"
    exit 0
}

# Hidden: powershell.exe has no true hidden flag that survives the Task
# Scheduler UI, so the action uses -WindowStyle Hidden (the daemon itself is a
# detached background python; the window only flashes if run by hand).
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartScript`" -Port $Port"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
# 60s delay: let DriveFS/network settle before a cold python+semantic_kernel start.
$trigger.Delay = 'PT60S'
# No 3-day default kill: the daemon is meant to live as long as the session fleet.
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Days 365)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

if (-not $PSCmdlet.ShouldProcess("scheduled task '$TaskName' (logon, Limited)", 'register')) {
    Write-Output "[WhatIf] would register: $TaskName"
    Write-Output "[WhatIf]   execute: powershell.exe -WindowStyle Hidden -File `"$StartScript`" -Port $Port"
    Write-Output "[WhatIf]   trigger: at logon of $env:USERNAME (60s delay), ExecutionTimeLimit 365d, RunLevel Limited"
    exit 0
}

try {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null
} catch {
    Write-Output "[FAIL] Register-ScheduledTask refused (non-elevated attempt, no auto-elevation):"
    Write-Output "       $($_.Exception.Message)"
    Write-Output "       This pilot needs NO elevated task; if this seat requires one, ask the coordinator"
    Write-Output "       for a UAC window instead of elevating silently (uac-dryrun-discipline)."
    exit 1
}

$reg = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $reg) { Write-Output '[FAIL] registration returned success but task not found'; exit 1 }
Write-Output "[OK] task '$TaskName' registered (State=$($reg.State)) - runs start-sk-agent-daemon.ps1 -Port $Port at logon (+60s)"
exit 0
