<#
.SYNOPSIS
    Install or uninstall the 5-minute session-view publisher task (#3833, etape 2).

.DESCRIPTION
    Creates a Windows scheduled task that runs session-view.py --write every
    5 minutes (#4694 script, #3833 etat block step 2): read the local session
    registry (~/.claude/sessions/<pid>.json), classify each session (actif /
    repos-recent / repos-ancien / mort), then atomically OVERWRITE the one
    per-machine state file under <ROOSYNC_SHARED_PATH>/session-view/<machine>.json.
    No dashboard append by design (#3833: quiet channel).

    CADENCE : 5 minutes (etape 2 criterion: "sur 6 sieges, le fichier a moins
    de 5 minutes"). The run is a pure read + one small JSON overwrite; the
    measured one-shot cost on po-2028 (7 sessions) is < 1 s.

    Installation SANS elevation (precedent #3834, install-rotate-scheduling-
    logs-schtask.ps1): Register-ScheduledTask en RunLevel Limited, utilisateur
    courant — aucun UAC n'est declenche, chaque machine installe sa tache
    directement. Le dry-run (-WhatIf) reste la preview standard avant le geste.

    Interpreter : python (celui du PATH — meme exigence que les organes de
    diagnostic ; preflight dur : REFUS si absent, une tache 5 min qui
    echouerait a chaque tir en silence serait pire que pas de tache).
    python est appele avec -X utf8 : le lesson cp1252 (#4672) a montre qu'un
    print() hors ASCII peut faire exit 1 en silence sur Windows.

    Freshness = liveness : la tache n'ecrit pas de log (une ligne par session,
    5 min de cadence — du bruit pour rien) ; l'instrument de verite est le
    fichier d'etat lui-meme (champ generatedAt) et LastTaskResult via
    Get-ScheduledTaskInfo. C'est exactement ce que la vue agregee (etape 3)
    lira.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER IntervalMinutes
    Repetition interval in minutes (default 5, per #3833 etape 2).

.PARAMETER SharedPath
    Shared state root. Empty (default) = resolved the same way as the rotate
    installer (#3834): ROOSYNC_SHARED_PATH at User level, else the GDrive
    candidates below. Explicit value bypasses resolution.

.EXAMPLE
    .\install-session-view-publisher-schtask.ps1 -WhatIf
    # Dry-run : preview complet, rien n'est enregistre.

.EXAMPLE
    .\install-session-view-publisher-schtask.ps1
    # Enregistre la tache 5 min (RunLevel Limited, sans elevation).

.EXAMPLE
    .\install-session-view-publisher-schtask.ps1 -Uninstall

.NOTES
    Issue : #3833 (etape 2 ; script : #4694). Installation par machine, sans
    elevation. Le chemin du script embarque dans la tache est celui du
    checkout d'ou l'installateur est lance — installer depuis le checkout
    principal de la machine, pas depuis un worktree jete.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Uninstall,
    [int]$IntervalMinutes = 5,
    [string]$SharedPath = ''
)

$ErrorActionPreference = 'Stop'
Write-Host ("[INFO] PowerShell : {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$viewScript = Join-Path (Split-Path $scriptDir -Parent) 'diagnostic\session-view.py'
$taskName = 'roo-session-view-publisher'

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
    Write-Host "ERROR: session-view.py not found: $viewScript" -ForegroundColor Red
    exit 1
}

if ($IntervalMinutes -lt 1 -or $IntervalMinutes -gt 60) {
    Write-Host "ERROR: -IntervalMinutes must be 1..60. Got: $IntervalMinutes" -ForegroundColor Red
    exit 1
}

# python : preflight dur (meme logique que 7z dans l'installateur #3834).
$pythonExe = (Get-Command python.exe -ErrorAction SilentlyContinue).Source
if (-not $pythonExe) {
    Write-Host "ERROR: python.exe introuvable dans le PATH — la tache echouerait a chaque tir. Installer python d'abord." -ForegroundColor Red
    exit 1
}

# Destination par defaut : resolution identique a #3834 (ROOSYNC_SHARED_PATH
# User, sinon candidats GDrive testes par Test-Path). REFUS (exit 1) si
# aucun .shared-state n'existe : le tir creerait une arborescence parallele.
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

$action = New-ScheduledTaskAction -Execute $pythonExe -Argument $viewArgs

# Repetition indefinie toutes les N minutes : Duration nulle EXPLICITEMENT, pas
# -RepetitionDuration ([TimeSpan]::MaxValue) — le Task Scheduler refuse cette
# valeur avec 0x80041318 "Duration:P99999999DT23H59M59S" (mesure po-2028
# 14/11 ; precedent installe-usability-classifier-task.ps1, qui documente en
# plus que l'erreur peut etre NON terminante : une tache qui affiche
# "Installed" alors que le trigger n'a jamais atterri).
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$trigger.Repetition.Duration = $null
$trigger.Repetition.StopAtDurationEnd = $false

# RunLevel Limited : le run ne touche que ~/.claude/sessions (lecture) et le
# GDrive de l'utilisateur (une reecriture atomique) — aucune elevation.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2)

$description = "Session-view publisher (#3833 step 2, script #4694): every $IntervalMinutes min, read ~/.claude/sessions/*.json + process liveness, atomically overwrite <shared>/session-view/<machine>.json (machine x workspace x status). Freshness of that file IS the liveness signal (aggregated view, step 3)."

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
Write-Host "State file  : $SharedPath\session-view\$($env:COMPUTERNAME.ToLower()).json (atomic overwrite)"
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "To register (sans elevation, RunLevel Limited, precedent #3834) : re-run without -WhatIf"

# ========================================
# REGISTER (sans elevation) — idempotent : retrait de l'existante d'abord
# ========================================
if ($PSCmdlet.ShouldProcess($taskName, 'Register-ScheduledTask (5-min session-view publisher)')) {
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
