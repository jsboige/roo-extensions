# Pester fixture for Test-ConcurrentClaimActive (scripts/scheduling/claim-lock.ps1).
# Fix #2428: the pre-fix step 4 yielded on any [CLAIMED] from another machine in
# the last 5 comments, however old and already released — 5 claim->yield cycles
# in 48 h on #2428. Run: powershell -NoProfile -ExecutionPolicy Bypass -File claim-lock.Tests.ps1
# (or Invoke-Pester on this file). Powershell 5.1 and 7 both supported.

BeforeAll {
    Write-Host "Running under PowerShell $($PSVersionTable.PSVersion)"
    . "$PSScriptRoot\claim-lock.ps1"

    # Fixed clock so fixtures are deterministic.
    $Script:Now = [datetime]'2026-09-23T09:00:00Z'

    function New-Comment([string]$Body, [scriptblock]$AgeMinutes) {
        $CreatedAt = if ($null -eq $AgeMinutes) { $null } else { $Script:Now.AddMinutes((& $AgeMinutes)) }
        [PSCustomObject]@{ body = $Body; createdAt = $CreatedAt }
    }

    # Real bodies from the #2428 history (2026-09-21..23) — same literal format.
    $Script:Claimed = '[CLAIMED] by claude on myia-po-20{0} at 2026-09-2{1}T{2}Z'
    $Script:Released = '[RELEASED] by claude on myia-po-20{0} — race condition detected, yielding to other claimer.'

    # The full #2428 cascade: 5 claim+release pairs from other machines, all old.
    $Script:Cascade2428 = @(
        (New-Comment ($Script:Claimed -f '25', '1', '08:31:07') { -2520 }),  # 42 h ago
        (New-Comment ($Script:Released -f '25')                            { -2520 }),
        (New-Comment ($Script:Claimed -f '26', '1', '19:20:45') { -2360 }),
        (New-Comment ($Script:Released -f '26')                            { -2360 }),
        (New-Comment ($Script:Claimed -f '25', '2', '02:30:35') { -2280 }),
        (New-Comment ($Script:Released -f '25')                            { -2280 }),
        (New-Comment ($Script:Claimed -f '26', '2', '13:20:52') { -1940 }),
        (New-Comment ($Script:Released -f '26')                            { -1940 }),
        (New-Comment ($Script:Claimed -f 'web1-0', '3', '06:12:36') { -165 }),  # 2h45 ago — outside the 30 min window
        (New-Comment ($Script:Released -f 'web1-0')                        { -165 })
    )
}

Describe 'Test-ConcurrentClaimActive — lock window + released-tracking (#2428)' {
    It 'full #2428 cascade: all claims old (>=30 min) -> no active competitor (loop broken)' {
        $Comments = @($Script:Cascade2428) + @(New-Comment ($Script:Claimed -f '26', '3', '08:59:00') { -1 })  # our own fresh claim
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'a claim from another machine within the window, no release -> active competitor' {
        $Comments = @(New-Comment ($Script:Claimed -f '25', '3', '08:50:00') { -10 })  # 10 min ago, never released
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }

    It 'a claim from another machine within the window BUT followed by its [RELEASED] -> not a competitor' {
        $Comments = @(
            (New-Comment ($Script:Claimed -f '25', '3', '08:50:00') { -10 }),
            (New-Comment ($Script:Released -f '25')                 { -9 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'a claim from another machine within the window BUT followed by a [DONE] -> not a competitor' {
        $Comments = @(
            (New-Comment ($Script:Claimed -f '25', '3', '08:50:00') { -10 }),
            (New-Comment '[DONE] myia-po-2025 — delivered via PR #9999' { -9 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'own claim within the window -> not a competitor' {
        $Comments = @(New-Comment ($Script:Claimed -f '26', '3', '08:50:00') { -10 })  # myia-po-2026 claimed
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'claim exactly at the window edge (30 min) -> outside, not a competitor' {
        $Comments = @(New-Comment ($Script:Claimed -f '25', '3', '08:30:00') { -30 })
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'undatable claim from another machine -> treated as held (fail-safe)' {
        $Comments = @(New-Comment ($Script:Claimed -f '25', '3', '08:50:00') $null)
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }

    It 'no claim comments at all -> no competitor' {
        $Comments = @(
            (New-Comment 'plain review comment' { -120 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'newer own claim coexists with an OLD other-machine claim -> keeps own lock (the #2428 fix case)' {
        # The exact moment a worker on po-2026 double-checks after claiming:
        # the last 20 comments contain old claims from po-2025/po-2026/web1, all released or stale.
        $Comments = @($Script:Cascade2428) + @(New-Comment ($Script:Claimed -f '26', '3', '08:59:30') { 0.5 })
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'two machines claiming within the window, neither released -> still yields (true race kept)' {
        $Comments = @(
            (New-Comment ($Script:Claimed -f '25', '3', '08:58:00') { -2 }),  # other machine, 2 min ago
            (New-Comment ($Script:Claimed -f '26', '3', '08:59:30') { 0.5 })  # us
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }
}

Describe 'Test-ConcurrentClaimActive — release attribution (ai-01 review on #3798)' {
    # The pre-review bug: ANY post-claim [RELEASED]/[DONE] freed the claim, no
    # matter which machine posted it. In a true race the LOSER yields, which
    # made the WINNER look released to any third worker => duplicate work.
    # A release only frees the claim of the machine it names.

    It 'race loser yields: winner still holds (ai-01 probe, exact)' {
        # po-2025 claimed -10 min (never released); po-2024 claimed -9 min then
        # released -8 min. Old logic returned False (po-2024 release freed
        # po-2025); the winner po-2025 must still count as an active competitor.
        $Comments = @(
            (New-Comment ($Script:Claimed  -f '25', '3', '08:50:00') { -10 }),
            (New-Comment ($Script:Claimed  -f '24', '3', '08:51:00') { -9 }),
            (New-Comment ($Script:Released -f '24')                  { -8 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }

    It 'a [DONE] from ANOTHER machine does not free a fresh claim either' {
        $Comments = @(
            (New-Comment ($Script:Claimed -f '25', '3', '08:50:00') { -10 }),
            (New-Comment '[DONE] myia-po-2024 — delivered via PR #9999' { -9 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }

    It 'the winners OWN release still frees its claim (attribution is a filter, not a blanket block)' {
        $Comments = @(
            (New-Comment ($Script:Claimed  -f '25', '3', '08:50:00') { -10 }),
            (New-Comment ($Script:Claimed  -f '24', '3', '08:51:00') { -9 }),
            (New-Comment ($Script:Released -f '24')                  { -8 }),
            (New-Comment ($Script:Released -f '25')                  { -5 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'ADR-17 comment formats attribute too ([CLAIMED] myia-po-2025 -- / [RELEASED] myia-po-2025)' {
        $Comments = @(
            (New-Comment '[CLAIMED] myia-po-2025 -- fixing the jq filter' { -10 }),
            (New-Comment '[RELEASED] myia-po-2025'                        { -9 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $false
    }

    It 'unattributable claim body (no machine name) + foreign release -> conservative: still held' {
        $Comments = @(
            (New-Comment '[CLAIMED] working on it'                        { -10 }),
            (New-Comment ($Script:Released -f '24')                       { -9 })
        )
        Test-ConcurrentClaimActive -Comments $Comments -MachineId 'myia-po-2026' -Now $Script:Now | Should -Be $true
    }
}