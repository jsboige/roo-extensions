# Behaviour tests for scripts/monitoring/link-qualification.ps1 and the CLI
# scripts/monitoring/test-link-billed.ps1.
#
# The two forms of a billed mobile link are both covered, because the user's
# subscription is used both ways (26/10):
#   1. phone shared over USB  -> adapter description, Windows says Unrestricted
#   2. phone Wi-Fi hotspot    -> profile name, the metered flag can be lost
#
# They EXECUTE the classification (no network, no WinRT), so they run under
# pwsh 7 on the ubuntu CI runner as well as under 5.1.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/monitoring/link-qualification.ps1")
    function New-Link([string]$cost = 'Unrestricted', [string]$profile = 'Ethernet',
                      [string]$adapter = 'Intel(R) Ethernet Connection (17) I219-LM',
                      [bool]$roaming = $false, [bool]$approaching = $false, [bool]$over = $false) {
        [pscustomobject]@{
            CostType = $cost; Roaming = $roaming; ApproachingDataLimit = $approaching
            OverDataLimit = $over; ProfileName = $profile
            AdapterId = '0000-1111'; AdapterName = 'Ethernet'; AdapterDescription = $adapter
        }
    }
}

Describe "Get-MeteredProfiles" {
    It "Trims the names, so a space typed around one does not break the match" {
        # "ROO_METERED_PROFILES=Jesse hotspot; OtherNet" must yield "OtherNet",
        # not " OtherNet" -- the untrimmed name never matches the profile.
        $profiles = Get-MeteredProfiles -Raw 'Jesse hotspot; OtherNet'
        $profiles | Should -HaveCount 2
        $profiles[0] | Should -Be 'Jesse hotspot'
        $profiles[1] | Should -Be 'OtherNet'
    }
    It "Is empty when nothing is configured" {
        Get-MeteredProfiles -Raw '' | Should -HaveCount 0
        Get-MeteredProfiles -Raw $null | Should -HaveCount 0
    }
    It "Drops empty entries" {
        Get-MeteredProfiles -Raw 'a;;b;' | Should -HaveCount 2
    }
}

Describe "Test-LinkBilled" {
    It "Fixed and Variable costs are billed" {
        Test-LinkBilled -Link (New-Link -cost 'Fixed') | Should -BeTrue
        Test-LinkBilled -Link (New-Link -cost 'Variable') | Should -BeTrue
    }
    It "An unrestricted link is not billed" {
        Test-LinkBilled -Link (New-Link -cost 'Unrestricted') | Should -BeFalse
    }
    It "Roaming or a data-limit flag is billed whatever the cost type" {
        Test-LinkBilled -Link (New-Link -roaming $true) | Should -BeTrue
        Test-LinkBilled -Link (New-Link -approaching $true) | Should -BeTrue
        Test-LinkBilled -Link (New-Link -cost 'Unknown' -over $true) | Should -BeTrue
    }

    It "A phone shared over USB is billed even when Windows reports it unrestricted" {
        $link = New-Link -cost 'Unrestricted' -profile 'Reseau 29' `
            -adapter 'SAMSUNG Mobile USB Remote NDIS Network Device'
        Test-LinkBilled -Link $link | Should -BeTrue
    }
    It "An iPhone shared over USB is billed too" {
        $link = New-Link -cost 'Unrestricted' -profile 'iPhone' -adapter 'Apple Mobile Device Ethernet'
        Test-LinkBilled -Link $link | Should -BeTrue
    }
    It "An ordinary Ethernet adapter is not billed by the tether pattern" {
        Test-LinkBilled -Link (New-Link -cost 'Unrestricted' -profile 'Reseau 29') | Should -BeFalse
    }

    It "A listed profile is billed even when Windows reports it unrestricted" {
        $link = New-Link -cost 'Unrestricted' -profile 'Jesse hotspot'
        Test-LinkBilled -Link $link -MeteredProfiles @('Jesse hotspot') | Should -BeTrue
    }
    It "The profile name is matched case-insensitively" {
        # Windows reports "Jesse hotspot"; an operator writes "Jesse Hotspot".
        $link = New-Link -cost 'Unrestricted' -profile 'Jesse hotspot'
        Test-LinkBilled -Link $link -MeteredProfiles @('Jesse Hotspot') | Should -BeTrue
        Test-LinkBilled -Link $link -MeteredProfiles @('JESSE HOTSPOT') | Should -BeTrue
    }
    It "A profile that is not listed is not billed" {
        $link = New-Link -cost 'Unrestricted' -profile 'epf-educ'
        Test-LinkBilled -Link $link -MeteredProfiles @('Jesse hotspot') | Should -BeFalse
    }
    It "A link object that is absent is not billed" {
        Test-LinkBilled -Link $null | Should -BeFalse
    }
}

Describe "Get-LinkBillingReason" {
    It "Names the cost type when the cost says so" {
        Get-LinkBillingReason -Link (New-Link -cost 'Fixed') | Should -Be 'cost=Fixed'
    }
    It "Names the tether adapter, which is the only signal that sees a USB phone" {
        $link = New-Link -cost 'Unrestricted' -profile 'Reseau 29' `
            -adapter 'SAMSUNG Mobile USB Remote NDIS Network Device'
        Get-LinkBillingReason -Link $link | Should -BeLike 'tether-adapter=*'
    }
    It "Names the profile when the profile is what identifies it" {
        $link = New-Link -cost 'Unrestricted' -profile 'Jesse hotspot'
        Get-LinkBillingReason -Link $link -MeteredProfiles @('Jesse hotspot') | Should -Be 'profile=Jesse hotspot'
    }
    It "Is null on an unbilled link" {
        Get-LinkBillingReason -Link (New-Link -cost 'Unrestricted') | Should -BeNullOrEmpty
    }
}

Describe "test-link-billed.ps1 (CLI contract)" {
    It "The script exists next to the shared helper" {
        Test-Path (Join-Path $projectRoot "scripts/monitoring/test-link-billed.ps1") | Should -BeTrue
        Test-Path (Join-Path $projectRoot "scripts/monitoring/link-qualification.ps1") | Should -BeTrue
    }
    It "Documents the three outcomes and their exit codes" {
        $cli = Get-Content (Join-Path $projectRoot "scripts/monitoring/test-link-billed.ps1") -Raw
        $cli | Should -Match 'UNBILLED'
        $cli | Should -Match 'BILLED'
        $cli | Should -Match 'UNKNOWN'
        $cli | Should -Match 'exit 4'
    }
    It "The watch and the gate share one implementation" {
        # The watch must classify links through the shared helper, not through
        # its own copy: two implementations is how the watch and the gate end
        # up disagreeing about what "billed" means.
        $watch = Get-Content (Join-Path $projectRoot "scripts/monitoring/metered-link-watch.ps1") -Raw
        $watch | Should -Match 'link-qualification\.ps1'
        $watch | Should -Match 'Test-LinkBilled'
    }
    It "The watch wrapper defaults to the shared tether pattern" {
        # A direct call of Test-MeteredLink without the pattern must still see
        # a phone shared over USB: an empty default would pass green while
        # ignoring the tether -- the shape of the defect that cost ~20 GB.
        $watch = Get-Content (Join-Path $projectRoot "scripts/monitoring/metered-link-watch.ps1") -Raw
        $watch | Should -Match '\[string\]\$TetherAdapterPattern = \$script:DefaultTetherAdapterPattern\)'
    }
    It "Both consumers parse the environment list through the helper" {
        # The trimming lives in Get-MeteredProfiles; a consumer that splits the
        # variable itself reintroduces the untrimmed name.
        foreach ($file in @('scripts/monitoring/metered-link-watch.ps1', 'scripts/monitoring/test-link-billed.ps1')) {
            $text = Get-Content (Join-Path $projectRoot $file) -Raw
            $text | Should -Match 'Get-MeteredProfiles'
            $text | Should -Not -Match "ROO_METERED_PROFILES -split"
        }
    }
}
