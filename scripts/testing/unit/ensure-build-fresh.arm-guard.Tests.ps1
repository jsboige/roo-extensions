<#
.SYNOPSIS
    Guard test: ensure-build-fresh.ps1 must keep its #3489 contracts (ARM guard, -Arm escape, defer-before-build).

.DESCRIPTION
    ensure-build-fresh.ps1 is the interactive pre-flight helper that rebuilds the roo-state-manager
    build/ dir when stale (#2822). Rebuilding while live RSM host processes run produces mixed ESM
    graphs and the assertSharedStoreAccessible crash that makes inbox unreadable until VS Code
    restart (#3489).

    This is a STRUCTURAL guard (AST + content): the unit CI must not trigger a rebuild or touch live
    processes. It asserts:
      - the script parses,
      - the ARM guard probes live RSM hosts (Get-CimInstance + roo-state-manager build/index.js|mcp-wrapper.cjs regex),
      - defer is the default (ARMED-DEFER emitted before the build invocation when live hosts exist),
      - the -Arm escape hatch is declared as a named switch and warns that a restart is required,
      - the crash signature it protects against (#3489 / assertSharedStoreAccessible) is named,
      - the existing FRESH no-op path is preserved.

.NOTES
    Issue #3489
    Requires Pester 5+
#>

Describe 'ensure-build-fresh ARM guard (#3489)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $content = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Probes live RSM host processes via Get-CimInstance Win32_Process' {
        $content | Should -Match 'Get-CimInstance Win32_Process'
        $content | Should -Match 'roo-state-manager'
        $content | Should -Match 'CommandLine'
        $content | Should -Match 'mcp-wrapper'
        $content | Should -Match '\.cjs'
    }

    It 'Refuses on the HEADLESS path only, and still decides before the build' {
        # Arbitration on the #3489 FRICTION (2026-09-07): what decides is not how many hosts are
        # alive but whether the CALLER can close the armed window with a restart. RSM is the MCP
        # of every session, so "refuse under live hosts" reduced to "never rebuild" on every
        # interactive machine (po-2026: STALE 14 h across 4 executor cycles; po-2025 deadlocked;
        # both released only by direct human mandate).
        $content | Should -Match 'ARMED-DEFER'
        $headlessIdx = $content.IndexOf('$Headless -and -not $Arm')
        $deferIdx    = $content.IndexOf("Exit-NotFresh 'ARMED-DEFER'")
        $buildIdx    = $content.IndexOf('& npm.cmd run build')
        # the defer is gated by -Headless (overridable by -Arm), not by the host count alone
        $headlessIdx | Should -BeGreaterThan 0
        $deferIdx    | Should -BeGreaterThan $headlessIdx
        ($deferIdx - $headlessIdx) | Should -BeLessThan 400   # same guard block, not elsewhere
        # ...and the refusal is still reached BEFORE any build is invoked
        $buildIdx | Should -BeGreaterThan $deferIdx

        # Positive control: the discriminator is absent from the pre-arbitration shape, so this
        # test goes red if the unconditional "refuse under live hosts" gate is ever restored.
        'if ($liveHosts.Count -gt 0) { if ($Arm) { } else { ARMED-DEFER; exit 0 } }'.IndexOf('$Headless -and -not $Arm') | Should -Be -1
    }

    It 'Declares the named -Headless switch that scheduled callers pass' {
        $content | Should -Match '\[switch\]\$Headless'
    }

    It 'The interactive default rebuilds and states that the restart is OWED' {
        # The interactive caller can restart VS Code, so it rebuilds — but the armed window it
        # opens must be named, or the machine is left armed silently (the failure this guard
        # exists for). ARM is emitted, and the build is NOT skipped on that path.
        $content | Should -Match 'THE RESTART IS OWED'
        $armIdx   = $content.IndexOf("Write-Result 'ARM'")
        $buildIdx = $content.IndexOf('& npm.cmd run build')
        $armIdx   | Should -BeGreaterThan 0
        $buildIdx | Should -BeGreaterThan $armIdx
    }

    It 'Does not claim the restart is OWED on a run that rebuilds NOTHING (-DryRun / -WhatIf)' {
        # Finding by po-2024 reviewing #3519, reproduced on main 2026-09-08 (ai-01): the
        # categorical ARM line fired under -DryRun AND under -WhatIf, then the run skipped the
        # build -- announcing a debt it had not incurred, with build/index.js mtime unchanged.
        # An operator reading the first line believes the machine was armed by their command.
        #
        # The predicate must cover BOTH dry doors: -DryRun exits at the gate below, -WhatIf is
        # declined by ShouldProcess. Testing only -DryRun would leave -WhatIf free to drift.
        $content | Should -Match '\$noRebuildThisRun\s*=\s*\$DryRun\s+-or\s+\$WhatIfPreference'
        $content | Should -Match 'NOTHING was rebuilt and NOTHING is armed'

        # The categorical claim must live in the ELSE branch, i.e. after the guard.
        # Measured on TOKENS, not on raw text: a comment quoting the string (this fix ships
        # one, naming the incident) sits before the guard and made a raw IndexOf assertion
        # fail on the comment instead of the code -- the test would have been measuring prose.
        $owedToken = $tokens |
            Where-Object { $_.Kind -ne 'Comment' -and $_.Text -like '*THE RESTART IS OWED*' } |
            Select-Object -First 1
        $owedToken | Should -Not -BeNullOrEmpty -Because 'the categorical ARM message must still exist for real rebuilds'
        $guardIdx = $content.IndexOf('if ($noRebuildThisRun)')
        $guardIdx | Should -BeGreaterThan -1
        $owedToken.Extent.StartOffset | Should -BeGreaterThan $guardIdx
    }

    It 'Declares the named -Arm escape hatch switch' {
        $content | Should -Match '\[switch\]\$Arm'
    }

    It 'The -Arm override warns that a VS Code restart is required' {
        $content | Should -Match 'ARM'
        $content | Should -Match 'VS Code restart'
    }

    It 'Names the crash signature it protects against (#3489 / assertSharedStoreAccessible)' {
        $content | Should -Match 'assertSharedStoreAccessible'
        $content | Should -Match '#3489'
    }

    It 'Preserves the FRESH no-op path' {
        $content | Should -Match 'build/ is up to date'
    }

    It 'Counts each RSM role once: separate indexHosts and wrapperHosts (ai-01 review note)' {
        # Each VS Code RSM session spawns TWO distinct node processes: mcp-wrapper.cjs (parent) +
        # build/index.js (child). The c.28 merged #3493 aggregated both with a single regex,
        # so a 30-session machine reported "60 live RSM host(s)". The role-once fix splits the
        # filter into two variables so the message reports session count (30) plus the role split.
        $content | Should -Match '\$indexHosts\s*=\s*@\(Get-CimInstance Win32_Process'
        $content | Should -Match '\$wrapperHosts\s*=\s*@\(Get-CimInstance Win32_Process'
        # The combined single filter must be gone (regression guard for the c.28 bug).
        # Literal .Contains, not a hand-escaped -Match pattern: hand-escaping is what made the
        # previous guard inert (ai-01 review #3502). The positive control proves the predicate bites.
        $content.Contains('index\.js|mcp-wrapper\.cjs') | Should -BeFalse
        'roo-state-manager[\/](build[\/]index\.js|mcp-wrapper\.cjs)'.Contains('index\.js|mcp-wrapper\.cjs') | Should -BeTrue
    }

    It 'Computes the ARMÉ signature from index.js hosts only, not wrapper.cjs' {
        # The wrapper.cjs hosts do NOT load the build/ ESM modules themselves; only the
        # build/index.js child does. Counting wrappers in the "predating build/index.js" set
        # would inflate the signature. The fix loops $indexHosts, not $liveHosts.
        $indexHostsIdx = $content.IndexOf('$indexHosts')
        $staleLoopIdx = $content.IndexOf('foreach ($h in $indexHosts)')
        $staleLoopIdx | Should -BeGreaterThan $indexHostsIdx
        $staleLoopIdx | Should -BeGreaterThan 0
    }

    It 'Corroborates CIM-listed hosts with the .NET view before counting (ghost tolerance)' {
        # Finding by po-204 (2026-09-12, c.413): Win32_Process keeps listing a terminated
        # process whose object handle a third party retains (unreaped child of a killed
        # mcp-wrapper). CIM counted it; taskkill reported "no running instance"; the .NET view
        # reported HasExited=True. One such ghost held this guard at exit 10 across three
        # consecutive pre-flights after a legitimate host-kill pass, with ZERO real hosts
        # predating the fresh build. The corroboration must:
        #   1. exist as a function consulted by BOTH host lists,
        #   2. exclude ONLY processes positively proven exited (fail-closed: an inability to
        #      prove exit keeps the host counted).
        $content | Should -Match 'function Test-ProcessExited'
        # Both lists pass through the corroboration AFTER the CIM query and BEFORE $liveHosts.
        $cimIdx      = $content.IndexOf('$wrapperHosts = @(Get-CimInstance Win32_Process')
        $filterIdx   = $content.IndexOf('$indexHosts   = @($indexHosts   | Where-Object { -not (Test-ProcessExited')
        $liveIdx     = $content.IndexOf('$liveHosts = @($indexHosts + $wrapperHosts)')
        $cimIdx    | Should -BeGreaterThan 0
        $filterIdx | Should -BeGreaterThan $cimIdx
        $liveIdx   | Should -BeGreaterThan $filterIdx
        $content | Should -Match '\$wrapperHosts = @\(\$wrapperHosts \| Where-Object \{ -not \(Test-ProcessExited'
        # Fail-closed shape: the catch branch returns $false (cannot prove exit -> keep counting).
        $fnStart = $content.IndexOf('function Test-ProcessExited')
        $fnEnd   = $content.IndexOf('}', $content.IndexOf('return $false', $fnStart))
        $fnBody = $content.Substring($fnStart, $fnEnd - $fnStart)
        $fnBody | Should -Match 'return \$true'    # null (absent from OS list) or HasExited both exclude
        $fnBody | Should -Match 'catch \{\s*\r?\n\s*return \$false'
        # Positive control: the pre-fix shape (CIM lists consumed directly, no corroboration)
        # contains no Test-ProcessExited call, so this predicate bites on regression to it.
        '$indexHosts = @(Get-CimInstance Win32_Process -Filter "Name = ''node.exe''" | Where-Object { $_.CommandLine -match ''roo-state-manager'' })'.Contains('Test-ProcessExited') | Should -BeFalse
    }
}
