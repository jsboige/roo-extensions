# Behaviour tests for scripts/monitoring/metered-link-watch.ps1
#
# They EXECUTE the classification functions (dot-sourced, the main body is
# skipped on dot-source): no network, no WinRT, so they run under pwsh 7 on
# the ubuntu CI runner as well as under 5.1.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/monitoring/metered-link-watch.ps1")
    function New-Sample([int64]$epoch, [int64]$rx, [int64]$tx, [string]$id = 'wifi') {
        [pscustomobject]@{ Epoch = $epoch; AdapterId = $id; RxBytes = $rx; TxBytes = $tx }
    }
}

Describe "Test-MeteredLink" {
    It "Fixed and Variable costs are billed" {
        Test-MeteredLink -CostType 'Fixed' -ProfileName 'x' | Should -BeTrue
        Test-MeteredLink -CostType 'Variable' -ProfileName 'x' | Should -BeTrue
    }
    It "An unrestricted link is not billed" {
        Test-MeteredLink -CostType 'Unrestricted' -ProfileName 'Ethernet' | Should -BeFalse
    }
    It "A listed profile is billed even when Windows reports it unrestricted" {
        Test-MeteredLink -CostType 'Unrestricted' -ProfileName 'Jesse hotspot' -MeteredProfiles @('Jesse hotspot') | Should -BeTrue
    }
    It "Roaming or a data-limit flag is billed whatever the cost type" {
        Test-MeteredLink -CostType 'Unrestricted' -Roaming $true -ProfileName 'x' | Should -BeTrue
        Test-MeteredLink -CostType 'Unknown' -OverLimit $true -ProfileName 'x' | Should -BeTrue
    }
    It "A phone shared over USB is billed even when Windows reports it unrestricted" {
        Test-MeteredLink -CostType 'Unrestricted' -ProfileName 'Reseau 29' `
            -AdapterDescription 'SAMSUNG Mobile USB Remote NDIS Network Device' `
            -TetherAdapterPattern 'Remote NDIS|Apple Mobile Device Ethernet' | Should -BeTrue
    }
    It "An ordinary Ethernet adapter is not billed by the tether pattern" {
        Test-MeteredLink -CostType 'Unrestricted' -ProfileName 'Reseau 29' `
            -AdapterDescription 'Intel(R) Ethernet Connection (17) I219-LM' `
            -TetherAdapterPattern 'Remote NDIS|Apple Mobile Device Ethernet' | Should -BeFalse
    }
    It "A phone shared over USB is billed even when the caller omits the pattern" {
        # The default must be the shared pattern. An empty default would let a
        # direct call pass green while ignoring the tether -- the shape of the
        # defect that cost ~20 GB on 2026-10-26.
        Test-MeteredLink -CostType 'Unrestricted' -ProfileName 'Reseau 29' `
            -AdapterDescription 'SAMSUNG Mobile USB Remote NDIS Network Device' | Should -BeTrue
    }
}

Describe "Get-LinkDelta" {
    It "The first sample is a baseline" {
        (Get-LinkDelta -Previous $null -Current (New-Sample 600 10 10)).Status | Should -Be 'BASELINE'
    }
    It "Sums received and sent bytes over the elapsed minutes" {
        $d = Get-LinkDelta -Previous (New-Sample 0 100 50) -Current (New-Sample 900 1100 250)
        $d.Status | Should -Be 'DELTA'
        $d.Bytes | Should -Be 1200
        $d.Minutes | Should -Be 15
    }
    It "Counters that went down (reboot, reconnect) re-baseline instead of a negative volume" {
        (Get-LinkDelta -Previous (New-Sample 0 5GB 1GB) -Current (New-Sample 900 2MB 1MB)).Status | Should -Be 'BASELINE'
    }
    It "Another adapter re-baselines: its counters are not comparable" {
        (Get-LinkDelta -Previous (New-Sample 0 1 1 'ethernet') -Current (New-Sample 900 5GB 1 'wifi')).Status | Should -Be 'BASELINE'
    }
}

Describe "Get-WatchVerdict" {
    BeforeAll {
        $heavy = [pscustomobject]@{ Status = 'DELTA'; Bytes = 600MB; Minutes = 15 }
        $light = [pscustomobject]@{ Status = 'DELTA'; Bytes = 50MB; Minutes = 15 }
    }
    It "Heavy traffic on a billed link alerts" {
        Get-WatchVerdict -Metered $true -Delta $heavy -ThresholdBytes 500MB -LastAlertEpoch $null -NowEpoch 10000 -CooldownMinutes 60 | Should -Be 'ALERT'
    }
    It "The same traffic on an unbilled link stays quiet" {
        Get-WatchVerdict -Metered $false -Delta $heavy -ThresholdBytes 500MB -LastAlertEpoch $null -NowEpoch 10000 -CooldownMinutes 60 | Should -Be 'QUIET'
    }
    It "Light traffic on a billed link stays quiet" {
        Get-WatchVerdict -Metered $true -Delta $light -ThresholdBytes 500MB -LastAlertEpoch $null -NowEpoch 10000 -CooldownMinutes 60 | Should -Be 'QUIET'
    }
    It "A baseline never alerts" {
        $base = [pscustomobject]@{ Status = 'BASELINE'; Bytes = 0; Minutes = 0 }
        Get-WatchVerdict -Metered $true -Delta $base -ThresholdBytes 1 -LastAlertEpoch $null -NowEpoch 10000 -CooldownMinutes 60 | Should -Be 'QUIET'
    }
    It "An alert inside the cooldown is held, and fires again once it has elapsed" {
        Get-WatchVerdict -Metered $true -Delta $heavy -ThresholdBytes 500MB -LastAlertEpoch 10000 -NowEpoch (10000 + 59 * 60) -CooldownMinutes 60 | Should -Be 'COOLDOWN'
        Get-WatchVerdict -Metered $true -Delta $heavy -ThresholdBytes 500MB -LastAlertEpoch 10000 -NowEpoch (10000 + 60 * 60) -CooldownMinutes 60 | Should -Be 'ALERT'
    }
}
