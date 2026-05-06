<#
.SYNOPSIS
    Installs the scheduled task 'Hermes-MCP-Watchdog' (SYSTEM, At startup + Every 5 min).

.DESCRIPTION
    - Execution account: NT AUTHORITY\SYSTEM (no user session required)
    - Trigger 1: At startup (with 2 min delay to allow Docker to start)
    - Trigger 2: Every 5 min indefinitely
    - Logon type: ServiceAccount (SYSTEM has no password)
    - Run level: Highest (SYSTEM already has it, but explicit)
    - Restart on failure: 3 attempts every 1 min

.PARAMETER TaskName
    Default: Hermes-MCP-Watchdog

.PARAMETER ScriptPath
    Default: C:\dev\roo-extensions\scripts\hermes-watchdog\hermes-mcp-watchdog.ps1

.PARAMETER IntervalMinutes
    Polling interval in minutes. Default: 5

.PARAMETER StartupDelayMinutes
    Delay after startup before first run. Default: 2

.PARAMETER ContainerName
    Hermes container name to monitor. Default: hermes (gateway)

.EXAMPLE
    # Must be run as admin
    .\install-hermes-watchdog.ps1

.EXAMPLE
    # Monitor dashboard container instead
    .\install-hermes-watchdog.ps1 -ContainerName hermes-dashboard
#>

param(
    [string]$TaskName = 'Hermes-MCP-Watchdog',
    [string]$ScriptPath = 'C:\dev\roo-extensions\scripts\hermes-watchdog\hermes-mcp-watchdog.ps1',
    [int]$IntervalMinutes = 5,
    [int]$StartupDelayMinutes = 2,
    [string]$ContainerName = 'hermes'
)

$ErrorActionPreference = 'Stop'

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script must be run as Administrator."
    exit 1
}

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found: $ScriptPath"
    exit 1
}

Write-Host "=== Installing scheduled task: $TaskName ==="
Write-Host "Container: $ContainerName"
Write-Host "Interval: $IntervalMinutes minutes"
Write-Host ""

# Remove existing
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Action: powershell.exe -ExecutionPolicy Bypass -NoProfile -File <script> -ContainerName <name>
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -ContainerName $ContainerName" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Trigger 1: At startup + delay
$trigStart = New-ScheduledTaskTrigger -AtStartup
$trigStart.Delay = "PT${StartupDelayMinutes}M"

# Trigger 2: repeat every N minutes indefinitely (via -Once + RepetitionInterval)
$trigRepeat = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Principal: SYSTEM, highest run level
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Settings: restart on failure, no battery restriction, allow-start-if-missed
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 3 `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger @($trigStart, $trigRepeat) `
    -Principal $principal `
    -Settings $settings `
    -Description "Hermes MCP-remote bridge watchdog. Monitors mcp-remote for ClosedResourceError and auto-restarts container. Poll every $IntervalMinutes min + at startup. Max 3 restarts/hour then escalate."

Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "=== Task installed ==="

$t = Get-ScheduledTask -TaskName $TaskName
Write-Host "State: $($t.State)"
Write-Host "Triggers:"
$t.Triggers | ForEach-Object {
    Write-Host ("  - {0} StartBoundary={1} Delay={2} RepetitionInterval={3}" -f $_.CimClass.CimClassName, $_.StartBoundary, $_.Delay, $_.Repetition.Interval)
}

Write-Host ""
Write-Host "To test immediately: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "To view logs: Get-Content C:\dev\roo-extensions\outputs\hermes-watchdog\hermes-watchdog-$(Get-Date -Format yyyyMMdd).log -Tail 20"
Write-Host "To view task history: Get-ScheduledTaskInfo '$TaskName'"
Write-Host ""
Write-Host "To uninstall: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
