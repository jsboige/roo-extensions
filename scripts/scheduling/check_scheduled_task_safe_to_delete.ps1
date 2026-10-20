<#
.SYNOPSIS
    Garde pre-suppression de taches planifiees Claude* (#4097) : la charge utile decide, pas le nom.

.DESCRIPTION
    Incident fondateur (x2 le 06/10) : des audits ont supprime des lanceurs
    Claude-Worker / Claude-MetaAudit en se fiant au NOM, alors que le .vbs
    embarquait start-claude-worker.ps1 / start-meta-audit.ps1 sous
    roo-extensions\scripts\scheduling\ -- des lanceurs proteges, generes par
    harden-hidden-tasks.ps1. Perte de heartbeat worker + restauration erronnee
    en etat Enabled (occurrence 2).

    Ce garde rend le verdict AVANT tout Unregister-ScheduledTask / schtasks /delete :

      [SAFE]                  ni lanceur roo-extensions, ET XML pre-op present
      [REFUSED:PROTECTED]     une cible resolue vit sous roo-extensions\scripts\scheduling\
                              (les deux separateurs : \ et /)
      [REFUSED:NO-BACKUP]     aucun XML de sauvegarde pre-op dans le BackupDir
      [INSTRUMENT]            tache introuvable, lanceur illisible, ou lanceur
                              LU sans cible script extraite (contenu opaque :
                              -EncodedCommand, chaine .cmd...) -- lisible
                              n'est pas compris ; un garde muet ne valide rien,
                              il arrete

    Une tache invisible au jeton courant (SYSTEM / RunLevel Highest) rend
    "introuvable" : c'est INSTRUMENT, pas SAFE (regle UAC -- "absent" en
    non-eleve n'est pas une mesure).

    LECTURE PURE : ce script ne supprime rien, n'exporte rien, n'ecrit rien.
    La sauvegarde XML reste un geste de l'operateur (ligne de commande imprimee
    au refus NO-BACKUP).

    PS 5.1 compatible (ASCII uniquement) ; les fonctions pures testables vivent
    dans check_scheduled_task_safe_to_delete.lib.ps1.

.PARAMETER TaskName
    Nom(s) exact(s) de tache a verifier (jamais un wildcard : le garde juge
    des taches identifiees, un sweep sauvage est l'anti-pattern meme de #4097).

.PARAMETER BackupDir
    Repertoire des XML pre-op (defaut : ~\.roo-state-manager\preop-backup).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\scheduling\check_scheduled_task_safe_to_delete.ps1 "Claude-Worker"
    # exit 0 = supprimable ; exit 1 = REFUSED (ne pas supprimer) ; exit 2 = instrument

.NOTES
    Issue #4097. Sortie machine-readable : chaque ligne porte son marqueur
    [SAFE] / [REFUSED:*] / [INSTRUMENT].
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$TaskName,

    [string]$BackupDir = (Join-Path $env:USERPROFILE '.roo-state-manager\preop-backup')
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'check_scheduled_task_safe_to_delete.lib.ps1')

# Adapters injectables : la lib reste pure (testable sur synthetiques), l'orchestrateur
# branche les vrais E/S.
$readFile = {
    param([string]$Path)
    try { return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop) }
    catch { return $null }
}
$testPath = {
    param([string]$Path)
    return (Test-Path -Path $Path -ErrorAction SilentlyContinue)
}

$worst = 0   # 0 SAFE / 1 REFUSED / 2 INSTRUMENT -- l'etat le pire gagne

foreach ($name in $TaskName) {
    try {
        $task = Get-ScheduledTask -TaskName $name -ErrorAction Stop
    } catch {
        Write-Output ('[INSTRUMENT] {0} : introuvable au jeton courant ({1})' -f $name, $_.Exception.Message.Trim())
        $worst = 2
        continue
    }

    $resolved = @{ Targets = @(); Launcher = $null; Readable = $true; Opaque = $false }
    foreach ($action in @($task.Actions)) {
        if ($null -eq $action) { continue }
        $r = Get-TaskScriptTargets -Execute ([string]$action.Execute) -Arguments ([string]$action.Arguments) -ReadFile $readFile
        if ($r.Launcher) { $resolved.Launcher = $r.Launcher }
        if (-not $r.Readable) { $resolved.Readable = $false }
        if ($r.Opaque) { $resolved.Opaque = $true }
        $resolved.Targets += @($r.Targets)
    }

    if (-not $resolved.Readable) {
        Write-Output ('[INSTRUMENT] {0} : lanceur {1} illisible -- reparer/lire avant decision' -f $name, $resolved.Launcher)
        $worst = 2
        continue
    }

    if ($resolved.Opaque) {
        Write-Output ('[INSTRUMENT] {0} : lanceur {1} lu mais AUCUNE cible script extraite (contenu opaque ?) -- lire avant decision, lisible n''est pas compris' -f $name, $resolved.Launcher)
        $worst = 2
        continue
    }

    if (Test-IsProtectedRooLauncher -Targets $resolved.Targets) {
        $payload = (@($resolved.Targets) | Where-Object { $_ -match $script:ProtectedSegmentPattern } | Select-Object -First 1)
        Write-Output ('[REFUSED:PROTECTED] {0} : lanceur roo-extensions (charge utile {1}) -- NE PAS supprimer' -f $name, $payload)
        if ($worst -lt 1) { $worst = 1 }
        continue
    }

    if (-not (Test-HasPreopBackup -TaskName $name -BackupDir $BackupDir -TestPath $testPath)) {
        $safe = $name -replace '[\\/:*?"<>|]', '_'
        $machine = $env:COMPUTERNAME.ToLower()
        $stamp = (Get-Date).ToString('yyyyMMdd-HHmm')
        $xml = Join-Path $BackupDir ('{0}-{1}-{2}.xml' -f $safe, $machine, $stamp)
        Write-Output ('[REFUSED:NO-BACKUP] {0} : aucun XML pre-op dans {1}' -f $name, $BackupDir)
        Write-Output ('    creer d''abord : Export-ScheduledTask -TaskName "{0}" | Out-File -Encoding utf8 "{1}"' -f $name, $xml)
        if ($worst -lt 1) { $worst = 1 }
        continue
    }

    $detail = ''
    if (@($resolved.Targets).Count -gt 0) { $detail = ' (charge utile : {0})' -f (@($resolved.Targets) -join ' ; ') }
    # Un lanceur declare SANS cible extraite n'arrive jamais ici : Opaque -> INSTRUMENT ci-dessus.
    Write-Output ('[SAFE] {0} : ni lanceur roo-extensions, XML pre-op present{1}' -f $name, $detail)
}

exit $worst
