# Installation de la veille de purge MSAL - issue #1422, point 3.
#
# Objectif : « le faire partir seul quand la derniere fenetre de VS Code se ferme ».
# Une tache planifiee SANS elevation, dans le contexte de l'utilisateur courant, sonde
# toutes les minutes ; le lanceur refuse d'ecrire tant qu'un processus VS Code vit, et
# se retire lui-meme une fois la purge faite (ou au plafond).
#
#   .\install-msal-purge-watch.ps1 -DryRun      -> construit et affiche la tache, N'ECRIT RIEN
#   .\install-msal-purge-watch.ps1 -Install     -> enregistre la tache
#   .\install-msal-purge-watch.ps1 -Uninstall   -> retire la tache
#
# Discipline UAC (regle flotte) : -DryRun d'abord, sortie postee ; la tache peut etre
# creee par un utilisateur standard, mais si l'enregistrement est refuse, le message le
# dit — ne pas relancer en eleve sans avoir poste le refus.
param(
    [switch]$DryRun,
    [switch]$Install,
    [switch]$Uninstall,
    [string]$TaskName = 'MsalPurgeWatch',
    [int]$MaxMinutes = 480,
    [string]$ScriptPath = (Join-Path $PSScriptRoot 'purge-msal.ps1')
)

$ErrorActionPreference = 'Stop'

if (@($DryRun, $Install, $Uninstall | Where-Object { $_ }).Count -ne 1) {
    Write-Host "usage: install-msal-purge-watch.ps1 -DryRun | -Install | -Uninstall"
    exit 2
}

if ($Uninstall) {
    $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if (-not $existing) { Write-Host "[INFO] tache '$TaskName' absente : rien a retirer"; exit 0 }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "[OK] tache '$TaskName' retiree"
    exit 0
}

if (-not (Test-Path $ScriptPath)) { Write-Host "[ERREUR] lanceur introuvable : $ScriptPath"; exit 1 }

$argLine = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Watch -SelfUnregisterTask "{1}" -MaxMinutes {2}' -f $ScriptPath, $TaskName, $MaxMinutes

# Chaque construction est nommee : un echec sur un runner CI doit dire LAQUELLE, pas
# rendre un exit 1 muet (mesure : marshall-scripts-pester ne voyait que le code).
function New-Step([string]$what, [scriptblock]$build) {
    try { & $build } catch {
        Write-Host "[ERREUR] $what : $($_.Exception.Message)"
        exit 1
    }
}

$action = New-Step 'New-ScheduledTaskAction' { New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argLine }

# Sonde toutes les minutes pendant la fenetre declaree ; le lanceur sort en ~50 ms
# quand VS Code est ouvert, donc le cout est nul tant que l'utilisateur travaille.
$start = (Get-Date).AddMinutes(1)
$trigger = New-Step 'New-ScheduledTaskTrigger' {
    New-ScheduledTaskTrigger -Once -At $start `
        -RepetitionInterval (New-TimeSpan -Minutes 1) `
        -RepetitionDuration (New-TimeSpan -Minutes $MaxMinutes)
}

$settings = New-Step 'New-ScheduledTaskSettingsSet' {
    New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
}

if ($DryRun) {
    Write-Host "[DRY-RUN] tache construite, RIEN enregistre."
    Write-Host "  TaskName    : $TaskName"
    Write-Host "  Execute     : powershell.exe"
    Write-Host "  Argument    : $argLine"
    Write-Host "  Trigger     : once at $($start.ToString('yyyy-MM-dd HH:mm:ss')), repeat 1 min for $MaxMinutes min"
    Write-Host "  Settings    : battery-ok, catch-up, 1 instance, limite 2 min par sonde"
    Write-Host "  Log         : $(Join-Path $env:USERPROFILE '.roo-state-manager\msal-purge\watch.log')"
    Write-Host "  Effet       : aucune ecriture tant qu'un processus Code vit ; purge une seule fois ensuite."
    exit 0
}

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) { Write-Host "[INFO] tache '$TaskName' deja presente : remplacement (-Force)" }

try {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Description 'Purge MSAL du jeton mort (#1422) a la fermeture de VS Code' `
        -Force -ErrorAction Stop | Out-Null
} catch {
    Write-Host "[REFUS] enregistrement impossible : $($_.Exception.Message)"
    Write-Host "        (ne pas relancer en eleve sans avoir poste ce refus)"
    exit 1
}

# ASCII volontairement : ce fichier est lu par powershell.exe ; sans BOM, un tiret
# cadratin UTF-8 se decode 0x94 = guillemet courbe et FERME la chaine (ParserError
# mesure sur marshall-scripts-pester). Ne pas reintroduire d'em-dash en chaine.
$t = Get-ScheduledTask -TaskName $TaskName
Write-Host "[OK] tache '$TaskName' enregistree - State=$($t.State), prochaine sonde $($start.ToString('HH:mm'))"
exit 0