<#
.SYNOPSIS
    Shared classification of a Windows internet link: is it billed?

.DESCRIPTION
    One implementation, shared by the consumers that must agree on the answer:
      - scripts/monitoring/metered-link-watch.ps1 (alerts the fleet on volume)
      - scripts/monitoring/test-link-billed.ps1 (CLI: a scheduled task asks it
        before it starts anything heavy)

    The 2026-10-26 bandwidth leak (about 20 GB over a billed phone link in two
    hours) showed that "billed" has more than one shape. The user's mobile
    subscription is used two ways, and BOTH must be recognised:
      1. a phone shared over USB ("modem USB"). Windows presents it as a plain
         Ethernet link and reports the cost as Unrestricted. Only the adapter
         description reveals it: "Remote NDIS", "Apple Mobile Device Ethernet".
      2. the phone's Wi-Fi hotspot ("hotspot"). Windows reports the cost as
         Fixed once the metered flag is set, but that flag is a local setting
         that a reinstall or a new network profile can lose. The profile NAME
         is a second, independent signal.

    Cost type alone therefore never decides. The verdict is the union of three
    signals, and the reason says which one fired.

    Fail-open is NOT the design here. When the probe cannot answer, the
    verdict is UNKNOWN, a third outcome: the caller decides. A gate that
    protects a budget and a gate that keeps CI running pull in opposite
    directions, so this module does not pick for them -- it reports.

.NOTES
    Dot-source this file; it has no side effects and never exits.
    Windows PowerShell 5.1 only for the probe (the WinRT type accelerator does
    not exist in pwsh 7). The classification itself is engine-agnostic and is
    what the unit tests exercise.
#>

# A phone shared over USB, whatever the cost Windows reports.
$script:DefaultTetherAdapterPattern = 'Remote NDIS|Apple Mobile Device Ethernet|USB RNDIS'

function Get-LinkProfileInfo {
    <#
    .SYNOPSIS
        Reads the current internet profile: cost, flags, profile name, adapter.
    .OUTPUTS
        A PSCustomObject, or $null when there is no internet profile.
    #>
    try {
        $null = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime]
    } catch {
        throw 'WinRT connectivity API unavailable: run this under Windows PowerShell 5.1 (powershell.exe)'
    }
    $p = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
    if (-not $p) { return $null }
    $cost = $p.GetConnectionCost()
    $guid = $p.NetworkAdapter.NetworkAdapterId
    $adapter = Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { [guid]$_.InterfaceGuid -eq $guid } | Select-Object -First 1
    return [pscustomobject]@{
        CostType            = "$($cost.NetworkCostType)"
        Roaming             = [bool]$cost.Roaming
        ApproachingDataLimit = [bool]$cost.ApproachingDataLimit
        OverDataLimit       = [bool]$cost.OverDataLimit
        ProfileName         = "$($p.ProfileName)"
        AdapterId           = $guid.ToString()
        AdapterName         = if ($adapter) { "$($adapter.Name)" } else { '' }
        AdapterDescription  = if ($adapter) { "$($adapter.InterfaceDescription)" } else { '' }
    }
}

function Test-LinkBilled {
    <#
    .SYNOPSIS
        True when the link is billed. False when it is not.
    .DESCRIPTION
        The union of three independent signals:
          - the Windows cost type is Fixed or Variable, or a roaming / data
            limit flag is raised;
          - the profile name is in -MeteredProfiles (case-insensitive), which
            survives the loss of the metered flag on a known hotspot;
          - the adapter description matches the tether pattern, which is the
            only signal that sees a phone shared over USB.
        A profile name matches case-insensitively: Windows reports "Jesse
        hotspot", operators write "Jesse Hotspot".
    #>
    param(
        $Link,
        [string[]]$MeteredProfiles = @(),
        [string]$TetherAdapterPattern = $script:DefaultTetherAdapterPattern
    )
    if (-not $Link) { return $false }

    if ($Link.CostType -eq 'Fixed' -or $Link.CostType -eq 'Variable') { return $true }
    if ($Link.Roaming -or $Link.ApproachingDataLimit -or $Link.OverDataLimit) { return $true }

    if ($MeteredProfiles -and $MeteredProfiles.Count -gt 0) {
        foreach ($candidate in $MeteredProfiles) {
            if ($candidate -and $Link.ProfileName -and $Link.ProfileName -eq $candidate) { return $true }
        }
    }

    if ($TetherAdapterPattern -and $Link.AdapterDescription -and
        $Link.AdapterDescription -match $TetherAdapterPattern) { return $true }

    return $false
}

function Get-LinkBillingReason {
    <#
    .SYNOPSIS
        Why the link is billed, or $null when it is not.
    #>
    param(
        $Link,
        [string[]]$MeteredProfiles = @(),
        [string]$TetherAdapterPattern = $script:DefaultTetherAdapterPattern
    )
    if (-not $Link) { return $null }
    if ($Link.CostType -eq 'Fixed' -or $Link.CostType -eq 'Variable') { return "cost=$($Link.CostType)" }
    if ($Link.Roaming) { return 'roaming' }
    if ($Link.ApproachingDataLimit) { return 'approaching-data-limit' }
    if ($Link.OverDataLimit) { return 'over-data-limit' }
    if ($MeteredProfiles) {
        foreach ($candidate in $MeteredProfiles) {
            if ($candidate -and $Link.ProfileName -and $Link.ProfileName -eq $candidate) {
                return "profile=$($Link.ProfileName)"
            }
        }
    }
    if ($TetherAdapterPattern -and $Link.AdapterDescription -and
        $Link.AdapterDescription -match $TetherAdapterPattern) {
        return "tether-adapter=$($Link.AdapterDescription)"
    }
    return $null
}
