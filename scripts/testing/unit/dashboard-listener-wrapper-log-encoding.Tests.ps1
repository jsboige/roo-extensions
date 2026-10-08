<#
.SYNOPSIS
    Regression coverage for #3761 residue (b): listener log encoding must not follow the engine.

.DESCRIPTION
    Tee-Object -FilePath writes UTF-8 no BOM under PS 7 but UTF-16LE under PS 5.1.
    The wrapper is invoked by whichever engine the hidden VBS launcher names, and
    that engine has already flipped once fleet-wide (harden #75 pins launchers to
    5.1; pwsh is absent from some machines). Measured on po-2023: the same log dir
    holds UTF-8 days (listener-20261004) and one UTF-16LE day (listener-20261005)
    - and readers grep these files raw (vibe-feeder.ps1 looks for PROMPT_OK /
    PROMPT_TIMEOUT lines), so a UTF-16LE day silently blinds the RUN-IN-FLIGHT
    guard.

    Add-LogFileLine owns the append with an explicit UTF8Encoding($false) - the
    same .NET call as the listener's other write sites, byte-identical on every
    engine.

    Non-ASCII content in the assertions is built from [char] codes, not literals:
    a BOM-less .ps1 read under PS 5.1 decodes literals as ANSI, which would make
    the test lie about bytes it never wrote.

    Extraction pattern: dashboard-listener-poll-nullguard.Tests.ps1 (AST function
    extraction - the wrapper runs a single-instance mutex and an infinite loop,
    so it cannot be dot-sourced).

    Excluded from CI? No - unit suite, pure temp-dir file effects.
#>

Describe 'Listener wrapper log encoding (#3761 residue b)' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $wrapperPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/dashboard-listener-wrapper.ps1'

        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $wrapperPath, [ref]$tokens, [ref]$parseErrors)
        @($parseErrors) | Should -BeNullOrEmpty

        $script:WrapperText = [System.IO.File]::ReadAllText($wrapperPath)

        $definition = $ast.FindAll(
            { param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $true
        ) | Where-Object Name -EQ 'Add-LogFileLine' | Select-Object -First 1
        if (-not $definition) { throw "Add-LogFileLine not found in $wrapperPath" }

        Invoke-Expression $definition.Extent.Text

        $script:Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("t3761enc-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $script:Tmp -Force | Out-Null
    }
    AfterAll {
        if (Test-Path $script:Tmp) { Remove-Item $script:Tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }

    Context 'Add-LogFileLine - byte-exact UTF-8 no BOM on every engine' {
        It 'creates the file with no BOM and no UTF-16 NUL bytes' {
            $f = Join-Path $script:Tmp 'fresh.log'
            Add-LogFileLine $f 'first line'
            $bytes = [System.IO.File]::ReadAllBytes($f)
            $bytes[0] | Should -Not -Be 0xEF    # UTF-8 BOM
            $bytes[0] | Should -Not -Be 0xFF    # UTF-16LE BOM
            ($bytes -contains 0) | Should -BeFalse -Because 'an interleaved NUL every other byte is the UTF-16LE signature'
        }

        It 'appends: two calls give two readable UTF-8 lines' {
            $f = Join-Path $script:Tmp 'append.log'
            Add-LogFileLine $f 'alpha'
            Add-LogFileLine $f 'beta'
            $lines = [System.IO.File]::ReadAllLines($f, [System.Text.UTF8Encoding]::new($false))
            $lines.Count | Should -Be 2
            $lines[0] | Should -Be 'alpha'
            $lines[1] | Should -Be 'beta'
        }

        It 'non-ASCII content round-trips as UTF-8 bytes, not UTF-16LE' {
            # 'e-acute' in UTF-8 = 0xC3 0xA9; in UTF-16LE = 0xE9 0x00.
            $f = Join-Path $script:Tmp 'accent.log'
            Add-LogFileLine $f ("debut" + [char]0xE9)
            $bytes = [System.IO.File]::ReadAllBytes($f)
            ($bytes -contains 0xC3) | Should -BeTrue -Because 'the UTF-8 lead byte must be present'
            ($bytes -contains 0) | Should -BeFalse -Because 'a NUL byte would mean UTF-16LE won'
        }

        It 'a failed append does not throw (logging must never kill the listener chain)' {
            { Add-LogFileLine $script:Tmp 'x' } | Should -Not -Throw
        }
    }

    Context 'Static composition - the wrapper no longer tees' {
        It 'no Tee-Object call survives in the wrapper' {
            # Executable form (piped call), not the bare name: the helper's own
            # doc-comment names Tee-Object in prose, and a bare-name assertion
            # would fail on the comment that justifies the fix.
            $script:WrapperText | Should -Not -Match '\|\s*Tee-Object'
            # positive control: the predicate bites on the pre-fix shape
            '"$Message [$ts]" | Tee-Object -FilePath $logFile -Append' | Should -Match '\|\s*Tee-Object'
        }

        It 'both former sites route through Add-LogFileLine' {
            ([regex]::Matches($script:WrapperText, 'Add-LogFileLine \$logFile')).Count | Should -Be 2
        }

        It 'the append carries the explicit no-BOM encoding' {
            $script:WrapperText | Should -Match 'AppendAllText'
            $script:WrapperText | Should -Match 'UTF8Encoding\]::new\(\$false\)'
        }
    }
}
