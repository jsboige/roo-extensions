<#
.SYNOPSIS
    Drift-guard for the #3731 `2>&1` class, lot 2 (intermittent sites) in
    scripts/claude/executor-preflight.ps1:

      1. `git branch --show-current` at the head of the try block ran with a
         PS-level `2>&1` under the file-global EAP=Stop — any git stderr
         chatter (warnings, config advice) let PS 5.1 mint ErrorRecords and
         promote them to a terminating NativeCommandError on a successful
         call. Intermittent by nature.

      2. The ensure-build-fresh helper invocation carried the same PS-level
         `2>&1`, mitigated only by an EAP-relax block (save/Continue/restore)
         that suppressed the promotion instead of removing the ErrorRecords.

    Both now merge stderr at the cmd.exe layer (`& cmd /c "... 2>&1"`, the
    canonical form established by #3731): PS only ever sees strings under any
    EAP, and cmd propagates the native exit code to $LASTEXITCODE.
#>

Describe 'Executor pre-flight stderr class, lot 2 (#3731)' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)
        $preflightParseErrors = @($errors).Count
    }

    It 'parses cleanly' {
        $preflightParseErrors | Should -Be 0
    }

    It 'reads the current branch via cmd-layer stderr merge, not PS-level 2>&1' {
        # Canonical lot-2 form: cmd owns the merge, so no ErrorRecord exists to
        # promote under the file-global EAP=Stop.
        $preflight | Should -Match 'cmd /c "git -C ""\$RepoRoot"" branch --show-current 2>&1"'
        # The bare PS-level redirect on the git call is gone.
        $preflight | Should -Not -Match '\& git -C \$RepoRoot branch --show-current 2>&1'
        # The exit-code guard survives the conversion (cmd propagates git's exit).
        $preflight | Should -Match 'LASTEXITCODE -ne 0'
        $preflight | Should -Match 'Could not read current branch'
    }

    It 'invokes the helper via cmd-layer stderr merge with its exit code intact' {
        $preflight | Should -Match 'cmd /c "powershell\.exe -ExecutionPolicy Bypass -File ""\$helper"" -RepoRoot ""\$RepoRoot"" -RequireFresh 2>&1"'
        # The bare PS-level redirect on the helper call is gone.
        $preflight | Should -Not -Match '-File \$helper -RepoRoot \$RepoRoot -RequireFresh 2>&1'
        # The discriminated exit below still reads $LASTEXITCODE, which cmd
        # propagates from the helper (including the absorbing 10).
        $preflight | Should -Match '\$freshExit = \$LASTEXITCODE'
        $preflight | Should -Match 'if \(\$freshExit -eq 10\)'
    }

    It 'retired the EAP-relax block around the helper call (mitigation superseded)' {
        # The relax block only existed to suppress the promotion of ErrorRecords
        # minted by the PS-level 2>&1. With cmd doing the merge there is nothing
        # to promote, so the save/restore pair must be gone from the file.
        $preflight | Should -Not -Match '\$savedEap'
        $preflight | Should -Not -Match "\`$ErrorActionPreference = 'Continue'"
    }

    It 'helper invocation stays ordered after the helper existence guard' {
        $guardIdx = $preflight.IndexOf('Test-Path $helper')
        $cmdIdx = $preflight.IndexOf('cmd /c "powershell.exe')
        $guardIdx | Should -BeGreaterOrEqual 0
        $cmdIdx | Should -BeGreaterThan $guardIdx
    }
}
