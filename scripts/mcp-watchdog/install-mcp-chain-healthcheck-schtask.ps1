<#
.SYNOPSIS
    Installe la scheduled task 'MCP-Chain-Healthcheck' (user context, At startup + every 5 min).

.DESCRIPTION
    Consumer-side / host-side read-only probe for the MCP chain (arbitrage #3495, option 1).
    Branche mcp-chain-healthcheck.ps1 en mode -Scheduled : battement observable
    (fichier d'etat a chaque tick + note dashboard machine 1/h), notes sur transition
    d'etat et panne, aucune reparation (read-only STRUCTUREL).

    Differences avec install-watchdog-schtask.ps1 (le watchdog host-of-bus) :
      - Compte d'execution : utilisateur courant ($env:USERNAME), pas SYSTEM —
        le spawn stdio du roo-state-manager doit resoudre le .env utilisateur ET
        le mount GDriveFS (C:\Drive), tous deux lies au profil (pattern
        install-gdrivefs-watchdog-schtask.ps1, prouve en prod).
      - Aucune sequence de reparation : la tache ne fait que sonder et publier.
      - Trigger : At startup (+2 min) + every 5 min.

.PARAMETER TaskName
    Default: MCP-Chain-Healthcheck

.PARAMETER ScriptPath
    Default: mcp-chain-healthcheck.ps1 a cote de ce script (resolu via $PSScriptRoot —
    aucun chemin D:\ ou C:\ hardcode : deployable sur toute machine du depot).

.PARAMETER IntervalMinutes
    Default: 5

.EXAMPLE
    # Doit être lance en Administrateur
    .\install-mcp-chain-healthcheck-schtask.ps1
#>

param(
    [string]$TaskName   = 'MCP-Chain-Healthcheck',
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'mcp-chain-healthcheck.ps1'),
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

# Action : powershell.exe -ExecutionPolicy Bypass -NoProfile -File <script> -Scheduled
$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$ScriptPath`" -Scheduled" `
    -WorkingDirectory (Split-Path $ScriptPath -Parent)

# Trigger 1 : At startup + delay
$trigStart = New-ScheduledTaskTrigger -AtStartup
$trigStart.Delay = "PT${StartupDelayMinutes}M"

# Trigger 2 : repeat every N minutes indefinitely (via -Once + RepetitionInterval)
$trigRepeat = New-ScheduledTaskTrigger `
    -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)

# Principal : utilisateur courant (acces .env utilisateur + mount GDriveFS), elevation maximale
$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

# Settings : restart on failure, no battery restriction, allow-start-if-missed.
# ExecutionTimeLimit 5 min : un tick = spawn stdio RSM (handshake) + publication
# conditionnelle (append dashboard peut prendre ~45 s si condensation serveur).
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 3 `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger @($trigStart, $trigRepeat) `
    -Principal $principal `
    -Settings $settings `
    -Description 'Healthcheck read-only de la chaine MCP locale (arbitrage #3495) : sondage 5 min, battement observable, notes dashboard machine sur transition/panne. Ne repare jamais.'

Register-ScheduledTask -TaskName $TaskName -InputObject $task | Out-Null

Write-Host "=== Task installed ==="

$t = Get-ScheduledTask -TaskName $TaskName
Write-Host "State: $($t.State)"
Write-Host "Triggers:"
$t.Triggers | ForEach-Object {
    Write-Host ("  - {0} StartBoundary={1} Delay={2} RepetitionInterval={3}" -f $_.CimClass.CimClassName, $_.StartBoundary, $_.Delay, $_.Repetition.Interval)
}
Write-Host ""
Write-Host "Principal: $env:USERNAME (Highest, Interactive) — .env utilisateur + GDriveFS accessibles au spawn RSM"
Write-Host ""
Write-Host "To test immediately: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "State file & logs:    <repo>\outputs\mcp-watchdog\healthcheck-state.json / healthcheck-YYYYMMDD.log"
