# start-sk-agent-daemon.ps1 - one shared sk-agent MCP daemon per seat (#4149 F2)
#
# Replaces the per-session stdio server (cost linear in open sessions, #4149:
# 6 procs / 527 MB for 3 sessions on web2) with ONE streamable-http daemon on
# 127.0.0.1. sk-agent already ships the transport (`sk_agent.py
# streamable-http`, validated #3412); this script is the seat-side lifecycle.
#
# Idempotent: if the port already listens, it probes the endpoint and exits 0.
# The API key is generated once into $KeyFile (never printed, never committed)
# and is REQUIRED by sk-agent for streamable-http (sk_agent.py:3488).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\start-sk-agent-daemon.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\start-sk-agent-daemon.ps1 -Port 8101 -WhatIf
# Exit codes: 0 = running (started or already up), 1 = failed to start/verify.

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [int]$Port = 8100,
    [string]$BindHost = '127.0.0.1',
    [string]$KeyFile = "$env:USERPROFILE\.sk-agent\daemon-api.key",
    # NB: resolved in the body, NOT in a param default -- $PSScriptRoot is
    # empty during param binding under `powershell.exe -File` (PS 5.1).
    [string]$RepoRoot = '',
    [string]$SkAgentDir = '',
    [string]$LogDir = "$env:LOCALAPPDATA\sk-agent\daemon",
    [int]$TimeoutSec = 60
)

$ErrorActionPreference = 'Stop'
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
$SkAgentDir = if ($SkAgentDir) { $SkAgentDir } else { Join-Path $RepoRoot 'mcps\internal\servers\sk-agent' }
$SkAgentPy = Join-Path $SkAgentDir 'sk_agent.py'
if (-not (Test-Path $SkAgentPy)) {
    Write-Output "[FAIL] sk_agent.py not found: $SkAgentPy"
    Write-Output "       (submodule not populated? run: git submodule update --init mcps/internal)"
    exit 1
}

function Test-DaemonHttp {
    # Any HTTP status back proves the endpoint is served; 401 without the
    # Authorization header is the expected auth-enforced answer (#3412).
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://${BindHost}:${Port}/mcp")
        $req.Method = 'POST'
        $req.Timeout = 5000
        $req.ContentType = 'application/json'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes('{}')
        $req.ContentLength = $bytes.Length
        $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
        $resp = $req.GetResponse(); $resp.Close()
        return $resp.StatusCode
    } catch [System.Net.WebException] {
        if ($_.Exception.Response) {
            $code = [int]$_.Exception.Response.StatusCode
            $_.Exception.Response.Close()
            return $code
        }
        return $null
    } catch {
        return $null
    }
}

# --- 1. Idempotence: already listening? ---
$listen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listen) {
    $status = Test-DaemonHttp
    Write-Output "[OK] port $Port already listening (pid $($listen[0].OwningProcess)) - daemon assumed up"
    if ($status) { Write-Output "     unauthenticated probe -> HTTP $status (auth enforced if 401)" }
    exit 0
}

# --- 3. Python ladder: venv > conda > PATH (same as run-sk-agent.ps1) ---
$python = $null
$venvPy = Join-Path $SkAgentDir 'venv\Scripts\python.exe'
if (Test-Path $venvPy) {
    $python = $venvPy
} elseif (Test-Path (Join-Path $env:USERPROFILE 'miniconda3\python.exe')) {
    $python = Join-Path $env:USERPROFILE 'miniconda3\python.exe'
} else {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source }
}
if (-not $python) { Write-Output '[FAIL] no python found (venv / miniconda / PATH)'; exit 1 }

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Force $LogDir | Out-Null }
$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$outLog = Join-Path $LogDir "daemon-$stamp.out.log"
$errLog = Join-Path $LogDir "daemon-$stamp.err.log"

if (-not $PSCmdlet.ShouldProcess("sk-agent daemon on ${BindHost}:${Port}", 'start process')) {
    Write-Output "[WhatIf] would start: $python `"$SkAgentPy`" streamable-http (host $BindHost, port $Port)"
    Write-Output "[WhatIf] key file: $KeyFile ($(if (Test-Path $KeyFile) { 'existing' } else { 'to be generated' })) ; logs: $LogDir"
    Write-Output "[WhatIf] nothing written (no key generated, no logs, no process)"
    exit 0
}

# --- 4. API key: generate once, never printed (after WhatIf: a dry run writes nothing) ---
$KeyDir = Split-Path -Parent $KeyFile
if (-not (Test-Path $KeyDir)) { New-Item -ItemType Directory -Force $KeyDir | Out-Null }
if (Test-Path $KeyFile) {
    $apiKey = ([System.IO.File]::ReadAllText($KeyFile)).Trim()
} else {
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $raw = New-Object byte[] 32
    $rng.GetBytes($raw)
    $apiKey = [Convert]::ToBase64String($raw).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    [System.IO.File]::WriteAllText($KeyFile, $apiKey, [System.Text.UTF8Encoding]::new($false))
}

# --- 5. Start (child inherits this process' env; key never printed) ---
$env:SK_AGENT_API_KEY = $apiKey
$env:SK_AGENT_HOST = $BindHost
$env:SK_AGENT_PORT = "$Port"
$proc = Start-Process -FilePath $python `
    -ArgumentList @("`"$SkAgentPy`"", 'streamable-http') `
    -WorkingDirectory $SkAgentDir `
    -WindowStyle Hidden `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
    -PassThru
[System.IO.File]::WriteAllText((Join-Path $LogDir 'daemon.pid'), "$($proc.Id)", [System.Text.UTF8Encoding]::new($false))
Write-Output "[START] pid $($proc.Id) -> $python streamable-http (${BindHost}:${Port})"

# --- 6. Wait for readiness, then verify auth is enforced ---
$deadline = (Get-Date).AddSeconds($TimeoutSec)
$listening = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 1
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { $listening = $true; break }
    if ($proc.HasExited) { break }
}
if (-not $listening) {
    Write-Output "[FAIL] daemon not listening on port $Port within ${TimeoutSec}s (exited=$($proc.HasExited))"
    if (Test-Path $errLog) { Write-Output '--- stderr tail ---'; Get-Content $errLog -Tail 15 }
    exit 1
}
$status = Test-DaemonHttp
Write-Output "[OK] daemon listening on ${BindHost}:${Port} - unauthenticated probe -> HTTP $status"
if ($status -ne 401) {
    Write-Output "[WARN] expected 401 without Authorization (auth enforced) - got $status; check SK_AGENT_API_KEY plumbing"
}
Write-Output "       logs: $outLog / $errLog ; key file: $KeyFile"
exit 0
