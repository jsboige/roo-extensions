<#
.SYNOPSIS
    Per-machine usability classifier: healthy / unreachable / reachable-but-unusable (#4327).

.DESCRIPTION
    Answers one question per roster machine, from the coordinator host (ai-01), with
    READ-ONLY probes: "is this machine reachable AND able to run work?" A machine can
    answer on the network and still be dead for work — po-2028 wedged twice on 23/10:
    the logon died ~5 min after a clean boot, no load, no kernel crash, WinRM kept
    answering (~10 s), and six shutdown requests were accepted by wininit but never
    executed. Only a physical power cycle recovered it.

    The third verdict is the point of this script. Neither of the two existing organs
    says it: check-all-listeners.ps1 reports "listener STALE/DEAD" after 2 h (a dead
    listener on a healthy machine prints the same line), and detect-approval-stalls.py
    only sees sessions that are alive and frozen, never sessions that never start.

    THE ALERT IS NOT THE LEVER. This script posts a [FLEET-ALERT] on the detector's
    machine dashboard and stops there; firing the hard reboot lever stays with the
    Maintenance lane (fleet_remote_reboot.ps1 -Hard), on its own line.

    Verdict rules, in order (first match wins) — each one is a measured input, none is
    inferred from a single signal:
      1. No probed port answers              -> unreachable
      2. Driving channel bad (silent or slow) AND sessions dead -> reachable-but-unusable
      3. Anything else                        -> healthy, with findings that name what is off

    "Sessions dead" needs positive evidence (a listener heartbeat older than the
    threshold). A machine with NO heartbeat file gets the `no-heartbeat` finding, not a
    death sentence: absence of the instrument is not a measurement of the machine. This
    is also what separates rule 2 from the 2 h listener check — on a healthy machine
    whose listener alone is dead, the driving channel answers fast and the verdict
    stays `healthy` with a `listener-stale` finding (acceptance criterion 3).

    Inputs per machine (acceptance criterion 5 — the alert names each value):
      - openPorts: TCP connect to 5985 (WinRM), 22 (SSH), 3389 (RDP), 445 (SMB).
      - driving channel: 5985 for the myia-* seats, 22 for the Linux web seats.
        Measured as a WS-Identify round-trip (read-only, no session, no command run on
        the target) for WinRM, or the TCP connect time for SSH.
      - listener heartbeat age, read from <shared>/listener-heartbeats/<machine>.heartbeat.

.PARAMETER Machines
    Machines to classify. Defaults to $env:ROO_FLEET_ROSTER, else the 9-machine roster
    of #4258.

.PARAMETER ReplayFile
    JSON timeline instead of live probes: either an array of samples, or an object
    {logonDeathUtc, samples:[...]}. Each sample carries the inputs above. This is how
    acceptance criterion 2 is reproduced (po-2028 replay) without touching the network;
    with logonDeathUtc present the output reports detectedAfterMinutes.

.PARAMETER WinrmSlowMs
    Driving-channel latency above which the channel counts as bad (default 5000;
    Maintenance measured ~10 s on the wedged machine, sub-second on healthy ones).

.PARAMETER HeartbeatStaleSeconds
    Listener heartbeat age above which sessions count as dead (default 1800; the
    listener pings every 5 min).

.PARAMETER NoAlert
    Classify and print only, post nothing.

.PARAMETER Json
    Machine-readable output.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -Json -NoAlert

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -ReplayFile fixtures\po2028-20261023.json

.NOTES
    Exit codes: 0 all healthy · 1 an unreachable machine (and none unusable) ·
    2 at least one reachable-but-unusable (the hard-lever signal) · 3 usage/replay error.
    Related: #4327, #2576 (listener check), #4243 (approval stalls), #4258 (roster).
#>

param(
    [string[]]$Machines = @(),
    [string]$ReplayFile = "",
    [int]$WinrmSlowMs = 5000,
    [int]$HeartbeatStaleSeconds = 1800,
    [int]$ProbeTimeoutMs = 3000,
    [switch]$NoAlert,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# #4258 roster — kept in sync with ROO_FLEET_ROSTER; the env wins when set.
$DefaultRoster = @(
    'myia-ai-01', 'myia-po-2023', 'myia-po-2024', 'myia-po-2025', 'myia-po-2026',
    'myia-po-2027', 'myia-po-2028', 'myia-web1', 'myia-web2'
)

# Linux seats have no WinRM: the channel that can run work on them is SSH.
$DrivingPortByMachine = @{
    'myia-web1' = 22
    'myia-web2' = 22
}
$DefaultDrivingPort = 5985
$ProbedPorts = @(5985, 22, 3389, 445)

# ---------------------------------------------------------------------------
# Decision — pure function over measured inputs (no probing, no clock, no I/O):
# this is what the replay mode exercises, and what the tests pin.
# ---------------------------------------------------------------------------
function Get-UsabilityVerdict {
    param(
        [string]$Machine,
        [string[]]$OpenPorts = @(),
        [bool]$DrivingChannelAnswered = $false,
        $DrivingLatencyMs = $null,
        $HeartbeatAgeSeconds = $null,
        [int]$DrivingPort = 5985,
        [int]$SlowThresholdMs = 5000,
        [int]$HeartbeatStaleSeconds = 1800
    )

    $findings = @()

    # Rule 1 — nothing answers: the network stack is down (or the box is off).
    if ($OpenPorts.Count -eq 0) {
        return [PSCustomObject]@{
            machine            = $Machine
            verdict            = 'unreachable'
            findings           = @('no-port-answers')
            openPorts          = @()
            drivingPort        = $DrivingPort
            drivingAnswered    = $DrivingChannelAnswered
            drivingLatencyMs   = $DrivingLatencyMs
            heartbeatAgeSeconds = $HeartbeatAgeSeconds
        }
    }

    # Driving channel health, named precisely so the alert can be read without a
    # second measurement (criterion 5).
    $channelBad = $false
    if (-not $DrivingChannelAnswered) {
        $channelBad = $true
        $findings += 'driving-channel-silent'
    } elseif ($null -ne $DrivingLatencyMs -and [int]$DrivingLatencyMs -gt $SlowThresholdMs) {
        $channelBad = $true
        $findings += 'driving-channel-slow'
    }

    # Session liveness — positive evidence only.
    $sessionsDead = $false
    if ($null -eq $HeartbeatAgeSeconds) {
        # No instrument. Not a death sentence; a machine whose channel is bad AND
        # whose liveness is unmeasured is suspect, and the finding says so.
        $findings += 'no-heartbeat'
        if ($channelBad) { $findings += 'unusable-suspect' }
    } elseif ([int]$HeartbeatAgeSeconds -gt $HeartbeatStaleSeconds) {
        $sessionsDead = $true
        $findings += 'listener-stale'
    }

    if ($OpenPorts.Count -lt $ProbedPorts.Count) { $findings += 'ports-partial' }

    # Rule 2 — reachable, but nothing can run there. Two independent signals must
    # agree: the channel that carries work is bad, and the sessions are dead.
    if ($channelBad -and $sessionsDead) {
        return [PSCustomObject]@{
            machine            = $Machine
            verdict            = 'reachable-but-unusable'
            findings           = $findings
            openPorts          = $OpenPorts
            drivingPort        = $DrivingPort
            drivingAnswered    = $DrivingChannelAnswered
            drivingLatencyMs   = $DrivingLatencyMs
            heartbeatAgeSeconds = $HeartbeatAgeSeconds
        }
    }

    # Rule 3 — healthy, findings carrying whatever is off (criterion 3: a dead
    # listener alone stays healthy + listener-stale).
    [PSCustomObject]@{
        machine            = $Machine
        verdict            = 'healthy'
        findings           = $findings
        openPorts          = $OpenPorts
        drivingPort        = $DrivingPort
        drivingAnswered    = $DrivingChannelAnswered
        drivingLatencyMs   = $DrivingLatencyMs
        heartbeatAgeSeconds = $HeartbeatAgeSeconds
    }
}

# ---------------------------------------------------------------------------
# Alert content (criterion 5): names every input and its value.
# ---------------------------------------------------------------------------
function New-AlertContent {
    param([Parameter(Mandatory)] $Result, [string]$Detector = $env:COMPUTERNAME)

    $lat = if ($null -ne $Result.drivingLatencyMs) { "$($Result.drivingLatencyMs) ms" } else { 'no answer' }
    $hb = if ($null -ne $Result.heartbeatAgeSeconds) { "$($Result.heartbeatAgeSeconds) s" } else { 'no heartbeat file' }
    $ports = if ($Result.openPorts.Count -gt 0) { $Result.openPorts -join ', ' } else { 'none' }

    $lines = @(
        "[FLEET-ALERT] [CRITICAL] $($Result.machine) — reachable-but-unusable (#4327)",
        "",
        "Measured by $Detector at $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')):",
        "- ports answering: $ports (probed 5985 WinRM, 22 SSH, 3389 RDP, 445 SMB)",
        "- driving channel ($($Result.drivingPort)): answered=$($Result.drivingAnswered), $lat (slow threshold $WinrmSlowMs ms)",
        "- listener heartbeat: $hb (dead threshold $HeartbeatStaleSeconds s)",
        "- findings: $($Result.findings -join ', ')",
        "",
        "The machine answers on the network but cannot run work. Hard reboot is NOT fired by this script — it stays with the Maintenance lane (fleet_remote_reboot.ps1 -Hard)."
    )
    return ($lines -join "`r`n")
}

# ---------------------------------------------------------------------------
# Live probes
# ---------------------------------------------------------------------------
function Test-TcpPort {
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 3000)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) { return $false }
        $client.EndConnect($iar)
        return $true
    } catch { return $false } finally { $client.Close() }
}

function Measure-DrivingChannel {
    # WinRM: WS-Identify over HTTP — read-only by construction (no session is
    # created, no command runs on the target), so criterion 1's "no write on the
    # target" holds even when the probe succeeds.
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 3000)

    if ($Port -ne 5985) {
        # SSH/TCP channels: connect time is the only read-only latency available.
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = Test-TcpPort -ComputerName $ComputerName -Port $Port -TimeoutMs $TimeoutMs
        $sw.Stop()
        return [PSCustomObject]@{ answered = $ok; latencyMs = $(if ($ok) { [int]$sw.ElapsedMilliseconds } else { $null }) }
    }

    $envelope = @'
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope" xmlns:wsmid="http://schemas.dmtf.org/wbem/wsman/identity/1/wsmanidentity.xsd"><s:Header/><s:Body><wsmid:Identify/></s:Body></s:Envelope>
'@
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $req = [System.Net.HttpWebRequest]::Create("http://${ComputerName}:${Port}/wsman")
        $req.Method = 'POST'
        $req.ContentType = 'application/soap+xml;charset=UTF-8'
        $req.Timeout = $TimeoutMs
        $req.ReadWriteTimeout = $TimeoutMs
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($envelope)
        $req.ContentLength = $bytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
        $resp = $req.GetResponse()
        $resp.Close()
        $sw.Stop()
        return [PSCustomObject]@{ answered = $true; latencyMs = [int]$sw.ElapsedMilliseconds }
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{ answered = $false; latencyMs = $null }
    }
}

function Get-HeartbeatAgeSeconds {
    param([string]$Machine)
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($sharedPath)) { return $null }
    $file = Join-Path (Join-Path $sharedPath 'listener-heartbeats') ("$Machine.heartbeat")
    if (-not (Test-Path $file)) { return $null }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $file).LastWriteTimeUtc).TotalSeconds
    return [int]$age
}

# ---------------------------------------------------------------------------
# Dashboard alert — same write path as check-all-listeners.ps1 (#4131 étape 3,
# arbitrage ai-01 14/10 option a): RSM CLI first (dual-write journal PG + file,
# append lock, format at the store), direct file write as fallback. The helper
# duplication with that script is known and documented there; convergence will
# happen when the shared writer is extracted, not by diverging here.
# ---------------------------------------------------------------------------
$script:RsmScriptsDirCache = $null

function Get-RsmScriptsDir {
    if ($null -ne $script:RsmScriptsDirCache) { return $script:RsmScriptsDirCache }
    $candidates = @()
    if (-not [string]::IsNullOrEmpty($env:RSM_SERVER_ROOT)) { $candidates += $env:RSM_SERVER_ROOT }
    $candidates += [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\..\mcps\internal\servers\roo-state-manager"))
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "scripts\rsm-dashboard-append.mjs")) {
            $script:RsmScriptsDirCache = Join-Path $c "scripts"
            return $script:RsmScriptsDirCache
        }
    }
    Write-Host "[FLEET-ALERT] RSM CLI dir not found (PG-first append disabled, file fallback only)."
    $script:RsmScriptsDirCache = ""
    return ""
}

function Invoke-RsmCliJson($scriptName, $cliArgs) {
    $dir = Get-RsmScriptsDir
    if ($dir -eq "") { return $null }
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $node) { return $null }
    $out = & $node.Source (Join-Path $dir $scriptName) @cliArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FLEET-ALERT] RSM CLI $scriptName exit $LASTEXITCODE (repli fichier)."
        return $null
    }
    try { return (($out -join "`n") | ConvertFrom-Json) } catch { return $null }
}

function Write-MachineDashboardAlert {
    param([Parameter(Mandatory)][string]$Content)
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($sharedPath)) {
        Write-Output "[FLEET-ALERT] ROOSYNC_SHARED_PATH not set — alert on stdout only (no dashboard write)."
        return
    }
    $localMachineId = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }

    $cli = Invoke-RsmCliJson "rsm-dashboard-append.mjs" @('--machine', $localMachineId, '--content', $Content)
    if ($null -ne $cli -and $cli.ok -eq $true) {
        Write-Output "[FLEET-ALERT] Posted to machine dashboard via RSM CLI (key $($cli.key), messageId $($cli.messageId), pgSynced=$($cli.pgSynced))"
        return
    }

    # File fallback — same conventions as Write-MachineDashboardMessage (#4124):
    # CRLF, [msg:] marker, plural "(N messages)" from the seed on.
    try {
        $dashDir = Join-Path $sharedPath 'dashboards'
        $machineFile = Join-Path $dashDir "machine-$localMachineId.md"
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        $rand = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
        $msgId = "$localMachineId" + ':classifier:ic-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss') + '-' + $rand
        $newMessage = "`r`n### [$timestamp] $localMachineId|classifier`r`n[msg: $msgId]`r`n`r`n$Content`r`n"

        if (-not (Test-Path $dashDir)) { New-Item -ItemType Directory -Path $dashDir -Force | Out-Null }

        if (Test-Path $machineFile) {
            $content = Get-Content $machineFile -Raw -Encoding UTF8
            $content = $content.TrimEnd() + "`r`n" + $newMessage
            $content = [regex]::Replace($content, '(?<=## Intercom\s*\()\d+(?=\s*messages?\))', { param($m); ([int]$m.Value + 1).ToString() })
            $content = [regex]::Replace($content, '(## Intercom \(\d+) message\)', '$1 messages)')
        } else {
            $content = "---`r`ntype: machine`r`nlastModified: '$timestamp'`r`nlastModifiedBy:`r`n  machineId: $localMachineId`r`n  workspace: classifier`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 messages)`r`n$newMessage"
        }
        [System.IO.File]::WriteAllText($machineFile, $content, [System.Text.UTF8Encoding]::new($false))
        Write-Output "[FLEET-ALERT] Posted to $machineFile (file fallback)"
    } catch {
        Write-Output "[FLEET-ALERT] Dashboard write failed (best-effort): $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# Inputs: live probes, or a recorded timeline (replay)
# ---------------------------------------------------------------------------
function New-LiveSample {
    param([string]$Machine)
    $drivingPort = if ($DrivingPortByMachine.ContainsKey($Machine)) { $DrivingPortByMachine[$Machine] } else { $DefaultDrivingPort }

    $open = @()
    foreach ($p in $ProbedPorts) {
        if (Test-TcpPort -ComputerName $Machine -Port $p -TimeoutMs $ProbeTimeoutMs) { $open += $p }
    }

    $channel = Measure-DrivingChannel -ComputerName $Machine -Port $drivingPort -TimeoutMs $ProbeTimeoutMs
    [PSCustomObject]@{
        machine                 = $Machine
        openPorts               = $open
        drivingChannelAnswered  = [bool]$channel.answered
        drivingLatencyMs        = $channel.latencyMs
        heartbeatAgeSeconds     = (Get-HeartbeatAgeSeconds -Machine $Machine)
        drivingPort             = $drivingPort
    }
}

function Read-ReplaySamples {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Replay file not found: $Path" }
    $raw = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $raw.samples) {
        return [PSCustomObject]@{ samples = @($raw.samples); logonDeathUtc = $raw.logonDeathUtc }
    }
    return [PSCustomObject]@{ samples = @($raw); logonDeathUtc = $null }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$results = @()
$detectedAfterMinutes = $null
$logonDeath = $null

if (-not [string]::IsNullOrEmpty($ReplayFile)) {
    try {
        $replay = Read-ReplaySamples -Path $ReplayFile
    } catch {
        Write-Error $_.Exception.Message
        exit 3
    }
    if ($null -ne $replay.logonDeathUtc) { $logonDeath = [DateTimeOffset]::Parse($replay.logonDeathUtc).UtcDateTime }

    foreach ($s in $replay.samples) {
        $drivingPort = if ($null -ne $s.drivingPort) { [int]$s.drivingPort } elseif ($DrivingPortByMachine.ContainsKey($s.machine)) { $DrivingPortByMachine[$s.machine] } else { $DefaultDrivingPort }
        $r = Get-UsabilityVerdict -Machine $s.machine -OpenPorts @($s.openPorts) `
            -DrivingChannelAnswered ([bool]$s.drivingChannelAnswered) -DrivingLatencyMs $s.drivingLatencyMs `
            -HeartbeatAgeSeconds $s.heartbeatAgeSeconds -DrivingPort $drivingPort `
            -SlowThresholdMs $WinrmSlowMs -HeartbeatStaleSeconds $HeartbeatStaleSeconds
        # The FULL verdict object is what the table and the alert read: an
        # atUtc-only summary would leave New-AlertContent with no inputs to name.
        $r | Add-Member -NotePropertyName atUtc -NotePropertyValue $s.atUtc -Force
        $results += $r

        if ($null -ne $logonDeath -and $null -eq $detectedAfterMinutes -and $r.verdict -eq 'reachable-but-unusable' -and -not [string]::IsNullOrEmpty($s.atUtc)) {
            $at = [DateTimeOffset]::Parse($s.atUtc).UtcDateTime
            $detectedAfterMinutes = [math]::Round(($at - $logonDeath).TotalMinutes, 1)
        }
    }
} else {
    $roster = if ($Machines.Count -gt 0) { $Machines } elseif (-not [string]::IsNullOrEmpty($env:ROO_FLEET_ROSTER)) { $env:ROO_FLEET_ROSTER -split ',' } else { $DefaultRoster }
    $roster = @($roster | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })

    foreach ($m in $roster) {
        $sample = New-LiveSample -Machine $m
        $r = Get-UsabilityVerdict -Machine $sample.machine -OpenPorts $sample.openPorts `
            -DrivingChannelAnswered $sample.drivingChannelAnswered -DrivingLatencyMs $sample.drivingLatencyMs `
            -HeartbeatAgeSeconds $sample.heartbeatAgeSeconds -DrivingPort $sample.drivingPort `
            -SlowThresholdMs $WinrmSlowMs -HeartbeatStaleSeconds $HeartbeatStaleSeconds
        $results += $r
    }
}

$unusable = @($results | Where-Object { $_.verdict -eq 'reachable-but-unusable' })
$unreachable = @($results | Where-Object { $_.verdict -eq 'unreachable' })

# ---------- Alerts (criterion 5) ----------
# Built BEFORE the output block so -Json can carry them INSIDE the payload: a
# consumer running `-Json | ConvertFrom-Json` must not choke on a markdown block
# appended after the JSON (measured: JsonReaderException "Additional text
# encountered after finished reading JSON content").
$alerts = @()
foreach ($r in $unusable) {
    $alerts += [PSCustomObject]@{ machine = $r.machine; content = (New-AlertContent -Result $r -Detector $env:COMPUTERNAME) }
}

# ---------- Output ----------
if ($Json) {
    [PSCustomObject]@{
        checkedAtUtc          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        detector              = $env:COMPUTERNAME
        replayFile            = $ReplayFile
        thresholds            = [PSCustomObject]@{ slowChannelMs = $WinrmSlowMs; heartbeatStaleSeconds = $HeartbeatStaleSeconds; probeTimeoutMs = $ProbeTimeoutMs }
        detectedAfterMinutes  = $detectedAfterMinutes
        machines              = $results
        alerts                = $alerts
    } | ConvertTo-Json -Depth 5
} else {
    Write-Output "### Machine usability — $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) UTC (detector $env:COMPUTERNAME)"
    Write-Output ""
    Write-Output "| Machine | Verdict | Ports | Driving channel | Heartbeat | Findings |"
    Write-Output "|---------|---------|-------|-----------------|-----------|----------|"
    foreach ($r in $results) {
        $ports = if ($r.openPorts.Count -gt 0) { $r.openPorts -join ',' } else { 'none' }
        $lat = if ($null -ne $r.drivingLatencyMs) { "$($r.drivingLatencyMs)ms" } elseif ($null -ne $r.drivingPort) { 'silent' } else { 'n/a' }
        $hb = if ($null -ne $r.heartbeatAgeSeconds) { "$($r.heartbeatAgeSeconds)s" } else { 'n/a' }
        $findings = if ($r.findings.Count -gt 0) { $r.findings -join ', ' } else { '-' }
        Write-Output "| $($r.machine) | $(if ($r.verdict -eq 'reachable-but-unusable') { '**' + $r.verdict + '**' } else { $r.verdict }) | $ports | $lat | $hb | $findings |"
    }
    Write-Output ""
    if ($null -ne $detectedAfterMinutes) {
        Write-Output "Detected **$detectedAfterMinutes min** after the recorded logon death (criterion 2)."
        Write-Output ""
    }
    Write-Output "Totals: $($results.Count) samples, $($unusable.Count) reachable-but-unusable, $($unreachable.Count) unreachable."
}

# ---------- Alert emission ----------
# The dashboard write is independent of the output mode (it is the point of the
# script); only the STDOUT echo is skipped under -Json, where the alerts already
# travel in the payload and extra text would break the parser.
foreach ($a in $alerts) {
    if (-not $Json) {
        Write-Output ""
        Write-Output $a.content
    }
    if (-not $NoAlert -and [string]::IsNullOrEmpty($ReplayFile)) {
        Write-MachineDashboardAlert -Content $a.content
    }
}

if ($unusable.Count -gt 0) { exit 2 }
if ($unreachable.Count -gt 0) { exit 1 }
exit 0
