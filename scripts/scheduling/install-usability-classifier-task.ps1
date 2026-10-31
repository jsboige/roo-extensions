<#
.SYNOPSIS
    Installe la tache planifiee Claude-UsabilityClassifier (#4327, RX122) :
    le classifieur de disponibilite de la flotte, tous les N minutes (defaut 5),
    sur la machine courante.

.DESCRIPTION
    Une tache planifiee (utilisateur courant, logon Interactive, RunLevel
    Limited - SANS elevation ni mot de passe stocke, precedent #3834) qui
    lance le lanceur start-usability-classifier.ps1 via un VBS genere
    (wscript.exe + Run(cmd, 0, True) = SW_HIDE, la convention
    harden-hidden-tasks : le tir de 5 min ne flash jamais de console). Le
    lanceur execute classify-machine-usability.ps1 avec -CredentialFile et
    journalise dans outputs/scheduling/logs/usability-classifier.log.

    Le chemin authentifie exige un PSCredential (sans lui, chaque siege
    joignable sort `system-log-unavailable` et le sweep exit 3 sans prouver
    rien - mesure 28/10). Le credential vit dans un fichier DPAPI
    (Export-Clixml, lisible UNIQUEMENT par l'utilisateur qui l'a exporte -
    d'ou la tache Interactive de cet utilisateur) ; ce script le cree en
    promptant Get-Credential quand il est absent.

    REFUS DE GARDE : avant l'enregistrement, une acceptance run
    (-NoAlert -Json -CredentialFile, lecture seule) s'execute. Si
    `system-log-unavailable` persiste sur TOUS les sieges Windows
    joignables, le credential ne fonctionne pas et la tache n'est PAS
    enregistree - une tache qui ticque toutes les 5 min sans lire les
    journaux System n'ajouterait que du bruit.

    Ce script N'est pas execute par un agent : l'enregistrement est le geste
    user, une fois, sur la machine cible.

.PARAMETER DryRun
    Construit les objets New-ScheduledTask* et les affiche, affiche le VBS
    qui serait genere, et n'ecrit RIEN : pas de fichier VBS, pas de tache,
    pas de credential (si le credential est absent, il n'est pas prompte).
    Si le credential existe deja, l'acceptance run (lecture seule) tourne
    meme en DryRun et son refus s'applique.

.PARAMETER CredentialFile
    Chemin du fichier DPAPI. Defaut : %USERPROFILE%\.roo-state-manager\
    winrm-classifier.cred.xml.

.PARAMETER IntervalMinutes
    Cadence du tir (defaut 5).

.PARAMETER LauncherDir
    Repertoire des VBS generes (convention roo-extensions de
    harden-hidden-tasks : C:\ProgramData\claude-hidden-launchers).

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File scripts\scheduling\install-usability-classifier-task.ps1 -DryRun

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -File scripts\scheduling\install-usability-classifier-task.ps1

.NOTES
    PS 5.1 compatible (pas de ternaire, pas de ??, pas de -Encoding
    utf8NoBom). Tache : Claude-UsabilityClassifier.
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$CredentialFile = "",
    [int]$IntervalMinutes = 5,
    [string]$LauncherDir = "C:\ProgramData\claude-hidden-launchers"
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($CredentialFile)) {
    $CredentialFile = Join-Path $HOME '.roo-state-manager\winrm-classifier.cred.xml'
}
if ($IntervalMinutes -lt 1) {
    Write-Host "ERROR: -IntervalMinutes doit etre >= 1 (recu : $IntervalMinutes)." -ForegroundColor Red
    exit 1
}

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$launcherPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDir 'start-usability-classifier.ps1'))
$classifierPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..\diagnostic\classify-machine-usability.ps1'))
$taskName = 'Claude-UsabilityClassifier'

# REFUS: a launcher resolved INSIDE a git worktree dies when the worktree is
# cleaned up (the VBS then points into the void), and a worktree path escapes
# the #4097 deletion predicate (which guards the MAIN checkout's
# scripts/scheduling/). Refuse loudly and name the main checkout.
if ($launcherPath -match '[\\/]\.claude[\\/]worktrees[\\/]') {
    $mainCheckout = $null
    try {
        # A linked worktree resolves to the main checkout's .git common dir;
        # the main checkout is its DIRECT parent (one Split-Path too many
        # named "D:\" instead of "D:\roo-extensions", measured 28/10).
        $commonDir = & git -C $scriptDir rev-parse --git-common-dir 2>$null
        if ($commonDir) {
            $commonDir = ([string]$commonDir).Trim()
            if (-not [System.IO.Path]::IsPathRooted($commonDir)) { $commonDir = Join-Path $scriptDir $commonDir }
            $mainCheckout = [System.IO.Path]::GetFullPath((Split-Path $commonDir -Parent))
        }
    } catch { }
    if (-not $mainCheckout) { $mainCheckout = 'D:\roo-extensions' }
    Write-Host "REFUS: le lanceur resolu vit dans un worktree git : $launcherPath" -ForegroundColor Red
    Write-Host "Un worktree est un lieu de travail ephemere : nettoye, le VBS pointe dans le vide, et le chemin echappe au predicat de suppression #4097." -ForegroundColor Red
    Write-Host "Relancer l'installation depuis le checkout principal : $mainCheckout" -ForegroundColor Red
    exit 1
}

# Computed AFTER the refusal: Join-Path on the default C:\ProgramData dir
# throws where drive C: does not exist (the Linux CI runner), and that must
# not pre-empt the refusal.
$vbsPath = Join-Path $LauncherDir ("{0}.vbs" -f $taskName)

# --- Pre-flight ----------------------------------------------------------------
foreach ($p in @($launcherPath, $classifierPath)) {
    if (-not (Test-Path $p)) {
        Write-Host "ERROR: script manquant : $p" -ForegroundColor Red
        exit 1
    }
}
$psExe = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $psExe) {
    Write-Host "ERROR: powershell.exe introuvable dans le PATH." -ForegroundColor Red
    exit 1
}
Write-Host ("[INFO] powershell : {0}" -f $psExe)
Write-Host ("[INFO] credential : {0}" -f $CredentialFile)
Write-Host ("[INFO] tache      : {0} (toutes les {1} min, utilisateur courant, sans elevation)" -f $taskName, $IntervalMinutes)

# --- (a) Credential file : prompt + Export-Clixml s'il est absent --------------
$credOk = $false
if (Test-Path $CredentialFile) {
    try {
        $credTest = Import-Clixml -LiteralPath $CredentialFile
        if ($credTest -is [System.Management.Automation.PSCredential]) { $credOk = $true }
    } catch { $credOk = $false }
    if (-not $credOk) {
        Write-Host "WARNING: le fichier existe mais n'est pas un PSCredential lisible : $CredentialFile" -ForegroundColor Yellow
    }
}
if (-not $credOk) {
    if ($DryRun) {
        Write-Host "[DRY] Credential absent/invalide : rien n'est ecrit, Get-Credential ne sera pas prompte."
        Write-Host "      L'acceptance run est sautee (rien a valider) ; au run reel un prompt Get-Credential crea le fichier."
    } else {
        Write-Host "Prompt pour le compte WinRM utilise pour lire les journaux System des sieges"
        Write-Host "(DPAPI : le fichier ne sera lisible que par l'utilisateur courant)."
        try {
            $cred = Get-Credential -Message "Compte WinRM du usability classifier (stocke dans $CredentialFile)"
        } catch {
            # Prompt annule : sortie CLAIRE - jamais exporter un credential $null.
            Write-Host "Get-Credential annule - rien n'est ecrit, aucune tache n'est enregistree." -ForegroundColor Yellow
            exit 1
        }
        if ($null -eq $cred) {
            Write-Host "Aucun credential fourni - rien n'est ecrit, aucune tache n'est enregistree." -ForegroundColor Yellow
            exit 1
        }
        $credDir = Split-Path $CredentialFile -Parent
        if ($credDir -and -not (Test-Path $credDir)) { New-Item -ItemType Directory -Path $credDir -Force | Out-Null }
        $cred | Export-Clixml -Path $CredentialFile
        Write-Host "Credential file ecrit : $CredentialFile" -ForegroundColor Green
        $credOk = $true
    }
}

# --- (b) Acceptance run : le credential doit PROUVER qu'il lit les logs --------
if ($credOk) {
    Write-Host ""
    Write-Host "Acceptance run : classify-machine-usability.ps1 -NoAlert -Json -CredentialFile (lecture seule, aucune alerte)..."
    $acceptOut = & $psExe -NoProfile -ExecutionPolicy Bypass -File $classifierPath -NoAlert -Json -CredentialFile $CredentialFile 2>&1
    $acceptCode = $LASTEXITCODE
    $json = $null
    try { $json = ($acceptOut -join "`n") | ConvertFrom-Json } catch { $json = $null }

    if ($null -eq $json -or $null -eq $json.machines) {
        Write-Host "REFUS: l'acceptance run n'a produit aucun JSON exploitable (exit $acceptCode). Aucune tache n'est enregistree." -ForegroundColor Red
        foreach ($l in @($acceptOut | Select-Object -Last 10)) { Write-Host "  $l" -ForegroundColor DarkGray }
        exit 1
    }

    Write-Host ("  (acceptance exit {0})" -f $acceptCode)
    foreach ($m in $json.machines) {
        $f = @($m.findings)
        $fs = if ($f.Count -gt 0) { $f -join ', ' } else { '-' }
        Write-Host ("  {0,-16} {1,-22} {2}" -f $m.machine, $m.verdict, $fs)
    }

    $windowsSeats = @($json.machines | Where-Object { [int]$_.drivingPort -eq 5985 })
    # The seat running the installer reads its own log in-process (systemLogChannel
    # 'local', #4327 31/10): that read never touches the credential, so it can prove
    # nothing about it. Only remote reads count, or a bad credential passes on the
    # strength of the local row alone.
    $reachable = @($windowsSeats | Where-Object { $_.verdict -ne 'unreachable' -and $_.systemLogChannel -ne 'local' })
    $logUnavail = @($reachable | Where-Object { @($_.findings) -contains 'system-log-unavailable' })

    if ($windowsSeats.Count -eq 0) {
        Write-Host "REFUS: aucun siege ne porte de drivingPort dans le JSON d'acceptance - impossible de distinguer les sieges Windows, le credential ne peut pas etre valide. Aucune tache n'est enregistree." -ForegroundColor Red
        exit 1
    }
    if ($reachable.Count -eq 0) {
        Write-Host "REFUS: aucun siege Windows DISTANT joignable dans l'acceptance run (la ligne du siege local est lue sans le credential et ne compte pas) - le credential ne peut etre valide. Aucune tache n'est enregistree." -ForegroundColor Red
        exit 1
    }
    if ($logUnavail.Count -eq $reachable.Count) {
        Write-Host ("REFUS: system-log-unavailable sur TOUS les {0} siege(s) Windows joignable(s) ({1}) - le credential ne fonctionne pas." -f $reachable.Count, (($logUnavail | ForEach-Object { $_.machine }) -join ', ')) -ForegroundColor Red
        Write-Host "A corriger avant de relancer :"
        Write-Host "  - le compte doit exister cote sieges et etre autorise sur WinRM (TrustedHosts / comptes locaux) ;"
        Write-Host "  - il doit pouvoir lire le journal System a distance : verifier a la main"
        Write-Host "      Invoke-Command -ComputerName <siege> -Credential <cred> { Get-WinEvent -LogName System -MaxEvents 1 }"
        Write-Host "  - si le compte est bon mais refuse, le compte a besoin des droits de lecture des events a distance."
        Write-Host "Aucune tache n'est enregistree."
        exit 1
    }
    Write-Host ("Acceptance OK : {0}/{1} siege(s) Windows joignable(s) lisent leur journal System." -f ($reachable.Count - $logUnavail.Count), $reachable.Count) -ForegroundColor Green
}

# --- (c) Construction de la tache ----------------------------------------------
# wscript + VBS = la convention harden-hidden-tasks : Run(cmd, 0, True) passe
# SW_HIDE dans le STARTUPINFO du CreateProcess, conhost n'est jamais affiche.
# La ligne de commande est FIGEE dans le VBS (aucun argument a wscript : pas de
# mauvais echappement de guillemets a la frontiere Task Scheduler -> wscript).
$cmd = 'powershell.exe -ExecutionPolicy Bypass -File "{0}" -CredentialFile "{1}"' -f $launcherPath, $CredentialFile
$vbsCmd = $cmd -replace '"', '""'
$vbs = @"
' Genere par install-usability-classifier-task.ps1 -- NE PAS EDITER A LA MAIN.
' Tache : $taskName (#4327, RX122) - usability classifier de la flotte, toutes les $IntervalMinutes min.
' Principe : Run(cmd, 0, True) passe SW_HIDE -> pas de flash conhost (convention harden-hidden-tasks).
' Fiabilite : On Error Resume Next + WScript.Quit Err.Number -> un echec remonte au
'             scheduler au lieu de rendre 0 (classe incident vllm 26/10).
Option Explicit
Dim sh, rc
On Error Resume Next
Set sh = CreateObject("WScript.Shell")
If Err.Number <> 0 Then WScript.Quit Err.Number
rc = sh.Run("$vbsCmd", 0, True)
If Err.Number <> 0 Then WScript.Quit Err.Number
WScript.Quit rc
"@

$action = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B //Nologo "{0}"' -f $vbsPath)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
# Repetition indefinie : Duration nulle EXPLICITEMENT, pas -RepetitionDuration
# ([TimeSpan]::MaxValue) - Server 2019 refuse cette valeur avec 0x80041318 et
# l'erreur est NON terminante (install-gdrivefs-watchdog-schtask.ps1 ;
# setup-scheduler.ps1 #967) : une tache qui affiche "Installed" alors que le
# trigger n'a jamais atterri.
$trigger.Repetition.Duration = $null
$trigger.Repetition.StopAtDurationEnd = $false
# Utilisateur courant, Interactive, Limited : ni le run ni l'enregistrement ne
# demandent d'elevation (precedent mesure #3834), pas de mot de passe stocke.
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -MultipleInstances IgnoreNew
$description = "Fleet usability classifier toutes les $IntervalMinutes min (#4327, RX122) : classify-machine-usability.ps1 avec -CredentialFile ; une alerte par incident (id stable machine+verdict+boot), cross-post workspace:Maintenance. Levier dur non tire par cette tache."

# --- DryRun : afficher, ne rien ecrire -----------------------------------------
if ($DryRun) {
    Write-Host ""
    Write-Host "========== DRY RUN - $taskName (rien n'est ecrit) ==========" -ForegroundColor Cyan
    Write-Host "Action      : $($action.Execute) $($action.Arguments)"
    Write-Host "Trigger     : Once a $(Get-Date -Format 'yyyy-MM-dd HH:mm') + repetition toutes les $IntervalMinutes min, duree indefinie"
    Write-Host "Principal   : $($principal.UserId) (RunLevel: $($principal.RunLevel), LogonType: $($principal.LogonType))"
    Write-Host "Settings    : StartWhenAvailable, MultipleInstances=IgnoreNew, batteries OK"
    Write-Host "Description : $description"
    Write-Host "VBS         : $vbsPath"
    Write-Host "  $vbs"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Pour enregistrer : relancer sans -DryRun (sans elevation)."
    exit 0
}

# --- Enregistrement (sans elevation) -------------------------------------------
if (-not (Test-Path $LauncherDir)) {
    New-Item -ItemType Directory -Path $LauncherDir -Force | Out-Null
}
# VBS en ASCII/ANSI-safe, sans BOM : wscript parse dans la codepage systeme.
[System.IO.File]::WriteAllText($vbsPath, $vbs, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "VBS ecrit : $vbsPath" -ForegroundColor Green

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Tache existante retiree : $taskName" -ForegroundColor Gray
}
Register-ScheduledTask -TaskName $taskName `
    -Action $action -Trigger $trigger -Principal $principal `
    -Settings $settings -Description $description | Out-Null

Write-Host "Tache enregistree : $taskName (toutes les $IntervalMinutes min, $env:USERNAME, sans elevation)" -ForegroundColor Green
Write-Host "  Lanceur  : $launcherPath"
Write-Host "  Log      : outputs\scheduling\logs\usability-classifier.log (dans le repo)"
Write-Host "  Tir test : schtasks /run /tn `"$taskName`""
