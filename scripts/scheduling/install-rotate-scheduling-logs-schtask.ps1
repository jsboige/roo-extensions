<#
.SYNOPSIS
    Install or uninstall the weekly scheduling-logs archive-then-remove task (#3834).

.DESCRIPTION
    Creates a Windows scheduled task that runs rotate-scheduling-logs.ps1 once a
    week in ARCHIVE-PUIS-RETRAIT mode (-ArchiveTo <GDrive root> -Execute):
    inventory -> 7z packaging -> integrity checks -> hash-guarded local removal.
    Bare deletion is impossible by construction (refused by the rotate script
    itself, decision user 13/09, #3834).

    CADENCE : hebdomadaire (defaut dimanche 04:53). Justification par les volumes
    mesures (#3323/#3834) : quelques centaines de Mo par machine et par mois ;
    avec les fenetres de retention 7/14/30 j, un run hebdomadaire traite ~1/4 du
    volume mensuel (dizaines de Mo compressees, cf. 702,1 Mo -> 54,9 Mo sur
    ai-01, 64,2 Mo -> 6,1 Mo sur web1 le 24/09), garde le disque local proche de
    l'etat post-rotation et evite les archives de plusieurs centaines de Mo d'un
    run mensuel. 04:53 = hors heures pleines, hors :00 (jitter coord), apres le
    job transcripts 04:41 et le job claudish 04:17 pour ne pas contester la
    fenetre d'upload GDrive.

    Regle UAC (#3834) : l'installation exige une elevation (Register-ScheduledTask)
    et se fait machine par machine dans une fenetre UAC groupee — UNE SEULE passe
    par lane. Le dry-run (-WhatIf) est poste sur le dashboard AVANT la fenetre.

    Interpreter : powershell.exe (Windows PowerShell 5.1, present partout — pwsh
    absent d'une partie de la flotte #2368) ; le script rotate est verifie 5.1.

    RunLevel Limited : le run n'a besoin d'aucune elevation (logs du repo + GDrive
    de l'utilisateur interactif). Seule l'ENREGISTREMENT de la tache est elevee.

.PARAMETER Uninstall
    Remove the scheduled task instead of creating it.

.PARAMETER TaskDay
    Day of week for the weekly run (default "Sunday").

.PARAMETER TaskTime
    Run time as "HH:mm" (default "04:53", off-:00 / off-peak).

.PARAMETER ArchiveTo
    Root passed to the rotate script. Empty (default) = resolved from the
    RooSync .shared-state root (ROOSYNC_SHARED_PATH at User level, else the
    GDrive candidates below), i.e. <shared>\archives\scheduling-logs. The
    dated archive goes to <ArchiveTo>\<machine>\<yyyy-MM-dd>\. Explicit
    value bypasses resolution.

.PARAMETER SevenZip
    Optional explicit 7z path passed through to the rotate script.

.EXAMPLE
    .\install-rotate-scheduling-logs-schtask.ps1 -WhatIf
    # Dry-run : preview complet, rien n'est enregistre (pas d'elevation requise).
    # La sortie est postee sur le dashboard avant la fenetre UAC groupee (#3834).

.EXAMPLE
    .\install-rotate-scheduling-logs-schtask.ps1
    # Enregistre la tache hebdomadaire (elevation requise).

.EXAMPLE
    .\install-rotate-scheduling-logs-schtask.ps1 -Uninstall

.NOTES
    Issue : #3834 (suite #3323). Reviewed-but-NOT-installed par ce depot :
    le deploiement flotte = fenetre UAC groupee, decision user.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Uninstall,
    [string]$TaskDay = 'Sunday',
    [string]$TaskTime = '04:53',
    [string]$ArchiveTo = '',
    [string]$SevenZip = ''
)

$ErrorActionPreference = 'Stop'
Write-Host ("[INFO] PowerShell : {0} ({1})" -f $PSVersionTable.PSVersion, $PSVersionTable.PSEdition)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$rotateScript = Join-Path $scriptDir 'rotate-scheduling-logs.ps1'
$taskName = 'roo-rotate-scheduling-logs'

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
if (-not (Test-Path -LiteralPath $rotateScript)) {
    Write-Host "ERROR: rotate script not found: $rotateScript" -ForegroundColor Red
    exit 1
}

if ($TaskTime -notmatch '^\d{2}:\d{2}$') {
    Write-Host "ERROR: -TaskTime must be HH:mm (e.g. '04:53'). Got: $TaskTime" -ForegroundColor Red
    exit 1
}
$hour, $minute = $TaskTime -split ':'
if ([int]$hour -gt 23 -or [int]$minute -gt 59) {
    Write-Host "ERROR: -TaskTime out of range: $TaskTime" -ForegroundColor Red
    exit 1
}

$validDays = @('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
if ($TaskDay -notin $validDays) {
    Write-Host "ERROR: -TaskDay must be one of: $($validDays -join ', '). Got: $TaskDay" -ForegroundColor Red
    exit 1
}

# 7z : preflight dur — une tache hebdomadaire qui echouerait a chaque tir en
# silence serait pire que pas de tache. Memes candidats que le script rotate.
$sevenZipResolved = $null
if ($SevenZip -and (Test-Path -LiteralPath $SevenZip)) {
    $sevenZipResolved = $SevenZip
} else {
    $cmd = Get-Command 7z.exe -ErrorAction SilentlyContinue
    if ($cmd) { $sevenZipResolved = $cmd.Source }
    if (-not $sevenZipResolved) {
        foreach ($c in @(
            'C:\ProgramData\chocolatey\tools\7z.exe',
            (Join-Path $env:ProgramFiles 'Docker\Docker\7zr.exe'),
            (Join-Path $env:ProgramFiles '7-Zip\7z.exe'),
            'D:\Apps\PortableApps\7-ZipPortable\App\7-Zip64\7z.exe'
        )) {
            if ($c -and (Test-Path -LiteralPath $c)) { $sevenZipResolved = $c; break }
        }
    }
}
if (-not $sevenZipResolved) {
    Write-Host "ERROR: 7z introuvable (PATH, chocolatey, Docker, 7-Zip, PortableApps) — la tache echouerait a chaque tir. Installer 7z d'abord." -ForegroundColor Red
    exit 1
}

# Destination par defaut : resolution identique a
# scripts/dashboard-scheduler/install-dashboard-listener-schtask.ps1 (#3835) —
# d'abord ROOSYNC_SHARED_PATH (niveau User), sinon les candidats GDrive testes
# par Test-Path, puis <shared>\archives\scheduling-logs. REFUS (exit 1) si
# aucun .shared-state n'existe : le tir hebdomadaire ferait New-Item -Force
# sur une arborescence d'archives parallele que personne ne regarderait.
if (-not $ArchiveTo) {
    $sharedRoot = [System.Environment]::GetEnvironmentVariable('ROOSYNC_SHARED_PATH', 'User')
    if (-not $sharedRoot -or -not (Test-Path -LiteralPath $sharedRoot)) {
        $sharedRoot = $null
        foreach ($c in @(
            'G:\Mon Drive\Synchronisation\RooSync\.shared-state',
            "$env:USERPROFILE\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state",
            'D:\Google Drive\Mon Drive\Synchronisation\RooSync\.shared-state'
        )) {
            if ($c -and (Test-Path -LiteralPath $c)) { $sharedRoot = $c; break }
        }
    }
    if (-not $sharedRoot) {
        Write-Host "ERROR: aucun dossier RooSync .shared-state trouve (ROOSYNC_SHARED_PATH absent du User ou injoignable, candidats GDrive absents) — refus : passer -ArchiveTo explicitement apres creation du dossier. Un tir hebdomadaire sur une destination inexistante creerait une arborescence parallele." -ForegroundColor Red
        exit 1
    }
    $ArchiveTo = Join-Path $sharedRoot 'archives\scheduling-logs'
    Write-Host "[INFO] ArchiveTo resolu : $ArchiveTo (racine .shared-state : $sharedRoot)"
}

# Destination GDrive : avertissement si la racine n'est pas montee MAINTENANT
# (elle doit l'etre au moment du tir hebdomadaire).
$archiveRoot = [System.IO.Path]::GetPathRoot($ArchiveTo)
if ($archiveRoot -and -not (Test-Path -LiteralPath $archiveRoot)) {
    Write-Host "[WARN] Racine d'archivage non montee actuellement : $archiveRoot — la tache echouera tant que le lecteur GDrive n'est pas monte." -ForegroundColor Yellow
}

# ========================================
# BUILD SCHTASK COMPONENTS
# ========================================
# powershell.exe (5.1) : present sur toute la flotte, le script rotate y est
# verifie. Pas de pwsh — absent d'une partie des machines (#2368).
$psExe = (Get-Command powershell.exe -ErrorAction Stop).Source
$rotateArgs = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$rotateScript`" -ArchiveTo `"$ArchiveTo`" -Execute"
if ($SevenZip) { $rotateArgs += " -SevenZip `"$SevenZip`"" }

$action = New-ScheduledTaskAction -Execute $psExe -Argument $rotateArgs
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $TaskDay -At $TaskTime

# RunLevel Limited : le run touche seulement outputs/scheduling/logs du repo et
# le GDrive de l'utilisateur — aucune elevation requise au moment du tir.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 15)

$description = "Weekly scheduling-logs archive-then-remove (#3834): inventory -> 7z package -> integrity checks -> hash-guarded removal. Env/Lock/Unknown never touched. Bare deletion refused by design (decision user 13/09)."

# ========================================
# PREVIEW (affiche dans tous les cas ; -WhatIf n' enregistre rien)
# ========================================
Write-Host "========== SCHTASK PREVIEW — $taskName ==========" -ForegroundColor Cyan
Write-Host "TaskName    : $taskName"
Write-Host "Action      : $($action.Execute) $($action.Arguments)"
Write-Host "Trigger     : Weekly on $TaskDay at $TaskTime"
Write-Host "Principal   : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
Write-Host "Settings    : StartWhenAvailable, RestartCount 2 x 15 min"
Write-Host "Description : $description"
Write-Host "7z          : $sevenZipResolved"
Write-Host "ArchiveTo   : $ArchiveTo  (archive du jour -> <ArchiveTo>\$($env:COMPUTERNAME.ToLower())\<yyyy-MM-dd>\)"
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "To register (elevated, fenetre UAC groupee #3834) : re-run without -WhatIf"

# ========================================
# REGISTER (elevated) — idempotent : retrait de l'existante d'abord
# ========================================
if ($PSCmdlet.ShouldProcess($taskName, 'Register-ScheduledTask (weekly archive-then-remove)')) {
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
        Write-Host "Removed existing task: $taskName" -ForegroundColor Gray
    }
    Register-ScheduledTask -TaskName $taskName `
        -Action $action -Trigger $trigger -Principal $principal `
        -Settings $settings -Description $description | Out-Null
    Write-Host "Installed scheduled task: $taskName" -ForegroundColor Green
    Write-Host "  Weekly $TaskDay $TaskTime -> $rotateArgs"
    Write-Host "  To run immediately: schtasks /run /tn `"$taskName`""
}
