<#
.SYNOPSIS
    Watchdog E2E pour le chain MCP roo-state-manager (bot NanoClaw → mcp-tools.myia.io → TBXark → sparfenyuk).

.DESCRIPTION
    Probe le chain MCP depuis le point de vue du bot :
      1. E2E : POST initialize + VRAI tools/call (roosync_dashboard list) sur
         $baseUrl/roo-state-manager/mcp avec le bearer du bot. Le tool call
        touche GDrive — c'est le chemin exact des bots. Un initialize seul
        répond 200 pendant une panne totale (2026-08-15 : 2,5 jours, 720
        lignes "healthy" pendant que tous les appels échouaient).
      2. Si OK → log minimal (1 ligne) et sortie 0.
      3. Si KO → réparation pleine séquence (un sparfenyuk qui écoute peut
         avoir une instance RSM morte dedans — ne JAMAIS sauter son restart
         sur "port up") : Stop+Start MCP-Proxy-RSM puis docker restart
         myia-mcp-proxy (stale session TBXark #2023), cooldown 15 min.
      4. Si encore KO après réparation → ALERT (event log).
      5. Télémétrie flotte (#3394) : réparations/alertes ET un heartbeat
         périodique sont postés sur le MACHINE dashboard de l'hôte via la
         chaîne elle-même — best-effort, budget borné, jamais bloquant.

    Conçu pour tourner en SYSTEM via scheduled task "At startup + every 5 min".

.PARAMETER Mode
    'poll' (défaut) : run one shot and exit. 'dry-run' : probe only, never repair.

.PARAMETER BotEnvFile
    Path to NanoClaw .env (for MCP_PROXY_BASE_URL + MCP_PROXY_BEARER).
    Default: D:\nanoclaw\deploy\.env

.PARAMETER LogDir
    Directory for logs. Default: D:\roo-extensions\outputs\mcp-watchdog

.EXAMPLE
    .\mcp-chain-watchdog.ps1
    .\mcp-chain-watchdog.ps1 -Mode dry-run
#>

param(
    [ValidateSet('poll','dry-run')]
    [string]$Mode = 'poll',
    [string]$BotEnvFile = 'D:\nanoclaw\.env',
    [string]$LogDir = 'D:\roo-extensions\outputs\mcp-watchdog',
    [int]$LogRetentionDays = 14
)

$ErrorActionPreference = 'Continue'
$script:repairs = @()
$script:alerts  = @()

# ---------- logging ----------
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}
$logFile = Join-Path $LogDir ("watchdog-{0}.log" -f (Get-Date -Format 'yyyyMMdd'))

function Write-Log {
    param([string]$Level, [string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'
    $line = "{0} [{1,-5}] {2}" -f $ts, $Level, $Message
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

# ---------- read bot config ----------
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
    Write-Log 'ERROR' "Cannot read MCP_PROXY_BEARER from $BotEnvFile — watchdog cannot probe E2E"
    exit 2
}

$e2eUrl = "$baseUrl/roo-state-manager/mcp"

# ---------- probes ----------
$lanUrl = 'http://127.0.0.1:9090/roo-state-manager/mcp'

function Invoke-McpProbe {
    param([string]$Url, [int]$TimeoutSec = 20)

    # 2026-08-15: initialize alone is NOT a health check. The RSM backend's
    # internal instance died (after a GDrive stall) yet it answered initialize
    # 200 + serverInfo in <100ms for 2.5 DAYS while every tool call failed
    # with isError:true + empty text — this watchdog logged 720 "healthy"
    # lines in a single day of full outage. The probe must exercise a REAL
    # tool call that touches the shared state, i.e. exactly what the bots do.
    # Success = HTTP 200 AND the dashboard-list result body AND no top-level
    # MCP isError marker.
    $initBody = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-watchdog","version":"2.0"}}}'
    $initNote = '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    $callBody = '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"roosync_dashboard","arguments":{"action":"list"}}}'
    $headers = @{
        'Authorization' = "Bearer $bearer"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json, text/event-stream'
    }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $init = Invoke-WebRequest -Uri $Url -Method Post -Headers $headers -Body $initBody `
                                  -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        if ($init.StatusCode -ne 200) {
            $sw.Stop()
            return @{ Ok = $false; Status = $init.StatusCode; LatencyMs = $sw.ElapsedMilliseconds; Body = 'initialize failed' }
        }
        # Session id: present on sparfenyuk (mandatory for tool calls), absent
        # on stateless forwards (TBXark accepts calls without it). Header lookup
        # must be case-insensitive to work on both PS 5.1 and 7.
        $sid = $null
        foreach ($k in @($init.Headers.Keys)) { if ("$k" -ieq 'mcp-session-id') { $sid = $init.Headers[$k]; break } }
        $callHeaders = $headers
        if ($sid) {
            $callHeaders = @{} + $headers
            $callHeaders['mcp-session-id'] = "$sid"
            $null = Invoke-WebRequest -Uri $Url -Method Post -Headers $callHeaders -Body $initNote `
                                      -UseBasicParsing -TimeoutSec 10 -ErrorAction SilentlyContinue
        }
        $resp = Invoke-WebRequest -Uri $Url -Method Post -Headers $callHeaders -Body $callBody `
                                  -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        $sw.Stop()
        $content = $resp.Content
        # The healthy dashboard-list body carries "dashboards": [...] — escaped
        # when nested inside the MCP text field, plain at other layers; accept
        # both. The broken backend returns 200 with a top-level "isError":true
        # and empty text, which fails the dashboards marker.
        if ($resp.StatusCode -eq 200 -and $content -match 'dashboards\\{0,2}"\s*:' -and $content -notmatch '"isError"\s*:\s*true') {
            return @{ Ok = $true; Status = 200; LatencyMs = $sw.ElapsedMilliseconds; Body = $content.Substring(0, [Math]::Min(200, $content.Length)) }
        }
        $why = if ($content -match '"isError"\s*:\s*true') { 'toolcall isError:true (backend alive, instance dead)' }
               else { 'toolcall returned no dashboards marker' }
        return @{ Ok = $false; Status = $resp.StatusCode; LatencyMs = $sw.ElapsedMilliseconds; Body = "$why — $($content.Substring(0, [Math]::Min(200, $content.Length)))" }
    } catch {
        $sw.Stop()
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        # SLOW IS NOT DEAD. A timeout means we stopped waiting -- it says nothing
        # about whether the backend is alive. Measured 2026-08-16 on ai-01:
        # nominal round-trip is 589ms (p50 of 30 probes), yet a probe that took
        # 23_164ms SUCCEEDED, well past this 20s budget. Meanwhile the failure
        # this watchdog was written for -- the RSM instance dead inside a live
        # sparfenyuk -- is FAST: it answers 200 with isError:true in under 100ms.
        # So the discriminating signal is exactly the one a bare Ok=$false threw
        # away, and at 00:48 that cost a full destructive chain restart on a
        # backend that was merely waiting on GDrive.
        #
        # Detected on elapsed time, not on the exception type or message: the
        # messages are localised (this machine logged "Le delai d'attente de
        # l'operation a expire") and the exception class differs between PS 5.1
        # (WebException) and PS 7 (TaskCanceledException). Elapsed time is the
        # one signal that is neither locale- nor version-dependent.
        $budgetMs = [int]($TimeoutSec * 1000 * 0.9)
        $timedOut = ($status -eq 0 -and $sw.ElapsedMilliseconds -ge $budgetMs)
        return @{ Ok = $false; Status = $status; LatencyMs = $sw.ElapsedMilliseconds; TimedOut = $timedOut; Body = $_.Exception.Message }
    }
}

# Retry budget used once a probe has timed out, before concluding the chain is
# down. 3x the normal budget and ~2.5x the slowest round-trip ever observed to
# SUCCEED (23_164ms) -- generous enough that "still nothing after this" is real
# evidence of death rather than evidence of a slow shared drive.
#
# That 2.5x is a property of THIS machine, not of the number. Two reviewers
# measured their own worst SUCCEEDING GDrive round-trip on this PR:
#
#   ai-01    23s  -> 60s is a 2.5x margin
#   web1     54s  -> 60s is a 1.1x margin
#   po-2026  70s  -> 60s is BELOW the slowest success ever seen there
#
# po-2026's number is the one that matters, and it is above the budget: a cold
# read after a G: remount pays cloud lazy-hydration, a cost ai-01 cannot observe
# by construction because nothing hydrates here. On such a host a healthy call
# is classified TimedOut. That is survivable only because of the rule above --
# post-fc663849 a timeout DEFERS the repair instead of performing it, so the
# damage is a WARN every 2 minutes during a long stall, not a chain restart.
#
# So: this figure is not portable, and 60 is not a floor. Anyone deploying this
# watchdog elsewhere has to re-derive it from that host's own slowest success
# (po-2026 recommends >= 90s to cover the measured range). The harness bounds it
# 24..180 rather than pinning 60 precisely so that re-deriving stays cheap.
#
# Left as a constant rather than a parameter on purpose: this watchdog runs on
# ai-01 alone -- both web1 and po-2026 checked their own schtasks and neither
# hosts it -- and a knob for a deployment that does not exist would be an
# abstraction with a single caller. What a future deployer actually needs is not
# a knob but the measurements, so the measurements are what is recorded here.
$SlowRetryTimeoutSec = 60

# ---------- fleet telemetry (#3394) ----------
# Two bus outages (02/09 23:10->00:05Z, 03/09 01:21->01:44Z) were only visible
# through bot anecdotes, and afterwards nobody could tell whether this watchdog
# had even run: its actions lived in a local log and a local Event Log, neither
# of which the fleet reads. These notes go to the MACHINE dashboard of this
# host, through the very chain being guarded, so that:
#   - a repair or an alert becomes fleet-visible within one tick;
#   - a periodic heartbeat proves the watchdog itself is alive -- its own
#     meta-failure (schtask gone or stopped) is otherwise indistinguishable
#     from a healthy quiet chain, which is how 15/08 stayed invisible 2.5 days.
#
# Best-effort ONLY: short per-request budget, one fallback URL, no retry, all
# errors swallowed. The schtask runs under a 2-min ExecutionTimeLimit, and a
# dashboard append can legitimately take ~45 s when the auto-condensation
# fires (measured 01/09/2026); telemetry that can outrun its budget is
# telemetry that gets the repair sequence killed mid-flight.
$FleetNoteTimeoutSec = 8

function Publish-FleetNote {
    param([string]$Level, [string]$Text)
    $initBody = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-watchdog","version":"2.1"}}}'
    $payload = @{
        jsonrpc = '2.0'
        id      = 3
        method  = 'tools/call'
        params  = @{
            name      = 'roosync_dashboard'
            arguments = @{
                action  = 'append'
                type    = 'machine'
                tags    = @($Level, 'mcp-chain-watchdog')
                content = $Text
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress
    $headers = @{
        'Authorization' = "Bearer $bearer"
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json, text/event-stream'
    }
    foreach ($url in @($e2eUrl, $lanUrl)) {
        try {
            $init = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -Body $initBody `
                                      -UseBasicParsing -TimeoutSec $FleetNoteTimeoutSec -ErrorAction Stop
            $sid = $null
            foreach ($k in @($init.Headers.Keys)) { if ("$k" -ieq 'mcp-session-id') { $sid = $init.Headers[$k]; break } }
            $callHeaders = $headers
            if ($sid) {
                $callHeaders = @{} + $headers
                $callHeaders['mcp-session-id'] = "$sid"
                $null = Invoke-WebRequest -Uri $url -Method Post -Headers $callHeaders `
                                          -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' `
                                          -UseBasicParsing -TimeoutSec $FleetNoteTimeoutSec -ErrorAction SilentlyContinue
            }
            $null = Invoke-WebRequest -Uri $url -Method Post -Headers $callHeaders -Body $payload `
                                      -UseBasicParsing -TimeoutSec $FleetNoteTimeoutSec -ErrorAction Stop
            Write-Log 'INFO' "fleet note posted to machine dashboard ($Level)"
            return $true
        } catch {
            continue
        }
    }
    Write-Log 'WARN' 'fleet note NOT posted (chain down or slow) — telemetry is best-effort, continuing'
    return $false
}

function Test-E2E { Invoke-McpProbe -Url $e2eUrl -TimeoutSec 20 }

function Test-Lan { Invoke-McpProbe -Url $lanUrl -TimeoutSec 20 }

function Test-UrlIsLocalHop {
    <#
    .SYNOPSIS
        True when a probe URL resolves to this very machine.
    .DESCRIPTION
        Used to decide whether the differential (e2e vs LAN) verdict means
        anything at all. Comparing the URL STRINGS -- which is what this script
        did until 2026-08-16 -- answers a different question: on ai-01,
        MCP_PROXY_BASE_URL is http://host.docker.internal:9090, and
        host.docker.internal resolves to 192.168.0.47, which IS ai-01. The two
        probes then traverse the identical hop while differing as text, and the
        verdict built on that difference blamed a machine that is not even in
        the path: at 00:50:33 it logged "wedge is upstream of ai-01 (IIS/ARR on
        po-2023)" for a stall entirely local to this host.
    #>
    param([Parameter(Mandatory)][string]$Url)

    try {
        $u = [Uri]$Url
        $targets = @([System.Net.Dns]::GetHostAddresses($u.Host) | ForEach-Object { $_.IPAddressToString })
        if (-not $targets) { return $false }
        $mine = @([System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) | ForEach-Object { $_.IPAddressToString })
        foreach ($t in $targets) {
            if ($t -eq '127.0.0.1' -or $t -eq '::1' -or ($mine -contains $t)) { return $true }
        }
        return $false
    } catch {
        # Unresolvable: say "not local" rather than guess. The caller only uses
        # this to GRANT the upstream-wedge verdict, so the cautious answer is
        # the one that does not manufacture a second hop out of a DNS failure.
        return $false
    }
}

# The differential verdict is only meaningful when the e2e probe actually leaves
# this machine. If both ends land here, they are one hop and one failure.
$probesAreDistinctHops = -not ((Test-UrlIsLocalHop -Url $e2eUrl) -and (Test-UrlIsLocalHop -Url $lanUrl))

function Test-Sparfenyuk {
    try {
        $response = Invoke-WebRequest -Uri 'http://127.0.0.1:9091/status' -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return ($response.StatusCode -eq 200)
    } catch {
        return $false
    }
}

function Test-TbxarkPort {
    try {
        $tcp = Test-NetConnection -ComputerName '127.0.0.1' -Port 9090 -WarningAction SilentlyContinue -InformationLevel Quiet
        return $tcp
    } catch {
        return $false
    }
}

# ---------- repair actions are inlined in the main flow below ----------

# ---------- main ----------
Write-Log 'INFO' "Watchdog start (mode=$Mode, e2e=$e2eUrl)"

# Repair cooldown: the task fires every 2 min, and a full chain restart kills
# live sessions. If a repair ran recently and the probe still fails, log and
# wait rather than restart-storming the chain (each restart re-drops the bots).
$RepairCooldownMin = 15
$repairStateFile = Join-Path $LogDir 'repair-state.json'
$lastRepairAt = [datetime]::MinValue
if (Test-Path $repairStateFile) {
    try { $lastRepairAt = [datetime](Get-Content $repairStateFile -Raw | ConvertFrom-Json).lastRepairAt } catch { }
}
$repairOnCooldown = ((Get-Date) - $lastRepairAt).TotalMinutes -lt $RepairCooldownMin

$result = Test-E2E

# A timed-out probe buys one retry on a generous budget before we are allowed to
# call the chain down. The repair below stops the task, restarts sparfenyuk and
# restarts the container -- it drops every live bot session. That price is worth
# paying against a dead instance; it is pure damage against a slow shared drive,
# and on 2026-08-16 the script paid it twice in four minutes for a stall that
# resolved on its own by 00:52.
if (-not $result.Ok -and $result.TimedOut) {
    Write-Log 'WARN' "E2E probe spent its full 20s budget (latency=$($result.LatencyMs)ms) — that is slowness, not proof of death. Retrying once with ${SlowRetryTimeoutSec}s before concluding."
    $result = Invoke-McpProbe -Url $e2eUrl -TimeoutSec $SlowRetryTimeoutSec
    if ($result.Ok) { $script:alerts += "chain-slow: $($result.LatencyMs)ms (nominal ~600ms)" }
}

if ($result.Ok) {
    if ($result.LatencyMs -ge 20000) {
        Write-Log 'OK' "E2E chain healthy but SLOW (REAL tool call, latency=$($result.LatencyMs)ms vs ~600ms nominal) — reported, NOT repaired."
    } else {
        Write-Log 'OK'   "E2E chain healthy (REAL tool call, latency=$($result.LatencyMs)ms)"
    }
} else {
    $bodyExcerpt = ($result.Body -replace '\s+', ' ').Substring(0, [Math]::Min(180, $result.Body.Length))
    Write-Log 'FAIL' "E2E chain DOWN (HTTP $($result.Status), latency=$($result.LatencyMs)ms) — $bodyExcerpt"

    # Differential probe: is the wedge in our backend or upstream (IIS/ARR/network)?
    # Only meaningful when the e2e probe genuinely leaves this machine — see
    # Test-UrlIsLocalHop. Until 2026-08-16 the condition was $e2eUrl -ne $lanUrl,
    # which compares two spellings of the same hop and grants the upstream
    # verdict on a difference of text.
    #
    # Second measurement of the same night, taken on main by 155db6df: a GDrive
    # flap made the e2e spelling time out at 20s while the LAN spelling squeaked
    # through at 15s, and this branch mislabeled a purely local slowdown as an
    # upstream wedge. Same defect, caught twice, hours apart.
    #
    # 155db6df gated the branch on $e2eUrl -match 'mcp-tools\.myia\.io'. That
    # closes this instance and no other: it hardcodes today's edge hostname, so
    # a renamed edge or a second one silently changes the verdict, and it keeps
    # naming po-2023 in the log line. Test-UrlIsLocalHop asks the question the
    # verdict actually rests on — does this probe leave the host — by resolving
    # both URLs and comparing against our own addresses. No hostname is spelled
    # out anywhere, and no machine is accused.
    $lanResult = Test-Lan

    # The same argument as above, applied to the probe that actually DECIDES the
    # repair. Until po-2025 reviewed this PR the retry covered only the E2E side,
    # so a GDrive stall outliving 20+60+20s still reached the destructive branch
    # -- a hundred seconds later than before, but just as destructively. The
    # budget was never the guard; the reasoning is: the failure this repair
    # exists for (a dead RSM instance inside a live sparfenyuk) answers in under
    # 100 ms with isError:true, so it can NEVER present as a timeout.
    if (-not $lanResult.Ok -and $lanResult.TimedOut) {
        Write-Log 'WARN' "LAN probe spent its full 20s budget (latency=$($lanResult.LatencyMs)ms) — retrying once with ${SlowRetryTimeoutSec}s before deciding anything destructive."
        $lanResult = Invoke-McpProbe -Url $lanUrl -TimeoutSec $SlowRetryTimeoutSec
    }

    if ($lanResult.Ok -and $probesAreDistinctHops) {
        # Names no machine: this host knows that the wedge is NOT in its own
        # backend, and nothing more. The previous wording asserted "IIS/ARR on
        # po-2023" -- a conclusion the probe cannot support, and the same false
        # attribution the hop guard above was written to stop producing.
        Write-Log 'WARN' "LAN backend HEALTHY (latency=$($lanResult.LatencyMs)ms) — wedge is upstream of $env:COMPUTERNAME (reverse proxy / network), NOT in this backend. NOT restarting."
        $script:alerts += "upstream-issue: e2e-http-$($result.Status) lan-ok"
        $result = $lanResult  # final result reflects backend health (OK), not E2E
    } elseif ($lanResult.TimedOut) {
        # Both probes ran out of clock, the second one on a 60s budget. That is
        # 100+ seconds of silence, which is a lot -- and still not the signature
        # of the fault this repair treats. Restarting here trades a stall that
        # may clear itself (00:48 -> healthy at 00:52) for a certainty: every
        # live bot session dropped. Report it and let the next tick decide.
        Write-Log 'WARN' "LAN probe STILL timing out after the ${SlowRetryTimeoutSec}s retry (latency=$($lanResult.LatencyMs)ms) — unresponsive is not dead. Deferring repair to the next tick."
        $script:alerts += "chain-unresponsive-repair-deferred: e2e-and-lan-both-timed-out"
    } elseif ($repairOnCooldown) {
        Write-Log 'WARN' "chain still down but repair is on cooldown (last repair $([math]::Round(((Get-Date) - $lastRepairAt).TotalMinutes,0)) min ago < $RepairCooldownMin) — waiting, not restarting"
        $script:alerts += "chain-down-repair-on-cooldown"
    } else {
        Write-Log 'WARN' "Backend DOWN at the tool-call level (LAN HTTP $($lanResult.Status)) — running full repair sequence."

        # 2026-08-15 lesson: a listening sparfenyuk is NOT a healthy sparfenyuk.
        # The outage lived 2.5 days precisely because "port 9091 up" skipped
        # the restart while the RSM instance inside was dead (init OK, every
        # tool call isError). The repair is therefore ALWAYS the full sequence,
        # proven end-to-end that night: stop+start the task (fresh sparfenyuk
        # AND fresh RSM child), then restart TBXark (stale-session cache #2023).
        try {
            if ($Mode -eq 'dry-run') {
                Write-Log 'INFO' 'DRY-RUN: would Stop+Start MCP-Proxy-RSM then docker restart myia-mcp-proxy'
            } else {
                $sparfenyukPortUp = Test-Sparfenyuk
                Stop-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 3
                Start-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction Stop
                $script:repairs += if ($sparfenyukPortUp) { 'sparfenyuk-restart(port-was-up-instance-dead)' } else { 'sparfenyuk-restart(port-was-down)' }
                Start-Sleep -Seconds 10
                & docker restart myia-mcp-proxy 2>&1 | Out-Null
                $script:repairs += 'tbxark-restart'
                Start-Sleep -Seconds 15
                @{ lastRepairAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -Path $repairStateFile -Encoding utf8
            }
        } catch {
            Write-Log 'ERROR' "Repair sequence failed: $($_.Exception.Message)"
            $script:alerts += "repair-failed: $($_.Exception.Message)"
        }

        $result = Test-E2E
        if ($result.Ok) {
            Write-Log 'OK' "E2E chain recovered after full repair sequence (latency=$($result.LatencyMs)ms)"
        } else {
            Write-Log 'ERROR' "E2E chain STILL DOWN after full repair sequence (HTTP $($result.Status)) — needs human eyes (GDrive? RSM code?)"
            $script:alerts += "e2e-still-down-after-full-repair: http-$($result.Status)"
        }
    }
}

# ---------- summary + event log ----------
if ($script:repairs.Count -gt 0) {
    $summary = "Watchdog repaired MCP chain: $($script:repairs -join ', '); final=$(if($result.Ok){'OK'}else{"FAIL HTTP $($result.Status)"})"
    Write-Log 'INFO' $summary
    # Event log (EventLog "Application" - source must exist; use fallback if not registered)
    try {
        $src = 'MCP-Chain-Watchdog'
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $src -EventId 1000 -EntryType Information -Message $summary -ErrorAction SilentlyContinue
    } catch {}
}

if ($script:alerts.Count -gt 0) {
    $alertMsg = "Watchdog ALERT: $($script:alerts -join '; ')"
    Write-Log 'ALERT' $alertMsg
    try {
        $src = 'MCP-Chain-Watchdog'
        if (-not [System.Diagnostics.EventLog]::SourceExists($src)) {
            New-EventLog -LogName Application -Source $src -ErrorAction SilentlyContinue
        }
        Write-EventLog -LogName Application -Source $src -EventId 2000 -EntryType Error -Message $alertMsg -ErrorAction SilentlyContinue
    } catch {}
}

# ---------- fleet telemetry emission (#3394) ----------
# One note per run, max: repairs/alerts take precedence over the heartbeat.
# Heartbeat throttle: the task fires every 2 min; a note per tick would spam
# the machine dashboard and feed the 92% auto-condensation for nothing. 6h =
# 4 lines/day. On a chain that stays healthy, silence beyond ~2x this interval
# means the watchdog itself is dead — see verify-watchdog-deployment.ps1.
$HeartbeatIntervalHours = 6
if ($script:repairs.Count -gt 0 -or $script:alerts.Count -gt 0) {
    $parts = @()
    if ($script:repairs.Count -gt 0) { $parts += "repaired: $($script:repairs -join ', ')" }
    if ($script:alerts.Count -gt 0)  { $parts += "alerts: $($script:alerts -join '; ')" }
    $parts += "final=$(if ($result.Ok) { 'OK' } else { 'DOWN' })"
    $note = (($parts -join ' | ') -replace '\s+', ' ')
    if ($note.Length -gt 300) { $note = $note.Substring(0, 300) }
    $null = Publish-FleetNote -Level 'WARN' -Text $note
} elseif ($result.Ok) {
    $heartbeatStateFile = Join-Path $LogDir 'heartbeat-state.json'
    $lastHeartbeatAt = [datetime]::MinValue
    if (Test-Path $heartbeatStateFile) {
        try { $lastHeartbeatAt = [datetime](Get-Content $heartbeatStateFile -Raw | ConvertFrom-Json).lastHeartbeatAt } catch { }
    }
    if (((Get-Date) - $lastHeartbeatAt).TotalHours -ge $HeartbeatIntervalHours) {
        if (Publish-FleetNote -Level 'INFO' -Text "alive: E2E chain healthy (latency=$($result.LatencyMs)ms)") {
            @{ lastHeartbeatAt = (Get-Date).ToString('o') } | ConvertTo-Json | Set-Content -Path $heartbeatStateFile -Encoding utf8
        }
    }
}

# ---------- log rotation ----------
try {
    Get-ChildItem -Path $LogDir -Filter 'watchdog-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Exit code : 0 if final state OK, 1 if repair failed
if ($result.Ok) { exit 0 } else { exit 1 }
