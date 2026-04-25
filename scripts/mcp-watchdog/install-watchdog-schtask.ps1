<#
.SYNOPSIS
    Installe la scheduled task 'MCP-Chain-Watchdog' (SYSTEM, At startup + Every 5 min).

.DESCRIPTION
    - Compte d'exécution : NT AUTHORITY\SYSTEM (pas besoin de session user)
    - Trigger 1 : At startup (avec délai 2 min pour laisser Docker démarrer)
    - Trigger 2 : Every 5 min indéfiniment
    - Logon type : Password = N/A (SYSTEM n'a pas besoin de password)
    - Run level : Highest (SYSTEM l'a déjà, mais explicite)
    - Restart on failure : 3 tentatives toutes les 1 min

.PARAMETER TaskName
    Default: MCP-Chain-Watchdog

.PARAMETER ScriptPath
    Default: D:\roo-extensions\scripts\mcp-watchdog\mcp-chain-watchdog.ps1

.EXAMPLE
    # Doit être lancé en admin
    .\install-watchdog-schtask.ps1
#>

param(
    [string]$TaskName   = 'MCP-Chain-Watchdog',
    [string]$ScriptPath = 'D:\roo-extensions\scripts\mcp-watchdog\mcp-chain-watchdog.ps1',
    [int]$IntervalMinutes = 5,
    [int]$StartupDelayMinutes = 2
)

$ErrorActionPreference = 'Stop'

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Ce script doit etre execute en Administrateur."
    exit 1
}

if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script introuvable: $ScriptPath"
    exit 1
}

Write-Host "=== Install scheduled task: $TaskName ==="

# Remove existing
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Action : powershell.exe -ExecutionPolicy Bypass -NoProfile -File <script>
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`"" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Trigger 1 : At startup + delay
$trigStart = New-ScheduledTaskTrigger -AtStartup
$trigStart.Delay = "PT${StartupDelayMinutes}M"

# Trigger 2 : repeat every N minutes indefinitely (via -Once + RepetitionInterval)
$trigRepeat = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Principal : SYSTEM, highest run level
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# Settings : restart on failure, no battery restriction, allow-start-if-missed
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
    -Description 'Watchdog E2E du chain MCP (bot NanoClaw -> mcp-tools.myia.io -> TBXark -> sparfenyuk). Poll toutes les 5 min + at startup, repare sparfenyuk/TBXark en cascade.'

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
Write-Host "To view logs: Get-Content D:\roo-extensions\outputs\mcp-watchdog\watchdog-$(Get-Date -Format yyyyMMdd).log -Tail 20"
