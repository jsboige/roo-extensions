# ============================================================================
# gh-issues.ps1 — lectures d'issues en REST (0 point GraphQL) — #4150 lot 7
# ============================================================================
# Même contrat que gh-pull-requests.ps1 (lots 2-5) : chaque fonction rend
# @{ Ok = bool; Items|Item; Error }, l'échec ≠ l'absence (Ok = $false avec le
# motif), et l'appelant décide du fail-safe. Motivation : doctrine #4604 —
# `gh issue list|view` consomme le quota GraphQL partagé flotte (5 000 pts/h
# épuisés en ~60 s, #4150), `gh api repos/...` consomme le budget REST core
# (jamais épuisé en pratique).
#
# Différence de casse assumée avec gh-pull-requests.ps1 : les champs rendus
# ici suivent la casse EXACTE de `gh --json` (number, title, updatedAt...).
# Les consommateurs historiques des scripts d'ordonnancement lisent ces noms
# en minuscules — la parité rend la conversion chirurgicale (seule la ligne
# de fetch change, pas les dizaines de lectures aval).
#
# Pièges REST couverts (mésurés/constatés dans les lots précédents) :
#   * GET /repos/{r}/issues renvoie AUSSI les PRs (une PR est une issue) :
#     filtrées ici sur l'absence de `pull_request` — parité `gh issue list`,
#     qui n'a jamais rendu une PR.
#   * La négation de label (`-label:x` dans --search) n'existe pas côté
#     serveur REST : -ExcludeLabels filtre côté client.
#   * `--label` ET `--search` ensemble : gh DROPPE --search silencieusement
#     (mesuré 23/09, cf. start-copilot-dispatcher) ; ici les deux vivent dans
#     des paramètres distincts, serveur ET client respectivement.
#   * #3731 : sous EAP=Stop en 5.1, le stderr d'un natif redirigé est
#     TERMINANT — chaque appel `& gh api` vit dans un try/catch.
#   * Guillemets EXPLICITES autour de l'URL : `&` (query string) est un
#     métacaractère cmd.exe (lot 2).
#
# Usage :
#   . "$PSScriptRoot\..\common\gh-issues.ps1"
#   $s = Get-IssueSummary -Repo jsboige/roo-extensions -Labels @('bug') -MaxCount 10
#   if (-not $s.Ok) { <fail-safe> } else { $s.Items[0].number }
# ============================================================================

$script:IssueSummaryJq = (
    '.[] | {number: .number, title: .title, body: .body, state: .state, ' +
    'url: .html_url, updatedAt: .updated_at, ' +
    'labels: [.labels[] | {name: .name}], ' +
    'assignees: [.assignees[] | {login: .login}], ' +
    'is_pr: (.pull_request != null)}'
)

function ConvertTo-IsoString {
    # pwsh 7.4+ COERCE les timestamps ISO en [datetime] au ConvertFrom-Json ;
    # PS 5.1 les laisse en chaîne (review #4641, point b : les assertions de
    # forme échouaient sur tout hôte pwsh 7). Le contrat du module est
    # gh-parité STRING (gh --json émet des chaînes ISO seconde-précision) —
    # les deux hôtes rendent donc la même forme, consommateurs inchangés.
    param($Value)

    if ($Value -is [datetime]) {
        return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [datetimeoffset]) {
        return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
    }
    return "$Value"
}

function ConvertFrom-RestIssue {
    # Forme gh-parité : state MAJUSCULE (gh émet OPEN/CLOSED ; REST open/closed),
    # labels [{name}], assignees [{login}] — les objets, pas les scalaires
    # (le reaper coordinator lit `$_.assignees | % { $_.login }`).
    param([Parameter(Mandatory)]$Raw)

    [pscustomobject]@{
        number    = $Raw.number
        title     = $Raw.title
        body      = $Raw.body
        state     = "$($Raw.state)".ToUpperInvariant()
        url       = $Raw.url
        updatedAt = ConvertTo-IsoString $Raw.updatedAt
        labels    = @($Raw.labels | Where-Object { $_ })
        assignees = @($Raw.assignees | Where-Object { $_ })
    }
}

function Get-IssueSummary {
    <#
    .SYNOPSIS
        Liste des issues d'un dépôt, lues en REST (0 point GraphQL) — remplace
        `gh issue list --json number,title,body,labels,assignees,updatedAt,url`.
    .PARAMETER Repo
        slug owner/repo.
    .PARAMETER State
        open | closed | all (défaut open).
    .PARAMETER Labels
        Filtre ET côté serveur (`labels=a,b`), équivalent `--label`.
    .PARAMETER ExcludeLabels
        Négation côté CLIENT (équivalent `-label:x` dans --search) : une issue
        portant UN de ces labels est exclue. Le filtre vit DANS la boucle de
        pagination (lot 8) : la fenêtre MaxCount compte les issues non exclues —
        parité `--search -label:x --limit N`, où le filtre servait AVANT la fenêtre.
    .PARAMETER NoAssignee
        Écart serveur des issues assignées (`assignee=none`, lot 8) — parité
        `--search no:assignee` : la fenêtre MaxCount compte les NON-ASSIGNÉES.
    .PARAMETER MaxCount
        Nombre maximum d'issues (0 = tout, pagination complète). Tri REST par
        created desc = même ordre que gh, les plus récentes d'abord.
    .OUTPUTS
        @{ Ok = bool; Items = issue[] (PRs exclues); Error }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [ValidateSet('open', 'closed', 'all')][string]$State = 'open',
        [string[]]$Labels,
        [string[]]$ExcludeLabels,
        [int]$MaxCount = 0,
        [switch]$NoAssignee
    )

    $perPage = 100
    $url = "repos/$Repo/issues?state=$State&per_page=$perPage&sort=created&direction=desc"
    if ($NoAssignee) { $url += '&assignee=none' }
    if ($Labels -and $Labels.Count -gt 0) {
        # Encodage minimal : les labels fleet sont alphanumériques + tirets,
        # mais un `:` ou espace ne doit pas casser la query string.
        $url += '&labels=' + [uri]::EscapeDataString(($Labels -join ','))
    }

    $items = @()
    $page = 1
    # maxPages = plafond de SÉCURITÉ, pas un budget : l'arrêt pilote sur le
    # compte d'issues FILTRÉES (PRs exclues, ci-dessous) et sur la page courte.
    # Un budget dérivé de MaxCount compterait des items BRUTS (issues+PRs) et
    # rétrécirait la fenêtre du reaper de la part de PRs (200 → ~170 à 15 % de
    # PRs) — drift relevé par la review #4641 ; l'ancien `gh issue list
    # --limit N` rendait N issues, pas N items bruts.
    $maxPages = 40
    while ($page -le $maxPages) {
        $quotedUrl = if ($PSVersionTable.PSEdition -eq 'Desktop') { '"' + $url + '&page=' + $page + '"' } else { $url + '&page=' + $page }
        try {
            $out = & gh api $quotedUrl --jq $script:IssueSummaryJq 2>$null
        } catch {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api threw: $($_.Exception.Message)" }
        }
        if ($LASTEXITCODE -ne 0) {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api exit $LASTEXITCODE" }
        }
        $pageItems = @($out | Where-Object { $_ -and $_.ToString().Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        foreach ($raw in $pageItems) {
            # Une PR est une issue côté REST — jamais rendue par `gh issue list`.
            if ($raw.is_pr) { continue }
            $item = ConvertFrom-RestIssue -Raw $raw
            # Exclusion de labels DANS la boucle (lot 8 — même classe que la dérive
            # #4641) : en post-boucle, la fenêtre MaxCount comptait des items exclus
            # ensuite et le pool du worker recevait moins de N candidates réelles.
            if ($ExcludeLabels -and $ExcludeLabels.Count -gt 0) {
                $names = @($item.labels | ForEach-Object { "$($_.name)" })
                $hit = $false
                foreach ($x in $ExcludeLabels) { if ($names -contains "$x") { $hit = $true; break } }
                if ($hit) { continue }
            }
            $items += $item
        }
        if ($MaxCount -gt 0 -and $items.Count -ge $MaxCount) { break }
        if ($pageItems.Count -lt $perPage) { break }
        $page++
    }

    if ($MaxCount -gt 0 -and $items.Count -gt $MaxCount) { $items = $items[0..($MaxCount - 1)] }
    return [pscustomobject]@{ Ok = $true; Items = @($items); Error = $null }
}

function Get-IssueDetail {
    <#
    .SYNOPSIS
        Détail d'une issue en REST — remplace `gh issue view N --json number,
        title,body,state,url,labels`.
    .OUTPUTS
        @{ Ok = bool; Item (même forme que Get-IssueSummary, assignees inclus);
           Error }. Un NUMÉRO DE PR rend Ok = $false (« is a pull request ») —
        parité `gh issue view`, qui refuse aussi.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][int]$Number
    )

    # La forme détail : `. | {...}` (objet seul, pas le tableau de la liste).
    $jq = ('. | {number: .number, title: .title, body: .body, state: .state, ' +
        'url: .html_url, updatedAt: .updated_at, ' +
        'labels: [.labels[] | {name: .name}], ' +
        'assignees: [.assignees[] | {login: .login}], ' +
        'is_pr: (.pull_request != null)}')

    $quotedUrl = if ($PSVersionTable.PSEdition -eq 'Desktop') { '"' + "repos/$Repo/issues/$Number" + '"' } else { "repos/$Repo/issues/$Number" }
    try {
        $out = & gh api $quotedUrl --jq $jq 2>$null
    } catch {
        return [pscustomobject]@{ Ok = $false; Item = $null; Error = "gh api threw: $($_.Exception.Message)" }
    }
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{ Ok = $false; Item = $null; Error = "gh api exit $LASTEXITCODE" }
    }
    $lines = @($out | Where-Object { $_ -and $_.ToString().Trim() })
    if ($lines.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; Item = $null; Error = "issue #$($Number): sortie vide" }
    }
    $raw = $lines[0] | ConvertFrom-Json
    if ($raw.is_pr) {
        return [pscustomobject]@{ Ok = $false; Item = $null; Error = "issue #$Number is a pull request (gh issue view parity)" }
    }
    return [pscustomobject]@{ Ok = $true; Item = (ConvertFrom-RestIssue -Raw $raw); Error = $null }
}

function Get-IssueComments {
    <#
    .SYNOPSIS
        Commentaires d'une issue en REST, pagination complète — remplace
        `gh issue view N --json comments`. Les endpoints de commentaires
        paginent à 30 par défaut : une issue à 40 commentaires serait
        tronquée sans la boucle (mesuré lot 3 sur les fichiers de PR).
    .OUTPUTS
        @{ Ok = bool; Items = @{author = @{login}; body; createdAt}[]; Error }
        — casse gh : createdAt, pas created_at.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][int]$Number,
        [int]$MaxPages = 20
    )

    $jq = '.[] | {author: {login: .user.login}, body: .body, createdAt: .created_at}'
    $items = @()
    $page = 1
    while ($page -le $MaxPages) {
        $quotedUrl = if ($PSVersionTable.PSEdition -eq 'Desktop') { '"' + "repos/$Repo/issues/$Number/comments?per_page=100&page=$page" + '"' } else { "repos/$Repo/issues/$Number/comments?per_page=100&page=$page" }
        try {
            $out = & gh api $quotedUrl --jq $jq 2>$null
        } catch {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api threw: $($_.Exception.Message)" }
        }
        if ($LASTEXITCODE -ne 0) {
            return [pscustomobject]@{ Ok = $false; Items = @(); Error = "gh api exit $LASTEXITCODE" }
        }
        $pageItems = @($out | Where-Object { $_ -and $_.ToString().Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
        # createdAt normalisé (ConvertTo-IsoString) : contrat string gh-parité
        # sous les deux hôtes (review #4641, point b).
        $items += @($pageItems | ForEach-Object {
            [pscustomobject]@{ author = $_.author; body = $_.body; createdAt = (ConvertTo-IsoString $_.createdAt) }
        })
        if ($pageItems.Count -lt 100) { break }
        $page++
    }
    return [pscustomobject]@{ Ok = $true; Items = @($items); Error = $null }
}
