<#
.SYNOPSIS
    Decisions injectables du watchdog GDriveFS (defaut #4508 : kill confirme +
    repaired verifie par ecriture).

.DESCRIPTION
    Extraites de gdrivefs-watchdog.ps1 pour etre testables sous Pester sans
    monter reellement G: ni tuer de processus -- les sondes sont injectables.

    Defaut #4508 (mesure ai-01, nuit du 03/11, journal
    outputs/gdrivefs-watchdog/watchdog-20261103.log) :

    1. KILL SUR UN SEUL PROBE. 03:04:30 : UN timeout stat de 5 s sur un
       DriveFS VIVANT (pids 22556,23148) a suffit pour que le watchdog le tue
       (03:04:33). La maintenance automatique Windows (Defender, Chkdsk
       ProactiveScan, StorageSense, NGEN -- 02:55:37-02:58:52) rend un montage
       OCCUPE, pas coince : le kill a transforme une minute lente en coupure
       de 20 minutes. Un probe qui se recupere = occupe : on journalise, on ne
       tue pas.

    2. REPAIRED AVANT QUE LE DISQUE SOIT UTILISABLE. $script:repairs etait
       alimente des le retour de Start-Process (03:04:36), et le resume
       evenement 1000 "repaired" partait a 03:04:38 pendant que la ligne
       suivante du journal disait que G: n'existait pas encore. La meme nuit,
       C1 est passe vert a 03:18:28 alors qu'une ecriture profonde etait
       encore refusee a 03:23:05 (mesure NanoClaw 05:31Z) : stat+enum ne
       prouve pas l'aptitude a ecrire. "repaired" n'est emis qu'apres une
       ecriture sentinelle REUSSIE (ecriture + relecture + suppression dans un
       dossier profond du montage) ; sinon evenement distinct write-pending.

    Kill-switchs (parametres du script principal, style existant) :
      -ConfirmKillProbeSeconds 0  -> kill sur le premier probe echoue (legacy)
      -SkipWriteVerify            -> repaired des Start-Process (legacy)

    PS 5.1 compatible : pas de ternaire, pas de ?., ASCII uniquement.
#>

function Confirm-C1Failure {
    # Regle 1 : un echec C1 sur une instance VIVANTE ne declenche un kill
    # qu'apres confirmation -- un second probe PLUS LONG dans le meme poll.
    # Un probe qui reussit = montage occupe (maintenance, scan), pas coince :
    # Confirmed=$false et l'appelant ne tue rien.
    # ConfirmSeconds <= 0 = kill-switch legacy : kill sur le seul premier probe,
    # sans executer le second (le court-circuit precede l'appel).
    # $RunProbe recoit le timeout en secondes et doit rendre une hashtable
    # { Live = bool; Reason = string } (la forme de Test-GDriveFSMountLive).
    # Tout resultat non exploitable ($null, pas de Live) est traite comme
    # CONFIRME : fail-closed, un probe muet ne sauve jamais une instance
    # potentiellement coincee... et ne la tue pas seul pour autant -- le
    # premier echec reste un echec, la question est la confirmation.
    param(
        [string]$InitialReason,
        [int]$ConfirmSeconds,
        [scriptblock]$RunProbe
    )
    if ($ConfirmSeconds -le 0) {
        return @{ Confirmed = $true; Reason = 'legacy-single-probe' }
    }
    $second = & $RunProbe $ConfirmSeconds
    if ($second -and $second.Live) {
        return @{ Confirmed = $false; Reason = 'busy-recovered' }
    }
    $secondReason = 'probe-invalid'
    if ($second) { $secondReason = [string]$second.Reason }
    return @{ Confirmed = $true; Reason = "confirmed-by-second-probe-${ConfirmSeconds}s ($secondReason)" }
}

function Invoke-MountWriteProbe {
    # Regle 2 : sonde d'ecriture PROFONDE. Ecrit une sentinelle sous
    # $FolderPath (cree au besoin), la relit, la supprime. C'est le veritable
    # critere "disque utilisable" : apres une relance, G: stat/enum reussit
    # pendant que les ecritures profondes sont encore refusees 15-20 min
    # (mesure 03/11 : C1 vert 03:18:28, ecriture refusee 03:23:05).
    # Rend @{ WriteOk = bool; Detail = string } ; ne leve jamais.
    # $Probe (optionnel) remplace l'implementation complete pour les tests
    # (runners CI ubuntu : aucun montage reel n'existe la-bas).
    param(
        [string]$FolderPath,
        [scriptblock]$Probe
    )
    if ($Probe) {
        return (& $Probe $FolderPath)
    }
    try {
        if (-not (Test-Path -LiteralPath $FolderPath)) {
            New-Item -ItemType Directory -Path $FolderPath -Force -ErrorAction Stop | Out-Null
        }
        $name = 'sentinel-{0}.tmp' -f ([guid]::NewGuid().ToString('N'))
        $path = Join-Path $FolderPath $name
        $payload = 'gdrivefs-watchdog-write-probe'
        Set-Content -LiteralPath $path -Value $payload -Encoding Ascii -ErrorAction Stop
        $readBack = Get-Content -LiteralPath $path -ErrorAction Stop
        Remove-Item -LiteralPath $path -Force -ErrorAction Stop
        if ("$readBack" -ne $payload) {
            return @{ WriteOk = $false; Detail = 'readback-mismatch' }
        }
        return @{ WriteOk = $true; Detail = 'write+read+delete-ok' }
    } catch {
        return @{ WriteOk = $false; Detail = $_.Exception.Message }
    }
}

function Get-RepairEventVerdict {
    # Verdict d'evenement pour un cycle post-relance :
    #   'repaired'      -> processus vivant, C1 vivant, ecriture profonde OK
    #   'write-pending' -> processus vivant, C1 vivant, ecriture refusee
    #   'deferred'      -> processus ou C1 pas encore la : la fenetre de grace
    #                       (StartupGraceSeconds, #3466) garde le verdict
    # Un consommateur peut ainsi distinguer "processus revu" de "disque
    # utilisable" -- l'evenement 1000 repaired ne dit plus que la seconde.
    param(
        [bool]$ProcessAlive,
        [bool]$C1Live,
        $WriteResult
    )
    if (-not $ProcessAlive) { return 'deferred' }
    if (-not $C1Live) { return 'deferred' }
    if ($WriteResult -and $WriteResult.WriteOk) { return 'repaired' }
    return 'write-pending'
}
