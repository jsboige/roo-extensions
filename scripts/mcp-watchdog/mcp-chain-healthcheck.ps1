<#
.SYNOPSIS
    Read-only healthcheck for the MCP chain (NanoClaw -> mcp-tools.myia.io -> TBXark -> sparfenyuk -> roo-state-manager).

.DESCRIPTION
    Probes each layer of the chain WITHOUT making any repairs. Use this as a first-line
    diagnostic when an agent reports "lost roo-state-manager" — it pinpoints the broken
    layer and suggests the fix command to run.

    Tests, in order:
      1. Local roo-state-manager wrapper: spawn + handshake (initialize + tools/list)
      2. sparfenyuk mcp-proxy: HTTP GET http://127.0.0.1:9091/status
      3. TBXark proxy port: TCP connect to 127.0.0.1:9090
      4. E2E chain: POST initialize on https://mcp-tools.myia.io/roo-state-manager/mcp
         (requires bot bearer in D:\nanoclaw\.env)

    Exit code: 0 if all green, 1 if any layer fails.

.PARAMETER BotEnvFile
    Path to NanoClaw .env (for MCP_PROXY_BASE_URL + MCP_PROXY_BEARER).
    Default: D:\nanoclaw\.env

.PARAMETER SkipE2E
    Skip the E2E test (useful when offline or .env unavailable).

.EXAMPLE
    .\mcp-chain-healthcheck.ps1
    # Prints a status table for each layer.

.EXAMPLE
    .\mcp-chain-healthcheck.ps1 -SkipE2E
    # Skip the cloud E2E test (faster, no auth needed).
#>

param(
    [string]$BotEnvFile = 'D:\nanoclaw\.env',
    [switch]$SkipE2E
)

$ErrorActionPreference = 'Continue'

# ---------- helpers ----------
function Read-EnvValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path $Path)) { return $null }
    foreach ($line in Get-Content -Path $Path -Encoding utf8 -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$") {
            return $matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

# ---------- Layer 1: local wrapper handshake ----------
function Test-LocalWrapper {
    $wrapperPath = 'D:\roo-extensions\mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs'
    if (-not (Test-Path $wrapperPath)) {
        return @{ Ok = $false; Detail = 'wrapper file missing'; Hint = 'cd mcps/internal && git submodule update --init --recursive' }
    }
    $buildPath = 'D:\roo-extensions\mcps\internal\servers\roo-state-manager\build\index.js'
    if (-not (Test-Path $buildPath)) {
        return @{ Ok = $false; Detail = 'build/index.js missing'; Hint = 'cd mcps/internal/servers/roo-state-manager && npm run build' }
    }

    $stdin = @'
{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"healthcheck","version":"1.0"}}}
{"jsonrpc":"2.0","method":"tools/list","id":2}
'@
    try {
        $output = $stdin | & node $wrapperPath 2>&1 | Select-String -Pattern '"result"' -SimpleMatch | Select-Object -First 2
        $toolsResp = $output | Where-Object { $_ -match '"tools":\[' } | Select-Object -First 1
        if ($toolsResp) {
            $count = ([regex]::Matches($toolsResp.Line, '"name":"')).Count
            return @{ Ok = $true; Detail = "$count tools returned"; Hint = '' }
        }
        return @{ Ok = $false; Detail = 'no tools/list response within timeout'; Hint = 'check build, .env, and roo-state-manager logs in $env:TEMP\roo-state-manager-logs' }
    } catch {
        return @{ Ok = $false; Detail = $_.Exception.Message; Hint = 'rebuild: cd mcps/internal/servers/roo-state-manager && npm run build' }
    }
}

# ---------- Layer 2: sparfenyuk mcp-proxy ----------
function Test-Sparfenyuk {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:9091/status' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            return @{ Ok = $true; Detail = "HTTP 200 (proxy up)"; Hint = '' }
        }
        return @{ Ok = $false; Detail = "HTTP $($response.StatusCode)"; Hint = 'Start-ScheduledTask -TaskName "MCP-Proxy-RSM"' }
    } catch {
        return @{ Ok = $false; Detail = "down ($($_.Exception.Message))"; Hint = 'Start-ScheduledTask -TaskName "MCP-Proxy-RSM"' }
    }
}

# ---------- Layer 3: TBXark Docker port ----------
function Test-TbxarkPort {
    try {
        $tcp = Test-NetConnection -ComputerName '127.0.0.1' -Port 9090 -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($tcp) {
            return @{ Ok = $true; Detail = 'port 9090 reachable'; Hint = '' }
        }
        return @{ Ok = $false; Detail = 'port 9090 closed'; Hint = 'docker start myia-mcp-proxy' }
    } catch {
        return @{ Ok = $false; Detail = $_.Exception.Message; Hint = 'check Docker daemon: docker ps' }
    }
}

# ---------- Layer 4: E2E ----------
function Test-E2E {
    param([string]$Path)
    $bearer = Read-EnvValue -Path $Path -Key 'MCP_PROXY_BEARER'
    $baseUrl = Read-EnvValue -Path $Path -Key 'MCP_PROXY_BASE_URL'
    if ([string]::IsNullOrEmpty($baseUrl)) { $baseUrl = 'https://mcp-tools.myia.io' }
    if ([string]::IsNullOrEmpty($bearer)) {
        return @{ Ok = $false; Detail = "no MCP_PROXY_BEARER in $Path"; Hint = 'verify NanoClaw .env exists and is readable' }
    }

    $url = "$baseUrl/roo-state-manager/mcp"
    $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"healthcheck","version":"1.0"}}}'
    try {
        $response = Invoke-WebRequest -Uri $url -Method Post -Headers @{
            'Authorization' = "Bearer $bearer"
            'Content-Type'  = 'application/json'
            'Accept'        = 'application/json, text/event-stream'
        } -Body $body -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        if ($response.StatusCode -eq 200 -and $response.Content -match 'serverInfo') {
            return @{ Ok = $true; Detail = "HTTP 200, serverInfo present"; Hint = '' }
        }
        return @{ Ok = $false; Detail = "HTTP $($response.StatusCode)"; Hint = '.\mcp-chain-watchdog.ps1 (auto-repair)' }
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ Ok = $false; Detail = "HTTP $status — $($_.Exception.Message)"; Hint = '.\mcp-chain-watchdog.ps1 (auto-repair)' }
    }
}

# ---------- run all probes ----------
Write-Host ''
Write-Host '=== MCP Chain Healthcheck ===' -ForegroundColor Cyan
Write-Host ''

$results = @()

Write-Host '[1/4] Local roo-state-manager wrapper...' -NoNewline
$r1 = Test-LocalWrapper
if ($r1.Ok) { Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' FAIL' -ForegroundColor Red }
$results += [pscustomobject]@{ Layer='1. Local wrapper'; Status=$(if($r1.Ok){'OK'}else{'FAIL'}); Detail=$r1.Detail; Fix=$r1.Hint }

Write-Host '[2/4] sparfenyuk mcp-proxy (port 9091)...' -NoNewline
$r2 = Test-Sparfenyuk
if ($r2.Ok) { Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' FAIL' -ForegroundColor Red }
$results += [pscustomobject]@{ Layer='2. sparfenyuk'; Status=$(if($r2.Ok){'OK'}else{'FAIL'}); Detail=$r2.Detail; Fix=$r2.Hint }

Write-Host '[3/4] TBXark proxy (port 9090)...' -NoNewline
$r3 = Test-TbxarkPort
if ($r3.Ok) { Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' FAIL' -ForegroundColor Red }
$results += [pscustomobject]@{ Layer='3. TBXark proxy'; Status=$(if($r3.Ok){'OK'}else{'FAIL'}); Detail=$r3.Detail; Fix=$r3.Hint }

if (-not $SkipE2E) {
    Write-Host '[4/4] E2E chain (mcp-tools.myia.io)...' -NoNewline
    $r4 = Test-E2E -Path $BotEnvFile
    if ($r4.Ok) { Write-Host ' OK' -ForegroundColor Green } else { Write-Host ' FAIL' -ForegroundColor Red }
    $results += [pscustomobject]@{ Layer='4. E2E (cloud)'; Status=$(if($r4.Ok){'OK'}else{'FAIL'}); Detail=$r4.Detail; Fix=$r4.Hint }
} else {
    Write-Host '[4/4] E2E chain SKIPPED (-SkipE2E)' -ForegroundColor Yellow
}

Write-Host ''
$results | Format-Table -AutoSize -Wrap

# ---------- summary + exit code ----------
$failures = $results | Where-Object { $_.Status -eq 'FAIL' }
if ($failures.Count -eq 0) {
    Write-Host 'All layers healthy. roo-state-manager is reachable.' -ForegroundColor Green
    Write-Host ''
    exit 0
} else {
    Write-Host "$($failures.Count) layer(s) failed. Suggested fixes:" -ForegroundColor Red
    foreach ($f in $failures) {
        if ($f.Fix) { Write-Host "  $($f.Layer): $($f.Fix)" -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host 'For full auto-repair, run:' -ForegroundColor Cyan
    Write-Host '  .\scripts\mcp-watchdog\mcp-chain-watchdog.ps1' -ForegroundColor Cyan
    Write-Host ''
    exit 1
}
