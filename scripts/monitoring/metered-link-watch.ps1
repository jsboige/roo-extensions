<#
.SYNOPSIS
    Alert the fleet when a machine pulls heavy traffic over a metered (billed) link.

.DESCRIPTION
    Bandwidth leak of 2026-10-26: about 20 GB went over a billed phone hotspot in
    two hours and no agent noticed. Windows data usage (SRUM) cannot be the
    instrument: traffic NATed into WSL never reaches its per-app counters
    (measured on ai-01 since boot: 887 GB received by the adapter and absent
    from SRUM, equal within 0.2 % to what the host forwarded to the WSL VM).

    This watch reads the RAW byte counters of the adapter that carries the
    internet profile, so VM, container and CI-runner traffic all count. Each
    run compares them with the previous sample kept in -StatePath. When the
    link is metered and the volume since the previous sample reaches
    -ThresholdMB, it posts a [WARN] on the GLOBAL dashboard through
    rsm-dashboard-append.mjs (deterministic, no LLM spawned), at most once per
    -CooldownMinutes.

    Run it every 15 minutes from a user scheduled task, under Windows
    PowerShell 5.1 (the WinRT connection-cost API is not reachable from pwsh 7;
    there the link counts as metered only through -MeteredProfiles).

.PARAMETER ThresholdMB
    Volume (Rx + Tx) since the previous sample that triggers the alert.

.PARAMETER MeteredProfiles
    Profile names (Wi-Fi SSID) treated as billed even when Windows reports the
    link as unrestricted. Default: $env:ROO_METERED_PROFILES (';'-separated).

.PARAMETER TetherAdapterPattern
    Regex on the adapter description. A matching adapter is a phone shared
    over USB, billed whatever Windows reports: the 2026-10-26 leak ran over
    "SAMSUNG Mobile USB Remote NDIS Network Device", a plain Ethernet link to
    Windows, with no Wi-Fi profile to list.

.PARAMETER NoAlert
    Measure and print the verdict, never post.

.NOTES
    Exit codes: 0 quiet or baseline, 3 alert, 2 WinRT unavailable (wrong engine).
    Install (user task, no elevation), from the checkout that holds this script:
      schtasks /create /tn "RooMeteredLinkWatch" /sc minute /mo 15 /f /tr
        "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File <checkout>\scripts\monitoring\metered-link-watch.ps1"
#>
param(
    [int]$ThresholdMB = 500,
    [int]$CooldownMinutes = 60,
    [string[]]$MeteredProfiles = @(($env:ROO_METERED_PROFILES -split ';') | Where-Object { $_ }),
    [string]$TetherAdapterPattern = '',
    [string]$StatePath = '',
    [switch]$NoAlert
)

# The classification itself lives in link-qualification.ps1, shared with
# test-link-billed.ps1: one implementation, so the watch and the CI gate can
# never disagree about what "billed" means. This wrapper keeps the watch's own
# parameter shape (its tests call it that way).
$script:LinkHelperPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'link-qualification.ps1'
if (-not (Test-Path -LiteralPath $script:LinkHelperPath)) {
    throw "link-qualification.ps1 not found next to this script ($script:LinkHelperPath)"
}
. $script:LinkHelperPath
if (-not $TetherAdapterPattern) { $TetherAdapterPattern = $script:DefaultTetherAdapterPattern }

function Test-MeteredLink {
    param([string]$CostType, [bool]$Roaming, [bool]$ApproachingLimit, [bool]$OverLimit,
          [string]$ProfileName, [string[]]$MeteredProfiles = @(),
          [string]$AdapterDescription = '', [string]$TetherAdapterPattern = '')
    $link = [pscustomobject]@{
        CostType = $CostType; Roaming = $Roaming; ApproachingDataLimit = $ApproachingLimit
        OverDataLimit = $OverLimit; ProfileName = $ProfileName; AdapterDescription = $AdapterDescription
    }
    return Test-LinkBilled -Link $link -MeteredProfiles $MeteredProfiles -TetherAdapterPattern $TetherAdapterPattern
}

# Counters restart at zero after a reboot or a reconnect, and a new adapter
# has its own: in both cases the delta is meaningless, so the sample becomes
# the new baseline instead of producing a negative or foreign volume.
function Get-LinkDelta {
    param($Previous, $Current)
    if (-not $Previous -or $Previous.AdapterId -ne $Current.AdapterId) {
        return [pscustomobject]@{ Status = 'BASELINE'; Bytes = 0; Minutes = 0 }
    }
    # A sample whose counters could not be read is not a measurement. Comparing
    # it with a real one would either invent a negative volume or, the other way
    # round, turn the next good sample into a huge false delta.
    $currentHasCounters = $true
    if ($null -ne $Current.PSObject.Properties['CountersAvailable']) {
        $currentHasCounters = [bool]$Current.CountersAvailable
    }
    $previousHasCounters = $true
    if ($null -ne $Previous.PSObject.Properties['CountersAvailable']) {
        $previousHasCounters = [bool]$Previous.CountersAvailable
    }
    if (-not $currentHasCounters -or -not $previousHasCounters) {
        return [pscustomobject]@{ Status = 'BASELINE'; Bytes = 0; Minutes = 0 }
    }
    $rx = [int64]$Current.RxBytes - [int64]$Previous.RxBytes
    $tx = [int64]$Current.TxBytes - [int64]$Previous.TxBytes
    if ($rx -lt 0 -or $tx -lt 0) {
        return [pscustomobject]@{ Status = 'BASELINE'; Bytes = 0; Minutes = 0 }
    }
    $minutes = ([int64]$Current.Epoch - [int64]$Previous.Epoch) / 60
    return [pscustomobject]@{ Status = 'DELTA'; Bytes = $rx + $tx; Minutes = [math]::Round($minutes, 1) }
}

function Get-WatchVerdict {
    param([bool]$Metered, $Delta, [int64]$ThresholdBytes, $LastAlertEpoch, [int64]$NowEpoch, [int]$CooldownMinutes)
    if (-not $Metered -or $Delta.Status -ne 'DELTA' -or $Delta.Bytes -lt $ThresholdBytes) { return 'QUIET' }
    if ($LastAlertEpoch -and ($NowEpoch - [int64]$LastAlertEpoch) -lt $CooldownMinutes * 60) { return 'COOLDOWN' }
    return 'ALERT'
}

function Get-InternetLinkSample {
    # The profile read is shared with test-link-billed.ps1 (link-qualification.ps1),
    # so the watch and the CI gate qualify a link the same way.
    $link = Get-LinkProfileInfo
    if (-not $link) { return $null }
    # An adapter that cannot be resolved leaves the counters unreadable, but the
    # cost type, the profile name and the flags still qualify the link: losing
    # the whole sample would hide a metered link behind a lookup hiccup.
    $stats = $null
    if ($link.AdapterName) {
        try { $stats = Get-NetAdapterStatistics -Name $link.AdapterName -ErrorAction Stop } catch { $stats = $null }
    }
    return [pscustomobject]@{
        Epoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); AdapterId = $link.AdapterId
        Adapter = $link.AdapterName
        AdapterDescription = $link.AdapterDescription; Profile = $link.ProfileName; CostType = $link.CostType
        Roaming = $link.Roaming
        ApproachingLimit = $link.ApproachingDataLimit; OverLimit = $link.OverDataLimit
        CountersAvailable = [bool]$stats
        RxBytes = if ($stats) { [int64]$stats.ReceivedBytes } else { 0 }
        TxBytes = if ($stats) { [int64]$stats.SentBytes } else { 0 }
    }
}

if ($MyInvocation.InvocationName -eq '.') { return }
if (-not $StatePath) { $StatePath = Join-Path $env:LOCALAPPDATA 'roo-extensions\metered-link-watch.json' }

try { $sample = Get-InternetLinkSample } catch { Write-Output "[metered-link-watch] $($_.Exception.Message)"; exit 2 }
if (-not $sample) { Write-Output '[metered-link-watch] no internet profile -- nothing to measure'; exit 0 }

$state = $null
if (Test-Path $StatePath) { try { $state = Get-Content $StatePath -Raw | ConvertFrom-Json } catch { } }
$metered = Test-MeteredLink -CostType $sample.CostType -Roaming $sample.Roaming -ApproachingLimit $sample.ApproachingLimit `
    -OverLimit $sample.OverLimit -ProfileName $sample.Profile -MeteredProfiles $MeteredProfiles `
    -AdapterDescription $sample.AdapterDescription -TetherAdapterPattern $TetherAdapterPattern
$delta = Get-LinkDelta -Previous $state -Current $sample
$lastAlert = if ($state) { $state.LastAlertEpoch } else { $null }
$verdict = Get-WatchVerdict -Metered $metered -Delta $delta -ThresholdBytes ([int64]$ThresholdMB * 1MB) `
    -LastAlertEpoch $lastAlert -NowEpoch $sample.Epoch -CooldownMinutes $CooldownMinutes

$mb = [math]::Round($delta.Bytes / 1MB)
Write-Output ("[metered-link-watch] {0} profile='{1}' adapter='{2}' cost={3} metered={4} delta={5} MB in {6} min" -f `
    $verdict, $sample.Profile, $sample.Adapter, $sample.CostType, $metered, $mb, $delta.Minutes)
if ($sample.CountersAvailable -eq $false) {
    # The link is still qualified (cost, profile, adapter), but the volume could
    # not be measured. Say so: a watch that cannot count must not look like a
    # watch that counted nothing.
    Write-Output "[metered-link-watch] WARNING adapter counters unreadable for '$($sample.Adapter)' -- volume not measured this run"
}

if ($verdict -eq 'ALERT' -and -not $NoAlert) {
    $machine = if ($env:ROOSYNC_MACHINE_ID) { $env:ROOSYNC_MACHINE_ID.ToLowerInvariant() } else { $env:COMPUTERNAME.ToLowerInvariant() }
    $content = "[WARN] Metered link: $machine pulled $mb MB in $($delta.Minutes) min over '$($sample.Profile)' " +
        "(adapter $($sample.Adapter), Windows cost $($sample.CostType)). Raw adapter counters: WSL, Docker and CI-runner " +
        "traffic included, which Windows data usage does not show. Pause CI runners, indexing and syncs while on this link."
    $rsmRoot = if ($env:RSM_SERVER_ROOT) { $env:RSM_SERVER_ROOT } else { Join-Path $PSScriptRoot '..\..\mcps\internal\servers\roo-state-manager' }
    $cli = [System.IO.Path]::GetFullPath((Join-Path $rsmRoot 'scripts\rsm-dashboard-append.mjs'))
    $msgId = "$($machine):metered-watch:" + [DateTime]::UtcNow.ToString('yyyyMMddTHHmm')
    & node $cli --machine $machine --dashboard global --message-id $msgId --author-workspace roo-extensions --content $content
    if ($LASTEXITCODE -eq 0) { $lastAlert = $sample.Epoch } else { Write-Output "[metered-link-watch] dashboard post failed (exit $LASTEXITCODE)" }
}

$sample | Add-Member -NotePropertyName LastAlertEpoch -NotePropertyValue $lastAlert -Force
$dir = Split-Path $StatePath -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
[System.IO.File]::WriteAllText($StatePath, ($sample | ConvertTo-Json), (New-Object System.Text.UTF8Encoding($false)))
if ($verdict -eq 'ALERT') { exit 3 }
exit 0
