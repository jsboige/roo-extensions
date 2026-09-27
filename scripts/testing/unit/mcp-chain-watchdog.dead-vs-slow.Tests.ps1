<#
.SYNOPSIS
    Behavioural test: the watchdog tells a dead sparfenyuk from a slow or restarting one
    before it runs Stop-ScheduledTask (#3898).

.DESCRIPTION
    Measured on ai-01, 23/09 -> 28/09: proxy.log recorded 85 starts of mcp-proxy and 0
    "exited with code". The "~12 deaths a day" were restarts of a live process: NanoClaw's
    watchdog-tbxark.ps1 restarts the whole stack when its tools/call exceeds 40 s, and this
    watchdog read the TBXark -32603 that restart produced under its own probe as a death,
    then ran a second full repair right behind it (55 of its 99 full repairs since 14/09).
    The "port-was-down" label came from a 5 s /status sampled on a busy or restarting stack.

    Get-SparfenyukVerdict and Get-SparfenyukRestartLabel are EXTRACTED from the script under
    test (a copy pasted here could diverge) and driven against scripted collaborators:

      - Test-SparfenyukListening    -> the :9091 socket table, one scripted answer per call
      - Get-SparfenyukRestartAgeSec -> seconds since MCP-Proxy-RSM started, one per call
      - Invoke-McpProbe             -> the direct tool call on :9091, records URL and budget
      - Get-RunSecondsLeft          -> the run budget left
      - Start-Sleep                 -> records the settle, sleeps nothing

    The three branches the issue names (fast death, slow response, port down) come first;
    the 15/08 signature (listener up, RSM child dead, isError in < 100 ms) is the fast death.

.NOTES
    Issue #3898 (RX62). Requires Pester 5+.
#>

Describe 'mcp-chain-watchdog dead vs slow before restarting sparfenyuk (#3898)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\mcp-watchdog\mcp-chain-watchdog.ps1'
        $script:content = Get-Content $scriptPath -Raw

        function Get-FunctionSource {
            param([string]$Name)
            $m = [regex]::Match($script:content, "(?s)function $Name \{.*?\n\}")
            if (-not $m.Success) { throw "$Name not found in mcp-chain-watchdog.ps1" }
            $m.Value
        }
        $script:verdictSource = Get-FunctionSource 'Get-SparfenyukVerdict'
        $script:labelSource   = Get-FunctionSource 'Get-SparfenyukRestartLabel'

        function Get-DeclaredConst {
            param([string]$Name)
            $m = [regex]::Match($script:content, "\`$$Name = (\d+)")
            if (-not $m.Success) { throw "`$$Name not found in mcp-chain-watchdog.ps1" }
            [int]$m.Groups[1].Value
        }
        $script:declaredDirectSec   = Get-DeclaredConst 'DirectProbeTimeoutSec'
        $script:declaredInFlightSec = Get-DeclaredConst 'RestartInFlightSec'
        $script:declaredSettleSec   = Get-DeclaredConst 'PortDownSettleSec'
        $script:declaredCooldownMin = Get-DeclaredConst 'RepairCooldownMin'
        $m = [regex]::Match($script:content, "\`$directUrl = '([^']+)'")
        if (-not $m.Success) { throw '$directUrl not found in mcp-chain-watchdog.ps1' }
        $script:declaredDirectUrl = $m.Groups[1].Value

        # A probe result as Invoke-McpProbe returns it.
        function New-Probe {
            param([bool]$Ok, [bool]$TimedOut = $false, [int]$Status = 200, [int]$LatencyMs = 50, [string]$Body = '')
            @{ Ok = $Ok; TimedOut = $TimedOut; Status = $Status; LatencyMs = $LatencyMs; Body = $Body }
        }

        # Drives the extracted verdict. Each scripted list is consumed one entry per call;
        # the last entry repeats once the list is exhausted.
        function Invoke-Verdict {
            param(
                [bool[]]$Listening = @($true),
                [double[]]$RestartAgeSec = @(3600),
                $Probe = $null,
                [double]$RunSecondsLeft = 105
            )
            $state = [pscustomobject]@{
                ListenCalls = 0; AgeCalls = 0; Probes = 0; ProbeUrl = $null; ProbeBudget = $null; SleptSec = 0
            }

            $RestartInFlightSec    = $script:declaredInFlightSec
            $PortDownSettleSec     = $script:declaredSettleSec
            $DirectProbeTimeoutSec = $script:declaredDirectSec
            $directUrl             = $script:declaredDirectUrl

            function Test-SparfenyukListening {
                $i = [Math]::Min($state.ListenCalls, $Listening.Count - 1); $state.ListenCalls += 1
                $Listening[$i]
            }
            function Get-SparfenyukRestartAgeSec {
                $i = [Math]::Min($state.AgeCalls, $RestartAgeSec.Count - 1); $state.AgeCalls += 1
                $RestartAgeSec[$i]
            }
            function Get-RunSecondsLeft { $RunSecondsLeft }
            function Start-Sleep { param([int]$Seconds) $state.SleptSec += $Seconds }
            function Invoke-McpProbe {
                param([string]$Url, [int]$TimeoutSec)
                $state.Probes += 1; $state.ProbeUrl = $Url; $state.ProbeBudget = $TimeoutSec
                $Probe
            }

            # Dot-sourced so the function lands in THIS scope, where the stubs above
            # shadow the real collaborators.
            . ([scriptblock]::Create($script:verdictSource))
            $v = Get-SparfenyukVerdict

            [pscustomobject]@{
                Verdict     = $v.Verdict
                HasProbe    = ($null -ne $v.Probe)
                Probes      = $state.Probes
                ProbeUrl    = $state.ProbeUrl
                ProbeBudget = $state.ProbeBudget
                SleptSec    = $state.SleptSec
            }
        }

        . ([scriptblock]::Create($script:labelSource))
    }

    Context 'the three branches the issue names' {

        It 'fast death: listener up, the direct tool call fails fast with isError (the 15/08 case) -> dead' {
            $r = Invoke-Verdict -Listening @($true) `
                                -Probe (New-Probe -Ok $false -LatencyMs 80 -Body 'toolcall isError:true (backend alive, instance dead)')

            $r.Verdict  | Should -Be 'dead' -Because 'a live listener in front of a dead RSM child must still get the full repair'
            $r.Probes   | Should -BeExactly 1
            $r.ProbeUrl | Should -Be $script:declaredDirectUrl -Because 'the call goes to sparfenyuk itself, around TBXark'
        }

        It 'slow response: the direct tool call answers, even after 45 s -> slow, never restarted' {
            $r = Invoke-Verdict -Listening @($true) -Probe (New-Probe -Ok $true -LatencyMs 45000)

            $r.Verdict  | Should -Be 'slow'
            $r.HasProbe | Should -BeTrue -Because 'the caller logs the direct latency'
        }

        It 'port down: nothing listens on :9091, twice, and no restart is in flight -> port-down' {
            $r = Invoke-Verdict -Listening @($false, $false) -RestartAgeSec @(3600)

            $r.Verdict  | Should -Be 'port-down'
            $r.Probes   | Should -BeExactly 0 -Because 'a closed port answers nothing; probing it only spends run time'
            $r.SleptSec | Should -BeExactly $script:declaredSettleSec -Because 'a closed port is re-read once after the settle'
        }
    }

    Context 'a restart already in flight is not a death' {

        It 'MCP-Proxy-RSM started seconds ago -> booting, nothing probed' {
            $r = Invoke-Verdict -Listening @($false) -RestartAgeSec @(30)

            $r.Verdict  | Should -Be 'booting'
            $r.Probes   | Should -BeExactly 0
            $r.SleptSec | Should -BeExactly 0
        }

        It 'port closed inside another actor''s Stop -> 2 s -> Start gap -> booting once the Start lands' {
            # Measured 28/09 00:25:42 local: NanoClaw stopped the task, our probe got the
            # -32603 in the same second, and our own Stop followed. The settle lets the
            # other actor's Start land before the port is called down.
            $r = Invoke-Verdict -Listening @($false, $false) -RestartAgeSec @(3600, 2)

            $r.Verdict | Should -Be 'booting'
            $r.Probes  | Should -BeExactly 0
        }

        It 'a restart that kills the port holder under the direct probe -> booting, not dead' {
            # run-proxy.cmd taskkills the :9091 holder before binding: the probe sees a reset.
            $r = Invoke-Verdict -Listening @($true) -RestartAgeSec @(3600, 1) `
                                -Probe (New-Probe -Ok $false -Status 0 -LatencyMs 900 -Body 'connection reset')

            $r.Verdict | Should -Be 'booting'
        }

        It 'an old start does not count as in flight' {
            $r = Invoke-Verdict -Listening @($true) -RestartAgeSec @($script:declaredInFlightSec + 1) `
                                -Probe (New-Probe -Ok $false -LatencyMs 60)

            $r.Verdict | Should -Be 'dead'
        }
    }

    Context 'deferrals' {

        It 'the direct probe spends its whole budget -> unresponsive (deferred, not repaired)' {
            $r = Invoke-Verdict -Listening @($true) `
                                -Probe (New-Probe -Ok $false -TimedOut $true -Status 0 -LatencyMs 60010)

            $r.Verdict | Should -Be 'unresponsive'
        }

        It 'the direct probe does not fit in the run -> no-time, nothing probed' {
            $r = Invoke-Verdict -Listening @($true) -RunSecondsLeft ($script:declaredDirectSec + 9) `
                                -Probe (New-Probe -Ok $true)

            $r.Verdict | Should -Be 'no-time'
            $r.Probes  | Should -BeExactly 0 -Because 'a probe the task limit would cut must not start'
        }

        It 'the direct probe gets the declared budget when it fits' {
            $r = Invoke-Verdict -Listening @($true) -Probe (New-Probe -Ok $true)

            $r.ProbeBudget | Should -BeExactly $script:declaredDirectSec
        }
    }

    Context 'the repair label (a /status timeout is not a closed port)' {

        It '/status answers -> port-was-up-instance-dead' {
            Get-SparfenyukRestartLabel -StatusOk $true -Listening $true |
                Should -Be 'sparfenyuk-restart(port-was-up-instance-dead)'
        }

        It '/status times out on a listening port -> status-timeout-port-listening' {
            Get-SparfenyukRestartLabel -StatusOk $false -Listening $true |
                Should -Be 'sparfenyuk-restart(status-timeout-port-listening)'
        }

        It '/status fails and nothing listens -> port-was-down' {
            Get-SparfenyukRestartLabel -StatusOk $false -Listening $false |
                Should -Be 'sparfenyuk-restart(port-was-down)'
        }
    }

    Context 'declared constants and call-site wiring (static guards)' {

        It 'the direct probe targets sparfenyuk on :9091, not TBXark on :9090' {
            $script:declaredDirectUrl | Should -Match '^http://127\.0\.0\.1:9091/'
        }

        It 'keeps the approved budgets' {
            $script:declaredDirectSec   | Should -BeGreaterOrEqual 60 -Because 'approved scope: >= 60 s for the direct probe'
            $script:declaredInFlightSec | Should -BeGreaterOrEqual 120 -Because 'a restarted stack needs ~100-110 s to answer'
            $script:declaredInFlightSec | Should -BeLessThan ($script:declaredCooldownMin * 60) -Because 'our own repairs must still be caught by the cooldown first'
            $script:declaredSettleSec   | Should -BeGreaterOrEqual 3 -Because 'the Stop -> Start gap of the other actor is 2 s'
            $script:declaredSettleSec   | Should -BeLessOrEqual 15
        }

        It 'the verdict is taken after the cooldown and before the run-time guard and the full repair' {
            $iCooldown = $script:content.IndexOf('elseif ($repairOnCooldown)')
            $iVerdict  = $script:content.IndexOf('Get-SparfenyukVerdict).Verdict')
            $iTimeLeft = $script:content.IndexOf('elseif ((Get-RunSecondsLeft) -lt $RepairWorstCaseSec)')
            $iFull     = $script:content.IndexOf('running full repair sequence')
            $iStop     = $script:content.IndexOf("Stop-ScheduledTask -TaskName 'MCP-Proxy-RSM'")
            $iCooldown | Should -BeGreaterThan 0
            $iVerdict  | Should -BeGreaterThan $iCooldown
            $iTimeLeft | Should -BeGreaterThan $iVerdict -Because 'the run-time guard must be read after the direct probe spent its time'
            $iFull     | Should -BeGreaterThan $iTimeLeft
            $iStop     | Should -BeGreaterThan $iFull
        }

        It 'only dead and port-down reach the destructive branch' {
            $script:content | Should -Match "\(\`$sparfenyuk = Get-SparfenyukVerdict\)\.Verdict -notin @\('dead', 'port-down'\)"
        }

        It 'the not-dead branch restarts nothing' {
            $m = [regex]::Match($script:content, "(?s)Get-SparfenyukVerdict\)\.Verdict -notin[^\n]*\n(.*?)\n\s*\} elseif \(\(Get-RunSecondsLeft\) -lt \`$RepairWorstCaseSec\)")
            $m.Success | Should -BeTrue
            $m.Groups[1].Value | Should -Not -Match 'Stop-ScheduledTask|Start-ScheduledTask|docker\s+restart|docker\s+kill'
            foreach ($v in 'booting', 'slow', 'unresponsive', 'no-time') {
                $m.Groups[1].Value | Should -Match "'$v' \{" -Because "verdict '$v' needs its own handling"
            }
        }

        It 'the repair records the label read before the Stop, not the old two-way guess' {
            $script:content | Should -Match 'Get-SparfenyukRestartLabel -StatusOk \(Test-Sparfenyuk\) -Listening \(Test-SparfenyukListening\)\s*\r?\n\s*Stop-ScheduledTask'
            $script:content | Should -Match '\$script:repairs \+= \$restartLabel'
            $script:content | Should -Not -Match "else \{ 'sparfenyuk-restart\(port-was-down\)' \}"
        }
    }
}
