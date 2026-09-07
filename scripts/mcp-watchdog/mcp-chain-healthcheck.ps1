<#
.SYNOPSIS
    Read-only healthcheck for the MCP chain (local roo-state-manager -> proxies -> cloud E2E).
    Consumer-side capable: portable repo paths, host layers auto-detected, no bearer required.

.DESCRIPTION
    Probes each layer of the chain WITHOUT making any repairs — this script contains
    NO repair path by construction (arbitrage #3495: read-only structural, not a
    removable flag). If a layer is down, the check NAMES it; a human or a lane decides.

    Tests, in order:
      1. Local roo-state-manager wrapper: spawn + handshake (initialize + tools/list)
         — paths resolved relative to this script, works on any machine hosting the repo.
      2. sparfenyuk mcp-proxy: HTTP GET http://127.0.0.1:9091/status        [host-of-bus only]
      3. TBXark proxy port: TCP connect to 127.0.0.1:9090                   [host-of-bus only]
      4. E2E chain: POST initialize on $MCP_PROXY_BASE_URL/roo-state-manager/mcp
         (requires bot bearer in the NanoClaw .env; N/A when the env file is absent)

    Layers 2-3 apply only where the bus is hosted (presence of the 'MCP-Proxy-RSM'
    schtask is the host marker — the same prerequisite the host-side watchdog uses).
    On consumer machines they report N/A, not FAIL.

    Exit codes: 0 = all applicable layers green, 1 = at least one applicable layer
    failed, 3 = no applicable layer on this machine (probe not applicable here).

.PARAMETER BotEnvFile
    Path to NanoClaw .env (for MCP_PROXY_BASE_URL + MCP_PROXY_BEARER).
    Default: D:\nanoclaw\.env

.PARAMETER SkipE2E
    Skip the E2E test entirely (layer not listed).

.PARAMETER Scheduled
    Unattended tick mode for the schtask (install-mcp-chain-healthcheck-schtask.ps1):
      - writes outputs/mcp-watchdog/healthcheck-state.json every tick (local heartbeat:
        its mtime proves the probe itself is alive — silence is distinguishable from health)
      - publishes a machine-dashboard note ONLY on: first run (listing applicable vs N/A
        layers, once), state transition, hourly heartbeat, or ongoing failure
        (server-side dedup by messageId bucket keeps red notes to <= 4/hour)
      - never logs N/A layers again after the first-run note

.PARAMETER StateFile
    Path of the persistent state JSON used by -Scheduled.
    Default: <repo>\outputs\mcp-watchdog\healthcheck-state.json

.PARAMETER HeartbeatMinutes
    Minimum interval between two GREEN heartbeat notes in -Scheduled mode. Default: 60.

.EXAMPLE
    .\mcp-chain-healthcheck.ps1
    # Prints a status table for each layer (manual diagnostic — unchanged behavior).

.EXAMPLE
    .\mcp-chain-healthcheck.ps1 -SkipE2E
    # Skip the cloud E2E test (faster, no auth needed).

.EXAMPLE
    .\mcp-chain-healthcheck.ps1 -Scheduled
    # Unattended tick: state file + conditional dashboard note, no console noise.
#>

param(
    [string]$BotEnvFile = 'D:\nanoclaw\.env',
    [switch]$SkipE2E,
    [switch]$Scheduled,
    [string]$StateFile = '',
    [int]$HeartbeatMinutes = 60
)

$ErrorActionPreference = 'Continue'

# ---------- repo resolution (portable: C:\dev\roo-extensions, D:\roo-extensions, ...) ----------
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$RsmServerDir = Join-Path $RepoRoot 'mcps\internal\servers\roo-state-manager'

# ---------- host-of-bus detection ----------
# 'MCP-Proxy-RSM' is the schtask the host-of-bus watchdog repairs through; it exists
# only where the bus is hosted. Its absence means layers 2-3 are NOT APPLICABLE (not failed).
$IsHostOfBus = [bool](Get-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction SilentlyContinue)

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

function Write-TickLog {
    param([string]$Level, [string]$Text)
    $logDir = Join-Path $RepoRoot 'outputs\mcp-watchdog'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logFile = Join-Path $logDir ("healthcheck-{0}.log" -f (Get-Date -Format yyyyMMdd))
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -Path $logFile -Value "$stamp [$Level] $Text" -Encoding utf8
}

# ---------- Layer 1: local wrapper handshake ----------
function Test-LocalWrapper {
    $wrapperPath = Join-Path $RsmServerDir 'mcp-wrapper.cjs'
    if (-not (Test-Path $wrapperPath)) {
        return @{ Ok = $false; Detail = 'wrapper file missing'; Hint = 'cd mcps/internal && git submodule update --init --recursive' }
    }
    $buildPath = Join-Path $RsmServerDir 'build\index.js'
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
        return @{ Ok = $false; Detail = $_.Exception.Message; Hint = 'check build freshness (scripts/claude/ensure-build-fresh.ps1)' }
    }
}

# ---------- Layer 2: sparfenyuk mcp-proxy [host-of-bus only] ----------
function Test-Sparfenyuk {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:9091/status' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            return @{ Ok = $true; Detail = "HTTP 200 (proxy up)"; Hint = '' }
        }
        return @{ Ok = $false; Detail = "HTTP $($response.StatusCode)"; Hint = 'layer down — report to the coordinator lane (this check never repairs)' }
    } catch {
        return @{ Ok = $false; Detail = "down ($($_.Exception.Message))"; Hint = 'layer down — report to the coordinator lane (this check never repairs)' }
    }
}

# ---------- Layer 3: TBXark Docker port [host-of-bus only] ----------
function Test-TbxarkPort {
    try {
        $tcp = Test-NetConnection -ComputerName '127.0.0.1' -Port 9090 -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($tcp) {
            return @{ Ok = $true; Detail = 'port 9090 reachable'; Hint = '' }
        }
        return @{ Ok = $false; Detail = 'port 9090 closed'; Hint = 'layer down — report to the coordinator lane (this check never repairs)' }
    } catch {
        return @{ Ok = $false; Detail = $_.Exception.Message; Hint = 'check Docker daemon on the host-of-bus machine' }
    }
}

# ---------- Layer 4: E2E ----------
function Test-E2E {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return @{ Ok = $true; NA = $true; Detail = 'no bot .env on this machine'; Hint = '' }
    }
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
        return @{ Ok = $false; Detail = "HTTP $($response.StatusCode)"; Hint = 'bus down — report to the coordinator lane (this check never repairs)' }
    } catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ Ok = $false; Detail = "HTTP $status — $($_.Exception.Message)"; Hint = 'bus down — report to the coordinator lane (this check never repairs)' }
    }
}

# ---------- read-only publication (machine dashboard note via local stdio spawn) ----------
# Publishes THROUGH the very chain layer 1 probes: spawning the local roo-state-manager
# and calling roosync_dashboard(append, machine). No proxy bearer is needed — the server
# authenticates to the store with its own .env, the way every consumer session does.
# Known limit, by design: if layer 1 itself is down, the note cannot leave the machine —
# the failure stays observable in the state file, the log, and the stale heartbeat.
#
# The spawn keeps stdin OPEN until the tools/call response arrives: the wrapper kills
# the server when stdin closes (EOF kill cascade, 10 s graceful shutdown), while a
# dashboard append can legitimately take tens of seconds (GDrive write + possible
# server-side condensation). Piping the requests and closing stdin races the kill
# against the append — measured: response id:3 never emitted, note lost silently.
function Publish-HealthNote {
    param([string]$Level, [string]$Text, [int]$TimeoutSec = 120)
    $wrapperPath = Join-Path $RsmServerDir 'mcp-wrapper.cjs'
    if (-not (Test-Path $wrapperPath)) { return $false }

    # Idempotence (#3276 pattern): the id carries
    # host + level + text digest + 15-min bucket, so a red state re-publishing
    # every 5-min tick collapses to <= 4 notes/hour server-side.
    $epoch = [datetime]::UtcNow - [datetime]::new(1970, 1, 1, 0, 0, 0, [datetimekind]::Utc)
    $bucket = [int][math]::Floor($epoch.TotalSeconds / 900)
    $md5 = [System.Security.Cryptography.MD5]::Create()
    try {
        $digestBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$Level|$Text"))
    } finally { $md5.Dispose() }
    $digest = [System.BitConverter]::ToString($digestBytes).Replace('-', '').Substring(0, 12)
    $noteId = "healthcheck-$env:COMPUTERNAME-$Level-$digest-$bucket"

    $appendArgs = @{
        action    = 'append'
        type      = 'machine'
        tags      = @($Level, 'mcp-chain-healthcheck')
        content   = $Text
        messageId = $noteId
    }
    $appendReq = @{
        jsonrpc = '2.0'
        id      = 3
        method  = 'tools/call'
        params  = @{ name = 'roosync_dashboard'; arguments = $appendArgs }
    } | ConvertTo-Json -Depth 6 -Compress

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'node'
    $psi.Arguments = "`"$wrapperPath`""
    $psi.WorkingDirectory = $RepoRoot   # wrapper derives WORKSPACE_PATH from cwd
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $false   # logs go nowhere; stdout carries only JSON-RPC

    $proc = $null
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-healthcheck","version":"1.0"}}}')
        $proc.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
        $proc.StandardInput.WriteLine($appendReq)
        $proc.StandardInput.Flush()
        # stdin stays OPEN — see function header.

        $deadline = (Get-Date).AddSeconds($TimeoutSec)
        $found = $false
        $readTask = $proc.StandardOutput.ReadLineAsync()
        while ((Get-Date) -lt $deadline) {
            if (-not $readTask.Wait(1000)) { continue }
            $line = $readTask.Result
            if ($null -eq $line) { break }   # EOF — server gone
            if ($line -match '"id"\s*:\s*3') {
                # MCP n'émet "isError" que sur erreur — absent = succès.
                $found = ($line -notmatch '"isError"\s*:\s*true')
                break
            }
            $readTask = $proc.StandardOutput.ReadLineAsync()
        }
        return $found
    } catch {
        return $false
    } finally {
        if ($proc -and -not $proc.HasExited) {
            try { $proc.Kill() } catch { }
        }
        if ($proc) { $proc.Dispose() }
    }
}

# ---------- state file ----------
# One shape, two writes per tick: the first write persists the tick fields as soon
# as the probes ran (local heartbeat — its mtime proves the probe is alive even if
# everything after fails); the second rewrites the same object with the bookkeeping
# fields updated (lastNoteTs, firstRunDone, naReported, prevStatus).
if ([string]::IsNullOrEmpty($StateFile)) {
    $StateFile = Join-Path $RepoRoot 'outputs\mcp-watchdog\healthcheck-state.json'
}

function Read-HealthState {
    if (Test-Path $script:StateFile) {
        try { return Get-Content $script:StateFile -Raw -Encoding utf8 | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Write-HealthState {
    param([object]$State)
    $dir = Split-Path $script:StateFile -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($script:StateFile, (ConvertTo-Json $State -Depth 5), [System.Text.UTF8Encoding]::new($false))
}

# ---------- run probes ----------
$layerPlan = @(
    @{ Id = '1'; Label = '1. Local wrapper';  Applicable = $true;        Test = { Test-LocalWrapper } }
    @{ Id = '2'; Label = '2. sparfenyuk';     Applicable = $IsHostOfBus; Test = { Test-Sparfenyuk } }
    @{ Id = '3'; Label = '3. TBXark proxy';   Applicable = $IsHostOfBus; Test = { Test-TbxarkPort } }
    @{ Id = '4'; Label = '4. E2E (cloud)';    Applicable = $true;        Test = { Test-E2E -Path $BotEnvFile } }
)
if ($SkipE2E) { ($layerPlan | Where-Object Id -eq '4').Applicable = $false }

$results = @()
$naLayers = @()
$failures = @()

foreach ($layer in $layerPlan) {
    if (-not $layer.Applicable) {
        $results += [pscustomobject]@{ Layer = $layer.Label; Status = 'N/A'; Detail = 'not applicable on this machine'; Fix = '' }
        $naLayers += $layer.Label
        continue
    }
    $r = & $layer.Test
    if ($r.NA) {
        $results += [pscustomobject]@{ Layer = $layer.Label; Status = 'N/A'; Detail = $r.Detail; Fix = '' }
        $naLayers += $layer.Label
    } elseif ($r.Ok) {
        $results += [pscustomobject]@{ Layer = $layer.Label; Status = 'OK'; Detail = $r.Detail; Fix = '' }
    } else {
        $results += [pscustomobject]@{ Layer = $layer.Label; Status = 'FAIL'; Detail = $r.Detail; Fix = $r.Hint }
        $failures += $layer.Label
    }
}

$applicableCount = $results | Where-Object { $_.Status -ne 'N/A' } | Measure-Object | Select-Object -ExpandProperty Count

# ---------- status computation ----------
if ($applicableCount -eq 0) {
    $status = 'NA'
} elseif ($failures.Count -gt 0) {
    $status = 'RED'
} else {
    $status = 'GREEN'
}

# ---------- Scheduled mode: local heartbeat + conditional note ----------
if ($Scheduled) {
    $prev = Read-HealthState
    $prevFirstRun = [bool]($prev.firstRunDone)
    $prevNA       = [bool]($prev.naReported)
    $prevNoteTs   = [int]($prev.lastNoteTs)
    $prevStatus   = if ($null -ne $prev) { "$($prev.prevStatus)" } else { '' }
    $nowEpoch = [int][math]::Floor(((Get-Date).ToUniversalTime() - [datetime]::new(1970, 1, 1, 0, 0, 0, [datetimekind]::Utc)).TotalSeconds)

    # Local heartbeat: single-shape state object, written as soon as probes ran —
    # its mtime proves the probe is alive even if the publish path below dies.
    $tickState = @{
        timestamp    = (Get-Date).ToUniversalTime().ToString('o')
        status       = $status
        hostOfBus    = $IsHostOfBus
        layers       = @($results | ForEach-Object { @{ layer = $_.Layer; status = $_.Status; detail = $_.Detail } })
        firstRunDone = $prevFirstRun
        naReported   = $prevNA
        lastNoteTs   = $prevNoteTs
        prevStatus   = $prevStatus
    }
    Write-HealthState -State $tickState

    $publishReason = $null
    $noteLevel = 'INFO'
    $noteText = $null

    if ($status -eq 'NA') {
        # Exigence 2: report the non-applicable probe ONCE, then stay silent.
        if (-not $prevNA) {
            $publishReason = 'first-run NA'
            $noteText = "[mcp-chain-healthcheck] sonde non applicable ici — aucune couche applicable sur $env:COMPUTERNAME (repo=$RepoRoot, hostOfBus=$IsHostOfBus). La sonde cesse de publier."
        }
    } elseif (-not $prevFirstRun) {
        $publishReason = 'first-run'
        $naTxt = if ($naLayers.Count -gt 0) { " — N/A : $($naLayers -join ', ')" } else { '' }
        $noteText = "[mcp-chain-healthcheck] installé sur $env:COMPUTERNAME (role: $(if ($IsHostOfBus) {'host-of-bus'} else {'consumer'})) — premier tick : $status$naTxt. Battement 1/h, notes sur transition et panne."
    } elseif ($status -ne $prevStatus) {
        $publishReason = "transition $prevStatus -> $status"
        if ($status -eq 'RED') {
            $noteLevel = 'WARN'
            $noteText = "[mcp-chain-healthcheck] $env:COMPUTERNAME : passage $prevStatus -> RED. Couches en échec : $($failures -join ', '). Détails : $(($failures | ForEach-Object { $d = ($results | Where-Object Layer -eq $_).Detail; "$_ = $d" }) -join '; '). Repair interdit par design — arbitrage lane requise."
        } else {
            $noteText = "[mcp-chain-healthcheck] $env:COMPUTERNAME : retour au GREEN (était $prevStatus)."
        }
    } elseif ($status -eq 'RED') {
        $publishReason = 'ongoing red'
        $noteLevel = 'WARN'
        $noteText = "[mcp-chain-healthcheck] $env:COMPUTERNAME : toujours RED. Couches en échec : $($failures -join ', ')."
    } elseif (($nowEpoch - $prevNoteTs) -ge ($HeartbeatMinutes * 60)) {
        $publishReason = 'heartbeat'
        $noteText = "[mcp-chain-healthcheck] battement $env:COMPUTERNAME : GREEN ($($results | Where-Object Status -eq 'OK' | Measure-Object | Select-Object -ExpandProperty Count) couches OK, $($naLayers.Count) N/A). Probe vivante, chaîne locale saine."
    }

    if ($noteText) {
        $published = Publish-HealthNote -Level $noteLevel -Text $noteText
        if ($published) {
            Write-TickLog -Level 'INFO' -Text "note posted ($publishReason)"
            $tickState.lastNoteTs = $nowEpoch
        } else {
            # Publish failed — most likely layer 1 itself is down. The local state
            # file and this log line keep the failure observable until recovery.
            Write-TickLog -Level 'ERROR' -Text "note NOT posted ($publishReason) — publish path down; failure stays in state file"
        }
    }

    $tickState.prevStatus = $status
    $tickState.firstRunDone = $true
    if ($status -eq 'NA') { $tickState.naReported = $true }
    Write-HealthState -State $tickState

    if     ($status -eq 'RED') { exit 1 }
    elseif ($status -eq 'NA')  { exit 3 }
    else                       { exit 0 }
}

# ---------- Manual mode: unchanged diagnostic output ----------
Write-Host ''
Write-Host '=== MCP Chain Healthcheck ===' -ForegroundColor Cyan
Write-Host ''
$results | Format-Table -AutoSize -Wrap

if ($applicableCount -eq 0) {
    Write-Host "No applicable layer on this machine (role: $(if ($IsHostOfBus) {'host-of-bus'} else {'consumer'})). Probe not applicable here." -ForegroundColor Yellow
    Write-Host ''
    exit 3
}

if ($failures.Count -eq 0) {
    Write-Host "All applicable layers healthy ($($naLayers.Count) N/A). roo-state-manager is reachable." -ForegroundColor Green
    Write-Host ''
    exit 0
} else {
    Write-Host "$($failures.Count) layer(s) failed. Suggested actions:" -ForegroundColor Red
    foreach ($f in $failures) {
        $fix = ($results | Where-Object Layer -eq $f).Fix
        if ($fix) { Write-Host "  ${f}: $fix" -ForegroundColor Yellow }
    }
    Write-Host ''
    Write-Host 'This check never repairs (arbitrage #3495). Report the failure to the coordinator lane.' -ForegroundColor Cyan
    Write-Host ''
    exit 1
}
