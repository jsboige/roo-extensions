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
    `messageId` STABLE par machine + failureKind + jour UTC. Effet : le premier
    tir d une panne poste, les tirs suivants du meme jour et du meme kind sont
    des no-op (dedup serveur #3276 cote MCP, #4090 cote CLI fleet). Aucun agent
    n est lance, ni en succes ni en echec.

    Ce que le helper ne fait PAS : il ne devine pas la cause de la panne. Le
    texte reste celui, mesure, que le moniteur a deja construit.

    Le helper est un fichier separe (meme patron que `embeddings-verdict.ps1`)
    pour etre SOURCEABLE et testable sans executer la sonde reseau.
#>

function Get-EmbeddingsAlertMessageId {
    <#
    .SYNOPSIS
        Clef d idempotence stable : une alerte par machine, kind et jour UTC.
    #>
    param(
        [Parameter(Mandatory)][string]$MachineName,
        [Parameter(Mandatory)][string]$FailureKind,
        [datetime]$NowUtc = [datetime]::UtcNow
    )
    return ("{0}:embeddings-alert:{1}:{2}" -f $MachineName.ToLowerInvariant(), $FailureKind, $NowUtc.ToString('yyyyMMdd'))
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
    #>
    param(
        [Parameter(Mandatory)][string]$Tag,
        [Parameter(Mandatory)][string]$Message,
        [Parameter(Mandatory)][string]$FailureKind,
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
    $msgId = Get-EmbeddingsAlertMessageId -MachineName $MachineName -FailureKind $FailureKind -NowUtc $NowUtc

    & $node $cli --machine $MachineName --dashboard $Dashboard --message-id $msgId --author-workspace $AuthorWorkspace --content $content
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[ALERT] Dashboard post accepted (messageId $msgId)" -ForegroundColor Yellow
        return $true
    }
    Write-Host "[WARN] dashboard post failed (exit $LASTEXITCODE)" -ForegroundColor Yellow
    return $false
}
