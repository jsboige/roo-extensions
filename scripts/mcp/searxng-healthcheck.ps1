<#
.SYNOPSIS
    Health-check SearXNG pour le MCP searxng — appel REEL + classification par couches (#3264).

.DESCRIPTION
    Ne teste PAS la presence du process MCP : effectue un appel /search?q=..&format=json
    reel et nomme la couche fautive parmi :

        HEALTHY                     -> 200 + JSON results
        EDGE-IIS-BASIC-AUTH         -> 401 + WWW-Authenticate: Basic + signature IIS (edge IIS)
        EDGE-BASIC-AUTH             -> 401 + WWW-Authenticate: Basic (edge non-IIS)
        EDGE-AUTH-<scheme>          -> 401 avec autre scheme (Bearer, Negotiate...)
        AUTH-UNSPECIFIED            -> 401 sans WWW-Authenticate
        BACKEND-SEARXNG-FORMAT      -> 403 SearXNG (format json non autorise)
        BACKEND-FORBIDDEN           -> 403 autre
        RATE-LIMITED                -> 429 (limiter / bot detection SearXNG)
        UPSTREAM-ERROR              -> 5xx
        CONNECTIVITY-DNS|REFUSED|TIMEOUT|OTHER -> pas de reponse HTTP
        HTTP-4XX / BAD-JSON         -> non classe

    Contexte #3264 : mcp-searxng v0.4.5 n'envoie AUCUNE credential et ne le peut pas
    (fetch/undici refuse les URLs a userinfo : "Request cannot be constructed from a
    URL that includes credentials"). Si l'edge exige Basic auth, aucune correction
    client-side n'existe sans patch du package — voir mcps/external/searxng/TROUBLESHOOTING.md.

    Hygiene secrets : aucune valeur d'Authorization n'est lue ni affichee ; les
    userinfo eventuellement embarques dans une URL sont masques avant affichage.

.PARAMETER Url
    URL de l'instance a tester. Defaut : $env:SEARXNG_URL, sinon env du .mcp.json
    du repo, sinon https://search.myia.io/.

.PARAMETER BackendUrl
    URL du backend direct (ex http://192.168.0.47:8181/). Si fournie ET que l'URL
    principale echoue, le backend est sonde : s'il repond, le verdict precise que
    le backend est sain et que le defaut est purement edge.

.PARAMETER Query
    Requete de test (defaut 'searxng healthcheck myia').

.PARAMETER TimeoutSec
    Timeout HTTP en secondes (defaut 20).

.PARAMETER Json
    Sortie JSON machine-lisible au lieu du rapport texte.

.OUTPUTS
    Exit codes : 0 HEALTHY · 2 auth edge · 3 backend SearXNG · 4 rate-limit ·
    5 upstream 5xx · 6 connectivite · 1 indetermine.

.EXAMPLE
    pwsh -NoProfile -File scripts/mcp/searxng-healthcheck.ps1

.EXAMPLE
    pwsh -NoProfile -File scripts/mcp/searxng-healthcheck.ps1 -BackendUrl http://192.168.0.47:8181/ -Json
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$Url = '',

    [Parameter(Mandatory = $false)]
    [string]$BackendUrl = '',

    [Parameter(Mandatory = $false)]
    [string]$Query = 'searxng healthcheck myia',

    [Parameter(Mandatory = $false)]
    [int]$TimeoutSec = 20,

    [Parameter(Mandatory = $false)]
    [switch]$Json
)

# --- Helpers purs (testables unitairement, cf scripts/testing/unit/searxng-healthcheck.Tests.ps1) ---

function Get-MaskedUrl {
    param([string]$InputUrl)
    if (-not $InputUrl) { return $InputUrl }
    # Masque le userinfo (https://user:pass@host/... -> https://***@host/...), sans toucher au reste.
    return [regex]::Replace($InputUrl, '^(?<scheme>[a-zA-Z][a-zA-Z0-9+.\-]*://)(?:[^/@]+)@', '${scheme}***@')
}

function Get-SearxngVerdict {
    # Classifieur pur : status + headers + extrait de body -> verdict actionnable.
    param (
        [int]$StatusCode = 0,
        [hashtable]$ResponseHeaders = @{},
        [string]$Body = '',
        [string]$ErrorMessage = ''
    )

    $wwwAuth = ''
    if ($ResponseHeaders -and $ResponseHeaders.ContainsKey('WWW-Authenticate')) {
        $wwwAuth = [string]$ResponseHeaders['WWW-Authenticate']
    }
    $server = ''
    if ($ResponseHeaders -and $ResponseHeaders.ContainsKey('Server')) {
        $server = [string]$ResponseHeaders['Server']
    }
    $isIis = ($server -match 'IIS') -or ($Body -match 'IIS \d')
    $realm = ''
    if ($wwwAuth -match 'realm="([^"]+)"') { $realm = $Matches[1] }

    if ($StatusCode -eq 0) {
        $layer = 'CONNECTIVITY-OTHER'
        if ($ErrorMessage -match 'NameResolutionFailure|no such host|getaddrinfo') { $layer = 'CONNECTIVITY-DNS' }
        elseif ($ErrorMessage -match 'Connection refused|No connection could be made') { $layer = 'CONNECTIVITY-REFUSED' }
        elseif ($ErrorMessage -match 'timed out|timedout|timeout') { $layer = 'CONNECTIVITY-TIMEOUT' }
        return [pscustomobject]@{
            Layer = $layer; HttpCode = 'n/a'; Detail = $ErrorMessage
            Action = "Aucune reponse HTTP. Verifier la joignabilite de la cible (DNS/route/firewall/service)."
            ExitCode = 6
        }
    }

    switch ($StatusCode) {
        200 {
            if ($Body -match '"results"') {
                return [pscustomobject]@{
                    Layer = 'HEALTHY'; HttpCode = 200; Detail = 'Reponse JSON avec results.'
                    Action = 'Aucune action.'; ExitCode = 0
                }
            }
            return [pscustomobject]@{
                Layer = 'BAD-JSON'; HttpCode = 200; Detail = '200 sans champ results dans le body.'
                Action = 'La reponse 200 ne ressemble pas a l API SearXNG — verifier SEARXNG_URL.'
                ExitCode = 1
            }
        }
        401 {
            if ($wwwAuth -match 'Basic') {
                $layer = 'EDGE-BASIC-AUTH'
                if ($isIis) { $layer = 'EDGE-IIS-BASIC-AUTH' }
                $detail = "401 exige Basic auth"
                if ($realm) { $detail += " (realm `"$realm`")" }
                if ($isIis) { $detail += ", emis par l edge IIS AVANT le reverse proxy ARR" }
                return [pscustomobject]@{
                    Layer = $layer; HttpCode = 401; Detail = $detail
                    Action = 'mcp-searxng v0.4.5 ne peut pas s authentifier (undici refuse les URLs a userinfo). ' +
                        'Soit pointer SEARXNG_URL vers le backend LAN direct (flotte on-prem, ex http://192.168.0.47:8181/), ' +
                        'soit arbitrer l auth anonyme de l edge (changement shared-infra, user-gated).'
                    ExitCode = 2
                }
            }
            if ($wwwAuth) {
                $scheme = ($wwwAuth -split '[ ,]')[0]
                return [pscustomobject]@{
                    Layer = "EDGE-AUTH-$scheme"; HttpCode = 401; Detail = "401 exige $wwwAuth"
                    Action = 'Auth edge non supportee par mcp-searxng v0.4.5 — arbitrage edge requis.'
                    ExitCode = 2
                }
            }
            return [pscustomobject]@{
                Layer = 'AUTH-UNSPECIFIED'; HttpCode = 401; Detail = '401 sans WWW-Authenticate (bridge/proxy ?)'
                Action = 'Identifier l emetteur du 401 (proxy, bridge MCP) — pas de WWW-Authenticate pour qualifier.'
                ExitCode = 2
            }
        }
        403 {
            if ($Body -match 'format') {
                return [pscustomobject]@{
                    Layer = 'BACKEND-SEARXNG-FORMAT'; HttpCode = 403; Detail = "SearXNG refuse le format demande : $($Body.Substring(0, [Math]::Min(200, $Body.Length)))"
                    Action = 'Activer json dans search.formats du settings.yml SearXNG.'
                    ExitCode = 3
                }
            }
            return [pscustomobject]@{
                Layer = 'BACKEND-FORBIDDEN'; HttpCode = 403; Detail = $Body
                Action = '403 SearXNG (limiter regle, IP bannie ou path interdit) — verifier settings.yml.'
                ExitCode = 3
            }
        }
        429 {
            return [pscustomobject]@{
                Layer = 'RATE-LIMITED'; HttpCode = 429; Detail = '429 limiter / bot detection.'
                Action = 'Verifier le limiter SearXNG (botdetection) ou reduire la frequence d appel.'
                ExitCode = 4
            }
        }
        default {
            if ($StatusCode -ge 500) {
                return [pscustomobject]@{
                    Layer = 'UPSTREAM-ERROR'; HttpCode = $StatusCode; Detail = $Body
                    Action = 'Erreur amont (ARR/backend) — verifier l etat du backend SearXNG.'
                    ExitCode = 5
                }
            }
            return [pscustomobject]@{
                Layer = 'HTTP-4XX'; HttpCode = $StatusCode; Detail = $Body
                Action = "Statut $StatusCode non classe — investiguer manuellement."
                ExitCode = 1
            }
        }
    }
}

function Invoke-SearxngProbe {
    # Effectue l appel /search?q=<Query>&format=json. Ne lit ni n'envoie de credential.
    param (
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$Query,
        [int]$TimeoutSec = 20
    )
    $searchUrl = ('{0}search?q={1}&format=json' -f ($BaseUrl.TrimEnd('/') + '/'), [uri]::EscapeDataString($Query))
    try {
        $resp = Invoke-WebRequest -Uri $searchUrl -Method Get -UseBasicParsing -TimeoutSec $TimeoutSec -Headers @{ 'Accept' = 'application/json' }
        $headers = @{}
        if ($resp.Headers) {
            foreach ($k in $resp.Headers.Keys) { $headers[[string]$k] = [string]($resp.Headers[$k] -join ', ') }
        }
        $body = ''
        if ($resp.Content) { $body = [string]$resp.Content }
        return @{ StatusCode = [int]$resp.StatusCode; Headers = $headers; Body = $body; ErrorMessage = ''; Url = $searchUrl }
    }
    catch {
        $r = $_.Exception.Response
        $em = [string]$_.Exception.Message
        if ($null -ne $r) {
            $code = 0
            try { $code = [int]$r.StatusCode } catch { $code = 0 }
            $headers = @{}
            $body = ''
            try {
                if ($r.Headers -is [System.Net.Http.Headers.HttpResponseHeaders]) {
                    foreach ($h in $r.Headers.GetEnumerator()) { $headers[$h.Key] = [string]($h.Value -join ', ') }
                }
                elseif ($r.Headers -is [System.Net.WebHeaderCollection]) {
                    foreach ($k in $r.Headers.AllKeys) { $headers[$k] = [string]$r.Headers[$k] }
                }
            }
            catch { }
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $body = [string]$_.ErrorDetails.Message }
            if (-not $body) {
                try {
                    $stream = $null
                    if ($r.Content) { $stream = $r.Content.ReadAsStreamAsync().GetAwaiter().GetResult() }
                    elseif ($r.GetResponseStream) { $stream = $r.GetResponseStream() }
                    if ($stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        $body = $reader.ReadToEnd()
                    }
                }
                catch { }
            }
            if ($body -and $body.Length -gt 400) { $body = $body.Substring(0, 400) }
            return @{ StatusCode = $code; Headers = $headers; Body = $body; ErrorMessage = $em; Url = $searchUrl }
        }
        return @{ StatusCode = 0; Headers = @{}; Body = ''; ErrorMessage = $em; Url = $searchUrl }
    }
}

function Resolve-SearxngUrl {
    param([string]$RequestedUrl)
    if ($RequestedUrl) { return $RequestedUrl }
    if ($env:SEARXNG_URL) { return $env:SEARXNG_URL }
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $mcpJson = Join-Path $repoRoot '.mcp.json'
    if (Test-Path $mcpJson) {
        try {
            $cfg = Get-Content $mcpJson -Raw | ConvertFrom-Json
            $u = $cfg.mcpServers.searxng.env.SEARXNG_URL
            if ($u) { return [string]$u }
        }
        catch { }
    }
    return 'https://search.myia.io/'
}

# --- Main (execution directe uniquement ; dot-sourcing Pester -> definition des fonctions seules) ---

if ($MyInvocation.InvocationName -ne '.') {

    $targetUrl = Resolve-SearxngUrl -RequestedUrl $Url
    $probe = Invoke-SearxngProbe -BaseUrl $targetUrl -Query $Query -TimeoutSec $TimeoutSec
    $verdict = Get-SearxngVerdict -StatusCode $probe.StatusCode -ResponseHeaders $probe.Headers -Body $probe.Body -ErrorMessage $probe.ErrorMessage

    $report = [ordered]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Target    = Get-MaskedUrl $targetUrl
        Query     = $Query
        Layer     = $verdict.Layer
        HttpCode  = $verdict.HttpCode
        Detail    = $verdict.Detail
        Action    = $verdict.Action
    }

    $backendVerdict = $null
    if ($BackendUrl -and $verdict.ExitCode -ne 0) {
        $bprobe = Invoke-SearxngProbe -BaseUrl $BackendUrl -Query $Query -TimeoutSec $TimeoutSec
        $backendVerdict = Get-SearxngVerdict -StatusCode $bprobe.StatusCode -ResponseHeaders $bprobe.Headers -Body $bprobe.Body -ErrorMessage $bprobe.ErrorMessage
        $report['Backend'] = [ordered]@{
            Target = Get-MaskedUrl $BackendUrl
            Layer  = $backendVerdict.Layer
            Detail = $backendVerdict.Detail
        }
        if ($backendVerdict.ExitCode -eq 0) {
            $report['Action'] = 'Backend direct SAIN — le defaut est purement EDGE (IIS/ARR devant le backend). ' + $verdict.Action
        }
    }

    if ($Json) {
        $report | ConvertTo-Json -Depth 4
    }
    else {
        Write-Host ("searxng-healthcheck  {0}" -f $report['Timestamp'])
        Write-Host ("  Target  : {0}" -f $report['Target'])
        Write-Host ("  Verdict : {0} (HTTP {1})" -f $verdict.Layer, $verdict.HttpCode)
        Write-Host ("  Detail  : {0}" -f $verdict.Detail)
        Write-Host ("  Action  : {0}" -f $report['Action'])
        if ($backendVerdict) {
            Write-Host ("  Backend : {0} -> {1} ({2})" -f (Get-MaskedUrl $BackendUrl), $backendVerdict.Layer, $backendVerdict.Detail)
        }
    }
    exit $verdict.ExitCode
}
