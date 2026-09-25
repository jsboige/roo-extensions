<#
.SYNOPSIS
    Behavioural test: post-repair verification must re-probe, never declare a booting chain dead (#3802).

.DESCRIPTION
    Until #3802 a repair was followed by a FIXED 15 s settle and one `Test-E2E` probe.
    Measured 22/09 (nanoclaw 21:48Z and 22:10Z runs): the 22:09 full repair held -- the
    chain answered at ~22:15 after a ~109 s cold start -- yet both runs re-probed after
    15 s and emitted `e2e-still-down-after-full-repair` on a chain that was merely still
    booting. Two false alarms per repair window, each one drowning a real outage.

    The function is EXTRACTED from the script under test (a copy pasted here could
    diverge), then driven against a scripted chain and a scripted run clock:

      - `Test-E2E`        -> fails until the Nth probe, then answers OK
      - `Get-RunSecondsLeft` -> `TaskTimeLimitSec - 5 - elapsed`, where elapsed advances
                             by the declared per-probe cost and by each interval asked
                             of Start-Sleep. This mirrors the real budget arithmetic
                             (the loop pays for its own probes) instead of handing the
                             loop a fixed allowance it would never see in production.
      - `Start-Sleep`     -> records the requested interval, sleeps nothing (no real wait)

    The scenario ai-01 asked for -- "a chain answering at T+100 s, expected OK, with no
    e2e-still-down-after-full-repair alert" -- is covered by three tests that state what
    the budget actually allows, rather than the window one would wish for. A 2-min task
    gives the loop 115 s, and one probe plus one interval costs ~35 s of it: a run fits
    ~2 re-probes, so a ~100 s cold start is NOT confirmable in-run. What is guaranteed
    is the part that produced the false alarms: the run that repairs DEFERS instead of
    declaring the chain down, and the NEXT tick confirms OK in-run.

.NOTES
    Issue #3802 (RX37). Requires Pester 5+.
#>

Describe 'mcp-chain-watchdog post-repair verification (#3802)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\mcp-watchdog\mcp-chain-watchdog.ps1'
        $content = Get-Content $scriptPath -Raw

        # The function under test, verbatim from the script.
        $fnMatch = [regex]::Match($content, '(?s)function Wait-ForPostRepairRecovery \{.*?\n\}')
        if (-not $fnMatch.Success) { throw 'Wait-ForPostRepairRecovery not found in mcp-chain-watchdog.ps1' }
        $script:fnSource = $fnMatch.Value

        function Get-DeclaredConst {
            param([string]$Name)
            $m = [regex]::Match($content, "\`$$Name = (\d+)")
            if (-not $m.Success) { throw "`$$Name not found in mcp-chain-watchdog.ps1" }
            [int]$m.Groups[1].Value
        }
        $script:declaredCapSec      = Get-DeclaredConst 'PostRepairProbeCapSec'
        $script:declaredIntervalSec = Get-DeclaredConst 'PostRepairProbeIntervalSec'
        $script:declaredProbeCostSec = Get-DeclaredConst 'PostRepairProbeCostSec'
        $script:declaredTaskLimitSec = Get-DeclaredConst 'TaskTimeLimitSec'

        # Drives the extracted loop. Returns the loop's verdict plus what the scripted
        # chain and clock observed.
        function Invoke-PostRepairWait {
            param(
                [int]$AnswerAfterProbes = 999999,  # the scripted chain answers on this probe
                [int]$RepairCostSec = 0,           # clock already burnt by the destructive repair
                [int]$CapSec = -1                  # <=0 means "use the declared ceiling"; 0 tests the ceiling branch itself
            )
            if ($CapSec -lt 0) { $CapSec = $script:declaredCapSec }

            $state = [pscustomobject]@{
                Probes       = 0
                SleptSec     = 0
                ElapsedSec   = $RepairCostSec
                IntervalSec  = 0
            }

            # Loop knobs and collaborators, all resolved from this scope.
            $PostRepairProbeCapSec      = $CapSec
            $PostRepairProbeIntervalSec = $script:declaredIntervalSec
            $PostRepairProbeCostSec     = $script:declaredProbeCostSec

            function Get-RunSecondsLeft { ($script:declaredTaskLimitSec - 5) - $state.ElapsedSec }

            function Start-Sleep {
                param([int]$Seconds)
                $state.IntervalSec = $Seconds
                $state.SleptSec   += $Seconds
                $state.ElapsedSec += $Seconds
            }

            function Test-E2E {
                $state.Probes     += 1
                $state.ElapsedSec += $PostRepairProbeCostSec
                [pscustomobject]@{
                    Ok        = ($state.Probes -ge $AnswerAfterProbes)
                    Status    = if ($state.Probes -ge $AnswerAfterProbes) { 200 } else { 0 }
                    LatencyMs = 5
                }
            }

            # Dot-source the extracted definition so the function lands in THIS scope,
            # where the stubs above shadow the real collaborators.
            . ([scriptblock]::Create($script:fnSource))
            $verdict = Wait-ForPostRepairRecovery

            [pscustomobject]@{
                Ok        = $verdict.Result.Ok
                HasResult = ($null -ne $verdict.Result)
                Deferred  = $verdict.Deferred
                Probes    = $state.Probes
                SleptSec  = $state.SleptSec
            }
        }
    }

    Context 'the run that performs the repair' {

        It 'DEFERS -- never declares down -- on a chain that needs the 22/09 measured ~100 s' {
            # Full repair cost (45 s destructive worst case) already burnt: the run
            # has ~70 s of budget left, which fits 2-3 re-probes and then defers.
            # Before #3802 this is precisely the run that emitted
            # 'e2e-still-down-after-full-repair' 15 s after the repair.
            $r = Invoke-PostRepairWait -AnswerAfterProbes 8 -RepairCostSec 45

            $r.Deferred | Should -BeTrue -Because 'the chain has not answered yet; the run budget, not the chain, ended the wait'
            $r.Ok       | Should -BeFalse
            $r.Probes   | Should -BeGreaterThan 1 -Because 'a single 15 s probe is what produced the false alarm'
            $r.SleptSec | Should -BeGreaterThan 15 -Because 'the wait must outlast the old fixed settle'
        }

        It 'still has a real DOWN verdict when the chain genuinely stays down' {
            # Ceiling injected to 0 so the ceiling branch is reached without a real wait
            # (that branch compares the REAL stopwatch, which a scripted clock cannot
            # advance); the chain never answers. This is the branch the alert belongs to.
            $r = Invoke-PostRepairWait -AnswerAfterProbes 999999 -RepairCostSec 45 -CapSec 0

            $r.Deferred  | Should -BeFalse
            $r.HasResult | Should -BeTrue
            $r.Ok        | Should -BeFalse
        }
    }

    Context 'fast recovery' {

        It 'confirms in-run when the chain answers on the 2nd probe (TBXark-only path)' {
            $r = Invoke-PostRepairWait -AnswerAfterProbes 2 -RepairCostSec 20

            $r.Ok       | Should -BeTrue
            $r.Deferred | Should -BeFalse
            $r.Probes   | Should -BeExactly 2
        }

        It 'defers rather than declaring down beyond the ~35 s in-run window' {
            # Probe k costs k*20 + (k-1)*15 s of the 115 s budget, so the 3rd probe
            # would start at ~T+70 s with under the 30 s margin left: the loop defers
            # instead of starting a probe it cannot finish, and never reports down.
            $r = Invoke-PostRepairWait -AnswerAfterProbes 3 -RepairCostSec 20

            $r.Deferred | Should -BeTrue
            $r.Ok       | Should -BeFalse
        }
    }

    Context 'the next tick' {

        It 'confirms OK in-run on the ~100 s chain the repairing run had to defer' {
            # Fresh tick, 2 min later: the repair is on cooldown, so nothing destructive
            # is burnt and the very first probe sees the chain that has finished booting.
            # This is where ai-01's "T+100 s -> OK" lands -- one tick later than asked,
            # and never as an e2e-still-down alert.
            $r = Invoke-PostRepairWait -AnswerAfterProbes 1 -RepairCostSec 0

            $r.Ok        | Should -BeTrue
            $r.Deferred  | Should -BeFalse
            $r.HasResult | Should -BeTrue
            $r.Probes    | Should -BeExactly 1
        }

        It 'never starts a probe it cannot finish inside the remaining budget' {
            # 95 s already burnt: fewer than CostSec+10 s are left, so no probe may
            # start -- a probe cut mid-flight would cost the run its tail.
            $r = Invoke-PostRepairWait -AnswerAfterProbes 1 -RepairCostSec 95

            $r.Deferred  | Should -BeTrue
            $r.Probes    | Should -BeExactly 0
            $r.HasResult | Should -BeFalse
        }
    }

    Context 'declared constants and call-site wiring (static guards)' {

        It 'keeps the ceiling inside the 120-150 s window approved for #3802' {
            $script:declaredCapSec | Should -BeGreaterOrEqual 120
            $script:declaredCapSec | Should -BeLessOrEqual 150
        }

        It 'no longer waits a fixed 15 s after a repair' {
            # The two removals #3802 asked for. A partial revert that restored one
            # fixed settle would leave the false alarm reachable again.
            ([regex]::Matches($content, 'Start-Sleep -Seconds 15')).Count | Should -BeExactly 0
            ([regex]::Matches($content, '\$w = Wait-ForPostRepairRecovery')).Count | Should -BeExactly 2
        }

        It 'routes a deferred verdict to a WARN with no alert, in both repair paths' {
            $blocks = [regex]::Matches($content, '(?s)elseif \(\$w -and \$w\.Deferred\) \{.*?\n\s*\}')
            $blocks.Count | Should -BeExactly 2 -Because 'both the TBXark-only and the full repair path must defer rather than alert'
            foreach ($b in $blocks) {
                $b.Value | Should -Match 'deferredVerifications \+='
                $b.Value | Should -Not -Match '\$script:alerts' -Because 'a repair that has not been confirmed is not a repair that failed'
            }
        }

        It 'reports deferred as its own final state in the fleet note and the event log' {
            # Plain .Contains over the regex-escaped form: the literal carries `$`,
            # braces and quotes that a pattern would have to escape twice over.
            $content.Contains("{ 'OK' } elseif (`$script:deferredVerifications.Count -gt 0) { 'UNVERIFIED' }") |
                Should -BeTrue -Because 'the fleet note must not fold a deferred repair into DOWN'
            $content.Contains("'UNVERIFIED (chain had not answered when the run budget ended)'") |
                Should -BeTrue -Because 'the event log carries the same three-state verdict'
        }
    }
}