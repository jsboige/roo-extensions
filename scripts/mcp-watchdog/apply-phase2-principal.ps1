<#
.SYNOPSIS
    Phase 2 : re-register MCP-Proxy-RSM with LogonType=Password + AtStartup trigger.

.DESCRIPTION
    Problème résolu : la tâche actuelle a LogonType=Interactive, ce qui signifie
    qu'elle ne peut démarrer que si MYIA a une session interactive. Reboot sans
    logon = sparfenyuk down jusqu'au prochain logon.

    Fix : passer en LogonType=Password + ajouter trigger AtStartup. La tâche
    pourra démarrer automatiquement au boot même sans session utilisateur.

    Le profil MYIA (et donc le mount GDrive) sera chargé par Windows car la tâche
    tourne comme user MYIA avec password stocké.

.PARAMETER MyiaPassword
    Password du compte local MYIA. Utilisé uniquement pour Register-ScheduledTask,
    jamais persisté.

.PARAMETER TaskName
    Default: MCP-Proxy-RSM
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MyiaPassword,
    [string]$TaskName = 'MCP-Proxy-RSM',
    [string]$Wrapper = 'D:\Tools\mcp-proxy-sparfenyuk\run-proxy.cmd',
    [string]$WorkingDir = 'D:\Tools\mcp-proxy-sparfenyuk'
)

$ErrorActionPreference = 'Stop'

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Ce script doit etre execute en Administrateur."
    exit 1
}

if (-not (Test-Path $Wrapper)) {
    Write-Error "Wrapper introuvable: $Wrapper"
    exit 1
}

$userId = "$env:COMPUTERNAME\MYIA"
Write-Host "=== Phase 2: Re-register $TaskName with LogonType=Password + AtStartup ==="
Write-Host "User: $userId"
Write-Host "Wrapper: $Wrapper"

# Check task exists
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Existing task state: $($existing.State)"
    Write-Host "Current triggers: $($existing.Triggers.Count)"
    Write-Host "Current principal logon type: $($existing.Principal.LogonType)"

    # Stop it gracefully (task process kept running if already spawned — only the scheduler config changes)
    Write-Host "Unregistering old task (sparfenyuk process kept running)..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Action : preserved from original
$action = New-ScheduledTaskAction `
    -Execute 'cmd.exe' `
    -Argument "/c `"$Wrapper`"" `
    -WorkingDirectory $WorkingDir

# Triggers : TWO triggers
#  1. AtStartup (with 30s delay to let network/docker come up)
#  2. AtLogOn (backup for user sessions, keeps behavior similar to old config)
$trigStartup = New-ScheduledTaskTrigger -AtStartup
$trigStartup.Delay = 'PT30S'

$trigLogon = New-ScheduledTaskTrigger -AtLogOn -User $userId

# Settings : preserve restart-on-failure behavior
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -RestartCount 5 `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

# -User + -Password implies LogonType=Password automatically (no -Principal to avoid conflict)
Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger @($trigStartup, $trigLogon) `
    -Settings $settings `
    -User $userId `
    -Password $MyiaPassword `
    -RunLevel Limited `
    -Description 'sparfenyuk/mcp-proxy for roo-state-manager. LogonType=Password (reboot-safe). Triggers: AtStartup(+30s) + AtLogOn. Watchdog MCP-Chain-Watchdog monitors and restarts this if it goes down.' `
    -Force | Out-Null

# Clear password variable from memory
$MyiaPassword = 'CLEARED'
[GC]::Collect()

$t = Get-ScheduledTask -TaskName $TaskName
Write-Host ""
Write-Host "=== Re-registered ==="
Write-Host "Task name: $($t.TaskName)"
Write-Host "State: $($t.State)"
Write-Host "Principal user: $($t.Principal.UserId)"
Write-Host "Principal logon type: $($t.Principal.LogonType)"
Write-Host "Triggers ($($t.Triggers.Count)):"
$t.Triggers | ForEach-Object {
    Write-Host ("  - Kind: {0} Delay: {1}" -f $_.CimClass.CimClassName, $_.Delay)
}

# Verify sparfenyuk still running (we didn't restart it, just re-registered the scheduler)
Write-Host ""
Write-Host "=== Sanity check: sparfenyuk still listening? ==="
$tcp = Get-NetTCPConnection -LocalPort 9091 -State Listen -ErrorAction SilentlyContinue
if ($tcp) {
    Write-Host "[OK] Port 9091 LISTEN (PID=$($tcp.OwningProcess))"
} else {
    Write-Host "[WARN] Port 9091 not listening — starting task now..."
    Start-ScheduledTask -TaskName $TaskName
    Start-Sleep -Seconds 5
    $tcp = Get-NetTCPConnection -LocalPort 9091 -State Listen -ErrorAction SilentlyContinue
    if ($tcp) { Write-Host "[OK] Port 9091 recovered (PID=$($tcp.OwningProcess))" }
    else { Write-Host "[ERROR] Port 9091 still down after manual start" }
}

Write-Host ""
Write-Host "=== Phase 2 done ==="
Write-Host "Reboot-safe: yes"
Write-Host "Next test: reboot the machine without logging in, verify port 9091 listens within 1 min post-boot"
