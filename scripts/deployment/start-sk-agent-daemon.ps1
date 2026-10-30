# start-sk-agent-daemon.ps1 - one shared sk-agent MCP daemon per seat (#4149 F2)
#
# Replaces the per-session stdio server (cost linear in open sessions, #4149:
# 6 procs / 527 MB for 3 sessions on web2) with ONE streamable-http daemon on
# 127.0.0.1. sk-agent already ships the transport (`sk_agent.py
# streamable-http`, validated #3412); this script is the seat-side lifecycle.
#
# Idempotent: if the port already listens, it FAILS CLOSED unless the daemon the
# clients expect actually answers. #4149 review: a bare listener on the port is not
# proof — after a key rotation, or when another process holds the port, "[OK] assumed
# up" + exit 0 would send every client to a 401 while the starter reported success.
# The proof is two probes: an unauthenticated request must get 401 (auth enforced),
# and an MCP `initialize` carrying the bearer from $KeyFile must NOT get 401.
# The API key is generated once into $KeyFile (never printed, never committed)
# and is REQUIRED by sk-agent for streamable-http (sk_agent.py:3488).
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\start-sk-agent-daemon.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\deployment\start-sk-agent-daemon.ps1 -Port 8101 -WhatIf
# Exit codes: 0 = an authenticated daemon answers, 1 = failed to start/verify.

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

# MCP `initialize` handshake: the smallest request a real MCP endpoint must
# answer. A random HTTP server on the port answers 404/200 to `{}` happily — it
# cannot answer this with a 2xx JSON-RPC result, and the bearer gate sits in
# front of it. #4149 review: replace "any status back" with "this exact call".
$INIT_BODY = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"start-sk-agent-daemon","version":"1.0"}}}'

function Invoke-DaemonPost {
    # Returns the HTTP status code the endpoint answered with, or $null when
    # nothing HTTP answered at all. -ApiKey is sent as the bearer when given;
    # it is NEVER printed here and never lands in the returned value.
    param([string]$ApiKey = '', [string]$Body = '{}')
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://${BindHost}:${Port}/mcp")
        $req.Method = 'POST'
        $req.Timeout = 5000
        $req.ContentType = 'application/json'
        # streamable-http may answer either as JSON or as an SSE stream.
        $req.Accept = 'application/json, text/event-stream'
        if ($ApiKey) { $req.Headers.Add('Authorization', "Bearer $ApiKey") }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
        $req.ContentLength = $bytes.Length
        $s = $req.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        return $code
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

function Get-DaemonProof {
    # The proof #4149 review asked for, both halves:
    #   (a) an UNAUTHENTICATED request gets 401   -> auth is actually enforced
    #   (b) an `initialize` carrying the bearer from $KeyFile gets a NON-401
    #       answer                                 -> THIS key is the daemon's key
    # A bare listener holding the port fails (a) or never answers; a daemon left
    # over from a key rotation fails (b) with 401. Either way: no "[OK]".
    # -WaitSec re-tries until the deadline (a freshly started daemon may still be
    # arming its HTTP layer); the diagnosis returned is the LAST attempt's.
    #
    # Returns [PSCustomObject]@{ Ok = <bool>; Lines = <string[]> } and emits
    # NOTHING to the pipeline, on purpose: a function that prints its diagnosis
    # to the output stream returns an ARRAY, and `if (-not (Get-…))` on a 2-element
    # array is always $false — a raw listener then "proves" itself (measured: the
    # #4414 red test passed exactly that way). Callers read .Ok and print .Lines.
    param([string]$ApiKey, [int]$WaitSec = 0)
    $deadline = (Get-Date).AddSeconds($WaitSec)
    $anon = $null; $auth = $null; $ok = $false
    while ($true) {
        $anon = Invoke-DaemonPost
        $auth = if ($anon -eq 401) { Invoke-DaemonPost -ApiKey $ApiKey -Body $INIT_BODY } else { $null }
        $ok = ($anon -eq 401) -and ($null -ne $auth) -and ($auth -ne 401)
        if ($ok -or (Get-Date) -ge $deadline) { break }
        Start-Sleep -Seconds 1
    }
    if ($ok) {
        return [PSCustomObject]@{
            Ok    = $true
            Lines = @(
                '     unauthenticated probe      -> HTTP 401 (auth enforced)'
                "     authenticated initialize   -> HTTP $auth"
            )
        }
    }
    if ($null -eq $anon) {
        $why = @("[FAIL] nothing HTTP answers on ${BindHost}:${Port}/mcp (a raw listener owns the port, or it died)")
    } elseif ($anon -ne 401) {
        $why = @("[FAIL] unauthenticated probe -> HTTP $anon (expected 401: the port is not serving an auth-gated MCP endpoint)")
    } elseif ($null -eq $auth) {
        $why = @('[FAIL] authenticated initialize -> no answer (endpoint stopped or is not streamable-http)')
    } elseif ($auth -eq 401) {
        $why = @(
            "[FAIL] authenticated initialize -> HTTP 401 (the key in $KeyFile is not this listener's key)"
            "       a daemon from before a key rotation, or another seat's daemon owns this port"
        )
    } else {
        $why = @("[FAIL] authenticated initialize -> HTTP $auth (expected a 2xx JSON-RPC result)")
    }
    return [PSCustomObject]@{ Ok = $false; Lines = $why }
}

# --- 1. Idempotence: already listening? Then PROVE it is the daemon we expect ---
$listen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($listen) {
    $ownerPid = $listen[0].OwningProcess
    Write-Output "[INFO] port $Port already listening (pid $ownerPid) - proving it is the expected sk-agent daemon"
    # #4149 review: a listener on the port is not the daemon. Without the key we
    # cannot even ask, and "assumed up" + exit 0 would send every client to a 401
    # while the starter reported success. Fail closed instead.
    if (-not (Test-Path $KeyFile)) {
        Write-Output "[FAIL] key file not found: $KeyFile - cannot prove the listener on port $Port speaks our bearer"
        Write-Output '       (a daemon from another config/seat owns the port, or the key was removed)'
        exit 1
    }
    $existingKey = ([System.IO.File]::ReadAllText($KeyFile)).Trim()
    if (-not $existingKey) { Write-Output "[FAIL] key file is empty: $KeyFile"; exit 1 }
    $existingProof = Get-DaemonProof -ApiKey $existingKey -WaitSec 3
    $existingProof.Lines | ForEach-Object { Write-Output $_ }
    if (-not $existingProof.Ok) {
        Write-Output "[FAIL] refusing to report success: the listener on port $Port is not the sk-agent daemon this seat's clients expect"
        Write-Output "       diagnose: pid $ownerPid ; if it is a stale daemon, stop it and re-run this script"
        exit 1
    }
    Write-Output "[OK] daemon already up and proven on ${BindHost}:${Port} (pid $ownerPid)"
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

# --- 6. Wait for readiness, then PROVE the endpoint (auth + initialize) ---
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
# #4149 review: "listening" is not "ready". Require both probes; a process that
# listens but answers 200 without a bearer, or 401 to its own key, is a broken
# daemon and must not be reported as up (nor left holding the port for the next
# run to fail on). Kill what WE started, then exit non-zero.
$startProof = Get-DaemonProof -ApiKey $apiKey -WaitSec 10
$startProof.Lines | ForEach-Object { Write-Output $_ }
if (-not $startProof.Ok) {
    Write-Output "[FAIL] the daemon we started (pid $($proc.Id)) did not prove itself - stopping it"
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    if (Test-Path $errLog) { Write-Output '--- stderr tail ---'; Get-Content $errLog -Tail 15 }
    exit 1
}
Write-Output "[OK] daemon up and proven on ${BindHost}:${Port} (pid $($proc.Id))"
Write-Output "       logs: $outLog / $errLog ; key file: $KeyFile"
exit 0
