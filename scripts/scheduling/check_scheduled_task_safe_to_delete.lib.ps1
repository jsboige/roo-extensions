<#
.SYNOPSIS
    Fonctions pures du garde pre-suppression de taches planifiees (#4097).

.DESCRIPTION
    Incident fondateur (x2 le 06/10, po-204 03:16Z puis po-203 09:28Z) : un audit
    supprime un lanceur Claude* en se fiant au NOM, alors que la CHARGE UTILE (le
    .vbs genere par harden-hidden-tasks.ps1) le designe lanceur roo-extensions
    protege. La lecon « lire le VBS, pas le nom » etait une consigne de prose ;
    ces fonctions en font un garde outille.

    Extractions dans une .lib pour testabilite Pester sur objets SYNTHETIQUES
    (aucune tache reelle touchee) -- meme idiom que harden-hidden-tasks.lib.ps1
    (#4118). Les patterns de resolution sont ALIGNES sur harden-hidden-tasks.ps1
    (meme launcherPattern / targetPattern) : le garde et le generateur ne doivent
    jamais diverger sur ce qu'est un lanceur.

    PS 5.1 compatible : pas de ternaire, pas de ?. ; ASCII uniquement.
#>

# Chemin du lanceur .vbs dans Execute+Arguments -- identique au generateur.
$script:LauncherPattern = '(?i)((?:[A-Za-z]:[/\\]|\\\\)[^"]*\.vbs)'

# Scripts cibles embarques dans le texte du .vbs -- identique au generateur.
$script:TargetPattern = '(?i)((?:[A-Za-z]:[/\\]|/[a-z]/)[^"''\r\n]*?\.(?:ps1|py|js|cjs|bat|cmd|exe))'

# Predicat « lanceur roo-extensions protege » : la cible resolue vit sous le
# repertoire scheduling du depot (les lanceurs generes par harden-hidden-tasks
# pointent tous sur scripts/scheduling/*.ps1). Le chemin du depot varie par
# machine (D:\dev, D:\Dev...) : on ancre sur le SEGMENT, pas sur une racine.
$script:ProtectedSegmentPattern = '(?i)roo-extensions\\scripts\\scheduling\\'

function Get-TaskLauncherVbs {
    # Execute+Arguments bruts -> chemin du .vbs reference, ou $null. Un hote
    # wscript lance aussi du .js/.wsf qui n'est pas a nous : sans .vbs, la
    # reponse est $null et l'appelant juge sur l'Execute direct.
    param([string]$Execute, [string]$Arguments)
    $haystack = ('{0} {1}' -f $Execute, $Arguments)
    $m = [regex]::Match($haystack, $script:LauncherPattern)
    if ($m.Success) { return $m.Groups[1].Value }
    return $null
}

function Get-VbsScriptTargets {
    # Texte du .vbs -> liste des scripts cibles embarques (commande en dur par
    # le generateur, guillemets doubles "" : le targetPattern les exclut par
    # classe niee, pas de unescaping necessaire).
    param([string]$VbsText)
    if ([string]::IsNullOrWhiteSpace($VbsText)) { return @() }
    $targets = @()
    foreach ($m in [regex]::Matches($VbsText, $script:TargetPattern)) {
        $t = $m.Groups[1].Value.Trim()
        if ($t) { $targets += $t }
    }
    return $targets
}

function Get-TaskScriptTargets {
    # RESOLUTION COMPLETE : la charge utile reelle de la tache, pas son nom.
    # 1. .vbs reference -> on lit le lanceur et on extrait ses cibles ;
    # 2. sinon, l'Execute direct s'il est un script (+ cibles dans Arguments).
    # Rend @{ Targets = @(...); Launcher = <vbs|$null>; Readable = $bool } --
    # Readable=$false (vbs introuvable/illisible) = INSTRUMENT chez l'appelant,
    # jamais « pas protege » : un garde muet ne valide rien.
    param([string]$Execute, [string]$Arguments, [scriptblock]$ReadFile)
    $result = @{ Targets = @(); Launcher = $null; Readable = $true }
    $vbs = Get-TaskLauncherVbs -Execute $Execute -Arguments $Arguments
    if ($vbs) {
        $result.Launcher = $vbs
        $text = & $ReadFile $vbs
        if ($null -eq $text) { $result.Readable = $false; return $result }
        $result.Targets = Get-VbsScriptTargets -VbsText $text
        return $result
    }
    # Pas de vbs : l'Execute EST la charge utile si c'est un script.
    $exe = ('{0}' -f $Execute).Trim().Trim('"')
    if ($exe -match '(?i)\.(ps1|py|js|cjs|bat|cmd)$') { $result.Targets += $exe }
    foreach ($m in [regex]::Matches(([string]$Arguments), $script:TargetPattern)) {
        $result.Targets += $m.Groups[1].Value.Trim()
    }
    return $result
}

function Test-IsProtectedRooLauncher {
    # True si AU MOINS une cible resolue vit sous roo-extensions\scripts\scheduling\.
    # C'est le verdict du garde : le nom de la tache n'intervient NULLE PART.
    param([string[]]$Targets)
    foreach ($t in @($Targets)) {
        if ($t -and ($t -match $script:ProtectedSegmentPattern)) { return $true }
    }
    return $false
}

function Test-HasPreopBackup {
    # True si un XML de sauvegarde pre-op existe pour la tache dans BackupDir.
    # Convention flotte : preop-backup\<TaskName>-<machine>-<timestamp>.xml
    # (incident 06/10 : les XML restaient la preuve de restauration). Le nom de
    # tache est sanitize comme harden-hidden-tasks (caracteres interdits -> _).
    param([string]$TaskName, [string]$BackupDir, [scriptblock]$TestPath)
    if ([string]::IsNullOrWhiteSpace($TaskName)) { return $false }
    $safe = $TaskName -replace '[\\/:*?"<>|]', '_'
    $pattern = '{0}-*.xml' -f $safe
    # Construction en chaine pure, PAS Join-Path : sur un lecteur inexistant
    # (X:\ en test), Join-Path leve avant meme que Test-Path puisse repondre
    # faux -- la question est l'EXISTENCE du fichier, pas la validite du lecteur.
    $probe = '{0}\{1}' -f ($BackupDir.TrimEnd('\')), $pattern
    return [bool](& $TestPath $probe)
}
