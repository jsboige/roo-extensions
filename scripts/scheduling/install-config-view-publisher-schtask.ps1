<#
.SYNOPSIS
    Install or uninstall the hourly config-view publisher task (#3833, etape 4 / #603 case 17).

.DESCRIPTION
    Creates a Windows scheduled task that runs config-view.py --write every
    hour by default (#3833 step 4): read ~/.claude.json (top-level mcpServers
    names) + ~/.claude/settings.json (whitelist-masked env keys, permissions,
    identity keys, flags), then atomically OVERWRITE the one per-machine
    snapshot under <ROOSYNC_SHARED_PATH>/config-view/<machine>.json.

    THE WHITELIST IS THE MASK (see config-view.py): no secret-bearing value
    is ever copied, and a secret-deny pattern (KEY/TOKEN/SECRET/PASSWORD/
    CREDENTIAL/HEADER/AUTH) runs after the whitelist. No dashboard append by
    design (#3833: quiet channel).

    CADENCE : 60 minutes (config changes rarely; the fleet reader's default
    freshness threshold is 120 min = 2 missed ticks). The run is a pure read
    of two local files + one small JSON overwrite; measured one-shot cost
    < 1 s.

    Installation SANS elevation (precedent #3834 and the session-view
    installer, #3833 etape 2): Register-ScheduledTask en RunLevel Limited,
    utilisateur courant — aucun UAC n'est declenche. Le dry-run (-WhatIf)
    reste la preview standard avant le geste (mandat coordinateur #3833
    etape 4 : "poste le dry-run avant tout geste").

    Interpreter : python du PATH avec -X utf8 (lesson cp1252 #4672).

    Freshness = liveness : la tache n'ecrit pas de log ; l'instrument de
    verite est le champ generatedAt du snapshot et LastTaskResult via
    Get-ScheduledTaskInfo. C'est exactement ce que la vue agregee
    (config-view-fleet.py) lit.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER IntervalMinutes
    Repetition interval in minutes (default 60).

.PARAMETER SharedPath
    Shared state root. Empty (default) = resolved like the session-view
    installer: ROOSYNC_SHARED_PATH at User level, else GDrive candidates.

.EXAMPLE
    .\install-config-view-publisher-schtask.ps1 -WhatIf
    # Dry-run : preview complet, rien n'est enregistre.

.EXAMPLE
    .\install-config-view-publisher-schtask.ps1
    # Enregistre la tache horaire (RunLevel Limited, sans elevation).

.EXAMPLE
    .\install-config-view-publisher-schtask.ps1 -Uninstall

.NOTES
    Issue : #3833 (etape 4, cases 17-19 de #603). Installation par machine,
    sans elevation. Le chemin du script embarque dans la tache est celui du
    checkout d'ou l'installateur est lance — installer depuis le checkout
    principal de la machine, pas depuis un worktree jete.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Uninstall,
    [int]$IntervalMinutes = 60,
    [string]$SharedPath = ''
)

$ErrorActionPreference = 'Stop'
Write-Host ("[INFO] PowerShell : {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$viewScript = Join-Path (Split-Path $scriptDir -Parent) 'diagnostic\config-view.py'
$taskName = 'roo-config-view-publisher'

# ========================================
# UNINSTALL PATH
# ========================================
if ($Uninstall) {
    if ($PSCmdlet.ShouldProcess($taskName, 'Unregister-ScheduledTask')) {
        $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($existing) {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            Write-Host "Removed scheduled task: $taskName" -ForegroundColor Green
        } else {
            Write-Host "Task not found: $taskName" -ForegroundColor Yellow
        }
    }
    exit 0
}

# ========================================
# PRE-FLIGHT CHECKS
# ========================================
if (-not (Test-Path -LiteralPath $viewScript)) {
    Write-Host "ERROR: config-view.py not found: $viewScript" -ForegroundColor Red
    exit 1
}

if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 1440) {
    Write-Host "ERROR: -IntervalMinutes must be 1..1440. Got: $IntervalMinutes" -ForegroundColor Red
    exit 1
}

# python : preflight dur (meme logique que l'installateur session-view).
$pythonExe = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) {
    Write-Host "ERROR: python.exe introuvable dans le PATH — la tache echouerait a chaque tir. Installer python d'abord." -ForegroundColor Red
    exit 1
}
# pythonw.exe (#4771) : python.exe est un executable CONSOLE — en LogonType
# Interactive, chaque tir ouvrait une fenetre conhost visible (le clignotement
# attribue par Maintenance le 16/11). pythonw.exe est du sous-systeme GUI :
# aucune console n'est creee. Resolu dans le MEME repertoire que python.exe
# (meme interpreteur, memes paquets). Le script n'ecrit que via print(), qui ne
# fait rien quand sys.stdout/sys.stderr valent None sous pythonw ; le code de
# sortie remonte toujours dans LastTaskResult.
$pythonwExe = Join-Path (Split-Path $pythonExe -Parent) 'pythonw.exe'
if (-not (Test-Path -LiteralPath $pythonwExe)) {
    Write-Host "ERROR: pythonw.exe absent a cote de $pythonExe — refus : une tache python.exe ouvrirait une console a chaque tir (#4771)." -ForegroundColor Red
    exit 1
}

# Garde roster (review PR #4764) : le lecteur agrege (config-view-fleet.py)
# enumere les machines depuis les CLES de fleet-manifest.json et lit
# <machine>.json. Ce publieur ecrit COMPUTERNAME en minuscules — si ce nom
# n'est pas une cle du manifeste, le snapshot ne serait JAMAIS lu : refus
# avant l'installation (verifie chaque siege, web1/web2 compris).
$repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
$manifestPath = Join-Path $repoRoot '.claude\configs\fleet-manifest.json'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    Write-Host "ERROR: manifeste de flotte introuvable : $manifestPath" -ForegroundColor Red
    exit 1
}
$thisMachine = $env:COMPUTERNAME.ToLower()
try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $roster = @($manifest.machines.PSObject.Properties.Name)
} catch {
    Write-Host "ERROR: fleet-manifest.json illisible : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
if ($roster.Count -lt 1) {
    Write-Host "ERROR: fleet-manifest.json ne porte aucune machine (cle 'machines' vide)." -ForegroundColor Red
    exit 1
}
if ($roster -notcontains $thisMachine) {
    Write-Host "ERROR: ce siege ('$thisMachine') n'est pas une cle du manifeste de flotte : $($roster -join ', ')." -ForegroundColor Red
    Write-Host "       Le lecteur agrege (config-view-fleet.py) ne lirait jamais <shared>\config-view\$thisMachine.json." -ForegroundColor Red
    Write-Host "       Corriger le hostname ou ajouter la machine au manifeste avant l'installation." -ForegroundColor Red
    exit 1
}
Write-Host "[INFO] Siege '$thisMachine' present au manifeste ($($roster.Count) machines) — snapshot lisible par le lecteur fleet."

# Destination par defaut : resolution identique a l'installateur session-view.
if (-not $SharedPath) {
    $SharedPath = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
    if (-not $SharedPath -or -not (Test-Path -LiteralPath $SharedPath)) {
        $SharedPath = $null
        foreach ($c in @(
            'G:\Mon Drive\Synchronisation\RooSync\.shared-state',
            "$env:USERPROFILE\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state",
            'D:\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state'
        )) {
            if ($c -and (Test-Path -LiteralPath $c)) { $SharedPath = $c; break }
        }
    }
    if (-not $SharedPath) {
        Write-Host "ERROR: aucun dossier RooSync .shared-state trouve (ROOSYNC_SHARED_PATH absent du User ou injoignable, candidats GDrive absents) — refus : passer -SharedPath explicitement apres creation du dossier." -ForegroundColor Red
        exit 1
    }
    Write-Host "[INFO] SharedPath resolu : $SharedPath"
}
if (-not (Test-Path -LiteralPath $SharedPath)) {
    Write-Host "ERROR: -SharedPath injoignable : $SharedPath" -ForegroundColor Red
    exit 1
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
# -X utf8 : sortie/entree UTF-8 hors codepage machine (lesson cp1252 #4672).
$viewArgs = "-X utf8 `"$viewScript`" --write --shared-path `"$SharedPath`""

$action = New-ScheduledTaskAction -Execute $pythonwExe -Argument $viewArgs

# Repetition indefinie : Duration nulle EXPLICITEMENT (le Task Scheduler refuse
# [TimeSpan]::MaxValue avec 0x80041318 — mesure po-2028 14/11, precedent
# install-session-view-publisher-schtask.ps1).
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$trigger.Repetition.Duration = $null
$trigger.Repetition.StopAtDurationEnd = $false

# RunLevel Limited : le run ne touche que deux lectures locales et le GDrive
# de l'utilisateur (une reecriture atomique) — aucune elevation.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

$description = "Config-view publisher (#3833 step 4, #603 cases 17-19): every $IntervalMinutes min, read ~/.claude.json + ~/.claude/settings.json (whitelist-masked), atomically overwrite <shared>/config-view/<machine>.json. Freshness of that file IS the liveness signal (aggregated drift view: config-view-fleet.py)."

# ========================================
# PREVIEW (affiche dans tous les cas ; -WhatIf n'enregistre rien)
# ========================================
Write-Host "========== SCHTASK PREVIEW — $taskName ==========" -ForegroundColor Cyan
Write-Host "TaskName    : $taskName"
Write-Host "Action      : $($action.Execute) $($action.Arguments)"
Write-Host "Trigger     : every $IntervalMinutes min (indefinite, first run +1 min)"
Write-Host "Principal   : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
Write-Host "Settings    : StartWhenAvailable, IgnoreNew, ExecutionTimeLimit 2 min"
Write-Host "Description : $description"
Write-Host "State file  : $SharedPath\config-view\$($env:COMPUTERNAME.ToLower()).json (atomic overwrite)"
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "To register (sans elevation, RunLevel Limited, precedent #3834) : re-run without -WhatIf"

# ========================================
# REGISTER (sans elevation) — idempotent : retrait de l'existante d'abord
# ========================================
if ($PSCmdlet.ShouldProcess($taskName, 'Register-ScheduledTask (hourly config-view publisher)')) {
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed existing task: $taskName" -ForegroundColor Gray
    }
    Register-ScheduledTask -TaskName $taskName `
        -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description $description | Out-Null
    Write-Host "Installed scheduled task: $taskName" -ForegroundColor Green
    Write-Host "  every $IntervalMinutes min -> $($action.Execute) $($action.Arguments)"
    Write-Host "  To run immediately: schtasks /run /tn `"$taskName`""
}
