<#
.SYNOPSIS
    One-shot E2E slow-call probe for the MCP proxy chain (#1357, acceptance #4).

.DESCRIPTION
    Proves the public chain
      mcp-tools.myia.io -> IIS/ARR (po-2023) -> TBXark (:9090) -> sparfenyuk (:9091)
      -> roo-state-manager
    carries a legitimately slow (> 60 s) tool call to SUCCESS.

    The slow call is a real dashboard append that triggers the auto-condensation
    LLM leg -- the exact operation the 12-minute roosync_dashboard budget and
    the 24/09 timeout ladder exist for (77-165 s measured fleet-wide on 02/10,
    condensation and fallback-truncation legs alike). Any dashboard near the
    ~46 KB condensation threshold makes the slow leg deterministic; the default
    target (workspace roo-extensions) sits at that threshold most of the time.

    Must run on the bearer host (ai-01): reads MCP_PROXY_BASE_URL and
    MCP_PROXY_BEARER from the NanoClaw .env, like mcp-chain-watchdog.ps1.

    Exit codes:
      0  PASS            HTTP 200, no MCP isError, tool-call leg > 60 s.
      1  FAIL            cut, HTTP error, or isError:true.
      2  CONFIG MISSING  bearer unreadable from BotEnvFile.
      3  FAST-SUCCESS    200 + no isError but tool-call leg <= 60 s: chain
                         healthy, slow path NOT exercised (condensation did not
                         fire). Re-run later or target a near-threshold
                         dashboard. NOT an AC#4 pass.

    The append is a real, idempotent telemetry note: the messageId bucket is
    15 minutes plus a fingerprint of the note content (mcp-chain-watchdog.ps1's
    proven pattern, #3276 mechanism), so a client timeout (800 s) followed by
    a retry cannot double-write — the retry lands in the same bucket with the
    same fingerprint and is skipped server-side.

.PARAMETER BotEnvFile
    Path to the NanoClaw .env (MCP_PROXY_BASE_URL + MCP_PROXY_BEARER).
    Default: D:\nanoclaw\.env

.PARAMETER TimeoutSec
    Client budget for the tool call. Default 800 s -- ABOVE the 780 s (13 min)
    TBXark hop and the 720 s inner dashboard budget, so this client never cuts
    before an inner guard fires (ladder philosophy: innermost guard first).

.PARAMETER DashboardType
    Append target type: workspace (default), machine, or global.

.PARAMETER Workspace
    Target workspace when DashboardType=workspace. Default: roo-extensions.

.PARAMETER MachineId
    Target machine when DashboardType=machine. Default: server-side local.

.PARAMETER Note
    Content of the telemetry note. Keep it short and secret-free.

.EXAMPLE
    .\mcp-chain-slowcall-probe.ps1
    .\mcp-chain-slowcall-probe.ps1 -DashboardType machine
    .\mcp-chain-slowcall-probe.ps1 -TimeoutSec 900 -Workspace qdrant
#>
param(
    [string]$BotEnvFile = 'D:\nanoclaw\.env',
    [int]$TimeoutSec = 800,
    [ValidateSet('workspace','machine','global')]
    [string]$DashboardType = 'workspace',
    [string]$Workspace = 'roo-extensions',
    [string]$MachineId = '',
    [string]$Note = 'E2E slow-call probe (#1357 AC#4): dashboard append through the public chain; the auto-condensation leg is the deliberate slow path. Result reported on the issue.'
)

$ErrorActionPreference = 'Stop'

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

$baseUrl = Read-EnvValue -Path $BotEnvFile -Key 'MCP_PROXY_BASE_URL'
$bearer  = Read-EnvValue -Path $BotEnvFile -Key 'MCP_PROXY_BEARER'
if ([string]::IsNullOrEmpty($baseUrl)) { $baseUrl = 'https://mcp-tools.myia.io' }
if ([string]::IsNullOrEmpty($bearer)) {
    Write-Host "CONFIG MISSING: cannot read MCP_PROXY_BEARER from $BotEnvFile -- this probe runs on the bearer host (ai-01), like mcp-chain-watchdog.ps1"
    exit 2
}

$url = "$baseUrl/roo-state-manager/mcp"
$headers = @{
    'Authorization' = "Bearer $bearer"
    'Content-Type'  = 'application/json'
    'Accept'        = 'application/json, text/event-stream'
}

$initBody = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-chain-slowcall-probe","version":"1.0"}}}'

# Idempotence (#3276), same pattern as mcp-chain-watchdog.ps1's Publish-FleetNote
# (follow-up to the #4030 APPROVE review): the id is THE note (fingerprint of the
# content + 15-min bucket), not the attempt. A 1-min bucket dies against this
# probe's 800 s client timeout: the retry always starts in a later minute, and if
# the first append did write (WRITE-FIRST), the retry double-posts on a channel
# the whole fleet reads. With the fingerprint, two different notes never collide
# either — a NOTE text the operator changed IS a new note and must write.
$epoch = [datetime]::UtcNow - [datetime]::new(1970, 1, 1, 0, 0, 0, [datetimekind]::Utc)
$bucket = [int][math]::Floor($epoch.TotalSeconds / 900)
$md5 = [System.Security.Cryptography.MD5]::Create()
try {
    $digestBytes = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Note))
} finally { $md5.Dispose() }
$noteDigest = [System.BitConverter]::ToString($digestBytes).Replace('-', '').Substring(0, 12)
$appendArgs = @{
    action    = 'append'
    type      = $DashboardType
    tags      = @('INFO','mcp-chain-slowcall-probe')
    content   = $Note
    messageId = "e2e-slowcall-1357-$noteDigest-$bucket"
}
if ($DashboardType -eq 'workspace') { $appendArgs.workspace = $Workspace }
if ($DashboardType -eq 'machine' -and $MachineId) { $appendArgs.machineId = $MachineId }
$callBody = @{
    jsonrpc = '2.0'
    id      = 2
    method  = 'tools/call'
    params  = @{ name = 'roosync_dashboard'; arguments = $appendArgs }
} | ConvertTo-Json -Depth 6 -Compress

Write-Host "Probe target : $url"
Write-Host "Append target: $DashboardType$(if ($DashboardType -eq 'workspace') { " / $Workspace" } elseif ($DashboardType -eq 'machine' -and $MachineId) { " / $MachineId" })"
Write-Host "Client budget: ${TimeoutSec}s (tool-call leg)"

# Initialize: fast exchange, short budget -- only the tool call needs the long
# one.
$swInit = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $init = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -Body $initBody `
                              -UseBasicParsing -TimeoutSec 20 -ErrorAction Stop
} catch {
    $status = 0
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    Write-Host "FAIL: initialize HTTP $status after $($swInit.ElapsedMilliseconds)ms -- $($_.Exception.Message)"
    exit 1
}
$swInit.Stop()
if ($init.StatusCode -ne 200) {
    Write-Host "FAIL: initialize HTTP $($init.StatusCode)"
    exit 1
}

# Session id: present on sparfenyuk (mandatory), absent on stateless forwards
# (TBXark accepts calls without it). Case-insensitive lookup, PS 5.1 and 7.
$sid = $null
foreach ($k in @($init.Headers.Keys)) { if ("$k" -ieq 'mcp-session-id') { $sid = $init.Headers[$k]; break } }
$callHeaders = $headers
if ($sid) {
    $callHeaders = @{} + $headers
    $callHeaders['mcp-session-id'] = "$sid"
    $null = Invoke-WebRequest -Uri $url -Method Post -Headers $callHeaders `
                              -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' `
                              -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
}

$swCall = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $resp = Invoke-WebRequest -Uri $url -Method Post -Headers $callHeaders -Body $callBody `
                              -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
} catch {
    $swCall.Stop()
    $status = 0
    if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
    $elapsed = [int]$swCall.Elapsed.TotalSeconds
    Write-Host "FAIL: tools/call HTTP $status after ${elapsed}s (client budget ${TimeoutSec}s) -- $($_.Exception.Message)"
    Write-Host "  If elapsed ~= TimeoutSec, the CLIENT cut first: raise -TimeoutSec above every hop (800 s covers the 780 s TBXark hop and the 720 s inner budget)."
    Write-Host "  If elapsed << TimeoutSec, an outer layer cut: read the ladder in docs/harness/reference/mcp-proxy-architecture.md."
    exit 1
}
$swCall.Stop()
$elapsedSec = [int]$swCall.Elapsed.TotalSeconds
$content = $resp.Content

Write-Host "initialize   : HTTP $($init.StatusCode) in $($swInit.ElapsedMilliseconds)ms"
Write-Host "tools/call   : HTTP $($resp.StatusCode) in ${elapsedSec}s"
Write-Host ("response head: " + $content.Substring(0, [Math]::Min(200, $content.Length)))

if ($resp.StatusCode -eq 200 -and $content -match '"isError"\s*:\s*true') {
    Write-Host "FAIL: HTTP 200 but isError:true (backend alive, instance dead -- the 2026-08-15 signature). Not a slow-call PASS."
    exit 1
}
if ($resp.StatusCode -ne 200) {
    Write-Host "FAIL: HTTP $($resp.StatusCode)."
    exit 1
}
if ($elapsedSec -le 60) {
    Write-Host "FAST-SUCCESS: chain carried the call in ${elapsedSec}s (healthy), but the slow path was NOT exercised -- condensation did not fire. NOT an AC#4 pass. Re-run when the target dashboard is near the ~46 KB threshold, or pick a busier one."
    exit 3
}
Write-Host "PASS: >60s tool call (${elapsedSec}s) carried to SUCCESS through the full public chain (IIS/ARR -> TBXark 13min hop -> sparfenyuk -> RSM 720s dashboard budget). AC#4 satisfied."
exit 0
