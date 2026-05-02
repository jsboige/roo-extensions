<#
.SYNOPSIS
    Watchdog E2E pour le chain MCP roo-state-manager (bot NanoClaw → mcp-tools.myia.io → TBXark → sparfenyuk).

.DESCRIPTION
    Probe le chain MCP depuis le point de vue du bot :
      1. E2E : POST initialize sur https://mcp-tools.myia.io/roo-state-manager/mcp avec le bearer du bot.
      2. Si OK → log minimal (1 ligne) et sortie 0.
      3. Si KO → diagnostic progressif et réparation :
         a. Probe localhost:9091/status (sparfenyuk). Si down → Start-ScheduledTask MCP-Proxy-RSM.
         b. Re-probe E2E. Si encore KO → docker restart myia-mcp-proxy (TBXark stale session).
         c. Re-probe E2E. Si encore KO → ALERT (event log + dashboard si disponible).

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

function Invoke-McpInitialize {
    param([string]$Url, [int]$TimeoutSec = 15)
    $body = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"mcp-watchdog","version":"1.0"}}}'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $response = Invoke-WebRequest -Uri $Url -Method Post -Headers @{
            'Authorization' = "Bearer $bearer"
            'Content-Type'  = 'application/json'
            'Accept'        = 'application/json, text/event-stream'
        } -Body $body -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
        $sw.Stop()
        if ($response.StatusCode -eq 200 -and $response.Content -match 'serverInfo') {
            return @{ Ok = $true; Status = 200; LatencyMs = $sw.ElapsedMilliseconds; Body = $response.Content.Substring(0, [Math]::Min(200, $response.Content.Length)) }
        }
        return @{ Ok = $false; Status = $response.StatusCode; LatencyMs = $sw.ElapsedMilliseconds; Body = $response.Content.Substring(0, [Math]::Min(300, $response.Content.Length)) }
    } catch {
        $sw.Stop()
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }
        return @{ Ok = $false; Status = $status; LatencyMs = $sw.ElapsedMilliseconds; Body = $_.Exception.Message }
    }
}

function Test-E2E { Invoke-McpInitialize -Url $e2eUrl -TimeoutSec 15 }

function Test-Lan { Invoke-McpInitialize -Url $lanUrl -TimeoutSec 5 }

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

# ---------- repair actions ----------
function Invoke-RestartSparfenyuk {
    if ($Mode -eq 'dry-run') { Write-Log 'INFO' 'DRY-RUN: would Start-ScheduledTask MCP-Proxy-RSM'; return }
    Write-Log 'WARN' 'Sparfenyuk port 9091 down — starting MCP-Proxy-RSM scheduled task'
    try {
        Start-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction Stop
        $script:repairs += 'sparfenyuk-restart'
        Start-Sleep -Seconds 10
        Write-Log 'INFO' 'MCP-Proxy-RSM started, waited 10s for sparfenyuk'
    } catch {
        Write-Log 'ERROR' "Failed to start MCP-Proxy-RSM: $($_.Exception.Message)"
        $script:alerts += "sparfenyuk-restart-failed: $($_.Exception.Message)"
    }
}

function Invoke-RestartTbxark {
    if ($Mode -eq 'dry-run') { Write-Log 'INFO' 'DRY-RUN: would docker restart myia-mcp-proxy'; return }
    Write-Log 'WARN' 'TBXark chain still failing — docker restart myia-mcp-proxy (clear stale upstream session)'
    try {
        $out = & docker restart myia-mcp-proxy 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'ERROR' "docker restart failed (exit=$LASTEXITCODE): $out"
            $script:alerts += "tbxark-restart-failed: $out"
            return
        }
        $script:repairs += 'tbxark-restart'
        Start-Sleep -Seconds 15
        Write-Log 'INFO' 'myia-mcp-proxy restarted, waited 15s for TBXark'
    } catch {
        Write-Log 'ERROR' "docker restart exception: $($_.Exception.Message)"
        $script:alerts += "tbxark-restart-exception: $($_.Exception.Message)"
    }
}

# ---------- main ----------
Write-Log 'INFO' "Watchdog start (mode=$Mode, e2e=$e2eUrl)"

$result = Test-E2E
if ($result.Ok) {
    Write-Log 'OK'   "E2E chain healthy (HTTP 200, serverInfo present, latency=$($result.LatencyMs)ms)"
} else {
    $bodyExcerpt = ($result.Body -replace '\s+', ' ').Substring(0, [Math]::Min(180, $result.Body.Length))
    Write-Log 'FAIL' "E2E chain DOWN (HTTP $($result.Status), latency=$($result.LatencyMs)ms) — $bodyExcerpt"

    # Differential probe: is the wedge in our backend or upstream (IIS/ARR/network)?
    $lanResult = Test-Lan
    if ($lanResult.Ok) {
        Write-Log 'WARN' "LAN backend HEALTHY (HTTP 200, latency=$($lanResult.LatencyMs)ms) — wedge is upstream of ai-01 (IIS/ARR/network on po-2023). NOT restarting backend."
        $script:alerts += "iis-or-network-issue: e2e-http-$($result.Status) lan-ok"
        # Skip backend repairs — they would be useless and could mask the real cause
        $result = $lanResult  # final result reflects backend health (OK), not E2E
    } else {
        Write-Log 'WARN' "LAN backend ALSO DOWN (HTTP $($lanResult.Status), latency=$($lanResult.LatencyMs)ms) — wedge is local. Starting repair cascade."

    # Step 1 : sparfenyuk
    if (-not (Test-Sparfenyuk)) {
        Invoke-RestartSparfenyuk
    } else {
        Write-Log 'INFO' 'Sparfenyuk port 9091 is up — skipping sparfenyuk restart'
    }

    # Re-probe
    $result = Test-E2E
    if ($result.Ok) {
        Write-Log 'OK' 'E2E chain recovered after sparfenyuk check'
    } else {
        # Step 2 : TBXark stale session pattern
        if (Test-TbxarkPort) {
            Invoke-RestartTbxark
        } else {
            Write-Log 'ERROR' 'TBXark port 9090 also down — docker daemon issue?'
            $script:alerts += 'tbxark-port-down'
        }

        # Final re-probe
        $result = Test-E2E
        if ($result.Ok) {
            Write-Log 'OK' 'E2E chain recovered after TBXark restart'
        } else {
            # Escalation: tbxark-restart alone failed AND sparfenyuk port was up.
            # Sparfenyuk can be "port-up" but have a stale upstream session that
            # tbxark can't refresh on its own. Restart sparfenyuk explicitly,
            # then retry tbxark to clear its stale forward registration.
            Write-Log 'WARN' 'TBXark restart insufficient — escalating to full chain restart (sparfenyuk + tbxark)'
            try {
                if ($Mode -eq 'dry-run') {
                    Write-Log 'INFO' 'DRY-RUN: would Stop+Start MCP-Proxy-RSM and re-restart myia-mcp-proxy'
                } else {
                    Stop-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction SilentlyContinue
                    Start-Sleep -Seconds 3
                    Start-ScheduledTask -TaskName 'MCP-Proxy-RSM' -ErrorAction Stop
                    $script:repairs += 'sparfenyuk-restart-escalation'
                    Start-Sleep -Seconds 8
                    & docker restart myia-mcp-proxy 2>&1 | Out-Null
                    $script:repairs += 'tbxark-restart-escalation'
                    Start-Sleep -Seconds 12
                }
            } catch {
                Write-Log 'ERROR' "Escalation restart failed: $($_.Exception.Message)"
                $script:alerts += "escalation-failed: $($_.Exception.Message)"
            }

            $result = Test-E2E
            if ($result.Ok) {
                Write-Log 'OK' 'E2E chain recovered after escalation (full chain restart)'
            } else {
                Write-Log 'ERROR' "E2E chain STILL DOWN after escalation (HTTP $($result.Status))"
                $script:alerts += "e2e-still-down-after-escalation: http-$($result.Status)"
            }
        }
    }
    }  # close LAN-down else
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

# ---------- log rotation ----------
try {
    Get-ChildItem -Path $LogDir -Filter 'watchdog-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$LogRetentionDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
} catch {}

# Exit code : 0 if final state OK, 1 if repair failed
if ($result.Ok) { exit 0 } else { exit 1 }
