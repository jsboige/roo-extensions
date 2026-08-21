<#
.SYNOPSIS
    Install/remove/list/test la schtask du worker Vibe (#3202).

.DESCRIPTION
    Miroir de setup-copilot-dispatcher.ps1 : cree la tache planifiee qui porte la cadence
    du worker Mistral Vibe (Vibe n'a pas de CronCreate — la schtask est la seule option,
    derogation motivee a #3141, decision utilisateur 21/08).

    La tache est enregistree avec un launcher VBS cache (pattern harden-hidden-tasks.ps1 :
    wscript.exe //B + WScript.Shell.Run(cmd, 0, True)) pour eviter le flash conhost que
    -WindowStyle Hidden ne supprime pas. Le VBS est genere a l'installation, avec la
    commande en dur — aucun argument n'est passe a wscript (pas de piege d'echappement).

.PARAMETER Action
    install | remove | list | test

.PARAMETER IntervalHours
    Intervalle de repetition en heures (defaut : 1 — decision utilisateur 21/08).

.PARAMETER StaggerMinutes
    Decalage du premier tir par rapport a maintenant (anti-synchronisation flotte).
    Defaut : 0.

.PARAMETER ConfigPath
    Profil JSON passe au worker (ex: scripts/scheduling/vibe-profiles/coursia.json).
    Si fourni, le worker lit workspace + harnessCommand depuis le profil.

.PARAMETER HarnessCommand
    Commande CLI Vibe (alternative a -ConfigPath).

.PARAMETER Workspace
    Workspace cible (alternative a -ConfigPath).

.PARAMETER TimeoutMinutes
    Limite d'execution de la tache planifiee (defaut : 55).

.PARAMETER TaskName
    Nom de la tache (defaut : Vibe-Worker).

.PARAMETER LauncherDir
    Repertoire des VBS generes (defaut : C:\ProgramData\claude-hidden-launchers).

.PARAMETER Force
    Autorise le remplacement d'une tache preexistante que ce script n'a pas posee.
    Sans ce commutateur, l'installation refuse de toucher a une tache etrangere.

.PARAMETER DryRun
    Previsualisation sans modification.

.EXAMPLE
    pwsh -File scripts/scheduling/setup-vibe-scheduler.ps1 -Action install -ConfigPath scripts/scheduling/vibe-profiles/coursia.json

.NOTES
    Issue : #3202 (GO user 21/08). L'installation effective attend le CLI Vibe
    (synchro extensions VS Code).
#>
[CmdletBinding()]
param(
    [ValidateSet('install','remove','list','test')]
    [string]$Action = 'list',
    [int]$IntervalHours = 1,
    [int]$StaggerMinutes = 0,
    [string]$ConfigPath = "",
    [string]$HarnessCommand = "",
    [string]$Workspace = "",
    [int]$TimeoutMinutes = 55,
    [string]$TaskName = 'Vibe-Worker',
    [string]$LauncherDir = 'C:\ProgramData\claude-hidden-launchers',
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)
$workerScript = Join-Path $scriptDir "start-vibe-worker.ps1"

# Marqueur d'appropriation : porte par la description de la tache, seul champ que ce
# script controle et que Get-ScheduledTask rend sans elevation.
$VibeTaskMarker = 'Vibe worker (#3202)'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Show-Task {
    $t = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $t) {
        Write-Host "[--] $TaskName not installed" -ForegroundColor DarkGray
        return
    }
    Write-Host "[OK] $TaskName" -ForegroundColor Green
    Write-Host "State: $($t.State)"
    Write-Host "Description: $($t.Description)"
    $a = $t.Actions | Select-Object -First 1
    Write-Host "Action: $($a.Execute) $($a.Arguments)"
}

function Get-WorkerCommandLine {
    $psExe = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { "pwsh.exe" } else { "powershell.exe" }
    $workerArgs = "-ExecutionPolicy Bypass -File `"$workerScript`""
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $workerArgs += " -ConfigPath `"$ConfigPath`""
    } else {
        if (-not [string]::IsNullOrWhiteSpace($HarnessCommand)) { $workerArgs += " -HarnessCommand `"$HarnessCommand`"" }
        if (-not [string]::IsNullOrWhiteSpace($Workspace)) { $workerArgs += " -Workspace `"$Workspace`"" }
    }
    return @{ exe = $psExe; arguments = $workerArgs }
}

function Install-Task {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would install $TaskName (interval=${IntervalHours}h, stagger=${StaggerMinutes}min)" -ForegroundColor Yellow
        return
    }

    $cmd = Get-WorkerCommandLine
    $origCmd = '"{0}" {1}' -f $cmd.exe, $cmd.arguments

    # --- VBS hidden launcher (pattern harden-hidden-tasks.ps1) ---
    if (-not (Test-Path $LauncherDir)) {
        New-Item -ItemType Directory -Path $LauncherDir -Force | Out-Null
    }
    $safeName = $TaskName -replace '[\\/:*?"<>|]', '_'
    $vbsPath = Join-Path $LauncherDir ("{0}.vbs" -f $safeName)

    # --- Garde d'appropriation (incident po-2025, 21/08) ---
    # $LauncherDir est PARTAGE avec harden-hidden-tasks.ps1, qui y conserve
    # <TaskName>.orig.json = l'action d'ORIGINE d'une tache, pour rollback exact.
    # Sans cette garde, un -TaskName designant une tache preexistante causait trois
    # degats silencieux : le .vbs etranger reecrit, le .orig.json etranger ecrase
    # (original perdu -- un rollback ulterieur restaurerait la commande Vibe), et la
    # tache elle-meme desenregistree plus bas.
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask -and -not $Force) {
        $isOurs = $existingTask.Description -and $existingTask.Description.StartsWith($VibeTaskMarker)
        if (-not $isOurs) {
            $origPath = Join-Path $LauncherDir ("{0}.orig.json" -f $safeName)
            throw ("La tache '$TaskName' existe deja et n'a pas ete posee par ce script " +
                   "(description : '$($existingTask.Description)'). L'installer la remplacerait et " +
                   "ecraserait '$origPath', qui peut contenir l'action d'origine conservee par " +
                   "harden-hidden-tasks.ps1. Choisir un autre -TaskName, ou -Force si le remplacement " +
                   "est voulu et que le rollback de la tache existante n'est plus necessaire.")
        }
    }

    $vbsCmdLiteral = $origCmd -replace '"', '""'
    $vbs = @"
' Genere par scripts/scheduling/setup-vibe-scheduler.ps1 -- NE PAS EDITER A LA MAIN.
' Tache      : $TaskName
' Objet      : lancer le worker Vibe sans jamais afficher de console.
' Mecanisme  : Run(cmd, 0, True) passe SW_HIDE dans le STARTUPINFO du CreateProcess, donc
'              conhost n'est jamais affiche -- contrairement a -WindowStyle Hidden, applique
'              seulement APRES que PowerShell ait alloue et montre sa console (le "flash").
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("$vbsCmdLiteral", 0, True)
WScript.Quit rc
"@
    Write-Utf8NoBom -Path $vbsPath -Content $vbs

    # Sauvegarde de l'action d'origine (rollback exact, convention harden-hidden-tasks.ps1)
    # Ne jamais ecraser un backup deja present : c'est la garde de
    # harden-hidden-tasks.ps1:178, dont le commentaire ci-dessus revendique la convention.
    # Un .orig.json existant est, par construction, plus proche de l'original que celui
    # qu'on s'apprete a ecrire.
    $backupPath = Join-Path $LauncherDir ("{0}.orig.json" -f $safeName)
    if (-not (Test-Path $backupPath)) {
        @{ Execute = $cmd.exe; Arguments = $cmd.arguments; WorkingDirectory = $repoRoot } |
            ConvertTo-Json | Set-Content -Path $backupPath -Encoding utf8NoBOM
    }

    # --- Scheduled task ---
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }

    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes($StaggerMinutes) `
        -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) `
        -RepetitionDuration (New-TimeSpan -Days 365)
    $action = New-ScheduledTaskAction -Execute "wscript.exe" `
        -Argument "//B //Nologo `"$vbsPath`"" -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit (New-TimeSpan -Minutes $TimeoutMinutes) `
        -StartWhenAvailable `
        -MultipleInstances IgnoreNew

    Register-ScheduledTask -TaskName $TaskName `
        -Description "$VibeTaskMarker — Mistral Vibe cadence via schtask (pas de cron dans le harnais Vibe)." `
        -Trigger $trigger -Action $action -Settings $settings -RunLevel Limited | Out-Null

    Write-Host "[OK] Installed $TaskName (interval=${IntervalHours}h, VBS=$vbsPath)" -ForegroundColor Green
}

function Remove-Task {
    if ($DryRun) {
        Write-Host "[DRY-RUN] Would remove $TaskName" -ForegroundColor Yellow
        return
    }
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existing) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "[OK] Removed $TaskName" -ForegroundColor Green
    } else {
        Write-Host "[--] $TaskName not found" -ForegroundColor DarkGray
    }
    # Nettoyage VBS + backup (si presentes)
    $safeName = $TaskName -replace '[\\/:*?"<>|]', '_'
    foreach ($f in @((Join-Path $LauncherDir "$safeName.vbs"), (Join-Path $LauncherDir "$safeName.orig.json"))) {
        if (Test-Path $f) { Remove-Item $f -Force; Write-Host "[OK] Removed $f" -ForegroundColor DarkGray }
    }
}

function Test-Task {
    Write-Host "Running vibe worker in dry-run mode..." -ForegroundColor Cyan
    $cmd = Get-WorkerCommandLine
    & $cmd.exe -ExecutionPolicy Bypass -File $workerScript -ConfigPath $ConfigPath -HarnessCommand $HarnessCommand -Workspace $Workspace -DryRun
}

switch ($Action) {
    'list' { Show-Task }
    'install' { Install-Task }
    'remove' { Remove-Task }
    'test' { Test-Task }
}
