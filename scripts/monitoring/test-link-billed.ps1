<#
.SYNOPSIS
    Tell whether the current internet link is billed, for a scheduled task that
    is about to start something heavy.

.DESCRIPTION
    The 2026-10-26 bandwidth leak: the CI runners on po-2027 kept running over
    a billed phone link, and the Windows task that relaunched them every five
    minutes did not know it. A task that asks this question first turns
    itself into the guard instead of the resurrector.

    This is the CLI wrapper over scripts/monitoring/link-qualification.ps1.
    It prints one line whose first word is the verdict, and sets an exit code:

      UNBILLED    exit 0   the link is not billed -- heavy work is fine
      BILLED      exit 3   the link is billed -- do not start heavy work
      UNKNOWN     exit 4   the probe could not answer -- the caller decides

    UNKNOWN is a third outcome on purpose. A gate that protects a budget and a
    gate that keeps CI running pull in opposite directions; a gate that
    silently picks one of them is wrong by construction. The caller decides:
      - a CI runner that must not burn a metered link: treat UNKNOWN as billed;
      - a CI runner that must not stall the queue: treat UNKNOWN as unbilled,
        and rely on the volume watch (scripts/monitoring/metered-link-watch.ps1)
        to report the traffic anyway.
    Either way, "exit 0" alone is not enough to mean "go": read the first word.

    A known hotspot name can be forced billed through -MeteredProfiles or the
    ROO_METERED_PROFILES environment variable (';'-separated). That is the
    second signal for a phone hotspot whose Windows metered flag was lost: the
    cost type says Unrestricted, the adapter is ordinary Wi-Fi, and only the
    profile name still identifies it.

    A phone shared over USB needs no configuration: the adapter description
    ("Remote NDIS", "Apple Mobile Device Ethernet") is recognised as billed.

    From WSL, call it through the interop path:
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File <path>/test-link-billed.ps1

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\monitoring\test-link-billed.ps1
    # prints e.g. "BILLED reason=tether-adapter=... profile='Reseau 29' cost=Unrestricted"

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts\monitoring\test-link-billed.ps1 -MeteredProfiles 'Jesse hotspot'
#>
param(
    [string[]]$MeteredProfiles = @(($env:ROO_METERED_PROFILES -split ';') | Where-Object { $_ }),
    [string]$TetherAdapterPattern = '',
    [switch]$Quiet
)

$ErrorActionPreference = 'Continue'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$helper = Join-Path $scriptDir 'link-qualification.ps1'
if (-not (Test-Path -LiteralPath $helper)) {
    Write-Output 'UNKNOWN reason=helper-missing'
    exit 4
}
. $helper

if (-not $TetherAdapterPattern) { $TetherAdapterPattern = $script:DefaultTetherAdapterPattern }

try {
    $link = Get-LinkProfileInfo
} catch {
    if (-not $Quiet) { Write-Output "UNKNOWN reason=probe-failed detail=$($_.Exception.Message)" }
    exit 4
}

if (-not $link) {
    if (-not $Quiet) { Write-Output 'UNKNOWN reason=no-internet-profile' }
    exit 4
}

$billed = Test-LinkBilled -Link $link -MeteredProfiles $MeteredProfiles -TetherAdapterPattern $TetherAdapterPattern
if ($billed) {
    $reason = Get-LinkBillingReason -Link $link -MeteredProfiles $MeteredProfiles -TetherAdapterPattern $TetherAdapterPattern
    if (-not $Quiet) {
        Write-Output ("BILLED reason={0} profile='{1}' adapter='{2}' cost={3}" -f `
            $reason, $link.ProfileName, $link.AdapterDescription, $link.CostType)
    }
    exit 3
}

if (-not $Quiet) {
    Write-Output ("UNBILLED profile='{0}' adapter='{1}' cost={2}" -f `
        $link.ProfileName, $link.AdapterDescription, $link.CostType)
}
exit 0
