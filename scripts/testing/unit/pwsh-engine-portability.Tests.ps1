<#
.SYNOPSIS
    Guard: the WAKE path must not hard-depend on one PowerShell engine (#2368).

.DESCRIPTION
    MEASURED 2026-09-08 on ai-01, both engines — the two JSON->dictionary mechanisms are
    MUTUALLY EXCLUSIVE:

      ConvertFrom-Json -AsHashtable : PS 7.6.5 OK  / PS 5.1   FAILS (no such parameter)
      JavaScriptSerializer          : PS 5.1   OK  / PS 7.6.5 FAILS (System.Web.Extensions
                                      is .NET Framework only)

    Each script had picked one, so each was broken on the opposite engine:
      - dashboard-listener.ps1 used JavaScriptSerializer and runs under pwsh 7 => workspace
        path-resolution source #4 was DEAD fleet-wide (63 WARN hits in
        outputs/scheduling/logs/listener-*.log, 09-06 -> 09-07).
      - spawn-claude.ps1 used -AsHashtable => under 5.1 the catch dropped every
        workspace-scoped MCP override (silently undoing #2004 Phase 2).

    This is a STRUCTURAL guard (content): CI runs on ubuntu/pwsh and cannot exercise 5.1.
    Every predicate below carries a positive control, because a hand-escaped pattern that
    matches nothing is an inert guard (lesson from #3502).

.NOTES
    Issue #2368
#>

Describe 'PowerShell engine portability on the WAKE path (#2368)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '../../..'
        $script:spawn    = Get-Content (Join-Path $root 'scripts/dashboard-scheduler/spawn-claude.ps1') -Raw
        $script:listener = Get-Content (Join-Path $root 'scripts/dashboard-scheduler/dashboard-listener.ps1') -Raw
        $script:poll     = Get-Content (Join-Path $root 'scripts/dashboard-scheduler/poll-dashboard.ps1') -Raw
        $script:meta     = Get-Content (Join-Path $root 'scripts/scheduling/start-meta-audit.ps1') -Raw
        # Remaining naked -AsHashtable callers (finding ai-01 2026-09-08, per #2368)
        $script:audit    = Get-Content (Join-Path $root 'scripts/audit/audit-roo-tasks.ps1') -Raw
        $script:init     = Get-Content (Join-Path $root 'scripts/claude/init-claude-code.ps1') -Raw
        $script:copilot  = Get-Content (Join-Path $root 'scripts/copilot/configure-copilot-mcp.ps1') -Raw
        $script:rollout  = Get-Content (Join-Path $root 'scripts/scheduling/invoke-copilot-rollout-check.ps1') -Raw
        $script:dispatch = Get-Content (Join-Path $root 'scripts/scheduling/start-copilot-dispatcher.ps1') -Raw
    }

    It 'Both JSON-parsing scripts define the portable helper' {
        $spawn    | Should -Match 'function ConvertFrom-JsonToDictionary'
        $listener | Should -Match 'function ConvertFrom-JsonToDictionary'
    }

    It 'The helper branches on the engine rather than picking one' {
        foreach ($c in @($spawn, $listener)) {
            $c | Should -Match '\$PSVersionTable\.PSVersion\.Major -ge 7'
            $c | Should -Match 'ConvertFrom-Json -AsHashtable'      # the PS7 branch
            $c | Should -Match 'JavaScriptSerializer'               # the PS5.1 branch
        }
    }

    It 'Neither engine-specific parser is called OUTSIDE the helper' {
        # Count the EXECUTABLE call forms, not the bare names: the helper's own doc-comment
        # names both mechanisms, so a bare-name count matches prose as well as code. It did —
        # this assertion failed on its first run and caught its own over-broad predicate.
        $callAsh = '$Json | ConvertFrom-Json -AsHashtable'
        $callJss = 'New-Object System.Web.Script.Serialization.JavaScriptSerializer'
        foreach ($c in @($spawn, $listener)) {
            ([regex]::Matches($c, [regex]::Escape($callAsh))).Count | Should -Be 1
            ([regex]::Matches($c, [regex]::Escape($callJss))).Count | Should -Be 1
        }
        # positive controls: both predicates bite on text that really contains the call
        ([regex]::Matches("x $callAsh y", [regex]::Escape($callAsh))).Count | Should -Be 1
        ([regex]::Matches("x $callJss y", [regex]::Escape($callJss))).Count | Should -Be 1
    }

    It 'Membership is tested with IDictionary, never the concrete [hashtable]' {
        # Under 5.1 the portable parser yields Dictionary[string,object], which is NOT a
        # [hashtable] (measured: -is [hashtable] = False). Testing the concrete type drops
        # every workspace-scoped MCP override on 5.1.
        $spawn | Should -Match '\$proj -is \[System\.Collections\.IDictionary\]'
        $spawn.Contains('$proj -is [hashtable]') | Should -BeFalse
        # positive control: the predicate bites on the pre-fix shape
        'if ($proj -is [hashtable] -and $proj.ContainsKey(''mcpServers''))'.Contains('$proj -is [hashtable]') | Should -BeTrue
    }

    It 'No bare "& pwsh" invocation survives on the spawn/pre-flight paths' {
        foreach ($c in @($listener, $poll, $meta)) {
            $c.Contains('& pwsh ') | Should -BeFalse
        }
        # positive control: the predicate bites on the pre-fix shape
        '        & pwsh -File $SpawnScript @spawnArgs'.Contains('& pwsh ') | Should -BeTrue
    }

    It 'Each of those three sites resolves a host with a 5.1 fallback' {
        foreach ($c in @($listener, $poll, $meta)) {
            $c | Should -Match "Get-Command pwsh -ErrorAction SilentlyContinue"
            $c | Should -Match "else \{ 'powershell' \}"
            $c | Should -Match '& \$psHost '
        }
    }

    It 'The five remaining scripts define the portable helper' {
        foreach ($c in @($audit, $init, $copilot, $rollout, $dispatch)) {
            $c | Should -Match 'function ConvertFrom-JsonToDictionary'
        }
    }

    It 'No engine-specific parser is called OUTSIDE the helper in the five scripts' {
        $callAsh = '$Json | ConvertFrom-Json -AsHashtable'
        $callJss = 'New-Object System.Web.Script.Serialization.JavaScriptSerializer'
        foreach ($c in @($audit, $init, $copilot, $rollout, $dispatch)) {
            ([regex]::Matches($c, [regex]::Escape($callAsh))).Count | Should -Be 1
            ([regex]::Matches($c, [regex]::Escape($callJss))).Count | Should -Be 1
        }
        # positive controls
        ([regex]::Matches("x $callAsh y", [regex]::Escape($callAsh))).Count | Should -Be 1
        ([regex]::Matches("x $callJss y", [regex]::Escape($callJss))).Count | Should -Be 1
    }

    It 'The rollout check tests membership with IDictionary, never the concrete [hashtable]' {
        # Under 5.1 the portable parser yields Dictionary[string,object], which is NOT a
        # [hashtable]; testing the concrete type would drop the roo-state-manager match and
        # silently fall to the plain-text fallback. Assert the executable conditions, not the
        # helper's doc-comment text (which names the concrete type in prose).
        $rollout | Should -Match '\$json\.servers -is \[System\.Collections\.IDictionary\]'
        $rollout | Should -Match '\$json\.mcpServers -is \[System\.Collections\.IDictionary\]'
        $rollout.Contains('$json.servers -is [hashtable]') | Should -BeFalse
        $rollout.Contains('$json.mcpServers -is [hashtable]') | Should -BeFalse
        # positive control: the predicate bites on the pre-fix shape
        'if ($json.servers -is [hashtable] -and ...)'.Contains('$json.servers -is [hashtable]') | Should -BeTrue
    }

    It 'The audit script tests membership with ContainsKey, never the bare Contains' {
        # Dictionary[string,object] (the 5.1 shape) has ContainsKey, NOT Contains — the bare
        # .Contains() line was a second 5.1 breakage in the same script, found behaviourally.
        $audit | Should -Match '\$cache\.ContainsKey\(\$taskId\)'
        $audit.Contains('$cache.Contains($taskId)') | Should -BeFalse
        # positive control: the predicate bites on the pre-fix shape
        'if ($cache.Contains($taskId) -and ...)'.Contains('$cache.Contains($taskId)') | Should -BeTrue
    }

    It 'No .ps1 outside a portable helper pipes into the engine-specific parser (closes the CLASS)' {
        # The tests above enumerate five INSTANCES. A sixth bare caller added tomorrow passes
        # every one of them -- which is how start-copilot-dispatcher.ps1 survived this suite.
        # This predicate is written against the CLASS instead: any .ps1 under scripts/ that
        # PIPES into ConvertFrom-Json -AsHashtable without defining the portable helper.
        #
        # The pipe is the discriminator between a CALL and the doc-comments that merely name
        # the parameter (measured on this tree 2026-09-08: 10 piped call sites, 14 prose
        # mentions, zero overlap).
        #
        # Two files are exempt, for opposite reasons:
        #   - this test file quotes the pattern inside its own assertions;
        #   - start-claude-worker.ps1 DOCUMENTS a deliberate 5.1 fall-through to the #2280
        #     .env injection, which carries the same variables. Occurrence, not defect.
        $exempt      = @('pwsh-engine-portability.Tests.ps1', 'start-claude-worker.ps1')
        $callPattern = '\|\s*ConvertFrom-Json\s+-AsHashtable'
        $scriptsRoot = Join-Path $PSScriptRoot '../..'

        $offenders = Get-ChildItem $scriptsRoot -Recurse -Filter '*.ps1' |
            Where-Object { $exempt -notcontains $_.Name } |
            Where-Object {
                $body = Get-Content $_.FullName -Raw
                ($body -match $callPattern) -and
                ($body -notmatch 'function ConvertFrom-JsonToDictionary')
            } | ForEach-Object { $_.Name }

        $offenders | Should -BeNullOrEmpty

        # positive controls: the predicate must bite on a call and ignore a prose mention
        ('$raw | ConvertFrom-Json -AsHashtable'    -match $callPattern) | Should -BeTrue
        ('  ConvertFrom-Json -AsHashtable : PS 7'  -match $callPattern) | Should -BeFalse
    }

    It 'No .ps1 uses a PS7-only null operator without declaring #Requires -Version 7' {
        # Sibling class of the -AsHashtable split above, same root cause: syntax that only ONE
        # engine understands. `??` and `??=` are PS 7.0+. Under 5.1 they are not a runtime
        # error but a PARSE error -- the script does not run AT ALL, so no amount of internal
        # error handling saves it. Measured 2026-09-08 on ai-01 (PS 5.1.26100.9168):
        #   scripts/github/sync-issues-to-project.ps1 -> 2 errors
        #   scripts/github/set-project-fields.ps1     -> 4 errors (2 of them cascade)
        # while the docs tell agents to invoke both bare, and `pwsh` is absent from po-2027.
        #
        # The instrument is the TOKENIZER, not a regex. Measured on this tree: a `??` regex
        # matched 6 files, but only 2 were defects -- the other 4 carried `??` inside STRINGS
        # (git porcelain status codes, a UI label, one line of markdown prose). The parser
        # emits QuestionQuestion only for the real operator, so strings and comments are
        # discriminated for free. The controls at the bottom prove that, rather than assume it.
        $offenders = @()
        Get-ChildItem (Join-Path $PSScriptRoot '../..') -Recurse -Filter '*.ps1' | ForEach-Object {
            $tokens = $null; $perrs = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile(
                $_.FullName, [ref]$tokens, [ref]$perrs)
            $usesPs7Only = @($tokens | Where-Object {
                $_.Kind -eq [System.Management.Automation.Language.TokenKind]::QuestionQuestion -or
                $_.Kind -eq [System.Management.Automation.Language.TokenKind]::QuestionQuestionEquals
            }).Count -gt 0
            if ($usesPs7Only) {
                # Declaring the requirement is a legitimate choice; using it silently is not.
                $declares = (Get-Content $_.FullName -Raw) -match '(?im)^\s*#Requires\s+-Version\s+([7-9]|\d{2,})'
                if (-not $declares) { $offenders += $_.Name }
            }
        }
        $offenders | Should -BeNullOrEmpty -Because 'a PS7-only operator makes the script unparseable under 5.1, which the fleet still runs'

        # Controls, on the tokenizer itself: it must bite on the operators and stay blind to
        # the same two characters appearing in a string or a comment.
        function Test-Ps7NullOp([string]$Code) {
            $tk = $null; $er = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($Code, [ref]$tk, [ref]$er)
            @($tk | Where-Object {
                $_.Kind -eq [System.Management.Automation.Language.TokenKind]::QuestionQuestion -or
                $_.Kind -eq [System.Management.Automation.Language.TokenKind]::QuestionQuestionEquals
            }).Count -gt 0
        }
        (Test-Ps7NullOp '$a = $x ?? "d"')        | Should -BeTrue  -Because 'the operator must be detected'
        (Test-Ps7NullOp '$a ??= 5')              | Should -BeTrue  -Because 'the compound form must be detected too'
        (Test-Ps7NullOp '$s = "?? in a string"') | Should -BeFalse -Because 'a string is not an operator'
        (Test-Ps7NullOp "`$s = '??'")            | Should -BeFalse -Because 'a literal is not an operator'
        (Test-Ps7NullOp '# ?? in a comment')     | Should -BeFalse -Because 'a comment is not an operator'
    }
}
