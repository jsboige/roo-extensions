# gh-pull-requests.ps1 — lecture des pull requests en REST seul (#4150 lot 2)
#
# Doctrine #4604 : `gh pr list` / `gh pr view` / `gh issue view` passent par GraphQL ;
# le budget GraphQL de la flotte est fragmenté entre les sièges et tombe en 403 sous
# charge, alors que `gh api repos/...` consomme le budget REST (5 000 req/h, jamais
# entamé par les cycles). Ces quatre consommateurs (worktree-cleanup,
# cleanup-orphan-branches ×2, triage-merged-branches) ne lisent qu'une chose :
# « cette branche a-t-elle une PR, et est-elle mergée ? ».
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
    $jq = '.[] | {number: .number, state: .state, merged_at: .merged_at, head_ref: .head.ref}'

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
