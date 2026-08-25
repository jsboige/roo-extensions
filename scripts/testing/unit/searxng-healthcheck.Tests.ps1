# Tests unitaires + integration pour scripts/mcp/searxng-healthcheck.ps1 (#3264)
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Portable pwsh Windows ET Linux :
# - le mock HTTP embarque (HttpListener dans un Start-Job) est saute
#   proprement (Set-ItResult -Skipped) si le listener ne demarre pas.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/searxng-healthcheck.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/mcp/searxng-healthcheck.ps1")
}

Describe 'Get-SearxngVerdict - classification par couches (#3264)' {

    It '200 avec results -> HEALTHY (exit 0)' {
        $v = Get-SearxngVerdict -StatusCode 200 -ResponseHeaders @{} -Body '{"results":[{"title":"t"}]}'
        $v.Layer | Should -Be 'HEALTHY'
        $v.ExitCode | Should -Be 0
    }

    It 'signature #3264 : 401 + WWW-Authenticate Basic + page IIS -> EDGE-IIS-BASIC-AUTH (exit 2), realm extrait' {
        $v = Get-SearxngVerdict -StatusCode 401 `
            -ResponseHeaders @{ 'WWW-Authenticate' = 'Basic realm="myia"'; 'Server' = 'Microsoft-IIS/10.0' } `
            -Body 'IIS 10.0 Detailed Error - 401.2 - Unauthorized'
        $v.Layer | Should -Be 'EDGE-IIS-BASIC-AUTH'
        $v.ExitCode | Should -Be 2
        $v.Detail | Should -Match 'realm "myia"'
        $v.Action | Should -Match 'undici refuse les URLs a userinfo'
    }

    It '401 Basic sans signature IIS -> EDGE-BASIC-AUTH (exit 2)' {
        $v = Get-SearxngVerdict -StatusCode 401 -ResponseHeaders @{ 'WWW-Authenticate' = 'Basic realm="x"' } -Body 'denied'
        $v.Layer | Should -Be 'EDGE-BASIC-AUTH'
        $v.ExitCode | Should -Be 2
    }

    It '401 Bearer -> EDGE-AUTH-Bearer (exit 2)' {
        $v = Get-SearxngVerdict -StatusCode 401 -ResponseHeaders @{ 'WWW-Authenticate' = 'Bearer' } -Body ''
        $v.Layer | Should -Be 'EDGE-AUTH-Bearer'
        $v.ExitCode | Should -Be 2
    }

    It '401 sans WWW-Authenticate -> AUTH-UNSPECIFIED (exit 2)' {
        $v = Get-SearxngVerdict -StatusCode 401 -ResponseHeaders @{} -Body ''
        $v.Layer | Should -Be 'AUTH-UNSPECIFIED'
        $v.ExitCode | Should -Be 2
    }

    It '403 format json refuse -> BACKEND-SEARXNG-FORMAT (exit 3)' {
        $v = Get-SearxngVerdict -StatusCode 403 -ResponseHeaders @{} -Body 'The requested format is not supported'
        $v.Layer | Should -Be 'BACKEND-SEARXNG-FORMAT'
        $v.ExitCode | Should -Be 3
        $v.Action | Should -Match 'search.formats'
    }

    It '403 autre -> BACKEND-FORBIDDEN (exit 3)' {
        $v = Get-SearxngVerdict -StatusCode 403 -ResponseHeaders @{} -Body 'forbidden'
        $v.Layer | Should -Be 'BACKEND-FORBIDDEN'
        $v.ExitCode | Should -Be 3
    }

    It '429 -> RATE-LIMITED (exit 4)' {
        $v = Get-SearxngVerdict -StatusCode 429 -ResponseHeaders @{} -Body ''
        $v.Layer | Should -Be 'RATE-LIMITED'
        $v.ExitCode | Should -Be 4
    }

    It '502 -> UPSTREAM-ERROR (exit 5)' {
        $v = Get-SearxngVerdict -StatusCode 502 -ResponseHeaders @{} -Body 'bad gateway'
        $v.Layer | Should -Be 'UPSTREAM-ERROR'
        $v.ExitCode | Should -Be 5
    }

    It 'connection refusee -> CONNECTIVITY-REFUSED (exit 6)' {
        $v = Get-SearxngVerdict -StatusCode 0 -ErrorMessage 'Connection refused'
        $v.Layer | Should -Be 'CONNECTIVITY-REFUSED'
        $v.ExitCode | Should -Be 6
    }

    It 'echec DNS -> CONNECTIVITY-DNS (exit 6)' {
        $v = Get-SearxngVerdict -StatusCode 0 -ErrorMessage 'No such host is known. (NameResolutionFailure)'
        $v.Layer | Should -Be 'CONNECTIVITY-DNS'
        $v.ExitCode | Should -Be 6
    }
}

Describe 'Get-MaskedUrl - hygiene secrets (#3264)' {

    It 'masque le userinfo sans exposer le mot de passe' {
        $masked = Get-MaskedUrl 'https://user:secretpass@search.myia.io/'
        $masked | Should -Not -Match 'secretpass'
        $masked | Should -Match '^https://\*\*\*@search\.myia\.io/$'
    }

    It 'laisse une URL sans userinfo intacte' {
        Get-MaskedUrl 'http://192.168.0.47:8181/' | Should -Be 'http://192.168.0.47:8181/'
    }

    It 'retourne la valeur telle quelle sur entree vide' {
        Get-MaskedUrl '' | Should -Be ''
    }
}

Describe 'Invoke-SearxngProbe + Get-SearxngVerdict - integration chemin 401 (#3264)' {

    BeforeAll {
        # Mock de l'edge IIS : HttpListener dans un job. Repond 401 Basic realm="myia-test"
        # (avec signature IIS dans le body) pour toute requete SAUF q=healthy -> 200 JSON.
        $script:HcJob = Start-Job -ScriptBlock {
            $ErrorActionPreference = 'Stop'
            try {
                $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
                $tcp.Start(); $port = ($tcp.LocalEndpoint).Port; $tcp.Stop()
                $l = [System.Net.HttpListener]::new()
                $l.Prefixes.Add("http://127.0.0.1:$port/")
                $l.Start()
                "$port"
                for ($i = 0; $i -lt 4; $i++) {
                    $ctx = $l.GetContext()
                    if ($ctx.Request.QueryString['q'] -eq 'healthy') {
                        $ctx.Response.StatusCode = 200
                        $ctx.Response.ContentType = 'application/json'
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes('{"results":[{"title":"ok"}]}')
                    }
                    else {
                        $ctx.Response.StatusCode = 401
                        $ctx.Response.AddHeader('WWW-Authenticate', 'Basic realm="myia-test"')
                        $bytes = [System.Text.Encoding]::UTF8.GetBytes('IIS 10.0 Detailed Error - 401.2 - Unauthorized')
                    }
                    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                    $ctx.Response.Close()
                }
                $l.Stop()
            }
            catch {
                "ERROR: $($_.Exception.Message)"
            }
        }
        $deadline = (Get-Date).AddSeconds(20)
        $script:HcPort = $null
        $script:HcListenerError = $null
        do {
            Start-Sleep -Milliseconds 150
            $out = @(Receive-Job -Job $script:HcJob -Keep)
            $first = $out | Where-Object { "$_" -match '^\d+$' } | Select-Object -First 1
            if ($first) { $script:HcPort = [int]$first; break }
            $err = $out | Where-Object { "$_" -match '^ERROR:' } | Select-Object -First 1
            if ($err) { $script:HcListenerError = "$err"; break }
        } while ((Get-Date) -lt $deadline)
        if (-not $script:HcPort -and -not $script:HcListenerError) {
            $script:HcListenerError = 'timeout de demarrage du mock'
        }
    }

    AfterAll {
        if ($script:HcJob) {
            Stop-Job -Job $script:HcJob -ErrorAction SilentlyContinue
            Remove-Job -Job $script:HcJob -Force -ErrorAction SilentlyContinue
        }
    }

    It 'identifie la couche fautive sur un vrai chemin 401 Basic (EDGE-IIS-BASIC-AUTH, exit 2)' {
        if ($script:HcListenerError -or -not $script:HcPort) {
            Set-ItResult -Skipped -Because "mock HttpListener indisponible ($($script:HcListenerError))"
        }
        else {
            $probe = Invoke-SearxngProbe -BaseUrl "http://127.0.0.1:$($script:HcPort)/" -Query 'locked' -TimeoutSec 10
            $probe.StatusCode | Should -Be 401
            $probe.Headers['WWW-Authenticate'] | Should -Match 'Basic'
            $v = Get-SearxngVerdict -StatusCode $probe.StatusCode -ResponseHeaders $probe.Headers -Body $probe.Body -ErrorMessage $probe.ErrorMessage
            $v.Layer | Should -Be 'EDGE-IIS-BASIC-AUTH'
            $v.ExitCode | Should -Be 2
        }
    }

    It 'verdict HEALTHY sur un appel reel 200 avec results (exit 0)' {
        if ($script:HcListenerError -or -not $script:HcPort) {
            Set-ItResult -Skipped -Because "mock HttpListener indisponible ($($script:HcListenerError))"
        }
        else {
            $probe = Invoke-SearxngProbe -BaseUrl "http://127.0.0.1:$($script:HcPort)/" -Query 'healthy' -TimeoutSec 10
            $probe.StatusCode | Should -Be 200
            $v = Get-SearxngVerdict -StatusCode $probe.StatusCode -ResponseHeaders $probe.Headers -Body $probe.Body -ErrorMessage $probe.ErrorMessage
            $v.Layer | Should -Be 'HEALTHY'
            $v.ExitCode | Should -Be 0
        }
    }
}
