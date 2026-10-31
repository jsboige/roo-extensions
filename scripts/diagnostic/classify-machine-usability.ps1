<#
.SYNOPSIS
    Per-machine usability classifier: healthy / unreachable / reachable-but-unusable (#4327).

.DESCRIPTION
    Answers one question per roster machine, from the coordinator host (ai-01), with
    READ-ONLY probes: "is this machine reachable AND able to run work?" A machine can
    answer on the network and still be dead for work. po-2028 wedged twice on 23/10:
    the logon died 3.5 to 4.5 min after a clean boot, no load, no kernel crash, WinRM
    kept answering (~10 s), and six restart requests were accepted by wininit but
    never executed. Only a physical power cycle recovered it.

    The third verdict is the point of this script. Neither of the two existing organs
    says it: check-all-listeners.ps1 reports "listener STALE/DEAD" after 2 h (a dead
    listener on a healthy machine prints the same line), and detect-approval-stalls.py
    only sees sessions that are alive and frozen, never sessions that never start.

    THE ALERT IS NOT THE LEVER. This script posts a [FLEET-ALERT] on the AFFECTED
    machine's dashboard and cross-posts it to workspace: Maintenance (single meeting
    point, 06/09 rule); firing the hard reboot lever stays with the Maintenance lane
    (fleet_remote_reboot.ps1 -Hard), on its own line.

    VERDICT RULE (ai-01:Maintenance spec, #4327 comment of 24/10 12:05Z). First match
    wins, and every input is measured, never inferred from a single signal:
      1. unreachable            -> no interactive port answers (5985 and 3389 both
                                   closed on Windows seats; 22 closed on the Linux ones)
      2. reachable-but-unusable -> reachable AND either
                                   (a) a logon-death burst since the last boot, which
                                       is sufficient ON ITS OWN, or
                                   (b) abnormal authenticated WinRM latency AND the
                                       machine SILENT on BOTH liveness halves: listener
                                       heartbeat older than the threshold AND no
                                       dashboard append from any lane of the machine
      3. healthy                -> everything else, findings naming whatever is off

    THE DECISIVE INPUT IS THE TARGET'S OWN SYSTEM LOG, not WinRM latency. Within one
    second, >= 5 events 7031/7034 for per-user service instances (service names ending
    in _<5 hex chars>, the logon session LUID) inside [boot+2 min, boot+20 min] means
    the user session died: measured 3/3 on the wedges (T+3m28s, T+4m31s, T+3m38s, x6
    each) and 0 on 3 negative-control boots.

    WHAT EACH PROBE IS ALLOWED TO SAY:
      - WS-Identify / Test-WSMan is REACHABILITY ONLY and is never a wedge input. A
        healthy Windows WinRM endpoint answers HTTP 401 to an unauthenticated
        WS-Identify (measured from ai-01: localhost 401 in 2 ms, po-2023 401 in 79 ms),
        so any HTTP response is an answer; only a timeout or a connection error is
        silence.
      - Latency is measured on an AUTHENTICATED `Invoke-Command { 1 }` round trip,
        abnormal when > 3 s on 2 of 3 consecutive probes (healthy baseline measured
        24/10: 249-445 ms; wedged value ~10 s).
      - The listener heartbeat only CORROBORATES; it never decides alone, and the
        spec gives it a second half: "> 30 min with no RSM heartbeat AND no dashboard
        append from any lane". Both halves must be silent before the corroborator may
        fire - one fresh signal (a heartbeat, or a message posted by any lane of the
        machine on any shared dashboard) clears it. A machine with no heartbeat file
        gets `heartbeat-unknown`, not a death sentence: absence of the FILE is a
        measurement of the input and is measured today on a working machine (see
        Get-UsabilityVerdict). A missing INSTRUMENT (ROOSYNC_SHARED_PATH unset) is a
        different thing and is loud: exit 3, because a classifier that cannot read
        liveness must not print "all clear". An append age that could not be measured
        never corroborates either - the finding says so.
      - LogonUI >= 1 is deliberately NOT a criterion: it is the normal console lock
        screen, and that coarse test misled the Maintenance lane on the night of 23/10.
      - The count of 4624 logons from an external address in the window is REPORTED
        as a finding: an RDP client retrying in a loop can recreate the symptom.

    Inputs per machine (acceptance criterion 5 - the alert names each value):
      - openPorts: TCP connect to 5985 (WinRM), 22 (SSH), 3389 (RDP), 445 (SMB).
      - driving channel: 5985 for the myia-* seats, 22 for the Linux web seats.
      - last boot (System log event 12), the logon-death burst, external 4624 count:
        read over the same authenticated WinRM channel, in [boot, boot+20 min].
      - listener heartbeat age, read from <shared>/listener-heartbeats/<machine>.heartbeat.
      - dashboard append age: the newest message header posted by ANY lane of the
        machine on any shared dashboard (synthetic authors excluded - the condenser
        `system`, the wake-`listener` and this `classifier` itself; see
        Get-DashboardAppendAges). Second half of the liveness bar.

.PARAMETER Machines
    Machines to classify. Defaults to $env:ROO_FLEET_ROSTER, else the 9-machine roster
    of #4258. Comma-separated values are split, because `-Machines a,b` under
    `powershell -File` arrives as ONE string (measured: a bogus machine name and a
    false `unreachable`, exit 1).

.PARAMETER ReplayFile
    JSON timeline instead of live probes. Two shapes:
      - {machine, events:[{utc,id,message}], samples:[{atUtc,machine,openPorts,
         drivingChannelAnswered,drivingLatencySamplesMs,heartbeatAgeSeconds,
         dashboardAppendAgeSeconds?}],
         lastBootUtc?, logonDeathUtc?}
      A sample without `dashboardAppendAgeSeconds` leaves that half of the liveness
      bar unmeasured: the verdict is computed, the finding says `dashboard-append-unknown`,
      and the corroborator cannot fire on the heartbeat alone.
      - a bare array of samples (legacy), or {logonDeathUtc, samples:[...]}
    `events` feeds the SAME burst detector the live path uses, so the replay of the
    po-2028 timeline of 23/10 exercises the real decision code on the real rows.
    With a burst (or logonDeathUtc) present the output reports detectedAfterMinutes.

.PARAMETER WinrmSlowMs
    Authenticated round-trip latency above which one probe counts as abnormal
    (default 3000; the spec sets 3 s = >= 7x the healthy maximum).

.PARAMETER LatencyAbnormalMinCount
    How many of the consecutive latency probes must exceed the threshold before the
    channel counts as abnormal (default 2 of 3).

.PARAMETER HeartbeatStaleSeconds
    Liveness bar (default 1800 = the spec's 30 min). Applies to BOTH halves: the
    listener heartbeat age AND the dashboard-append age. The corroborator fires only
    when both are over the bar; a fresh sample of either one clears it.

.PARAMETER VerdictDeadlineMinutes
    AC2 target: the burst must be turned into a verdict within 10 min of the logon
    death. The replay reports the measured delay and this target side by side.

.PARAMETER Credential
    Credentials for the authenticated WinRM read. Without it the probes run as the
    detector's identity; a failed authentication yields the `latency-unmeasurable` /
    `system-log-unavailable` findings, never a silent green.

.PARAMETER CredentialFile
    Path of a DPAPI-encrypted PSCredential (Export-Clixml) for the authenticated
    WinRM reads - the scheduled 5-minute fire (RX122) carries a FILE, because a
    scheduled task cannot carry a live credential object. Loaded only when
    -Credential is NOT passed. A missing, unreadable, or non-PSCredential file is
    a LOUD exit 3 BEFORE any probe: a classifier told to run with a credential it
    cannot load must never silently fall back to the unauthenticated path - that
    is exactly how the no-credential run of 28/10 measured
    `system-log-unavailable` on every reachable seat and spent 81 s proving
    nothing.

.PARAMETER NoAlert
    Classify and print only, post nothing.

.PARAMETER Json
    Machine-readable output.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -Json -NoAlert

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\classify-machine-usability.ps1 -ReplayFile scripts\diagnostic\fixtures\po2028-20261023.json

.NOTES
    Exit codes: 0 all healthy - 1 an unreachable machine - 2 at least one
    reachable-but-unusable (the hard-lever signal) - 3 usage/replay error or missing
    instrument (ROOSYNC_SHARED_PATH unset in live mode): the measurement is
    incomplete, which is never reported as "all clear". Precedence 2 > 3 > 1 > 0.

    Liveness bar (spec section 2) - BOTH halves are implemented: the listener
    heartbeat AND the last dashboard append from any lane of the machine (shared
    dashboards, newest non-synthetic message header per machine). They only ever
    corroborate; the decisive input stays the target's System log. A machine with no
    heartbeat file is `heartbeat-unknown` with verdict `healthy` and exit 0, and that
    is deliberate rather than an oversight - the rationale and its measured
    counter-example are on Get-UsabilityVerdict. An append age that could not be
    measured yields `dashboard-append-unknown` and never corroborates.

    SCHEDULED FIRE (RX122): the 5-minute task (install-usability-classifier-task.ps1)
    runs this script with -CredentialFile. ONE ALERT PER INCIDENT: every post carries
    the stable incident id `classifier-4327-<machine>-unusable-<boot yyyyMMddTHHmm>`
    (UTC date when the boot is unknown) plus the MEASURED burst's minute when a
    burst exists - identical across fires on the same incident, new when the
    target reboots (or a second wedge bursts on the same boot). The dedup is a
    LOCAL state file on this seat (outputs/diagnostic/state/classifier-
    incidents.json, gitignored; pattern embeddings-alert.ps1 #4394), NOT the
    dashboard file, which condenses and would scroll the id out: the primary
    machine-dashboard post (whose id the escalation surface GENERATES by
    contract) is skipped while the incident is recorded, the state is written
    only after the post is accepted, absent/corrupt state posts (never
    silent), and a healthy verdict drops the entry so a later wedge posts
    again. The cross-post runs on every fire and is deduped by the RSM CLI on
    the id + `-maint`.

    Related: #4327, #2576 (listener check), #4243 (approval stalls), #4258 (roster).
#>

param(
    [string[]]$Machines = @(),
    [string]$ReplayFile = "",
    [int]$WinrmSlowMs = 3000,
    [int]$LatencyProbes = 3,
    [int]$LatencyAbnormalMinCount = 2,
    [int]$HeartbeatStaleSeconds = 1800,
    [int]$VerdictDeadlineMinutes = 10,
    [int]$ProbeTimeoutMs = 3000,
    [int]$BurstMinEvents = 5,
    [int]$BurstWindowStartMinutes = 2,
    [int]$BurstWindowEndMinutes = 20,
    [System.Management.Automation.PSCredential]$Credential = $null,
    [string]$CredentialFile = "",
    [switch]$NoAlert,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

# #4258 roster - kept in sync with ROO_FLEET_ROSTER; the env wins when set.
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
# Clock helpers - shared by the decision path and the replay reader.
# ---------------------------------------------------------------------------
function ConvertTo-UtcDateTime {
    # ConvertFrom-Json renders an ISO-8601 string as a [DateTime] under pwsh 7 and
    # leaves it a [string] under 5.1 - so the SAME replay file yields two types, and
    # an unconditional [DateTimeOffset]::Parse() throws on one engine (measured:
    # MethodInvocationException at the logonDeath line under pwsh 7, the delay
    # silently lost while the rest of the verdict looked right). Accept all three
    # shapes instead of assuming the seat's engine.
    #
    # A string WITHOUT an offset is rejected rather than read in the seat's timezone:
    # `2026-10-23T11:52:00` parsed locally shifts detectedAfterMinutes by the offset
    # and says nothing. `[DateTime]` with Kind=Unspecified is the same ambiguity.
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
    if ($Value -is [datetime]) {
        if ($Value.Kind -eq [System.DateTimeKind]::Unspecified) {
            throw "Timestamp '$Value' has no timezone marker; replay data must be UTC (suffix Z or an explicit offset)."
        }
        return $Value.ToUniversalTime()
    }
    $text = ([string]$Value).Trim()
    if ($text -notmatch '(Z|[+-]\d{2}:?\d{2})$') {
        throw "Timestamp '$text' has no UTC offset; replay data must be UTC (suffix Z or an explicit offset)."
    }
    return [DateTimeOffset]::Parse($text, [System.Globalization.CultureInfo]::InvariantCulture).UtcDateTime
}

# ---------------------------------------------------------------------------
# Decision - pure function over measured inputs (no probing, no clock, no I/O):
# this is what the replay mode exercises, and what the tests pin.
# ---------------------------------------------------------------------------
function Get-UsabilityVerdict {
    param(
        [string]$Machine,
        [string[]]$OpenPorts = @(),
        [bool]$DrivingChannelAnswered = $false,
        $DrivingLatencyMs = $null,
        $DrivingStatusCode = $null,
        [int[]]$LatencySamplesMs = @(),
        $HeartbeatAgeSeconds = $null,
        [bool]$HeartbeatInstrumentPresent = $true,
        $DashboardAppendAgeSeconds = $null,
        $LastBootUtc = $null,
        $Burst = $null,
        [bool]$SystemLogAvailable = $true,
        [bool]$SystemLogApplicable = $true,
        $ExternalLogonCount = $null,
        [int]$DrivingPort = 5985,
        [int]$SlowThresholdMs = 3000,
        [int]$HeartbeatStaleSeconds = 1800,
        [int[]]$ProbedPorts = @(5985, 22, 3389, 445),
        [int[]]$SampledPorts = @(),
        [int]$LatencyAbnormalMinCount = 2,
        [int]$BurstMinEvents = 5
    )

    $findings = @()

    # Rule 1 - unreachable: nothing interactive answers. The spec names TCP 5985 AND
    # 3389 for the Windows seats (ARP double-check stays with the operator: this
    # script does not shell out to ping, which the spec forbids as sole evidence).
    # The Linux seats have neither port, so their unreachability is the closed SSH.
    $reachable = if ($DrivingPort -eq 22) {
        ($OpenPorts -contains 22)
    } else {
        ($OpenPorts -contains 5985) -or ($OpenPorts -contains 3389)
    }
    if (-not $reachable) {
        return [PSCustomObject]@{
            machine             = $Machine
            verdict             = 'unreachable'
            findings            = @('no-port-answers')
            openPorts           = @($OpenPorts)
            drivingPort         = $DrivingPort
            drivingAnswered     = $DrivingChannelAnswered
            drivingStatusCode   = $DrivingStatusCode
            drivingLatencyMs    = $DrivingLatencyMs
            latencySamplesMs    = @($LatencySamplesMs)
            latencyAbnormal     = $false
            heartbeatAgeSeconds = $HeartbeatAgeSeconds
            dashboardAppendAgeSeconds = $DashboardAppendAgeSeconds
            lastBootUtc         = $LastBootUtc
            burst               = $Burst
            externalLogonCount  = $ExternalLogonCount
            systemLogAvailable  = $SystemLogAvailable
        }
    }

    # Reachability findings. `driving-channel-silent` is a finding, NOT a wedge input:
    # the spec reserves reachability for WS-Identify and says it must never feed a
    # wedge verdict, so a silent WS-Identify on a machine whose ports answer stays a
    # finding and is reported as such.
    if (-not $DrivingChannelAnswered) { $findings += 'driving-channel-silent' }

    # Latency - the authenticated round trip, and the only latency that counts.
    $abnormalCount = @($LatencySamplesMs | Where-Object { $null -ne $_ -and [int]$_ -gt $SlowThresholdMs }).Count
    $latencyAbnormal = $false
    if (@($LatencySamplesMs).Count -eq 0) {
        $findings += 'latency-unmeasurable'
    } elseif (@($LatencySamplesMs).Count -lt $LatencyAbnormalMinCount) {
        # "> 3 s on 2 of 3" needs at least two samples to be sayable.
        $findings += 'latency-samples-insufficient'
    } elseif ($abnormalCount -ge $LatencyAbnormalMinCount) {
        $latencyAbnormal = $true
        $findings += 'driving-channel-slow'
    }

    # Session liveness - corroborating only, never decisive. The spec's bar has TWO
    # halves (ai-01:Maintenance, 2026-10-24, section 2): "> 30 min with no RSM
    # heartbeat AND no dashboard append from any lane of the machine". Both must be
    # silent before the corroborator may fire, and one fresh sample of either clears
    # it: a lane that posted a message recently proved the machine can run work,
    # whatever the listener heartbeat says.
    $heartbeatStale = $false
    if (-not $HeartbeatInstrumentPresent) {
        $findings += 'no-instrument'
    } elseif ($null -eq $HeartbeatAgeSeconds) {
        # DELIBERATE, and measured - this answers the coordinator's residual review on
        # #4329 (24/10): a MISSING file is a measurement of the input (the detector
        # looked and there is nothing), not a failure to read it, which is what earns
        # exit 3 in `no-instrument` and `system-log-unavailable`. Measured
        # counter-example, ai-01 25/10: myia-po-2028 carries NO heartbeat file at all
        # while posting [DONE] c.24 at 16:32Z and opening PR #4359 - folding this into
        # the exit-3 guard would flag a demonstrably working machine on every sweep and
        # make exit 3 meaningless. The dashboard-append half below still measures
        # liveness for exactly such a machine.
        $findings += 'heartbeat-unknown'
    } elseif ([int]$HeartbeatAgeSeconds -gt $HeartbeatStaleSeconds) {
        $heartbeatStale = $true
        $findings += 'listener-stale'
    }

    # Second half of the bar. An UNMEASURED append age (no shared dashboards, no header
    # from any lane of this machine) is named and never corroborates: the corroborator
    # fires on evidence of silence, not on the absence of an instrument.
    $appendSilent = $false
    if ($HeartbeatInstrumentPresent) {
        if ($null -eq $DashboardAppendAgeSeconds) {
            $findings += 'dashboard-append-unknown'
        } elseif ([int]$DashboardAppendAgeSeconds -gt $HeartbeatStaleSeconds) {
            $appendSilent = $true
            $findings += 'no-recent-dashboard-append'
        }
    }
    $sessionsDead = $heartbeatStale -and $appendSilent

    # Logon-death burst - decisive on its own when it was seen.
    $burstDecisive = $false
    if ($null -ne $Burst -and [int]$Burst.count -ge $BurstMinEvents) {
        $burstDecisive = $true
        $findings += 'logon-death-burst'
    }
    # An unread System log on a WINDOWS seat means the decisive input is missing - a
    # wedge could be sitting there unseen. It is a finding AND it forces exit 3 (see
    # the exit block): measured on this very seat, where Invoke-Command to itself
    # fails and the first version still printed `healthy`, exit 0. The Linux seats
    # have no WinRM and no burst concept, so there it is simply not applicable.
    if (-not $SystemLogAvailable -and $SystemLogApplicable) { $findings += 'system-log-unavailable' }
    if ($null -ne $ExternalLogonCount -and [int]$ExternalLogonCount -gt 0) {
        $findings += 'external-4624-logons'
    }

    # Partial sample: the ports actually PROBED, not the ports that answered. The old
    # script-scope comparison (`openPorts.Count -lt $ProbedPorts.Count`) counted closed
    # ports as a partial sample, so it fired on every Linux seat and every replay
    # (permanent noise, ai-01 review item 2). A full probe passes its roster here and
    # stays quiet; only a replay that measured fewer ports raises the finding.
    if (@($SampledPorts).Count -gt 0 -and @($SampledPorts).Count -lt @($ProbedPorts).Count) { $findings += 'ports-partial' }

    $verdict = if ($burstDecisive -or ($latencyAbnormal -and $sessionsDead)) {
        'reachable-but-unusable'
    } else {
        'healthy'
    }

    [PSCustomObject]@{
        machine             = $Machine
        verdict             = $verdict
        findings            = $findings
        openPorts           = @($OpenPorts)
        drivingPort         = $DrivingPort
        drivingAnswered     = $DrivingChannelAnswered
        drivingStatusCode   = $DrivingStatusCode
        drivingLatencyMs    = $DrivingLatencyMs
        latencySamplesMs    = @($LatencySamplesMs)
        latencyAbnormal     = $latencyAbnormal
        heartbeatAgeSeconds = $HeartbeatAgeSeconds
        dashboardAppendAgeSeconds = $DashboardAppendAgeSeconds
        lastBootUtc         = $LastBootUtc
        burst               = $Burst
        externalLogonCount  = $ExternalLogonCount
        systemLogAvailable  = $SystemLogAvailable
    }
}

# ---------------------------------------------------------------------------
# Logon-death burst - pure over the System log rows (shared by the live path and
# the replay of the Maintenance lane's extract).
# ---------------------------------------------------------------------------
$LogonDeathServiceSuffix = '_[0-9a-fA-F]{5}(?![0-9a-fA-F])'

function Find-LogonDeathBurst {
    param(
        $Events,
        $LastBootUtc,
        [int]$MinEvents = 5,
        [int]$WindowStartMinutes = 2,
        [int]$WindowEndMinutes = 20
    )
    if ($null -eq $Events -or $null -eq $LastBootUtc) { return $null }

    $candidates = @()
    foreach ($e in @($Events)) {
        $id = if ($null -ne $e.id) { [int]$e.id } else { 0 }
        if ($id -ne 7031 -and $id -ne 7034) { continue }
        $message = [string]$e.message
        # The service name carries the logon session LUID as its _<5 hex> suffix;
        # that suffix is what makes the row evidence of a SESSION death rather than
        # of some unrelated service crash.
        if ($message -notmatch $LogonDeathServiceSuffix) { continue }
        $suffix = $Matches[0]
        $utc = $null
        try { $utc = ConvertTo-UtcDateTime $e.utc } catch { continue }
        if ($null -eq $utc) { continue }
        # `count` carries collapsed multiplicity: the Maintenance lane's archived
        # extract has ONE row per second ("duplicate burst lines per second
        # collapsed") while the live log emits six. Summing it is what makes the
        # archived row and the live burst the same measurement; a row without the
        # field counts once.
        $weight = if ($null -ne $e.count) { [int]$e.count } else { 1 }
        $candidates += [PSCustomObject]@{ utc = $utc; second = $utc.ToString('yyyy-MM-ddTHH:mm:ss'); suffix = $suffix; weight = $weight }
    }

    $best = $null
    foreach ($group in ($candidates | Group-Object second)) {
        $size = ($group.Group | Measure-Object -Property weight -Sum).Sum
        if ($size -lt $MinEvents) { continue }
        $at = $group.Group[0].utc
        $delay = ($at - $LastBootUtc).TotalMinutes
        if ($delay -lt $WindowStartMinutes -or $delay -gt $WindowEndMinutes) { continue }
        if ($null -eq $best -or $size -gt $best.count) {
            $best = [PSCustomObject]@{
                utc              = $at
                utcText          = $at.ToString('yyyy-MM-ddTHH:mm:ssZ')
                count            = [int]$size
                suffix           = $group.Group[0].suffix
                minutesAfterBoot = [math]::Round($delay, 1)
            }
        }
    }
    return $best
}

function Measure-ExternalLogonCount {
    # Counts 4624 rows whose message names an address outside the LAN. Heuristic by
    # necessity (the address lives in a localized insertion string), so it is
    # REPORTED as a finding and never decides anything: an RDP retry loop can
    # recreate the wedge symptom, and Maintenance must see that before firing.
    param($Events)
    if ($null -eq $Events) { return $null }
    $count = 0
    foreach ($e in @($Events)) {
        $id = if ($null -ne $e.id) { [int]$e.id } else { 0 }
        if ($id -ne 4624) { continue }
        foreach ($m in [regex]::Matches([string]$e.message, '\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\b')) {
            $ip = $m.Value
            if ($ip -like '10.*' -or $ip -like '127.*' -or $ip -like '192.168.*' -or $ip -eq '0.0.0.0') { continue }
            if ($ip -match '^172\.(1[6-9]|2[0-9]|3[01])\.') { continue }
            $count++
            break
        }
    }
    return $count
}

# ---------------------------------------------------------------------------
# Alert content (criterion 5): names every input and its value, and names the
# affected machine on the FIRST line (a reader must not have to hunt for it).
# ---------------------------------------------------------------------------

function Get-ClassifierIncidentId {
    # The ONE-ALERT-PER-INCIDENT key (RX122): machine + verdict + the target's
    # LAST BOOT, and - when a burst was MEASURED - the burst's own minute. Two
    # fires inside the same wedge read the same boot AND the same burst and
    # derive the SAME id, so a 5-minute cadence posts once per incident, not
    # once per fire. The burst stamp is what separates a SECOND wedge on the
    # same boot: boot+verdict alone would swallow it (same boot, later burst,
    # same id). No burst (the latency+silence path) -> boot+verdict fallback.
    # Boot unknown -> UTC date, so the id stays stable across the day even
    # without the System log. The charset stays inside the RSM CLI's message-id
    # grammar ([A-Za-z0-9._:-], <= 128).
    param([string]$Machine, $LastBootUtc = $null, $Burst = $null, [string]$Verdict = 'unusable', $Now = $null)
    $m = $Machine.ToLowerInvariant()
    if ($null -ne $LastBootUtc) {
        $stamp = $LastBootUtc.ToUniversalTime().ToString('yyyyMMddTHHmm')
    } else {
        if ($null -eq $Now) { $Now = (Get-Date).ToUniversalTime() }
        $stamp = $Now.ToString('yyyyMMdd')
    }
    $id = "classifier-4327-$m-$Verdict-$stamp"
    if ($null -ne $Burst -and $null -ne $Burst.utc) {
        $id = "$id-" + $Burst.utc.ToUniversalTime().ToString('yyyyMMddTHHmm')
    }
    return $id
}

function New-AlertContent {
    param(
        [Parameter(Mandatory)] $Result,
        [string]$Detector = $env:COMPUTERNAME,
        [int]$SlowThresholdMs = 3000,
        [int]$HeartbeatStaleSeconds = 1800,
        [int]$AbnormalMinCount = 2,
        [int]$DeadlineMinutes = 10,
        [string]$IncidentId = ""
    )

    $hb = if (-not $Result.heartbeatInstrumentPresent -and $null -eq $Result.heartbeatAgeSeconds) {
        'no instrument (ROOSYNC_SHARED_PATH unset)'
    } elseif ($null -ne $Result.heartbeatAgeSeconds) {
        "$($Result.heartbeatAgeSeconds) s"
    } else { 'no heartbeat file' }

    $ports = if (@($Result.openPorts).Count -gt 0) { ($Result.openPorts -join ', ') } else { 'none' }
    $boot = if ($null -ne $Result.lastBootUtc) { $Result.lastBootUtc.ToString('yyyy-MM-ddTHH:mm:ssZ') } else { 'unknown' }
    $append = if ($null -ne $Result.dashboardAppendAgeSeconds) {
        "$($Result.dashboardAppendAgeSeconds) s"
    } else { 'unknown (not measured this sweep)' }

    if ($null -ne $Result.burst) {
        $burstText = "$($Result.burst.utcText) x$($Result.burst.count) suffix $($Result.burst.suffix) (T+$($Result.burst.minutesAfterBoot) min after boot)"
    } else { 'none in [boot+2 min, boot+20 min]' }

    $lat = if (@($Result.latencySamplesMs).Count -gt 0) { ($Result.latencySamplesMs -join ', ') + ' ms' } else { 'unmeasurable (authentication failed or channel down)' }
    $wsman = if ($Result.drivingAnswered) {
        "answered=$($Result.drivingAnswered), status $($Result.drivingStatusCode), $($Result.drivingLatencyMs) ms"
    } else { 'no answer (timeout or connection error)' }
    $ext = if ($null -ne $Result.externalLogonCount) { "$($Result.externalLogonCount)" } else { 'unmeasured' }

    $lines = @(
        "[FLEET-ALERT] [CRITICAL] $($Result.machine) - reachable-but-unusable (#4327)",
        "",
        "Affected machine: **$($Result.machine)**. Measured by $Detector at $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')).",
        "",
        "- verdict: $($Result.verdict) (target: within $DeadlineMinutes min of the logon death, AC2)",
        "- incident id: $IncidentId (one alert per incident; a new boot is a new incident)",
        "- last boot (System log, event 12): $boot",
        "- logon-death burst (7031/7034, suffix _<5 hex>, same second, >= 5): $burstText",
        "- authenticated WinRM latency (Invoke-Command {1}), $($AbnormalMinCount) of $(@($Result.latencySamplesMs).Count) over the threshold: $lat (threshold $SlowThresholdMs ms)",
        "- WS-Identify reachability (never a wedge input): $wsman",
        "- listener heartbeat: $hb (corroborating threshold $HeartbeatStaleSeconds s; never decisive alone)",
        "- dashboard append from any lane of the machine: $append (same threshold $HeartbeatStaleSeconds s; both liveness halves must be silent before they corroborate)",
        "- external 4624 logons in the window: $ext",
        "- ports answering: $ports (probed 5985 WinRM, 22 SSH, 3389 RDP, 445 SMB)",
        "- findings: $(@($Result.findings) -join ', ')",
        "",
        "The machine answers on the network but cannot run work. Hard reboot is NOT fired by this script - it stays with the Maintenance lane (fleet_remote_reboot.ps1 -Hard). Maintenance answers on THIS thread: [CLAIMED] -Hard with the announcement, or no-fire plus the reason."
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
    # Reachability only (#4327 review, ai-01 24/10 11:36Z). A healthy Windows WinRM
    # endpoint answers HTTP 401 to an unauthenticated WS-Identify - measured from
    # ai-01: localhost 401 in 2 ms, myia-po-2023 401 in 79 ms. So ANY HTTP response
    # is an answer from the WinRM stack: 401 included. Silence is a timeout or a
    # connection error, nothing else. The status code and the round trip are kept
    # for the alert; the latency recorded here feeds NO verdict - the spec reserves
    # that role for the authenticated Invoke-Command probe below.
    #
    # `-WinRm` is a caller decision, not a port lookup, so the 401 rule can be pinned
    # by a test against any local HTTP endpoint instead of only against a real seat.
    param([string]$ComputerName, [int]$Port, [int]$TimeoutMs = 3000, [switch]$WinRm)

    if (-not $WinRm) {
        # SSH/TCP channels: connect time is the only read-only latency available.
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = Test-TcpPort -ComputerName $ComputerName -Port $Port -TimeoutMs $TimeoutMs
        $sw.Stop()
        return [PSCustomObject]@{
            answered   = $ok
            latencyMs  = $(if ($ok) { [int]$sw.ElapsedMilliseconds } else { $null })
            statusCode = $null
        }
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
        $status = [int]$resp.StatusCode
        $resp.Close()
        $sw.Stop()
        return [PSCustomObject]@{ answered = $true; latencyMs = [int]$sw.ElapsedMilliseconds; statusCode = $status }
    } catch {
        $sw.Stop()
        # WebException with a Response means the endpoint ANSWERED with a non-2xx
        # status: that is an answer, not silence. Only a response-less failure
        # (timeout, connection refused/reset, DNS) is silence.
        #
        # PowerShell wraps the .NET exception: under 5.1 `$_.Exception` is a
        # MethodInvocationException whose Response is NULL, and the WebException
        # hides in InnerException (measured - the first version of this fix read the
        # wrapper and kept treating 401 as silence, which is the whole defect it was
        # meant to close). Walk the chain instead of assuming one level.
        $web = $null
        $ex = $_.Exception
        while ($null -ne $ex) {
            if ($ex -is [System.Net.WebException]) { $web = $ex; break }
            $ex = $ex.InnerException
        }
        if ($null -ne $web -and $null -ne $web.Response) {
            $status = $null
            try { $status = [int]$web.Response.StatusCode } catch { $status = $null }
            try { $web.Response.Close() } catch { }
            return [PSCustomObject]@{ answered = $true; latencyMs = [int]$sw.ElapsedMilliseconds; statusCode = $status }
        }
        return [PSCustomObject]@{ answered = $false; latencyMs = $null; statusCode = $null }
    }
}

function Measure-WinrmLatency {
    # The ONLY latency that feeds a wedge verdict (spec, section 2): an authenticated
    # `Invoke-Command { 1 }` round trip, 3 consecutive probes, abnormal when 2 of 3
    # exceed the threshold. Returns an object so the caller can tell "measured fast"
    # from "could not measure" - an authentication failure must not read as healthy.
    param([string]$ComputerName, [int]$Count = 3, [int]$TimeoutMs = 3000, $Credential = $null)

    $samples = @()
    $errorText = ''
    for ($i = 0; $i -lt $Count; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            # No -IdleTimeout: the server refuses any value under 60 s, so every probe
            # failed before running (see Read-SystemLogFacts).
            $opts = New-PSSessionOption -OpenTimeout $TimeoutMs -OperationTimeout $TimeoutMs -CancelTimeout $TimeoutMs
            $invokeArgs = @{
                ComputerName = $ComputerName
                ScriptBlock  = { 1 }
                SessionOption = $opts
                ErrorAction  = 'Stop'
            }
            if ($null -ne $Credential) { $invokeArgs['Credential'] = $Credential }
            Invoke-Command @invokeArgs | Out-Null
            $sw.Stop()
            $samples += [int]$sw.ElapsedMilliseconds
        } catch {
            $sw.Stop()
            $errorText = $_.Exception.Message
            break
        }
    }
    return [PSCustomObject]@{ samples = @($samples); error = $errorText }
}

function Test-IsLocalSeat {
    # The seat this classifier runs on. Its own System log is read IN-PROCESS, never
    # over WinRM loopback, which is not an equivalent channel - measured on ai-01:
    # a loopback shell as the local account maint-admin fails with WinRM id=86,
    # 0x80080005 (wsmprovhost never registers, DCOM 10010), on 28/10 00:00Z and again
    # on 31/10 11:38Z, while that same account's shells opened from ANOTHER machine
    # succeed (31/10 00:05-00:07Z, no id=86). The task already runs on the seat with
    # a token that reads that log, so the loopback hop only added a failure mode.
    param([string]$ComputerName)
    if ([string]::IsNullOrWhiteSpace($ComputerName)) { return $false }
    $n = $ComputerName.Trim().ToLowerInvariant()
    if ($n -in @('localhost', '127.0.0.1', '::1', '.')) { return $true }
    $self = $env:COMPUTERNAME
    return (-not [string]::IsNullOrEmpty($self)) -and ($n -eq $self.ToLowerInvariant())
}

function Read-SystemLogFacts {
    # Last boot + the events of [boot, boot+20 min], read over the same authenticated
    # WinRM channel as the latency probe - or in-process for the seat itself (see
    # Test-IsLocalSeat). Returns ok=$false on any failure so the caller can report
    # `system-log-unavailable` instead of pretending zero bursts means a healthy
    # machine. `channel` says which path was used: a local read proves nothing about
    # the credential, and the installer's acceptance run must not count it.
    param([string]$ComputerName, $Credential = $null, $ProbeTimeoutMs = 3000, [int]$WindowMinutes = 20)

    $local = Test-IsLocalSeat $ComputerName
    $channel = if ($local) { 'local' } else { 'winrm' }

    # New-PSSessionOption is resolved OUTSIDE any catch would be a silent death on a
    # host that lacks the WSMan cmdlets (ci runs this suite on ubuntu, where the whole
    # sweep once produced no output at all): a missing instrument must come back as
    # ok=$false, never as a terminating error that kills the JSON.
    $invokeArgs = $null
    if (-not $local) {
        try {
            # IdleTimeout stays at its default (-1 = the server's own). The server
            # rejects any value under 60 s ("valeur minimale autorisee 60 (secondes)"),
            # and the 12 s set here made EVERY remote read fail whatever the
            # credential: measured 31/10 on po-2024, po-2025, po-2028, all three read
            # fine with the same credential once the option was dropped.
            $opts = New-PSSessionOption -OpenTimeout $ProbeTimeoutMs -OperationTimeout ($ProbeTimeoutMs * 4) -CancelTimeout ($ProbeTimeoutMs * 4)
            $invokeArgs = @{ ComputerName = $ComputerName; SessionOption = $opts; ErrorAction = 'Stop' }
        } catch {
            return [PSCustomObject]@{ ok = $false; error = $_.Exception.Message; lastBootUtc = $null; events = @(); channel = $channel }
        }
        if ($null -ne $Credential) { $invokeArgs['Credential'] = $Credential }
    }

    $bootBlock = {
        $ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 12 } -MaxEvents 1 -ErrorAction Stop
        if ($null -eq $ev) { return $null }
        return $ev.TimeCreated.ToUniversalTime().ToString('o')
    }
    try {
        $bootRaw = if ($local) { & $bootBlock } else { Invoke-Command @invokeArgs -ScriptBlock $bootBlock }
    } catch {
        return [PSCustomObject]@{ ok = $false; error = $_.Exception.Message; lastBootUtc = $null; events = @(); channel = $channel }
    }
    if ([string]::IsNullOrEmpty($bootRaw)) {
        return [PSCustomObject]@{ ok = $true; error = ''; lastBootUtc = $null; events = @(); channel = $channel }
    }
    try {
        $boot = ConvertTo-UtcDateTime $bootRaw
    } catch {
        return [PSCustomObject]@{ ok = $false; error = $_.Exception.Message; lastBootUtc = $null; events = @(); channel = $channel }
    }
    $to = $boot.AddMinutes($WindowMinutes)

    $eventsBlock = {
        param($from, $to)
        $ev = @()
        try {
            $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = [datetime]$from; EndTime = [datetime]$to; Id = 7031, 7034, 4624 } -ErrorAction Stop)
        } catch {
            if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') { return @() }
            throw
        }
        foreach ($e in $ev) {
            [PSCustomObject]@{
                utc     = $e.TimeCreated.ToUniversalTime().ToString('o')
                id      = $e.Id
                message = ($e.Message -replace '\s+', ' ')
            }
        }
    }
    try {
        $events = if ($local) {
            @(& $eventsBlock $boot.ToString('o') $to.ToString('o'))
        } else {
            @(Invoke-Command @invokeArgs -ScriptBlock $eventsBlock -ArgumentList $boot.ToString('o'), $to.ToString('o'))
        }
    } catch {
        return [PSCustomObject]@{ ok = $false; error = $_.Exception.Message; lastBootUtc = $boot; events = @(); channel = $channel }
    }
    return [PSCustomObject]@{ ok = $true; error = ''; lastBootUtc = $boot; events = $events; channel = $channel }
}

function Get-HeartbeatFacts {
    # Absence of the INSTRUMENT and absence of the FILE are two different things, and
    # the old code collapsed both into $null -> `no-heartbeat` -> healthy. An operator
    # running the classifier without ROOSYNC_SHARED_PATH got "the whole fleet is
    # fine"; now the instrument flag travels with the age and the caller makes it loud.
    param([string]$Machine)
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($sharedPath)) {
        return [PSCustomObject]@{ instrumentPresent = $false; ageSeconds = $null }
    }
    $file = Join-Path (Join-Path $sharedPath 'listener-heartbeats') ("$Machine.heartbeat")
    if (-not (Test-Path $file)) {
        return [PSCustomObject]@{ instrumentPresent = $true; ageSeconds = $null }
    }
    $age = ((Get-Date).ToUniversalTime() - (Get-Item $file).LastWriteTimeUtc).TotalSeconds
    return [PSCustomObject]@{ instrumentPresent = $true; ageSeconds = [int]$age }
}

# ---------------------------------------------------------------------------
# Dashboard-append half of the liveness bar (spec section 2). Synthetic authors are
# infrastructure, not a session that proves the machine can run work: `system` is the
# condenser (it writes on every dashboard and would zero out every age), the
# wake-`listener` posts its own reports, and this classifier's [FLEET-ALERT] lands as
# `<target>|listener` through the RSM CLI - so matching by author machine alone would
# let an alert corroborate itself on the next sweep.
# ---------------------------------------------------------------------------
$SyntheticAuthorWorkspaces = @('system', 'listener', 'classifier')

function Test-MachineAuthorMatch {
    # Author ids on the shared dashboards are not all canonical: `po-2026` and
    # `po-2025` (legacy short ids), `MYIA-PO-2025` (upper case) and
    # `myia-po-2025-win32-x64` (platform-suffixed lane) all belong to their roster
    # machine. Exact match first, then the two variations actually measured.
    param([string]$AuthorMachine, [string]$RosterMachine)
    $am = $AuthorMachine.Trim().ToLowerInvariant()
    $rm = $RosterMachine.Trim().ToLowerInvariant()
    if ($am -eq $rm) { return $true }
    if ($am -eq ($rm -replace '^myia-', '')) { return $true }
    if ($am.StartsWith("$rm-")) { return $true }
    return $false
}

function Get-DashboardAppendAges {
    # Newest message header per roster machine across the shared dashboards, as an
    # age in seconds. READ-ONLY, and per sweep not per probe: the answer is a fact
    # about the fleet, not about one machine. A machine with no header at all is
    # absent from agesByMachine - the caller reports `dashboard-append-unknown`
    # instead of inventing an age.
    param([string]$SharedPath, [string[]]$Machines = @(), $Now = $null)

    $state = [PSCustomObject]@{
        available     = $false
        agesByMachine = @{}
        filesRead     = 0
        filesFailed   = 0
        unreadable    = @()
    }
    if ([string]::IsNullOrEmpty($SharedPath)) { return $state }
    $dir = Join-Path $SharedPath 'dashboards'
    if (-not (Test-Path $dir)) { return $state }
    $state.available = $true
    if ($null -eq $Now) { $Now = (Get-Date).ToUniversalTime() }

    $latest = @{}
    $files = @(Get-ChildItem -Path $dir -File -Filter '*.md' -ErrorAction SilentlyContinue)
    foreach ($f in $files) {
        $text = $null
        try { $text = [System.IO.File]::ReadAllText($f.FullName) }
        catch {
            # A dashboard locked by Drive sync is a file that was NOT measured; count
            # it so the payload names the gap instead of narrowing the scan silently.
            $state.filesFailed++
            $state.unreadable += $f.Name
            continue
        }
        $state.filesRead++
        foreach ($m in [regex]::Matches($text, '(?m)^### \[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z)\] ([^|\r\n]+)\|([^|\r\n]*)')) {
            $rawAuthor = $m.Groups[2].Value.Trim()
            $parts = @($rawAuthor -split ':')
            $authorMachine = $parts[0].Trim()
            $workspaces = @()
            if ($parts.Count -gt 1) { $workspaces += ($parts[1..($parts.Count - 1)] -join ':') }
            $workspaces += $m.Groups[3].Value.Trim()

            $synthetic = ($authorMachine.ToLowerInvariant() -eq 'system')
            foreach ($w in $workspaces) {
                $first = ($w -split '\s+')[0].ToLowerInvariant()
                if ($SyntheticAuthorWorkspaces -contains $first) { $synthetic = $true; break }
            }
            if ($synthetic) { continue }

            $ts = $null
            foreach ($rm in $Machines) {
                if (-not (Test-MachineAuthorMatch -AuthorMachine $authorMachine -RosterMachine $rm)) { continue }
                if ($null -eq $ts) {
                    try { $ts = ConvertTo-UtcDateTime $m.Groups[1].Value } catch { $ts = $null }
                    if ($null -eq $ts) { break }
                }
                if (-not $latest.ContainsKey($rm) -or $ts -gt $latest[$rm]) { $latest[$rm] = $ts }
            }
        }
    }

    foreach ($rm in $Machines) {
        if ($latest.ContainsKey($rm)) {
            $age = ($Now - $latest[$rm]).TotalSeconds
            if ($age -lt 0) { $age = 0 }
            $state.agesByMachine[$rm] = [int]$age
        }
    }
    return $state
}

# ---------------------------------------------------------------------------
# Dashboard alert - same write path as check-all-listeners.ps1 (#4131 etape 3,
# arbitrage ai-01 14/10 option a): RSM CLI first (dual-write journal PG + file,
# append lock, format at the store), direct file write as fallback. The helper
# duplication with that script is known and documented there; convergence will
# happen when the shared writer is extracted, not by diverging here.
#
# Destination (spec, section 4): ONE post on the AFFECTED machine's dashboard, plus
# a cross-post to workspace: Maintenance. The CLI has no --crossPost flag and its
# escalation mode is `machine-<id>` by construction (#3761), so the cross-post is a
# second post on workspace:Maintenance carrying a stable --message-id (idempotent)
# that names the machine thread as the place to answer. One meeting point, two
# readers.
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

# ---------------------------------------------------------------------------
# Incident state - LOCAL to the detector seat (RX122 review, #4396). The
# dashboard FILE is not a state store: the machine dashboards condense all the
# time (po-2028 56 KB, po-2025 55 KB, 12 794 archive files) and the incident
# id scrolls out of the live file, so a guard that read the file back would
# repost. The state is a gitignored JSON under outputs/ (same pattern as
# embeddings-alert.ps1, #4394): written ONLY after the primary post is
# accepted, non-fatal when the write fails, and an absent or corrupt state
# means POST - never stay silent.
# ---------------------------------------------------------------------------

function Get-ClassifierStatePath {
    # CLASSIFIER_STATE_DIR moves the DIRECTORY (replay, tests) without
    # touching production state.
    param([string]$StateDir = "")
    $dir = $StateDir
    if ([string]::IsNullOrWhiteSpace($dir)) { $dir = $env:CLASSIFIER_STATE_DIR }
    if ([string]::IsNullOrWhiteSpace($dir)) {
        # scripts/diagnostic/<here> -> repo root
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $dir = Join-Path $repoRoot 'outputs\diagnostic\state'
    }
    return (Join-Path $dir 'classifier-incidents.json')
}

function Read-ClassifierIncidentState {
    # Status: 'none' (absent), 'ok', 'corrupt'. A corrupt state is a fact about
    # the INSTRUMENT, not the fleet: the caller posts anyway and the next
    # accepted post overwrites it.
    param([Parameter(Mandatory)][string]$StatePath)
    if (-not (Test-Path -LiteralPath $StatePath)) {
        return [pscustomobject]@{ Status = 'none'; Data = @(); Error = $null }
    }
    try {
        $raw = Get-Content -LiteralPath $StatePath -Raw -ErrorAction Stop
        if ([string]::IsNullOrWhiteSpace($raw)) { throw 'fichier vide' }
        $data = $raw | ConvertFrom-Json -ErrorAction Stop
        $entries = @()
        foreach ($p in @($data.PSObject.Properties)) {
            $entries += [pscustomobject]@{ Machine = $p.Name; IncidentId = [string]$p.Value.incidentId }
        }
        return [pscustomobject]@{ Status = 'ok'; Data = $entries; Error = $null }
    } catch {
        return [pscustomobject]@{ Status = 'corrupt'; Data = @(); Error = $_.Exception.Message }
    }
}

function Save-ClassifierIncidentState {
    # Atomic write (.tmp then move in the same directory), UTF-8 no BOM.
    param([Parameter(Mandatory)][string]$StatePath, [Parameter(Mandatory)]$Entries)
    $dir = Split-Path -Path $StatePath -Parent
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -Path $dir -ItemType Directory -Force | Out-Null
    }
    $map = @{}
    foreach ($e in @($Entries)) {
        $map[$e.Machine] = [PSCustomObject]@{ incidentId = [string]$e.IncidentId; postedAtUtc = (Get-Date).ToUniversalTime().ToString('o') }
    }
    $json = $map | ConvertTo-Json -Depth 4
    $tmp = "$StatePath.tmp"
    [System.IO.File]::WriteAllText($tmp, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}

function Update-ClassifierHealthyState {
    # Drop the recorded incident of every machine whose verdict is back to
    # HEALTHY: the state entry means "this incident was already announced",
    # not fleet history - without the drop, one wedge per boot per machine,
    # ever, and a later wedge on the same boot would be swallowed.
    param($Results, [string]$StateDir = "")
    $path = Get-ClassifierStatePath -StateDir $StateDir
    $state = Read-ClassifierIncidentState -StatePath $path
    if ($state.Status -ne 'ok') { return }
    $entries = @($state.Data)
    $changed = $false
    foreach ($r in @($Results)) {
        if ($r.verdict -ne 'healthy') { continue }
        $m = $r.machine.ToLowerInvariant()
        if (@($entries | Where-Object { $_.Machine -eq $m }).Count -gt 0) {
            $entries = @($entries | Where-Object { $_.Machine -ne $m })
            $changed = $true
        }
    }
    if (-not $changed) { return }
    try {
        Save-ClassifierIncidentState -StatePath $path -Entries $entries
    } catch {
        # The drop is lost, not the alert: the next accepted post rewrites.
        Write-Output "[FLEET-ALERT] incident state not updated ($($_.Exception.Message))"
    }
}

function Write-MachineDashboardAlert {
    param([Parameter(Mandatory)][string]$TargetMachine, [Parameter(Mandatory)][string]$Content, [Parameter(Mandatory)][string]$MessageId, [string]$StateDir = "")
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    if ([string]::IsNullOrEmpty($sharedPath)) {
        Write-Output "[FLEET-ALERT] ROOSYNC_SHARED_PATH not set - alert on stdout only (no dashboard write)."
        return
    }
    $target = $TargetMachine.ToLowerInvariant()

    # ONE ALERT PER INCIDENT (RX122) - dedup on the LOCAL state, never on the
    # dashboard file (it condenses; see the state block above). The escalation
    # surface also GENERATES its message id by contract - rsm-dashboard-append
    # .mjs REFUSES --message-id without --dashboard (measured 28/10,
    # dashboard-journal.mjs parseAppendArgs) - so no CLI-side dedup exists for
    # the primary post. Absent state says so in one line; corrupt state posts
    # anyway (never silent).
    $statePath = Get-ClassifierStatePath -StateDir $StateDir
    $state = Read-ClassifierIncidentState -StatePath $statePath
    $recordedId = $null
    foreach ($e in @($state.Data)) {
        if ($e.Machine -eq $target) { $recordedId = $e.IncidentId; break }
    }
    if ($state.Status -eq 'none') {
        Write-Output "[FLEET-ALERT] incident state absent ($statePath) - no local dedup, posting."
    }
    if ($state.Status -eq 'corrupt') {
        Write-Output "[FLEET-ALERT] incident state unreadable ($statePath): $($state.Error) - posting anyway (never silent)."
    }
    $skipPrimary = ($null -ne $recordedId -and $recordedId -eq $MessageId)

    # Record the incident in the LOCAL state - only after the primary post is
    # ACCEPTED (a refused post must not be marked announced), and the failure
    # of the write is non-fatal (the post already left; the next fire may
    # repost, which is visible, unlike silence).
    $script:ClassifierRecordIncident = {
        param($sp, $machine, $incidentId, $currentState)
        $entries = @($currentState.Data | Where-Object { $_.Machine -ne $machine })
        $entries += [pscustomobject]@{ Machine = $machine; IncidentId = $incidentId }
        try {
            Save-ClassifierIncidentState -StatePath $sp -Entries $entries
        } catch {
            Write-Output "[FLEET-ALERT] incident posted but state not saved ($($_.Exception.Message)) - next fire may post again"
        }
    }

    # Primary: the affected machine's own dashboard. `--machine` is the dashboard KEY
    # in escalation mode, so this is the target's file, not the detector's.
    if ($skipPrimary) {
        Write-Output "[FLEET-ALERT] Incident $MessageId already recorded in local state - primary post skipped (one alert per incident)."
    } else {
        $cli = Invoke-RsmCliJson "rsm-dashboard-append.mjs" @('--machine', $target, '--content', $Content)
        if ($null -ne $cli -and $cli.ok -eq $true) {
            Write-Output "[FLEET-ALERT] Posted to machine-$target dashboard via RSM CLI (key $($cli.key), messageId $($cli.messageId), pgSynced=$($cli.pgSynced))"
            & $script:ClassifierRecordIncident $statePath $target $MessageId $state
        } else {
        # File fallback - same conventions as Write-MachineDashboardMessage (#4124):
        # CRLF, [msg:] marker, plural "(N messages)" from the seed on.
        try {
            $dashDir = Join-Path $sharedPath 'dashboards'
            $machineFile = Join-Path $dashDir "machine-$target.md"
            $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            # The [msg:] marker carries the incident id for traceability in the
            # file; the DEDUP itself is the local state above, not this marker.
            $msgId = $MessageId
            $newMessage = "`r`n### [$timestamp] $target|classifier`r`n[msg: $msgId]`r`n`r`n$Content`r`n"

            if (-not (Test-Path $dashDir)) { New-Item -ItemType Directory -Path $dashDir -Force | Out-Null }

            if (Test-Path $machineFile) {
                $fileContent = Get-Content $machineFile -Raw -Encoding UTF8
                $fileContent = $fileContent.TrimEnd() + "`r`n" + $newMessage
                $fileContent = [regex]::Replace($fileContent, '(?<=## Intercom\s*\()\d+(?=\s*messages?\))', { param($m); ([int]$m.Value + 1).ToString() })
                $fileContent = [regex]::Replace($fileContent, '(## Intercom \(\d+) message\)', '$1 messages)')
            } else {
                $fileContent = "---`r`ntype: machine`r`nlastModified: '$timestamp'`r`nlastModifiedBy:`r`n  machineId: $target`r`n  workspace: classifier`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 messages)`r`n$newMessage"
            }
            [System.IO.File]::WriteAllText($machineFile, $fileContent, [System.Text.UTF8Encoding]::new($false))
            Write-Output "[FLEET-ALERT] Posted to $machineFile (file fallback)"
            & $script:ClassifierRecordIncident $statePath $target $MessageId $state
        } catch {
            Write-Output "[FLEET-ALERT] Dashboard write failed (best-effort): $($_.Exception.Message)"
        }
        }
    }

    # Cross-post: one line on workspace:Maintenance pointing back at the machine
    # thread. It runs on EVERY fire, including the ones whose primary post was
    # skipped (RX122 review): it is already idempotent through --message-id, so a
    # cross-post that failed on fire N is simply retried on fire N+1 - while a
    # skip would have lost it for the whole wedge. The id is the INCIDENT key
    # (not per UTC hour): the RSM CLI dedups on --message-id in --dashboard mode
    # (#4090), so the whole wedge - every 5-minute fire on the same boot and
    # burst - converges on ONE cross-post, and a new incident opens a new one.
    $crossBody = "[FLEET-ALERT] $target - reachable-but-unusable (#4327): details and the answer thread on the machine dashboard of $target. Hard lever decision belongs to this lane."
    $crossId = "$MessageId-maint"
    $cross = Invoke-RsmCliJson "rsm-dashboard-append.mjs" @('--dashboard', 'workspace:Maintenance', '--message-id', $crossId, '--author-workspace', 'classifier', '--content', $crossBody)
    if ($null -ne $cross -and $cross.ok -eq $true) {
        Write-Output "[FLEET-ALERT] Cross-posted to workspace:Maintenance (messageId $($cross.messageId))"
    } else {
        Write-Output "[FLEET-ALERT] Cross-post to workspace:Maintenance not written (primary alert stands)."
    }
}

# ---------------------------------------------------------------------------
# Inputs: live probes, or a recorded timeline (replay)
# ---------------------------------------------------------------------------
function New-LiveSample {
    param([string]$Machine, $DashboardAppendAgeSeconds = $null)

    $drivingPort = if ($DrivingPortByMachine.ContainsKey($Machine)) { $DrivingPortByMachine[$Machine] } else { $DefaultDrivingPort }

    $open = @()
    foreach ($p in $ProbedPorts) {
        if (Test-TcpPort -ComputerName $Machine -Port $p -TimeoutMs $ProbeTimeoutMs) { $open += $p }
    }

    $channel = Measure-DrivingChannel -ComputerName $Machine -Port $drivingPort -TimeoutMs $ProbeTimeoutMs -WinRm:($drivingPort -eq 5985)
    $heartbeat = Get-HeartbeatFacts -Machine $Machine

    # Remote authenticated reads only when the machine answers at all: probing a box
    # that is off is noise, and Invoke-Command would just burn the open timeout.
    $latencySamples = @()
    $lastBoot = $null
    $burst = $null
    $external = $null
    $systemLogOk = $false
    $systemLogChannel = $null
    $systemLogError = $null
    if ($open.Count -gt 0 -and $drivingPort -eq 5985) {
        # No latency probe against the seat itself: the only channel it could use is
        # the WinRM loopback that Test-IsLocalSeat documents as broken, and each try
        # costs a DCOM 10010 in the seat's own System log on every fire. A seat timing
        # its own WinRM is not the wedge signal anyway - a wedged seat runs no task.
        if (-not (Test-IsLocalSeat $Machine)) {
            $lat = Measure-WinrmLatency -ComputerName $Machine -Count $LatencyProbes -TimeoutMs $ProbeTimeoutMs -Credential $Credential
            $latencySamples = @($lat.samples)
        }
        $facts = Read-SystemLogFacts -ComputerName $Machine -Credential $Credential -ProbeTimeoutMs $ProbeTimeoutMs -WindowMinutes $BurstWindowEndMinutes
        $systemLogOk = [bool]$facts.ok
        $systemLogChannel = $facts.channel
        if (-not $facts.ok) { $systemLogError = $facts.error }
        if ($facts.ok) {
            $lastBoot = $facts.lastBootUtc
            $burst = Find-LogonDeathBurst -Events $facts.events -LastBootUtc $lastBoot -MinEvents $BurstMinEvents -WindowStartMinutes $BurstWindowStartMinutes -WindowEndMinutes $BurstWindowEndMinutes
            $external = Measure-ExternalLogonCount -Events $facts.events
        }
    }

    [PSCustomObject]@{
        machine                    = $Machine
        openPorts                  = $open
        drivingChannelAnswered     = [bool]$channel.answered
        drivingLatencyMs           = $channel.latencyMs
        drivingStatusCode          = $channel.statusCode
        LatencySamplesMs           = $latencySamples
        heartbeatAgeSeconds        = $heartbeat.ageSeconds
        heartbeatInstrumentPresent = $heartbeat.instrumentPresent
        dashboardAppendAgeSeconds  = $DashboardAppendAgeSeconds
        lastBootUtc                = $lastBoot
        burst                      = $burst
        externalLogonCount         = $external
        systemLogAvailable         = $systemLogOk
        systemLogChannel           = $systemLogChannel
        systemLogError             = $systemLogError
        drivingPort                = $drivingPort
    }
}

function Read-ReplaySamples {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Replay file not found: $Path" }
    $raw = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    # Shape 1 (current): {machine, events, samples, lastBootUtc?, logonDeathUtc?}
    # Shape 2 (legacy): {logonDeathUtc, samples:[...]} or a bare array of samples.
    if ($null -ne $raw.samples) {
        return [PSCustomObject]@{
            samples          = @($raw.samples)
            events           = @($raw.events | Where-Object { $null -ne $_ })
            lastBootUtc      = $raw.lastBootUtc
            logonDeathUtc    = $raw.logonDeathUtc
            machine          = $raw.machine
        }
    }
    return [PSCustomObject]@{ samples = @($raw); events = @(); lastBootUtc = $null; logonDeathUtc = $null; machine = $null }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
# Dot-source hook: CLASSIFIER_LIB_ONLY=1 defines the functions without running a
# classification, so the tests can pin the probes themselves (the 401 rule of the
# blocking review item is a probe behaviour, not a verdict rule - proving it through
# a whole fleet run would need a broken seat).
if ($env:CLASSIFIER_LIB_ONLY -eq '1') { return }

# -CredentialFile is the scheduled-fire form of -Credential (RX122): a task
# carries a file, not a live object. The load is fail-LOUD and happens BEFORE
# any probe: a classifier told to run with a credential it cannot load must
# never silently fall back to the unauthenticated path - that is exactly how
# the no-credential run of 28/10 produced `system-log-unavailable` on every
# reachable seat and an exit 3 that proved nothing about the fleet.
if (-not [string]::IsNullOrEmpty($CredentialFile) -and $null -eq $Credential) {
    if (-not (Test-Path -LiteralPath $CredentialFile)) {
        Write-Error "CredentialFile not found: $CredentialFile - refusing to run without credentials."
        exit 3
    }
    try {
        $importedCredential = Import-Clixml -LiteralPath $CredentialFile
    } catch {
        Write-Error "CredentialFile is not readable CLI XML: $CredentialFile ($($_.Exception.Message))"
        exit 3
    }
    if ($null -eq $importedCredential -or $importedCredential -isnot [System.Management.Automation.PSCredential]) {
        Write-Error "CredentialFile does not contain a PSCredential: $CredentialFile (expected Export-Clixml of a PSCredential, DPAPI-encrypted)."
        exit 3
    }
    $Credential = $importedCredential
}

$results = @()
$appendFacts = $null
$detectedAfterMinutes = $null
$logonDeath = $null
$lastBoot = $null
$burst = $null
$externalLogonCount = $null
$replayBurst = $null

if (-not [string]::IsNullOrEmpty($ReplayFile)) {
    $replay = $null
    try {
        $replay = Read-ReplaySamples -Path $ReplayFile
    } catch {
        Write-Error $_.Exception.Message
        exit 3
    }
    try {
        if ($null -ne $replay.lastBootUtc) { $lastBoot = ConvertTo-UtcDateTime $replay.lastBootUtc }
        if ($null -ne $replay.logonDeathUtc) { $logonDeath = ConvertTo-UtcDateTime $replay.logonDeathUtc }
        # The SAME pure detector the live path runs, over the archived rows: the
        # replay is evidence about the decision code, not a second implementation.
        if (@($replay.events).Count -gt 0 -and $null -ne $lastBoot) {
            $burst = Find-LogonDeathBurst -Events $replay.events -LastBootUtc $lastBoot -MinEvents $BurstMinEvents -WindowStartMinutes $BurstWindowStartMinutes -WindowEndMinutes $BurstWindowEndMinutes
            $externalLogonCount = Measure-ExternalLogonCount -Events $replay.events
        }
    } catch {
        Write-Error $_.Exception.Message
        exit 3
    }
    if ($null -eq $logonDeath -and $null -ne $burst) { $logonDeath = $burst.utc }
    $replayBurst = $burst

    foreach ($s in $replay.samples) {
        $machineName = if ($null -ne $s.machine) { [string]$s.machine } elseif ($null -ne $replay.machine) { [string]$replay.machine } else { 'unknown' }
        $drivingPort = if ($null -ne $s.drivingPort) { [int]$s.drivingPort } elseif ($DrivingPortByMachine.ContainsKey($machineName)) { $DrivingPortByMachine[$machineName] } else { $DefaultDrivingPort }
        $samplesMs = if ($null -ne $s.latencySamplesMs) { @($s.latencySamplesMs) } elseif ($null -ne $s.drivingLatencyMs) { @($s.drivingLatencyMs) } else { @() }
        # A burst is only visible to a detector that ran AFTER it. Replaying the same
        # burst into a sample taken before the logon death would manufacture a wedge
        # out of thin air (measured while writing this: the 07:47Z sample came out
        # `reachable-but-unusable` and the reported delay went NEGATIVE).
        $sampleAt = $null
        try { $sampleAt = ConvertTo-UtcDateTime $s.atUtc } catch { $sampleAt = $null }
        $sampleBurst = if ($null -ne $replayBurst -and $null -ne $sampleAt -and $sampleAt -ge $replayBurst.utc) { $replayBurst } else { $null }
        $r = Get-UsabilityVerdict -Machine $machineName -OpenPorts @($s.openPorts) `
            -DrivingChannelAnswered ([bool]$s.drivingChannelAnswered) -DrivingLatencyMs $s.drivingLatencyMs `
            -DrivingStatusCode $s.drivingStatusCode `
            -LatencySamplesMs $samplesMs `
            -HeartbeatAgeSeconds $s.heartbeatAgeSeconds `
            -HeartbeatInstrumentPresent $(if ($null -ne $s.heartbeatInstrumentPresent) { [bool]$s.heartbeatInstrumentPresent } else { $true }) `
            -DashboardAppendAgeSeconds $s.dashboardAppendAgeSeconds `
            -LastBootUtc $lastBoot -Burst $sampleBurst `
            -SystemLogAvailable $(if ($null -ne $s.systemLogAvailable) { [bool]$s.systemLogAvailable } else { $true }) `
            -SystemLogApplicable ($drivingPort -eq 5985) -ExternalLogonCount $externalLogonCount `
            -DrivingPort $drivingPort -SlowThresholdMs $WinrmSlowMs -HeartbeatStaleSeconds $HeartbeatStaleSeconds `
            -ProbedPorts $ProbedPorts -SampledPorts @($s.probedPorts | Where-Object { $null -ne $_ }) `
            -LatencyAbnormalMinCount $LatencyAbnormalMinCount -BurstMinEvents $BurstMinEvents
        # The FULL verdict object is what the table and the alert read: an
        # atUtc-only summary would leave New-AlertContent with no inputs to name.
        $r | Add-Member -NotePropertyName atUtc -NotePropertyValue $s.atUtc -Force
        $results += $r

        if ($null -ne $logonDeath -and $null -eq $detectedAfterMinutes -and $r.verdict -eq 'reachable-but-unusable' -and $null -ne $s.atUtc) {
            $at = ConvertTo-UtcDateTime $s.atUtc
            $detectedAfterMinutes = [math]::Round(($at - $logonDeath).TotalMinutes, 1)
        }
    }
} else {
    # `-Machines a,b` under `powershell -File` arrives as ONE string: split it here.
    $roster = if ($Machines.Count -gt 0) { $Machines } elseif (-not [string]::IsNullOrEmpty($env:ROO_FLEET_ROSTER)) { $env:ROO_FLEET_ROSTER -split ',' } else { $DefaultRoster }
    $roster = @($roster | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ -ne '' })

    $instrumentPresent = -not [string]::IsNullOrEmpty($env:ROOSYNC_SHARED_PATH)

    # Second half of the liveness bar, measured ONCE per sweep (it is a fact about the
    # fleet, not about one probe). A machine absent from agesByMachine gets $null and
    # is reported as `dashboard-append-unknown`.
    $appendFacts = Get-DashboardAppendAges -SharedPath $env:ROOSYNC_SHARED_PATH -Machines $roster

    foreach ($m in $roster) {
        $appendAge = $null
        if ($appendFacts.available -and $appendFacts.agesByMachine.ContainsKey($m)) { $appendAge = $appendFacts.agesByMachine[$m] }
        $sample = New-LiveSample -Machine $m -DashboardAppendAgeSeconds $appendAge
        $r = Get-UsabilityVerdict -Machine $sample.machine -OpenPorts @($sample.openPorts) `
            -DrivingChannelAnswered $sample.drivingChannelAnswered -DrivingLatencyMs $sample.drivingLatencyMs `
            -DrivingStatusCode $sample.drivingStatusCode -LatencySamplesMs @($sample.LatencySamplesMs) `
            -HeartbeatAgeSeconds $sample.heartbeatAgeSeconds -HeartbeatInstrumentPresent $sample.heartbeatInstrumentPresent `
            -DashboardAppendAgeSeconds $sample.dashboardAppendAgeSeconds `
            -LastBootUtc $sample.lastBootUtc -Burst $sample.burst -SystemLogAvailable $sample.systemLogAvailable `
            -SystemLogApplicable ($sample.drivingPort -eq 5985) `
            -ExternalLogonCount $sample.externalLogonCount -DrivingPort $sample.drivingPort `
            -SlowThresholdMs $WinrmSlowMs -HeartbeatStaleSeconds $HeartbeatStaleSeconds `
            -ProbedPorts $ProbedPorts -SampledPorts $ProbedPorts -LatencyAbnormalMinCount $LatencyAbnormalMinCount -BurstMinEvents $BurstMinEvents
        # Which path read the System log ('local' | 'winrm' | $null when not read):
        # the installer's acceptance run counts only 'winrm' rows as credential proof.
        $r | Add-Member -NotePropertyName systemLogChannel -NotePropertyValue $sample.systemLogChannel -Force
        # Why the read failed, verbatim: without it `system-log-unavailable` hid an
        # option the server rejected behind what read as a credential problem.
        $r | Add-Member -NotePropertyName systemLogError -NotePropertyValue $sample.systemLogError -Force
        $results += $r
    }
}

$unusable = @($results | Where-Object { $_.verdict -eq 'reachable-but-unusable' })
$unreachable = @($results | Where-Object { $_.verdict -eq 'unreachable' })
$instrumentMissing = @($results | Where-Object { @($_.findings) -contains 'no-instrument' }).Count -gt 0
$logUnavailable = @($results | Where-Object { @($_.findings) -contains 'system-log-unavailable' }).Count -gt 0

# A machine back to healthy drops its recorded incident so a LATER wedge posts
# again (RX122 review). Live mode only: a replay must not touch the seat's real
# state file with fixture machines.
if ([string]::IsNullOrEmpty($ReplayFile)) {
    Update-ClassifierHealthyState -Results $results
}

# ---------- Alerts (criterion 5) ----------
# Built BEFORE the output block so -Json can carry them INSIDE the payload: a
# consumer running `-Json | ConvertFrom-Json` must not choke on a markdown block
# appended after the JSON (measured: JsonReaderException "Additional text
# encountered after finished reading JSON content").
$alerts = @()
foreach ($r in $unusable) {
    # ONE id per alert, computed ONCE: the content line and the post guard must
    # read the same key, so both consume this value instead of re-deriving it.
    # The burst stamp goes in too: a second wedge on the same boot is a new
    # incident, not a repost.
    $incidentId = Get-ClassifierIncidentId -Machine $r.machine -LastBootUtc $r.lastBootUtc -Burst $r.burst
    $alerts += [PSCustomObject]@{
        machine   = $r.machine
        messageId = $incidentId
        content = (New-AlertContent -Result $r -Detector $env:COMPUTERNAME -SlowThresholdMs $WinrmSlowMs `
            -HeartbeatStaleSeconds $HeartbeatStaleSeconds -AbnormalMinCount $LatencyAbnormalMinCount -DeadlineMinutes $VerdictDeadlineMinutes `
            -IncidentId $incidentId)
    }
}

# ---------- Output ----------
if ($Json) {
    [PSCustomObject]@{
        checkedAtUtc          = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        detector              = $env:COMPUTERNAME
        replayFile            = $ReplayFile
        thresholds            = [PSCustomObject]@{
            slowChannelMs          = $WinrmSlowMs
            latencyAbnormalMinCount = $LatencyAbnormalMinCount
            heartbeatStaleSeconds  = $HeartbeatStaleSeconds
            probeTimeoutMs         = $ProbeTimeoutMs
            burstMinEvents         = $BurstMinEvents
            verdictDeadlineMinutes = $VerdictDeadlineMinutes
        }
        lastBootUtc           = $lastBoot
        logonDeathUtc         = $logonDeath
        burst                 = $burst
        detectedAfterMinutes  = $detectedAfterMinutes
        instrumentPresent     = (-not [string]::IsNullOrEmpty($env:ROOSYNC_SHARED_PATH))
        # Coverage of the second liveness half, so a consumer can tell "every lane was
        # silent for 2 h" from "the dashboards were not readable this sweep".
        dashboardAppendScan   = $(if ($null -ne $appendFacts) {
                [PSCustomObject]@{
                    available   = $appendFacts.available
                    filesRead   = $appendFacts.filesRead
                    filesFailed = $appendFacts.filesFailed
                    unreadable  = @($appendFacts.unreadable)
                }
            } else { $null })
        machines              = $results
        alerts                = $alerts
    } | ConvertTo-Json -Depth 6
} else {
    Write-Output "### Machine usability - $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) UTC (detector $env:COMPUTERNAME)"
    Write-Output ""
    Write-Output "| Machine | Verdict | Ports | WinRM latency (auth) | WS-Identify | Heartbeat | Dash append | Findings |"
    Write-Output "|---------|---------|-------|----------------------|-------------|-----------|-------------|----------|"
    foreach ($r in $results) {
        $ports = if (@($r.openPorts).Count -gt 0) { $r.openPorts -join ',' } else { 'none' }
        $lat = if (@($r.latencySamplesMs).Count -gt 0) { ($r.latencySamplesMs -join '/') + 'ms' } else { 'n/a' }
        $wsman = if ($r.drivingAnswered) { "answered $($r.drivingStatusCode)" } else { 'silent' }
        $hb = if ($null -ne $r.heartbeatAgeSeconds) { "$($r.heartbeatAgeSeconds)s" } else { 'n/a' }
        $ap = if ($null -ne $r.dashboardAppendAgeSeconds) { "$($r.dashboardAppendAgeSeconds)s" } else { 'n/a' }
        $findings = if (@($r.findings).Count -gt 0) { $r.findings -join ', ' } else { '-' }
        Write-Output "| $($r.machine) | $(if ($r.verdict -eq 'reachable-but-unusable') { '**' + $r.verdict + '**' } else { $r.verdict }) | $ports | $lat | $wsman | $hb | $ap | $findings |"
    }
    Write-Output ""
    if ($null -ne $burst) {
        Write-Output "Logon-death burst: **$($burst.utcText)** x$($burst.count), suffix $($burst.suffix), T+$($burst.minutesAfterBoot) min after the $($lastBoot.ToString('yyyy-MM-ddTHH:mm:ssZ')) boot."
    }
    if ($null -ne $detectedAfterMinutes) {
        $verdictTarget = if ($detectedAfterMinutes -le $VerdictDeadlineMinutes) { 'within' } else { 'OVER' }
        Write-Output "Detected **$detectedAfterMinutes min** after the recorded logon death ($verdictTarget the $VerdictDeadlineMinutes min target, criterion 2)."
    }
    Write-Output ""
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
        Write-MachineDashboardAlert -TargetMachine $a.machine -Content $a.content -MessageId $a.messageId
    }
}

if ($unusable.Count -gt 0) { exit 2 }
# A classifier that cannot read its inputs must not print "all clear": a missing
# heartbeat instrument, or an unreadable System log on a Windows seat (the decisive
# input), outranks a clean sweep and outranks `unreachable` (which at least names a
# machine), but never outranks a wedge alert.
# `heartbeat-unknown` and `dashboard-append-unknown` stay exit 0 ON PURPOSE: they
# name a corroborating-only input that is ABSENT (looked for, not there), not an
# instrument that failed to read - the measured rationale is on Get-UsabilityVerdict.
if ($instrumentMissing -or $logUnavailable) { exit 3 }
if ($unreachable.Count -gt 0) { exit 1 }
exit 0
