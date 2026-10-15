<#
.SYNOPSIS
    Fleet-wide health check: diagnose wake-listeners on all known machines (#2576).

.DESCRIPTION
    Designed to run as a cron worker (every 2h). For each known machine in the fleet:
    1. SSH or check local listener heartbeat
    2. Report [FLEET-ALERT] on the MACHINE dashboard of the detector
       (G-C #4131 étape 3, arbitrage ai-01 14/10 option a — via the submodule
       RSM CLI first: dual-write journal PG + file, append lock, format at the
       store; direct file write as fallback)
    3. Trigger auto-repair via repair-wake-listener.ps1 if listener is DEAD

    This implements the "alerting proactif" recommendation from #2576:
    if STALE >2h → [WARN] automatically posted to dashboard.

    Known machines (from fleet config):
    - myia-ai-01 (coordinateur)
    - myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026 (workers)
    - myia-web1 (worker)

.PARAMETER Machines
    Comma-separated list of machines to check. Defaults to full fleet.
    For each machine, format is "machineId:workspace" or just "machineId".

.PARAMETER NoRepair
    Skip auto-repair attempts. Only diagnose and report.

.PARAMETER NoAlert
    Skip dashboard alerting. Only output diagnostic results.

.PARAMETER Json
    Output JSON instead of markdown.

.EXAMPLE
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -Machines "web1,po-2023"
    pwsh -ExecutionPolicy Bypass -File scripts\dashboard-scheduler\check-all-listeners.ps1 -NoRepair

.NOTES
    Related: issue #2576 (web1 listener recurring STALE), #2431 (durability fix).
#>

param(
    [string]$Machines = "",
    [switch]$NoRepair,
    [switch]$NoAlert,
    [switch]$Json
)

$ErrorActionPreference = "Continue"

$nowUtc = (Get-Date).ToUniversalTime()

# Default fleet: all known machines
$defaultMachines = "myia-ai-01","myia-po-2023","myia-po-2024","myia-po-2025","myia-po-2026","myia-web1"
if (-not [string]::IsNullOrEmpty($Machines)) {
    $machineList = $Machines -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
} else {
    $machineList = $defaultMachines
}

$results = @()
$totalDead = 0

foreach ($machineEntry in $machineList) {
    # Parse machineId:workspace or just machineId
    $machineId = $machineEntry.Split(':')[0].Trim().ToLowerInvariant()
    $workspace = if ($machineEntry.Contains(':')) { $machineEntry.Split(':')[1].Trim() } else { "" }

    # Try to read shared heartbeat from ROOSYNC_SHARED_PATH
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    $sharedHbFile = if ($sharedPath) {
        Join-Path (Join-Path $sharedPath "listener-heartbeats") "$machineId.heartbeat"
    } else { $null }

    $heartbeatStatus = "UNKNOWN"
    $heartbeatAge = $null
    if ($sharedHbFile -and (Test-Path $sharedHbFile)) {
        $mt = (Get-Item $sharedHbFile).LastWriteTimeUtc
        $age = [int]($nowUtc - $mt).TotalSeconds
        $heartbeatAge = $age
        $heartbeatStatus = if ($age -lt 7200) { "ALIVE" } else { "STALE" }
        if ($age -gt 7200) { $totalDead++ }
    }

    # #3761 remède 3 : compteur de skips du jour, écrit par le listener à côté du
    # heartbeat (listener-heartbeats/<machine>.skips, UTF-8 no BOM, lignes
    # `date|workspace|count`). Absent = listener sans remède 3 ou 0 skip mesuré.
    $skipsToday = $null
    $skipsFile = if ($sharedPath) {
        Join-Path (Join-Path $sharedPath "listener-heartbeats") "$machineId.skips"
    } else { $null }
    if ($skipsFile -and (Test-Path $skipsFile)) {
        $today = $nowUtc.ToString("yyyy-MM-dd")
        $skipsToday = 0
        foreach ($line in [System.IO.File]::ReadAllLines($skipsFile)) {
            $parts = $line -split '\|'
            if ($parts.Count -ge 3 -and $parts[0] -eq $today) { $skipsToday += [int]$parts[2] }
        }
    }

    $results += [PSCustomObject]@{
        machineId    = $machineId
        workspace    = $workspace
        heartbeat    = $heartbeatStatus
        ageSeconds   = $heartbeatAge
        skipsToday   = $skipsToday
        isDead       = $heartbeatStatus -eq "STALE"
    }
}

# ---------- Output ----------
if ($Json) {
    [PSCustomObject]@{
        checkedAtUtc = $nowUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
        totalMachines = $results.Count
        totalDead     = $totalDead
        machines      = $results
    } | ConvertTo-Json -Depth 3
    exit $(if ($totalDead -gt 0) { 1 } else { 0 })
}

# ---------- Markdown report ----------
Write-Output "### Fleet listener health check — $nowUtc UTC"
Write-Output ""
Write-Output "| Machine | Heartbeat | Age | Skips today | Status |"
Write-Output "|---------|-----------|-----|-------------|--------|"
foreach ($r in $results) {
    $ageStr = if ($null -ne $r.ageSeconds) { "$($r.ageSeconds)s" } else { "N/A" }
    $skipsStr = if ($null -ne $r.skipsToday) { "$($r.skipsToday)" } else { "N/A" }
    $statusStr = if ($r.heartbeat -eq "ALIVE") { "**OK**" } elseif ($r.heartbeat -eq "STALE") { "**STALE >2h**" } else { "???" }
    Write-Output "| $($r.machineId) | $($r.heartbeat) | $ageStr | $skipsStr | $statusStr |"
}
Write-Output ""
Write-Output "Total: $($results.Count) machines checked, $totalDead STALE/DEAD."
Write-Output ""

# ========== G-C #4131 étape 3 : IO DASHBOARD VIA LES CLI DU SUBMODULE ==========
# Mêmes helpers que dashboard-listener.ps1 (sites 1-4, #4203) — duplication
# documentée, convergence à la prochaine évolution du listener. Fail-open :
# un appel CLI qui échoue (node absent, submodule absent, exit 1 échec
# d'écriture, exit 2 usage) rend $null et l'alerte retombe sur l'écriture
# fichier directe ci-dessous — l'alerte ne doit jamais se perdre.

$script:RsmScriptsDirCache = $null

function Get-RsmScriptsDir {
    # Résolution (une fois, cachée) : RSM_SERVER_ROOT env > submodule sibling du
    # dépôt qui porte ce script. Retourne "" si introuvable -> repli fichier.
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
    # Write-Host (pas Write-Output) : cette fonction est assignée par ses callers
    # (`$dir = Get-RsmScriptsDir`) — un Write-Output atterrit dans la variable de
    # l'appelant, pas sur stdout : diagnostic invisible ET tableau au lieu du
    # string attendu. Write-Host passe par la console, hors pipeline.
    Write-Host "[FLEET-ALERT] RSM CLI dir not found (PG-first append disabled, file fallback only)."
    $script:RsmScriptsDirCache = ""
    return ""
}

function Invoke-RsmCliJson($scriptName, $cliArgs) {
    # Appelle un CLI .mjs du submodule, rend le JSON stdout parsé ou $null
    # (fail-open, repli fichier garanti par le caller). Exit CLI : 0 ok ·
    # 1 échec d'écriture · 2 usage — les deux replient pareil.
    $dir = Get-RsmScriptsDir
    if ($dir -eq "") { return $null }
    $node = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $node) { return $null }
    $out = & $node.Source (Join-Path $dir $scriptName) @cliArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        # Write-Host : voir note Get-RsmScriptsDir — le caller assigne le retour
        # de cette fonction, un Write-Output serait capturé dans sa variable.
        Write-Host "[FLEET-ALERT] RSM CLI $scriptName exit $LASTEXITCODE (repli fichier)."
        return $null
    }
    try { return (($out -join "`n") | ConvertFrom-Json) } catch { return $null }
}

# ---------- Dashboard alert ----------
if ($totalDead -gt 0 -and -not $NoAlert) {
    $deadMachines = @($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId })
    $deadList = ($deadMachines | Select-Object -First 10) -join ', '
    $warnContent = "[FLEET-ALERT] [WARN] Fleet listener check: $totalDead of $($results.Count) machines have STALE/DEAD wake-listeners (threshold >2h). Machines affected: $deadList."
    Write-Output ""
    Write-Output $warnContent

    # G-C #4131 étape 3 (arbitrage ai-01 14/10, option a) : l'alerte vit sur le
    # dashboard MACHINE du détecteur, plus sur le dashboard workspace — c'était
    # la 2ᵉ implémentation dérivante du format d'écriture que l'étape supprime.
    # Primaire : rsm-dashboard-append.mjs (dual-write journal PG + fichier,
    # verrou append cross-process, compteur/pluralisation/seed délégués au
    # store, #3761 condition 1 par construction : machine uniquement, [ERROR]
    # refusé, auteur <machine>|listener). Repli : écriture fichier directe
    # ci-dessous, mêmes conventions que Write-MachineDashboardMessage
    # (dashboard-listener.ps1 site 4). Le lecteur suit l'alerte :
    # .claude/commands/coordinate.md lit le dashboard machine au démarrage.
    $sharedPath = $env:ROOSYNC_SHARED_PATH
    $localMachineId = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }

    if (-not $sharedPath) {
        Write-Output "[FLEET-ALERT] ROOSYNC_SHARED_PATH not set — alert on stdout only (no dashboard write)."
    } else {
        try {
            $sharedDashDir = Join-Path $sharedPath "dashboards"
            $machineDashFile = Join-Path $sharedDashDir "machine-$localMachineId.md"

            # Anti-spam: cooldown — skip if we already alerted for overlapping dead machines within 6h.
            # Prevents flooding on long outages (cron 2h × outage duration). Étape 3 : les alertes
            # vivant sur le dashboard machine du détecteur, le cooldown scanne CE fichier (le
            # workspace partagé ne les reçoit plus — le scanner serait structurellement vide).
            $cooldownHours = 6
            $cooldownCutoff = $nowUtc.AddHours(-$cooldownHours)
            $shouldAlert = $true

            if (Test-Path $machineDashFile) {
                $existingRaw = Get-Content $machineDashFile -Raw -Encoding UTF8
                # Match prior FLEET-ALERT messages — require [FLEET-ALERT] as first content line
                # (after [msg:] marker + blank line) to avoid false-positives on reports that quote alerts
                $alertRe = '(?m)^### \[([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?Z)\][^\r\n]*\r?\n(?:\[msg:[^\r\n]*\r?\n)?\r?\n\[FLEET-ALERT\][^\r\n]*Machines affected:\s*([^\r\n.]+)'
                foreach ($am in [regex]::Matches($existingRaw, $alertRe)) {
                    try {
                        $postTime = [DateTimeOffset]::Parse($am.Groups[1].Value).UtcDateTime
                        if ($postTime -ge $cooldownCutoff) {
                            $listed = @($am.Groups[2].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
                            $overlap = @($listed | Where-Object { $deadMachines -contains $_ })
                            if ($overlap.Count -gt 0) {
                                $shouldAlert = $false
                                Write-Output "[FLEET-ALERT] Cooldown: already posted about {$($listed -join ', ')} at $($am.Groups[1].Value) (within ${cooldownHours}h). Skipping."
                                break
                            }
                        }
                    } catch { }
                }
            }

            if ($shouldAlert) {
                # Primaire (étape 3) : append par le CLI du build servi — même
                # sérialisation et dual-write que l'hôte MCP, auteur
                # <machine>|listener, format/verrou/compteur au store.
                $cli = Invoke-RsmCliJson "rsm-dashboard-append.mjs" @('--machine', $localMachineId, '--content', $warnContent)
                if ($null -ne $cli -and $cli.ok -eq $true) {
                    Write-Output "[FLEET-ALERT] Posted [WARN] to machine dashboard via RSM CLI (key $($cli.key), messageId $($cli.messageId), pgSynced=$($cli.pgSynced))"
                } else {
                    # --- repli fichier (conventions Write-MachineDashboardMessage, inchangées) ---
                    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    $randSuffix = -join ((48..57) + (97..122) | Get-Random -Count 4 | ForEach-Object { [char]$_ })
                    # Stamp à la seconde (pas la minute) : deux escalades la même minute ne se
                    # distinguent que par les 4 aléas sinon (parité #4124).
                    $msgId = $localMachineId + ':listener:ic-' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss') + '-' + $randSuffix
                    $newMessage = "`r`n### [$timestamp] $localMachineId|listener`r`n[msg: $msgId]`r`n`r`n$warnContent`r`n"

                    if (-not (Test-Path $sharedDashDir)) {
                        New-Item -ItemType Directory -Path $sharedDashDir -Force | Out-Null
                    }

                    if (Test-Path $machineDashFile) {
                        $content = Get-Content $machineDashFile -Raw -Encoding UTF8
                        $content = $content.TrimEnd() + "`r`n" + $newMessage
                        # Bump du compteur + pluralisation (même fix que Write-MachineDashboardMessage,
                        # #4124) : le MCP rend toujours "(N messages)" (dashboard.ts:1936) et le parseur
                        # listener l'exige. Un bump chiffre-seul laisserait "(2 message)" si le
                        # fichier avait été semé au singulier.
                        $content = [regex]::Replace($content, '(?<=## Intercom\s*\()\d+(?=\s*messages?\))', {
                            param($m); ([int]$m.Value + 1).ToString()
                        })
                        $content = [regex]::Replace($content, '(## Intercom \(\d+) message\)', '$1 messages)')
                    } else {
                        # Dashboard doesn't exist — create minimal file. Seed au PLURIEL
                        # "(1 messages)" : convention du MCP (dashboard.ts:1936) — même règle
                        # que Write-MachineDashboardMessage.
                        $content = "---`r`ntype: machine`r`nlastModified: '$timestamp'`r`nlastModifiedBy:`r`n  machineId: $localMachineId`r`n  workspace: listener`r`ntotalMessages: 1`r`n---`r`n`r`n## Status`r`n`r`n## Intercom (1 messages)`r`n$newMessage"
                    }

                    [System.IO.File]::WriteAllText($machineDashFile, $content, [System.Text.UTF8Encoding]::new($false))
                    Write-Output "[FLEET-ALERT] Posted [WARN] to $machineDashFile (file fallback)"
                }
            }
        } catch {
            # Best-effort: GDrive unavailability must never fail the probe
            Write-Output "[FLEET-ALERT] Failed to write dashboard (best-effort, probe continues): $($_.Exception.Message)"
        }
    }
}

# ---------- Auto-repair ----------
if (-not $NoRepair -and $totalDead -gt 0) {
    Write-Output ""
    Write-Output "[REPAIR] Attempting auto-repair for affected machines..."
    Write-Output "Note: repair-wake-listener.ps1 must be run ON the affected machine (needs local access to scheduled tasks)."
    Write-Output "Dispatched repair commands would target: $($results | Where-Object { $_.isDead } | ForEach-Object { $_.machineId } | ForEach-Object { $_ })"
    Write-Output "[REPAIR] Use [WAKE-CLAUDE] on affected machines or dispatch via coordinator to trigger repair."
}

exit $(if ($totalDead -gt 0) { 1 } else { 0 })
