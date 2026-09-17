<#
.SYNOPSIS
    Rend REELLEMENT invisibles les fenetres des taches planifiees (fin du flash conhost).

.DESCRIPTION
    Probleme : une tache planifiee dont le Principal est `Interactive` et dont l'action est
    `powershell.exe` / `pwsh.exe` / `cmd.exe` cree une fenetre console dans la session de
    l'utilisateur. `-WindowStyle Hidden` NE LA SUPPRIME PAS : PowerShell alloue et affiche
    conhost, PUIS applique le style. D'ou le flash d'une fraction de seconde qui vole le focus
    clavier et ampute la frappe en cours. C'est structurel, pas un reglage rate.

    Correctif : router l'action via `wscript.exe` + un script VBS qui appelle
    `WScript.Shell.Run(cmd, 0, True)`. Le style SW_HIDE est alors passe dans le STARTUPINFO au
    moment du CreateProcess : conhost n'est jamais affiche. wscript.exe etant lui-meme un
    binaire du sous-systeme GUI, il n'alloue aucune console non plus.

    Deux patterns deja presents sur ai-01 prouvent les deux voies possibles :
      - `NanoClaw-Watchdog`   : Principal S4U      -> session 0, aucune fenetre (mais perd
                                                     l'acces aux ressources de session, ex. DriveFS)
      - `SystemBlackbox-*`    : wscript.exe + .vbs -> invisible ET reste en session utilisateur
    Ce script applique la SECONDE voie : les taches Claude ecrivent sur le partage GDrive
    (DriveFS est un systeme de fichiers user-mode monte par session), un passage en session 0
    les casserait.

    Un VBS dedie est genere PAR TACHE, avec la ligne de commande en dur. Aucun argument n'est
    passe a wscript : cela elimine tout risque de mauvais echappement des guillemets a la
    frontiere Task Scheduler -> wscript -> pwsh, qui est le piege classique de cette approche.

    L'action d'origine est sauvegardee en JSON a cote du VBS, ce qui rend -Rollback exact.

    COROLLAIRE, et c'est un piege : la ligne de commande etant FIGEE dans le VBS, un chemin qui
    bouge apres le durcissement (migration de depot, repointage de tache) laisse un VBS pointant
    dans le vide ALORS QUE l'action de la tache reste parfaitement coherente. Le chemin perime ne
    vit que DANS le VBS : tout audit au niveau des actions de tache est aveugle par construction.
    Le script audite donc les lanceurs deja durcis a chaque passage, et sort en erreur si une
    tache ACTIVE pointe dans le vide. Une cible perimee sur une tache Desactivee est seulement
    signalee -- une tache legacy remplacee est un cas legitime, pas un defaut.

.PARAMETER DryRun
    N'ecrit rien : affiche le plan (taches concernees, action avant/apres).

.PARAMETER Rollback
    Restaure les actions d'origine depuis les sauvegardes JSON.

.PARAMETER TaskName
    Restreint le traitement aux taches nommees (accepte plusieurs valeurs). Par defaut, toutes
    les taches eligibles hors `\Microsoft\` sont traitees.

.PARAMETER LauncherDir
    Repertoire des VBS generes et des sauvegardes. Defaut : C:\ProgramData\claude-hidden-launchers

.EXAMPLE
    pwsh -File scripts\scheduling\harden-hidden-tasks.ps1 -DryRun
    Affiche ce qui serait modifie, sans rien changer -- et audite les lanceurs deja durcis
    (cibles perimees), ce qui en fait le mode de controle a lancer apres une migration de depot.

.EXAMPLE
    pwsh -File scripts\scheduling\harden-hidden-tasks.ps1
    Applique. Les taches RunLevel=Highest sont ignorees si la session n'est pas elevee
    (elles sont listees en fin de rapport avec la commande a rejouer en admin).

.NOTES
    Idempotent : une tache deja routee via wscript n'est pas re-routee -- mais son lanceur est
    audite (voir le COROLLAIRE du .DESCRIPTION), car « deja durcie » ne veut pas dire « cible
    encore valide ».
    Issue : gene de frappe signalee par l'utilisateur (flashes ~51/h mesures sur ai-01).
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Rollback,
    [string[]]$TaskName,
    [string]$LauncherDir = 'C:\ProgramData\claude-hidden-launchers'
)

$ErrorActionPreference = 'Stop'

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Test-Elevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

$isElevated = Test-Elevated
if (-not (Test-Path $LauncherDir)) {
    if (-not $DryRun) { New-Item -ItemType Directory -Path $LauncherDir -Force | Out-Null }
}

# --- Selection des taches ------------------------------------------------------------------
# Eligible = action console (pwsh/powershell/cmd) + Principal Interactive.
# Un Principal S4U ou Password tourne en session 0 : aucune fenetre n'atteint le bureau,
# rien a corriger.
$consoleHosts = @('powershell.exe', 'pwsh.exe', 'cmd.exe')

$all = Get-ScheduledTask | Where-Object { $_.TaskPath -notlike '\Microsoft\*' }
if ($TaskName) { $all = $all | Where-Object { $_.TaskName -in $TaskName } }

# --- Audit des lanceurs deja durcis ---------------------------------------------------------
# Une tache deja routee via `wscript.exe` est « deja durcie » au sens de la FORME. Mais le VBS
# embarque la ligne de commande FIGEE (cf. header) : si le chemin sous-jacent a bouge depuis le
# durcissement (migration de depot, repointage de tache), le VBS garde l'ancien alors que
# l'action de la tache, elle, reste coherente. Le chemin perime ne vit que DANS le VBS -- tout
# audit au niveau des actions de tache est donc aveugle par construction. On le lit ici.
$staleLaunchers = @(foreach ($t in $all) {
    $action = $t.Actions | Select-Object -First 1
    if (-not $action -or -not $action.Execute) { continue }
    if ((Split-Path $action.Execute -Leaf) -ine 'wscript.exe') { continue }

    $vbsMatch = [regex]::Match([string]$action.Arguments, '(?i)([A-Za-z]:\\[^"]*\.vbs)')
    if (-not $vbsMatch.Success) { continue }
    $vbsPath = $vbsMatch.Groups[1].Value

    if (-not (Test-Path $vbsPath)) {
        [PSCustomObject]@{ Task = $t.TaskName; State = $t.State; Launcher = $vbsPath; Target = '(lanceur introuvable)' }
        continue
    }

    $vbsText = Get-Content $vbsPath -Raw
    foreach ($m in [regex]::Matches($vbsText, '(?i)([A-Za-z]:\\[^"\r\n]*?\.(?:ps1|py|js|cjs|bat|cmd|exe))')) {
        $target = $m.Groups[1].Value.Trim()
        if (-not (Test-Path $target)) {
            [PSCustomObject]@{ Task = $t.TaskName; State = $t.State; Launcher = $vbsPath; Target = $target }
        }
    }
})
# Une tache Desactivee a legitimement un lanceur perime (tache legacy remplacee) : informatif.
# Une tache ACTIVE dont le lanceur pointe dans le vide echoue en silence -- c'est le defaut.
# `$_ -and` est indispensable : `$null | Where-Object { $_.State -ne 'Disabled' }` laisse passer
# le $null, parce que `$null -ne 'Disabled'` est VRAI -- le script sortirait 1 sur une machine
# pourtant propre.
$staleActive = @($staleLaunchers | Where-Object { $_ -and $_.State -ne 'Disabled' })

function Write-LauncherAudit {
    param($Findings)
    if (-not $Findings) {
        Write-Host "Lanceurs durcis : aucune cible perimee." -ForegroundColor Green
        return
    }
    Write-Host ""
    Write-Host "=== Lanceurs durcis : cibles perimees ===" -ForegroundColor Yellow
    foreach ($f in $Findings) {
        $color = if ($f.State -eq 'Disabled') { 'DarkGray' } else { 'Red' }
        Write-Host ("  [{0}] {1}" -f $f.State, $f.Task) -ForegroundColor $color
        Write-Host ("         lanceur : {0}" -f $f.Launcher) -ForegroundColor DarkGray
        Write-Host ("         cible   : {0}  (introuvable)" -f $f.Target) -ForegroundColor $color
    }
    if ($Findings | Where-Object { $_.State -ne 'Disabled' }) {
        Write-Host ""
        Write-Host "  Une tache ACTIVE dont le lanceur pointe dans le vide echoue en silence." -ForegroundColor Red
        Write-Host "  Reparer : re-router la tache (Set-ScheduledTask) ou la re-hardener (-Rollback puis APPLY)." -ForegroundColor Yellow
    }
}

# Taches ecartees par la garde de propriete (cf. la boucle) -- rapportees, jamais silencieuses.
$skippedForeign = @()

$plan = foreach ($t in $all) {
    $action = $t.Actions | Select-Object -First 1
    if (-not $action -or -not $action.Execute) { continue }
    $exeLeaf = Split-Path $action.Execute -Leaf

    $backupPath = Join-Path $LauncherDir ("{0}.orig.json" -f ($t.TaskName -replace '[\\/:*?"<>|]', '_'))

    if ($Rollback) {
        if (Test-Path $backupPath) {
            [PSCustomObject]@{ Task = $t; Action = $action; Backup = $backupPath; Reason = 'rollback' }
        }
        continue
    }

    # Garde de PROPRIETE. Une tache pilotee par le deployeur de staging d'une autre lane
    # (`maint-scripts\`) ne doit pas voir son action routee vers NOTRE repertoire de lanceurs :
    # cela ajouterait un artefact que l'audit de derive de cette lane n'attribuerait pas a sa
    # portee, et qu'un nettoyage de claude-hidden-launchers\ casserait en silence. Exclusion par
    # DEFAUT -- c'est une regle de propriete, pas une liste a maintenir. `-TaskName <nom>` reste
    # l'opt-in explicite pour durcir une telle tache volontairement.
    if (-not $TaskName -and $action.Arguments -like '*maint-scripts\*') { $skippedForeign += $t.TaskName; continue }

    if ($exeLeaf -ieq 'wscript.exe') { continue }                       # deja durcie
    if ($exeLeaf -notin $consoleHosts) { continue }                     # pas de console -> pas de flash
    if ($t.Principal.LogonType -ne 'Interactive') { continue }          # session 0 -> invisible deja

    [PSCustomObject]@{ Task = $t; Action = $action; Backup = $backupPath; Reason = 'harden' }
}

if ($skippedForeign.Count -gt 0) {
    Write-Host ("Exclues (deployeur d'une autre lane, maint-scripts\) : {0}" -f ($skippedForeign -join ', ')) -ForegroundColor DarkGray
    Write-Host "  Pour les durcir volontairement : relancer avec -TaskName <nom>" -ForegroundColor DarkGray
}

if (-not $plan) {
    Write-Host "Rien a faire : aucune tache eligible." -ForegroundColor Green
    Write-LauncherAudit -Findings $staleLaunchers
    if ($staleActive.Count -gt 0) { exit 1 }
    return
}

# --- Application ---------------------------------------------------------------------------
$done = @(); $needElevation = @(); $failed = @()

foreach ($item in $plan) {
    $t = $item.Task
    $a = $item.Action
    $needsAdmin = ($t.Principal.RunLevel -eq 'Highest')

    if ($needsAdmin -and -not $isElevated) {
        $needElevation += $t.TaskName
        continue
    }

    if ($Rollback) {
        $orig = Get-Content $item.Backup -Raw | ConvertFrom-Json
        $newAction = New-ScheduledTaskAction -Execute $orig.Execute -Argument $orig.Arguments `
                        -WorkingDirectory ([string]::IsNullOrWhiteSpace($orig.WorkingDirectory) ? $null : $orig.WorkingDirectory)
        if ($DryRun) {
            Write-Host ("[DRY] rollback {0} -> {1} {2}" -f $t.TaskName, $orig.Execute, $orig.Arguments)
        } else {
            Set-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Action $newAction | Out-Null
            Remove-Item $item.Backup -Force
            $done += $t.TaskName
        }
        continue
    }

    # Ligne de commande d'origine, reconstruite telle quelle.
    $origCmd = if ([string]::IsNullOrWhiteSpace($a.Arguments)) { '"{0}"' -f $a.Execute }
               else { '"{0}" {1}' -f $a.Execute, $a.Arguments }

    $safeName = $t.TaskName -replace '[\\/:*?"<>|]', '_'
    $vbsPath  = Join-Path $LauncherDir ("{0}.vbs" -f $safeName)

    # VBS auto-suffisant : la commande est en dur, wscript ne recoit aucun argument.
    # Les guillemets de la commande sont doubles ("" ) pour la syntaxe litterale VBScript.
    $vbsCmdLiteral = $origCmd -replace '"', '""'
    $vbs = @"
' Genere par scripts/scheduling/harden-hidden-tasks.ps1 -- NE PAS EDITER A LA MAIN.
' Tache      : $($t.TaskName)
' Objet      : lancer la commande sans jamais afficher de console.
' Mecanisme  : Run(cmd, 0, True) passe SW_HIDE dans le STARTUPINFO du CreateProcess, donc
'              conhost n'est jamais affiche -- contrairement a `-WindowStyle Hidden`, applique
'              seulement APRES que PowerShell ait alloue et montre sa console (le "flash").
Option Explicit
Dim sh, rc
Set sh = CreateObject("WScript.Shell")
rc = sh.Run("$vbsCmdLiteral", 0, True)
WScript.Quit rc
"@

    if ($DryRun) {
        Write-Host ("[DRY] {0}" -f $t.TaskName) -ForegroundColor Cyan
        Write-Host ("       avant : {0} {1}" -f $a.Execute, $a.Arguments) -ForegroundColor DarkGray
        Write-Host ("       apres : wscript.exe //B //Nologo `"{0}`"" -f $vbsPath) -ForegroundColor DarkGray
        continue
    }

    try {
        # Sauvegarde AVANT modification (rollback exact).
        if (-not (Test-Path $item.Backup)) {
            @{ Execute = $a.Execute; Arguments = $a.Arguments; WorkingDirectory = $a.WorkingDirectory } |
                ConvertTo-Json | Set-Content -Path $item.Backup -Encoding utf8NoBOM
        }
        Write-Utf8NoBom -Path $vbsPath -Content $vbs

        $newAction = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ('//B //Nologo "{0}"' -f $vbsPath)
        Set-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -Action $newAction | Out-Null
        $done += $t.TaskName
    } catch {
        # `RunLevel=Highest` n'est PAS le seul verrou : une tache `Limited` creee par un
        # processus eleve porte une ACL qui refuse l'ecriture a l'utilisateur courant
        # (constate sur ai-01 : Verify-Qdrant-Mount, Postgres-Dump-Daily...). Le seul test
        # fiable est la tentative elle-meme -- on classe donc a posteriori.
        if ($_.Exception.Message -match 'Acc.s refus|Access is denied|UnauthorizedAccess') {
            $needElevation += $t.TaskName
        } else {
            $failed += ("{0} : {1}" -f $t.TaskName, $_.Exception.Message)
        }
    }
}

# --- Rapport -------------------------------------------------------------------------------
Write-Host ""
Write-Host "=== harden-hidden-tasks ===" -ForegroundColor Cyan
Write-Host ("Machine    : {0}" -f $env:COMPUTERNAME)
Write-Host ("Mode       : {0}" -f $(if ($Rollback) { 'ROLLBACK' } elseif ($DryRun) { 'DRY-RUN' } else { 'APPLY' }))
Write-Host ("Elevation  : {0}" -f $(if ($isElevated) { 'oui' } else { 'non' }))
Write-Host ("Traitees   : {0}" -f $done.Count)
if ($done)   { $done | ForEach-Object { Write-Host ("  OK   {0}" -f $_) -ForegroundColor Green } }
if ($failed) { $failed | ForEach-Object { Write-Host ("  FAIL {0}" -f $_) -ForegroundColor Red } }

if ($needElevation) {
    Write-Host ""
    Write-Host "Taches RunLevel=Highest -- necessitent une session elevee :" -ForegroundColor Yellow
    $needElevation | ForEach-Object { Write-Host ("  - {0}" -f $_) -ForegroundColor Yellow }
    Write-Host ""
    Write-Host "  Rejouer dans un terminal ADMIN :" -ForegroundColor Yellow
    Write-Host ("  pwsh -File `"{0}`"" -f $PSCommandPath) -ForegroundColor Yellow
}

Write-LauncherAudit -Findings $staleLaunchers

if ($failed -or $staleActive.Count -gt 0) { exit 1 }
