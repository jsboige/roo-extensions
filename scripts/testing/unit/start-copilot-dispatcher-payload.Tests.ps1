# Pester 5 tests: the Copilot dispatcher's Phase C prompt must travel BY FILE,
# never in argv (#622, Copilot lane).
#
# Defect these tests pin (measured on this host, 4 scheduled runs -- 08/10 x2,
# 09/10, 10/10):
#     Phase C execution failed (exit=1)
#     Dispatch output: La ligne de commande est trop longue.
# Windows CreateProcess caps the WHOLE command line at 32,767 characters. A
# work prompt past that never reaches the CLI, and the 180-minute escalation
# cooldown turns each miss into a SILENT failure: two dead runs a day, no
# escalation, no work. Escaping (ConvertTo-NativeArg) and length are INDEPENDENT
# defects -- escaping can be perfect, as it is, and the call still dies on size.
#
# What the fix buys, and what is asserted here: the argv becomes a constant
# ~100-character POINTER whatever the payload weighs, and the CLI reads the file
# itself (--allow-all-tools already grants file read -- same scope as before).
#
# Design notes (why these assertions can go red):
# * The decision core (Write-CopilotPromptFile, Get-DispatchArgv) is extracted
#   from the SHIPPED source text, never re-typed -- a re-typed copy would stay
#   green while the production script drifted away from it.
# * The load-bearing assertion is not "the argv is short" but "the argv length
#   is INDEPENDENT of the payload size" (measured on two payloads three orders
#   of magnitude apart). A fix that merely truncates the prompt would satisfy
#   the first and fail the second.
# * The last test is a POSITIVE CONTROL: it reverts the call site to the defect
#   form and asserts the wiring predicate reddens on it. If the predicate ever
#   stops discriminating, the control fails instead of the invariants above
#   passing vacuously.
#
# Run:  powershell -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/start-copilot-dispatcher-payload.Tests.ps1
# Or the whole unit suite (what CI runs):  ./scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit -CI

BeforeAll {
    $script:productionScript = Join-Path $PSScriptRoot '../../scheduling/start-copilot-dispatcher.ps1'
    $script:src = Get-Content -LiteralPath $script:productionScript -Raw

    # Extract the SHIPPED functions (first column-0 closing brace = their own end).
    foreach ($name in @('Write-CopilotPromptFile', 'Get-DispatchArgv')) {
        $m = [regex]::Match($script:src, "(?s)(function $name \{.*?\r?\n\})")
        if (-not $m.Success) { throw "$name not found in start-copilot-dispatcher.ps1" }
        Invoke-Expression $m.Groups[1].Value
    }

    # The wiring predicate, as one expression so the positive control can drive
    # the SAME logic against a mutated source instead of a copy of the regexes.
    $script:ArgvCarriesPointer = {
        param([string]$Text)
        ($Text -match '& copilot -p \(ConvertTo-NativeArg \$dispatchArgv\)') -and
        ($Text -notmatch '& copilot -p \(ConvertTo-NativeArg \$Prompt\)')
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 payload lands in a file (behavioral)' {

    It 'writes the payload verbatim, under outputs/scheduling/prompts/' {
        $stamp = [datetime]'2026-10-10T05:30:00'
        $path = Write-CopilotPromptFile -RepositoryRoot $TestDrive -Prompt 'corps du prompt' -Stamp $stamp

        $path | Should -Be (Join-Path $TestDrive 'outputs\scheduling\prompts\copilot-prompt-20261010-053000.md')
        Test-Path -LiteralPath $path | Should -BeTrue
        [System.IO.File]::ReadAllText($path) | Should -Be 'corps du prompt'
    }

    It 'writes UTF-8 WITHOUT a BOM (a BOM would corrupt the head of the CLI input)' {
        # The repo's own house rule: PowerShell writers that add a BOM break parsers
        # downstream. The pointer hands this file to a CLI, not to a PS cmdlet.
        $path = Write-CopilotPromptFile -RepositoryRoot $TestDrive `
            -Prompt 'accents : e a u << >>' -Stamp ([datetime]'2026-10-10T05:30:01')

        $bytes = [System.IO.File]::ReadAllBytes($path)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        [System.IO.File]::ReadAllText($path) | Should -Be 'accents : e a u << >>'
    }

    It 'keeps the argv a short constant pointer for a 40,000-char payload' {
        $payload = 'x' * 40000
        $path = Write-CopilotPromptFile -RepositoryRoot $TestDrive `
            -Prompt $payload -Stamp ([datetime]'2026-10-10T05:30:02')

        # The payload really did land whole (the fix must not truncate it).
        [System.IO.File]::ReadAllText($path).Length | Should -Be 40000

        $argv = Get-DispatchArgv -PromptFilePath $path
        $argv.Length | Should -BeLessThan 500
        # Comfortably under the Windows CreateProcess cap, argv plus flags alike.
        ($argv.Length + 40) | Should -BeLessThan 32767
        $argv | Should -Match ([regex]::Escape($path))
    }

    It 'the argv length is INDEPENDENT of the payload size (the load-bearing property)' {
        # Same-length stamps so the two pointers differ only by their payload.
        $smallPath = Write-CopilotPromptFile -RepositoryRoot $TestDrive `
            -Prompt 'a' -Stamp ([datetime]'2026-10-10T05:30:10')
        $bigPath = Write-CopilotPromptFile -RepositoryRoot $TestDrive `
            -Prompt ('b' * 40000) -Stamp ([datetime]'2026-10-10T05:30:11')

        (Get-DispatchArgv -PromptFilePath $bigPath).Length |
            Should -Be (Get-DispatchArgv -PromptFilePath $smallPath).Length
    }
}

Describe 'start-copilot-dispatcher.ps1 — #622 wiring (payload never in argv)' {

    It 'the Phase C call site hands the CLI the pointer, not the payload' {
        & $script:ArgvCarriesPointer $script:src | Should -BeTrue
    }

    It 'the payload is written to a file, then the argv is derived from that file' {
        $script:src | Should -Match '\$promptFile = Write-CopilotPromptFile -RepositoryRoot \$RepositoryRoot -Prompt \$Prompt -Stamp \(Get-Date\)'
        $script:src | Should -Match '\$dispatchArgv = Get-DispatchArgv -PromptFilePath \$promptFile'
    }

    It 'both lengths are logged, so a regression shows up in the run own log' {
        # Without this, the next size regression is invisible again: the failure
        # mode is a CLI error line, not a crasher, and the cooldown hides it.
        $script:src | Should -Match 'Phase C prompt payload: \{0\} chars'
        $script:src | Should -Match 'Phase C argv: \{0\} chars'
    }

    It 'the prompt file lives under outputs/ (gitignored), never in the repository' {
        # Single-quoted pattern: PowerShell does NOT process backslash escapes, so
        # a double-quoted '\\\\' would reach the regex as two literal backslashes.
        $script:src | Should -Match 'Join-Path \$RepositoryRoot ''outputs\\scheduling\\prompts'''
    }

    It 'exactly one copilot dispatch call site remains (denominator)' {
        # Prose mentions of the call (the #622 comment block quotes it) are not
        # call sites: the `& ` invocation prefix is the discriminator.
        $callLines = @($script:src -split '\r?\n' |
            Where-Object { $_ -match '& copilot -p' -and $_ -notmatch '^\s*#' })
        $callLines | Should -HaveCount 1
        $callLines[0] | Should -Match '\$dispatchArgv'
    }

    It 'positive control: the wiring predicate reddens on the reverted (#622 defect) form' {
        # String.Replace is literal -- a -replace pattern would read the leading
        # `$` as an end-of-line anchor and silently mutate nothing.
        $reverted = $script:src.Replace(
            '& copilot -p (ConvertTo-NativeArg $dispatchArgv)',
            '& copilot -p (ConvertTo-NativeArg $Prompt)')

        $reverted | Should -Not -Be $script:src          # the mutation actually took
        & $script:ArgvCarriesPointer $reverted | Should -BeFalse
    }
}
