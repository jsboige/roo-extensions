# gh-pull-requests.ps1 — lecture des pull requests en REST seul (#4150 lots 2-3)
#
# Doctrine #4604 : `gh pr list` / `gh pr view` / `gh issue view` passent par GraphQL ;
# le budget GraphQL de la flotte est fragmenté entre les sièges et tombe en 403 sous
# charge, alors que `gh api repos/...` consomme le budget REST (5 000 req/h, jamais
# entamé par les cycles). Lot 2 : quatre consommateurs (worktree-cleanup,
# cleanup-orphan-branches ×2, triage-merged-branches) ne lisent qu'une chose :
# « cette branche a-t-elle une PR, et est-elle mergée ? ».
#
# Lot 3 : le détail complet d'une PR (review-bot, pr-review-and-merge). Les champs
# `reviewDecision` et `statusCheckRollup` n'existent pas en REST v3 et sont composés :
#   - reviewDecision  ← GET /pulls/{n}/reviews, dernière revue significative en ordre
#     chronologique (approximation documentée : GraphQL tient aussi compte des
#     dismissals ciblés et du périmètre de branche protégée ; les consommateurs ne
#     comparent qu'à "APPROVED") ;
#   - statusCheckRollup ← GET /commits/{head_sha}/check-runs, avec normalisation de
#     casse (REST rend `completed`/`success` minuscules, gh rend COMPLETED/SUCCESS —
#     forme mesurée sur #4620 ; les consommateurs comparent en MAJUSCULES).
#   Les statuts de commit legacy (GET /commits/{sha}/status) ne sont PAS composés :
#   les deux dépôts de la flotte n'exposent que des check-runs GitHub Actions.
#   `mergeable` peut être null en REST comme en GraphQL (calcul en cours) : pass-through.
#
# Contrat de sortie inchangé : les appelants comparaient `state` à "MERGED" / "OPEN"
# (forme GraphQL, MAJUSCULES). REST rend `state = open|closed` et `merged_at`, d'où la
# normalisation : MERGED (closed + merged_at), CLOSED (closed sans merge), OPEN.
#
# Échec ≠ absence : un appel gh en erreur rend `Ok = $false` — l'appelant garde sa
# branche (fail-safe). Un tableau vide rend `Ok = $true` avec `Items = @()` (aucune PR).
#
# Usage :
#   . "$PSScriptRoot\..\common\gh-pull-requests.ps1"
#   $s = Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/foo -MaxCount 1
#   if (-not $s.Ok) { <fail-safe> } else { $s.Items[0].State }

function ConvertFrom-RestPullRequest {
    param([Parameter(Mandatory)]$Raw)

    $state = "$($Raw.state)".ToLowerInvariant()
    if ($state -eq 'open') { $state = 'OPEN' }
    elseif ($state -eq 'closed') { $state = if ($Raw.merged_at) { 'MERGED' } else { 'CLOSED' } }
    else { $state = $state.ToUpperInvariant() }

    [pscustomobject]@{
        Number      = $Raw.number
        HeadRefName = $Raw.head_ref
        State       = $state
        MergedAt    = $Raw.merged_at
        # Lot 3 : consommateurs du listing (review-bot) — filtre auteur côté client
        # (remplace `--search author:X`) et labels restreints.
        Title       = $Raw.title
        AuthorLogin = $Raw.login
        Labels      = @($Raw.labels | Where-Object { $_ })
    }
}

function Get-PullRequestSummary {
    <#
    .SYNOPSIS
        Liste des PR d'un dépôt, lues en REST (0 point GraphQL).
    .PARAMETER Repo
        slug owner/repo.
    .PARAMETER Head
        Filtre sur la branche source (nom de branche nu ; le owner est repris de Repo).
        REST exige `owner:branch` — c'est assemblé ici.
    .PARAMETER State
        open | closed | all (défaut all).
    .PARAMETER MaxCount
        Nombre maximum de PR à ramener (0 = tout, pagination complète).
        Utilisé quand l'appelant avait un `--limit N` : les mêmes PR les plus
        récentes (tri created desc) sont ramenées, à la page près.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [string]$Head,
        [ValidateSet('open', 'closed', 'all')][string]$State = 'all',
        [int]$MaxCount = 0
    )

    $perPage = 100
    $url = "repos/$Repo/pulls?state=$State&per_page=$perPage&sort=created&direction=desc"
    if ($Head) {
        $owner = ($Repo -split '/')[0]
        $url += "&head=$($owner):$Head"
    }

    # Une ligne JSON compacte par PR : même forme pour toutes les pages, sans --slurp.
    # title/login/labels (lot 3) : filter auteur côté client + labels restreints de
    # review-bot, qui listait via `gh pr list --json number,title,labels,author`.
    $jq = '.[] | {number: .number, state: .state, merged_at: .merged_at, head_ref: .head.ref, title: .title, login: .user.login, labels: [.labels[].name]}'

    $items = @()
    $page = 1
    $maxPages = if ($MaxCount -gt 0) { [Math]::Ceiling($MaxCount / $perPage) } else { 200 }
    while ($page -le $maxPages) {
        # Guillemets EXPLICITES autour de l'URL : PowerShell ne cite que les arguments
        # contenant un espace, or `&` (query string) est un métacaractère cmd.exe — sans
        # ces guillemets, cmd coupe l'URL ; mesuré : sortie correcte mais exit code 1,
        # donc la branche « échec » était prise à tort.
        $quotedUrl = '"' + $url + '&page=' + $page + '"'
        try {
            # #3731 : sous EAP=Stop (powershell.exe 5.1), le stderr d'un natif redirigé
            # devient NativeCommandError TERMINANT avant tout check de $LASTEXITCODE.
            # Ce helper tourne en production 5.1 (worktree-cleanup, sched cleanup) :
            # sans ce catch, un gh qui écrit sur stderr (quota, timeout réseau) tue le
            # run AVANT le fail-safe Ok=$false — la panne silencieuse que la PR élimine.
            $out = & gh api $quotedUrl --jq $jq 2>$null
        } catch {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api threw: $($_.Exception.Message)" }
        }
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api exit $code" }
        }
        $pageItems = @($out | Where-Object { $_ -and $_.ToString().Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        foreach ($raw in $pageItems) { $items += ConvertFrom-RestPullRequest -Raw $raw }
        if ($MaxCount -gt 0 -and $items.Count -ge $MaxCount) { break }
        if ($pageItems.Count -lt $perPage) { break }
        $page++
    }

    if ($Head) {
        # Le gh CLI peut manger le filtre `head=` par substitution interne de placeholder
        # quand le nom de branche contient le token « branch » (mesuré review #4616 :
        # head=jsboige:branch-foo rend des rows NON filtrés). On ne fait pas confiance à
        # la query string seule : la réponse est re-filtrée sur ce qu'on a demandé.
        $items = @($items | Where-Object { "$($_.HeadRefName)" -eq $Head })
    }

    if ($MaxCount -gt 0 -and $items.Count -gt $MaxCount) { $items = $items[0..($MaxCount - 1)] }
    return [pscustomobject]@{ Ok = $true; Items = @($items); Error = $null }
}

function Get-MergedPullRequestHeads {
    <#
    .SYNOPSIS
        Hashtable headRefName -> numéro de PR, pour toutes les PR mergées du dépôt.
    .DESCRIPTION
        Remplace `gh pr list --state merged --limit 5000 --json headRefName,number`
        (triage-merged-branches) : REST `state=closed` puis filtre merged_at, comme le
        faisait la jambe GraphQL. `--limit 5000` disparaît : la pagination va au bout.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Repo)

    $summary = Get-PullRequestSummary -Repo $Repo -State closed
    if (-not $summary.Ok) { return [pscustomobject]@{ Ok = $false; Map = @{}; Error = $summary.Error } }

    $map = @{}
    foreach ($pr in $summary.Items) {
        if ($pr.State -eq 'MERGED' -and $pr.HeadRefName -and -not $map.ContainsKey($pr.HeadRefName)) {
            $map[$pr.HeadRefName] = $pr.Number
        }
    }
    return [pscustomobject]@{ Ok = $true; Map = $map; Error = $null }
}

# ============================================================================
# Lot 3 (#4150) — détail complet d'une PR en REST, forme « gh pr view --json »
# ============================================================================

function Invoke-GhApiJson {
    # Interne au module : UN appel `gh api --jq`, sortie = lignes JSON (le jq rend
    # un objet par ligne, jamais un tableau — même contrat que Get-PullRequestSummary).
    # Échec ≠ absence : exit non-nul ou exception (stderr terminant en 5.1 EAP=Stop,
    # #3731) rend Ok = $false avec le motif — l'appelant décide du fail-safe.
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Jq
    )

    # Guillemets EXPLICITES : `&` (query string) est un métacaractère cmd.exe (lot 2).
    $quotedUrl = '"' + $Url + '"'
    try {
        $out = & gh api $quotedUrl --jq $Jq 2>$null
    } catch {
        return [pscustomobject]@{ Ok = $false; Lines = @(); Error = "gh api threw: $($_.Exception.Message)" }
    }
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{ Ok = $false; Lines = @(); Error = "gh api exit $LASTEXITCODE" }
    }
    $lines = @($out | Where-Object { $_ -and $_.ToString().Trim() })
    return [pscustomobject]@{ Ok = $true; Lines = $lines; Error = $null }
}

function Invoke-GhApiJsonPaged {
    # Interne au module : Invoke-GhApiJson + boucle de pagination (per_page=100,
    # arrêt sur page courte). Les endpoints de détail paginent à 30 par défaut —
    # une PR à 40 fichiers ou 40 check-runs serait tronquée sans ceci.
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$Jq,
        [int]$MaxPages = 10
    )

    $lines = @()
    $page = 1
    while ($page -le $MaxPages) {
        $sep = if ($Url.Contains('?')) { '&' } else { '?' }
        $r = Invoke-GhApiJson -Url "$Url${sep}per_page=100&page=$page" -Jq $Jq
        if (-not $r.Ok) { return $r }
        $pageLines = @($r.Lines)
        $lines += $pageLines
        if ($pageLines.Count -lt 100) { break }
        $page++
    }
    return [pscustomobject]@{ Ok = $true; Lines = $lines; Error = $null }
}

function ConvertFrom-RestReviews {
    # Approximation REST du reviewDecision GraphQL : les revues arrivent en ordre
    # chronologique ; la dernière revue SIGNIFICATIVE l'emporte.
    #   [CHANGES_REQUESTED, APPROVED] -> APPROVED     [APPROVED, CHANGES_REQUESTED] -> CHANGES_REQUESTED
    #   [APPROVED, DISMISSED]         -> REVIEW_REQUIRED (un dismissal annule l'état courant)
    #   COMMENTED est ignoré (informatif). GraphQL tient aussi compte des dismissals
    # ciblés et du périmètre de branche protégée — hors de portée REST ; les
    # consommateurs ne comparent qu'à "APPROVED" (review-bot skip les PR approuvées).
    param([Parameter(Mandatory)]$Reviews)

    $decision = 'REVIEW_REQUIRED'
    foreach ($review in @($Reviews)) {
        $state = "$($review.state)"
        if ($state -eq 'APPROVED') { $decision = 'APPROVED' }
        elseif ($state -eq 'CHANGES_REQUESTED') { $decision = 'CHANGES_REQUESTED' }
        elseif ($state -eq 'DISMISSED') { $decision = 'REVIEW_REQUIRED' }
    }
    return $decision
}

function ConvertFrom-RestCheckRun {
    # REST rend status/conclusion MINUSCULES (completed/success — mesuré sur #4620) ;
    # gh rend la forme MAJUSCULE (COMPLETED/SUCCESS) que les consommateurs comparent.
    param([Parameter(Mandatory)]$Run)

    $conclusion = $null
    if ($Run.conclusion) { $conclusion = "$($Run.conclusion)".ToUpperInvariant() }
    [pscustomobject]@{
        Name       = $Run.name
        Status     = "$($Run.status)".ToUpperInvariant()
        Conclusion = $conclusion
    }
}

function Get-CiRollupGate {
    <#
    .SYNOPSIS
        Classe un rollup de check-runs (forme ConvertFrom-RestCheckRun : Name/Status/
        Conclusion MAJUSCULES) en Pending / Failed — porte CI de pr-review-and-merge.
    .DESCRIPTION
        #4150 lot 4a : l'ancienne porte testait le vocabulaire des commit-status
        legacy sur .status (PENDING/FAILED/EXPECTED) — un check-run rouge porte
        status=COMPLETED + conclusion=FAILURE : un rouge n'a jamais bloqué le merge
        (constat coordinateur, review #4622). Le modèle check-run : status ∈
        QUEUED/IN_PROGRESS/COMPLETED, conclusion rempli seulement sur COMPLETED.
        Liste de PASSAGE (#4150 lot 5, review #4626 SHOULD 1) : SUCCESS/SKIPPED/NEUTRAL
        passent, toute AUTRE conclusion sur un run COMPLETED est rouge — une conclusion
        inconnue (STARTUP_FAILURE quand un workflow ne démarre pas, STALE) échoue la
        porte au lieu de passer en silence comme sous l'ancienne liste de blocage.
        Un run annulé ne prouve rien : il échoue. Les statuts legacy (EXPECTED/ERROR)
        restent couverts pour un rollup qui mêlerait les deux nomenclatures.
        #4150 lot 5 suite (APPROVE #4628, trou b) : liste de passage aussi sur le
        STATUT — QUEUED/IN_PROGRESS (+ legacy PENDING/WAITING/REQUESTED) = pending,
        COMPLETED = classé par conclusion ; tout AUTRE statut non-COMPLETED est rouge
        au lieu de passer vert (un statut inconnu n'est pas une preuve de CI).
    .OUTPUTS
        @{ Pending = object[]; Failed = object[] }
    #>
    param([Parameter(Mandatory)]$Checks)

    $pending = @($Checks | Where-Object {
        $_.Status -in @('QUEUED', 'IN_PROGRESS', 'PENDING', 'WAITING', 'REQUESTED') -or
        ($_.Status -eq 'COMPLETED' -and -not $_.Conclusion)
    })
    $failed = @($Checks | Where-Object {
        ($_.Status -eq 'COMPLETED' -and $null -ne $_.Conclusion -and
            $_.Conclusion -notin @('SUCCESS', 'SKIPPED', 'NEUTRAL')) -or
        $_.Status -in @('FAILED', 'EXPECTED', 'ERROR', 'FAILURE') -or
        ($_.Status -and $_.Status -notin @('QUEUED', 'IN_PROGRESS', 'PENDING',
            'WAITING', 'REQUESTED', 'COMPLETED', 'FAILED', 'EXPECTED', 'ERROR', 'FAILURE'))
    })
    return @{ Pending = $pending; Failed = $failed }
}

function Get-PullRequestReviewDecision {
    <#
    .SYNOPSIS
        reviewDecision d'une PR, composé depuis GET /pulls/{n}/reviews (0 point GraphQL).
    .OUTPUTS
        @{ Ok = bool; Decision = 'APPROVED'|'CHANGES_REQUESTED'|'REVIEW_REQUIRED'|$null; Error }
        Échec du fetch -> Ok = $false (l'appelant skip : commenter une PR déjà
        approuvée est le risque que ce champ existe pour éviter).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][int]$Number
    )

    $r = Invoke-GhApiJsonPaged -Url "repos/$Repo/pulls/$Number/reviews" -Jq '.[] | {state: .state}'
    if (-not $r.Ok) {
        return [pscustomobject]@{ Ok = $false; Decision = $null; Error = "reviews: $($r.Error)" }
    }
    $reviews = @($r.Lines | ForEach-Object { $_ | ConvertFrom-Json })
    return [pscustomobject]@{ Ok = $true; Decision = (ConvertFrom-RestReviews -Reviews $reviews); Error = $null }
}

function Get-PullRequestDetail {
    <#
    .SYNOPSIS
        Détail complet d'une PR en REST (5 appels : PR, fichiers, revues, check-runs
        par page), rendu dans la FORME de `gh pr view --json title,author,body,
        headRefName,baseRefName,state,mergeable,additions,deletions,files,
        reviewDecision,statusCheckRollup | ConvertFrom-Json` — propriétés et casse
        identiques, pour que les consommateurs gardent leur branchement.
    .OUTPUTS
        @{ Ok = bool; Item; Error } — Item : Number, State (OPEN|CLOSED|MERGED),
        Title, Body, Author @{login}, Mergeable (peut être null), Additions,
        Deletions, HeadRefName, BaseRefName, Files @{path, additions, deletions}[]
        (`path` = parité gh ; REST l'appelle `filename`), Labels string[], HeadSha,
        ReviewDecision, StatusCheckRollup @{Name, Status, Conclusion}[] MAJUSCULES.
        Tout échec d'appel (PR, fichiers, revues, check-runs) -> Ok = $false :
        les champs obtenus servent tous un branchement consommateur, un détail
        partiel serait une décision prise sur données fausses.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][int]$Number
    )

    $jqPr = '{number: .number, state: .state, merged: .merged, title: .title, body: .body, login: .user.login, additions: .additions, deletions: .deletions, mergeable: .mergeable, head_ref: .head.ref, head_sha: .head.sha, base_ref: .base.ref, labels: [.labels[].name]}'
    $r = Invoke-GhApiJson -Url "repos/$Repo/pulls/$Number" -Jq $jqPr
    if (-not $r.Ok) { return [pscustomobject]@{ Ok = $false; Item = $null; Error = "pr: $($r.Error)" } }
    $pr = @($r.Lines)[0] | ConvertFrom-Json

    # Normalisation d'état — même contrat que la liste (MERGED = closed + merged).
    $state = "$($pr.state)".ToLowerInvariant()
    if ($state -eq 'open') { $state = 'OPEN' }
    elseif ($state -eq 'closed') { $state = if ($pr.merged) { 'MERGED' } else { 'CLOSED' } }

    $filesR = Invoke-GhApiJsonPaged -Url "repos/$Repo/pulls/$Number/files" -Jq '.[] | {path: .filename, additions: .additions, deletions: .deletions}'
    if (-not $filesR.Ok) { return [pscustomobject]@{ Ok = $false; Item = $null; Error = "files: $($filesR.Error)" } }
    $files = @($filesR.Lines | ForEach-Object { $_ | ConvertFrom-Json })

    $decisionR = Get-PullRequestReviewDecision -Repo $Repo -Number $Number
    if (-not $decisionR.Ok) { return [pscustomobject]@{ Ok = $false; Item = $null; Error = $decisionR.Error } }

    $runsR = Invoke-GhApiJsonPaged -Url "repos/$Repo/commits/$($pr.head_sha)/check-runs" -Jq '.check_runs[] | {name: .name, status: .status, conclusion: .conclusion}'
    if (-not $runsR.Ok) { return [pscustomobject]@{ Ok = $false; Item = $null; Error = "check-runs: $($runsR.Error)" } }
    $rollup = @($runsR.Lines | ForEach-Object { $_ | ConvertFrom-Json } | ForEach-Object { ConvertFrom-RestCheckRun -Run $_ })

    $item = [pscustomobject]@{
        Number           = $pr.number
        State            = $state
        Title            = $pr.title
        Body             = $pr.body
        Author           = [pscustomobject]@{ login = $pr.login }
        Mergeable        = $pr.mergeable
        Additions        = $pr.additions
        Deletions        = $pr.deletions
        HeadRefName      = $pr.head_ref
        BaseRefName      = $pr.base_ref
        HeadSha          = $pr.head_sha
        Files            = $files
        Labels           = @($pr.labels | Where-Object { $_ })
        ReviewDecision   = $decisionR.Decision
        StatusCheckRollup = $rollup
    }
    return [pscustomobject]@{ Ok = $true; Item = $item; Error = $null }
}
