<#
.SYNOPSIS
    Post the embeddings alert to the dashboard WITHOUT spawning an agent.

.DESCRIPTION
    Incident 27/10 : `check-embeddings.ps1` spawnait un `claude -p` par tir en
    echec (une boucle par ligne FAIL). Mesure du jour : 35 lignes FAIL dans le
    journal = jusqu a 35 agents spawnes pour UN SEUL incident, chacun coutant
    des tokens pour reformuler une alerte que le script connaissait deja mot
    pour mot. Le multiplicateur n etait pas le TEXTE de l alerte (#4381 a rendu
    les libelles justes) : c etait le SPAWN.

    Le post passe desormais par le CLI `rsm-dashboard-append.mjs`, comme
    `metered-link-watch.ps1` (« deterministic, no LLM spawned »), avec un
    `messageId` STABLE. Aucun agent n est lance, ni en succes ni en echec.

    #4385 avait clefe par machine + failureKind + jour UTC. Une panne de
    3 heures produisait encore 3 posts : un par kind traverse, plus un de plus
    a chaque passage de 00:00Z -- et la FIN de la panne n etait jamais postee,
    donc un lecteur ne pouvait pas distinguer un incident vivant d un incident
    clos sans re-mesurer (#4393).

    D ou un ETAT D INCIDENT, un petit fichier JSON local par machine :
      - OUVERTURE : premier echec sans incident ouvert -> UN post, clef
        `<machine>:embeddings-incident:<debut yyyyMMddTHHmm>` ; cette clef ne
        bouge plus de tout l incident.
      - PENDANT : tout echec suivant, y compris d un kind different ou apres
        00:00Z, ne poste RIEN ; il met a jour l etat (dernier kind, compteur,
        dernier tir, kinds vus).
      - CLOTURE : premier succes alors qu un incident est ouvert -> UN
        `[RESOLVED]` (debut, fin, duree, kinds vus) sous sa propre clef
        `<clef d incident>:resolved`, puis l etat est efface.
      - Un etat absent ou ILLISIBLE retombe sur le comportement historique (on
        poste) : le trou doit etre visible, jamais silencieux.

    Nouveau DEFAUT, pas une option (mandat user 27/10 : un correctif est le
    defaut, pas un opt-in). Kill-switch : `EMBEDDINGS_ALERT_INCIDENT_STATE=0`
    restaure la clef historique par kind et par jour.

    Ce que le helper ne fait PAS : il ne devine pas la cause de la panne. Le
    texte reste celui, mesure, que le moniteur a deja construit.

    Le helper est un fichier separe (meme patron que `embeddings-verdict.ps1`)
    pour etre SOURCEABLE et testable sans executer la sonde reseau.
#>

function Get-EmbeddingsAlertMessageId {
    <#
    .SYNOPSIS
        Clef historique : une alerte par machine, kind et jour UTC (kill-switch).
    #>
    param(
        [Parameter(Mandatory)][string]$MachineName,
        [Parameter(Mandatory)][string]$FailureKind,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    return ("{0}:embeddings-alert:{1}:{2}" -f $MachineName.ToLowerInvariant(), $FailureKind, $NowUtc.ToString('yyyyMMdd'))
}

function Test-EmbeddingsIncidentStateDisabled {
    <#
    .SYNOPSIS
        Kill-switch : $true quand l etat d incident est desactive.
    #>
    $raw = $env:EMBEDDINGS_ALERT_INCIDENT_STATE
    if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
    return (@('0', 'false', 'off', 'no', 'disabled') -contains $raw.Trim().ToLowerInvariant())
}

function Get-EmbeddingsIncidentMessageId {
    <#
    .SYNOPSIS
        Clef d un incident, stable du debut a la fin : machine + minute de debut.
    #>
    param(
        [Parameter(Mandatory)][string]$MachineName,
        [Parameter(Mandatory)][datetime]$StartUtc
    )
    return ("{0}:embeddings-incident:{1}" -f $MachineName.ToLowerInvariant(), $StartUtc.ToUniversalTime().ToString('yyyyMMddTHHmm'))
}

function Get-EmbeddingsIncidentResolvedMessageId {
    <#
    .SYNOPSIS
        Clef de la cloture d un incident (sa propre clef stable, donc idempotente).
    #>
    param([Parameter(Mandatory)][string]$IncidentId)
    return ("{0}:resolved" -f $IncidentId)
}

function Resolve-EmbeddingsIncidentStatePath {
    <#
    .SYNOPSIS
        Emplacement du fichier d etat : un par machine, hors depot versionne.

    .DESCRIPTION
        `outputs/` est gitignore : l etat est un artefact de la machine, pas du
        depot. `EMBEDDINGS_ALERT_STATE_DIR` deplace le repertoire (rejeu,
        tests) sans toucher a l etat de production.
    #>
    param(
        [string]$StatePath,
        [string]$MachineName = ($env:COMPUTERNAME).ToLowerInvariant()
    )
    if ($StatePath) { return $StatePath }
    $machine = $MachineName.ToLowerInvariant()
    $dir = $env:EMBEDDINGS_ALERT_STATE_DIR
    if (-not $dir) {
        # scripts/monitoring/<ici> -> racine du depot
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $dir = Join-Path $repoRoot 'outputs\monitoring\state'
    }
    return (Join-Path $dir ("embeddings-incident-{0}.json" -f $machine))
}

function Read-EmbeddingsIncidentState {
    <#
    .SYNOPSIS
        Etat lu depuis le disque : 'none' (absent), 'open' (exploitable), 'corrupt'.
    #>
    param([Parameter(Mandatory)][string]$StatePath)

    if (-not (Test-Path -LiteralPath $StatePath)) {
        return [pscustomobject]@{ Status = 'none'; Data = $null; Error = $null }
    }
    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'fichier vide' }
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
        foreach ($field in @('IncidentId', 'StartUtc', 'FailureCount')) {
            $prop = $data.PSObject.Properties[$field]
            if (-not $prop -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                throw "champ manquant : $field"
            }
        }
        if (-not $data.PSObject.Properties['Kinds'] -or -not $data.Kinds) {
            $data | Add-Member -NotePropertyName Kinds -NotePropertyValue @() -Force
        }
        return [pscustomobject]@{ Status = 'open'; Data = $data; Error = $null }
    } catch {
        return [pscustomobject]@{ Status = 'corrupt'; Data = $null; Error = $_.Exception.Message }
    }
}

function Save-EmbeddingsIncidentState {
    <#
    .SYNOPSIS
        Ecriture atomique de l etat (.tmp puis deplacement dans le meme dossier).
    #>
    param(
        [Parameter(Mandatory)][string]$StatePath,
        [Parameter(Mandatory)][object]$Data
    )
    $dir = Split-Path -Path $StatePath -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $json = $Data | ConvertTo-Json -Depth 5
    $tmp = "$StatePath.tmp"
    [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}

function Remove-EmbeddingsIncidentState {
    <#
    .SYNOPSIS
        Effacement de l etat (un incident clos n a plus d etat).
    #>
    param([Parameter(Mandatory)][string]$StatePath)
    foreach ($p in @($StatePath, "$StatePath.tmp")) {
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
    }
}

function Format-EmbeddingsIncidentDuration {
    <#
    .SYNOPSIS
        Duree lisible : secondes, minutes, ou heures + minutes.
    #>
    param([Parameter(Mandatory)][timespan]$Duration)
    if ($Duration.TotalSeconds -lt 60) { return ("{0:N0} s" -f $Duration.TotalSeconds) }
    if ($Duration.TotalMinutes -lt 60) { return ("{0:N0} min" -f $Duration.TotalMinutes) }
    return ("{0:N0} h {1:D2} min" -f [math]::Floor($Duration.TotalHours), $Duration.Minutes)
}

function ConvertTo-EmbeddingsUtcDateTime {
    <#
    .SYNOPSIS
        Normalise en UTC une date relue depuis l etat (DateTime OU chaine ISO).

    .DESCRIPTION
        ConvertFrom-Json (PS 7) convertit une chaine ISO en [datetime] de kind
        LOCAL ; la stringifier puis la reparser la relit alors comme une heure
        locale, et l incident annoncait un debut decale d une heure (mesure :
        « Opened 22:10Z » pour un debut a 23:10Z). On traite donc les deux
        representations, sans jamais passer par la culture courante.
    #>
    param([Parameter(Mandatory)][object]$Value)

    if ($Value -is [datetime]) {
        $d = [datetime]$Value
        if ($d.Kind -eq [System.DateTimeKind]::Utc) { return $d }
        if ($d.Kind -eq [System.DateTimeKind]::Local) { return $d.ToUniversalTime() }
        return [datetime]::SpecifyKind($d, [System.DateTimeKind]::Utc)
    }

    $parsed = [datetime]::Parse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind)
    if ($parsed.Kind -eq [System.DateTimeKind]::Utc) { return $parsed }
    if ($parsed.Kind -eq [System.DateTimeKind]::Local) { return $parsed.ToUniversalTime() }
    return [datetime]::SpecifyKind($parsed, [System.DateTimeKind]::Utc)
}

function New-EmbeddingsResolvedMessage {
    <#
    .SYNOPSIS
        Texte mesure de cloture : debut, fin, duree, kinds vus.

    .DESCRIPTION
        Ne dit QUE ce que la sonde a mesure : le service a repondu normalement a
        ce tir. Aucune cause de la panne n est affirmee (meme regle que les
        libelles [CRITICAL], #4381).
    #>
    param(
        [Parameter(Mandatory)][object]$Data,
        [Parameter(Mandatory)][datetime]$EndUtc,
        [string]$SuccessDetail = ''
    )

    $start = ConvertTo-EmbeddingsUtcDateTime -Value $Data.StartUtc
    $duration = Format-EmbeddingsIncidentDuration -Duration ($EndUtc - $start)
    $kinds = @(@($Data.Kinds) | Where-Object { $_ })
    $kindText = if ($kinds.Count -gt 0) { $kinds -join ' -> ' } else { 'unknown' }
    $count = [int]$Data.FailureCount
    $probeText = if ($SuccessDetail) {
        "This run's probe answered normally ($SuccessDetail)."
    } else {
        "This run's probe answered normally."
    }

    return ("Embeddings incident CLOSED on {0}. Opened {1}Z, closed {2}Z after {3}. Failure kinds seen during the incident: {4}, across {5} failed probe(s). {6} This closes incident {7}: no further [CRITICAL] is posted for it." -f `
        $Data.Machine,
        $start.ToString('yyyy-MM-ddTHH:mm'),
        $EndUtc.ToString('yyyy-MM-ddTHH:mm'),
        $duration,
        $kindText,
        $count,
        $probeText,
        $Data.IncidentId)
}

function Resolve-EmbeddingsRsmRoot {
    param([string]$RsmRoot)
    if ($RsmRoot) { return $RsmRoot }
    if ($env:RSM_SERVER_ROOT) { return $env:RSM_SERVER_ROOT }
    # scripts/monitoring/<ici> -> racine du depot -> submodule RSM
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    return (Join-Path $repoRoot 'mcps\internal\servers\roo-state-manager')
}

function Send-DashboardAlert {
    <#
    .SYNOPSIS
        Poste une alerte [TAG] via le CLI RSM. Retourne $true si le post est accepte.

    .DESCRIPTION
        Aucun spawn d agent. Une CLI absente ou `node` introuvable ne fait pas
        echouer la sonde : on ecrit un WARN lisible dans le journal du moniteur
        et on retourne $false, pour que le trou soit visible au lieu d etre
        silencieux.

        `-MessageId` permet a l appelant d imposer sa clef (incident) ; sans
        lui, la clef historique par kind et par jour UTC s applique.
    #>
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$FailureKind,
        [string]$MessageId,
        [string]$MachineName = ($env:COMPUTERNAME).ToLowerInvariant(),
        [string]$Dashboard = 'workspace:roo-extensions',
        [string]$AuthorWorkspace = 'monitoring',
        [string]$RsmRoot,
        [string]$NodePath,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $root = Resolve-EmbeddingsRsmRoot -RsmRoot $RsmRoot
    $cli = Join-Path $root 'scripts\rsm-dashboard-append.mjs'
    if (-not (Test-Path $cli)) {
        Write-Host "[WARN] dashboard CLI not found ($cli) -- alert skipped" -ForegroundColor Yellow
        return $false
    }

    if ($NodePath) {
        $node = $NodePath
    } else {
        $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
        if (-not $nodeCmd) {
            Write-Host "[WARN] node not in PATH -- dashboard alert skipped" -ForegroundColor Yellow
            return $false
        }
        $node = $nodeCmd.Source
    }

    # Le CLI exige un contenu [TAG]-prefixe (validateTaggedContent). Le tag est
    # ajoute ici, une seule fois, pour que les appelants n aient qu a passer le
    # corps mesure.
    $content = if ($Message -match '^\[') { $Message } else { "[$Tag] $Message" }
    $msgId = if ($MessageId) {
        $MessageId
    } else {
        Get-EmbeddingsAlertMessageId -MachineName $MachineName -FailureKind $FailureKind -NowUtc $NowUtc
    }

    & $node $cli --machine $MachineName --dashboard $Dashboard --message-id $msgId --author-workspace $AuthorWorkspace --content $content
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[ALERT] Dashboard post accepted (messageId $msgId)" -ForegroundColor Yellow
        return $true
    }
    Write-Host "[WARN] dashboard post failed (exit $LASTEXITCODE)" -ForegroundColor Yellow
    return $false
}

function Send-EmbeddingsIncidentAlert {
    <#
    .SYNOPSIS
        Machine a etats de l incident : ouvre, tait, ou cloture le post dashboard.

    .DESCRIPTION
        -Outcome FAIL : ouvre l incident (1 post) ou met l etat a jour (0 post).
        -Outcome OK   : cloture l incident (1 [RESOLVED]) s il etait ouvert.

        Un etat absent ou illisible retombe sur « on poste » : c est la garantie
        qu une panne ne passe jamais sous silence.

        L etat n est ecrit QUE si le post a ete accepte : sinon la panne serait
        marquee « deja annoncee » sans avoir jamais ete annoncee, et le tirage
        suivant se tairait. Meme regle pour l effacement a la cloture.

        Retourne un objet : Action ('opened'|'suppressed'|'resolved'|'none'|
        'legacy'), Posted (bool), MessageId, StatePath.
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('FAIL', 'OK')][string]$Outcome,
        [string]$FailureKind = '',
        [string]$FailureMessage = '',
        [string]$SuccessDetail = '',
        [string]$MachineName = ($env:COMPUTERNAME).ToLowerInvariant(),
        [string]$StatePath,
        [string]$RsmRoot,
        [string]$NodePath,
        [string]$Dashboard = 'workspace:roo-extensions',
        [string]$AuthorWorkspace = 'monitoring',
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $now = $NowUtc.ToUniversalTime()
    $machine = $MachineName.ToLowerInvariant()
    $path = Resolve-EmbeddingsIncidentStatePath -StatePath $StatePath -MachineName $machine
    $common = @{
        MachineName     = $machine
        RsmRoot         = $RsmRoot
        NodePath        = $NodePath
        Dashboard       = $Dashboard
        AuthorWorkspace = $AuthorWorkspace
        NowUtc          = $now
    }

    if (Test-EmbeddingsIncidentStateDisabled) {
        if ($Outcome -eq 'OK') {
            return [pscustomobject]@{ Action = 'legacy'; Posted = $false; MessageId = $null; StatePath = $path }
        }
        $legacyId = Get-EmbeddingsAlertMessageId -MachineName $machine -FailureKind $FailureKind -NowUtc $now
        $postedLegacy = Send-DashboardAlert -Tag 'CRITICAL' -Message $FailureMessage -FailureKind $FailureKind @common
        return [pscustomobject]@{ Action = 'legacy'; Posted = $postedLegacy; MessageId = $legacyId; StatePath = $path }
    }

    $state = Read-EmbeddingsIncidentState -StatePath $path

    # --- CLOTURE : premier succes alors qu un incident est ouvert ---
    if ($Outcome -eq 'OK') {
        if ($state.Status -eq 'corrupt') {
            Write-Host "[WARN] incident state unreadable ($path): $($state.Error) -- nothing to close, state cleared" -ForegroundColor Yellow
            Remove-EmbeddingsIncidentState -StatePath $path
            return [pscustomobject]@{ Action = 'none'; Posted = $false; MessageId = $null; StatePath = $path }
        }
        if ($state.Status -ne 'open') {
            return [pscustomobject]@{ Action = 'none'; Posted = $false; MessageId = $null; StatePath = $path }
        }

        $data = $state.Data
        $resolvedId = Get-EmbeddingsIncidentResolvedMessageId -IncidentId $data.IncidentId
        $message = New-EmbeddingsResolvedMessage -Data $data -EndUtc $now -SuccessDetail $SuccessDetail
        $postedResolve = Send-DashboardAlert -Tag 'RESOLVED' -Message $message -FailureKind 'resolved' -MessageId $resolvedId @common
        if ($postedResolve) {
            Remove-EmbeddingsIncidentState -StatePath $path
        } else {
            # Post perdu : on garde l etat pour que le prochain succes reessaie.
            # Effacer ici perdrait la cloture pour toujours.
            Write-Host "[WARN] RESOLVED post failed -- incident state kept for the next run" -ForegroundColor Yellow
        }
        return [pscustomobject]@{ Action = 'resolved'; Posted = $postedResolve; MessageId = $resolvedId; StatePath = $path }
    }

    # --- PENDANT : echec alors qu un incident est deja annonce ---
    if ($state.Status -eq 'open') {
        $data = $state.Data
        $kinds = @(@($data.Kinds) | Where-Object { $_ })
        if ($FailureKind -and ($kinds -notcontains $FailureKind)) { $kinds += $FailureKind }
        $data.Kinds = $kinds
        $data.FailureCount = [int]$data.FailureCount + 1
        $data.LastKind = $FailureKind
        $data.LastSeenUtc = $now.ToString('o')
        Save-EmbeddingsIncidentState -StatePath $path -Data $data
        Write-Host "[ALERT] Incident $($data.IncidentId) still open -- no new post (kind $FailureKind, failure $($data.FailureCount))" -ForegroundColor Yellow
        return [pscustomobject]@{ Action = 'suppressed'; Posted = $false; MessageId = $data.IncidentId; StatePath = $path }
    }

    # --- OUVERTURE : premier echec, ou etat absent / illisible ---
    if ($state.Status -eq 'corrupt') {
        Write-Host "[WARN] incident state unreadable ($path): $($state.Error) -- posting anyway (never silent)" -ForegroundColor Yellow
    }

    $incidentId = Get-EmbeddingsIncidentMessageId -MachineName $machine -StartUtc $now
    $newData = [pscustomobject]@{
        Version      = 1
        Machine      = $machine
        IncidentId   = $incidentId
        StartUtc     = $now.ToString('o')
        LastSeenUtc  = $now.ToString('o')
        FailureCount = 1
        LastKind     = $FailureKind
        Kinds        = @(@($FailureKind) | Where-Object { $_ })
    }

    $postedOpen = Send-DashboardAlert -Tag 'CRITICAL' -Message $FailureMessage -FailureKind $FailureKind -MessageId $incidentId @common
    if ($postedOpen) {
        Save-EmbeddingsIncidentState -StatePath $path -Data $newData
    } else {
        # Post refuse : ne PAS marquer l incident comme annonce, sinon tous les
        # tirs suivants se taisent sur une panne que personne n a lue.
        Write-Host "[WARN] CRITICAL post failed -- incident not recorded, next run will retry" -ForegroundColor Yellow
    }
    return [pscustomobject]@{ Action = 'opened'; Posted = $postedOpen; MessageId = $incidentId; StatePath = $path }
}
