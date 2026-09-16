<#
.SYNOPSIS
    Guards the two #3605-incident fixes to scripts/claude/executor-preflight.ps1:

      1. Detached-HEAD / null-branch guard before .Trim() at the start of the try
         block. A null or empty current branch must throw with actionable context
         instead of a bare NullReferenceException.

      2. Catch block must NEVER reach `$_.Exception.Message` when `$_.Exception`
         is null (NativeCommandError and other ErrorRecords without a wrapped
         Exception). The original error must remain visible to the operator.
#>

Describe 'Executor pre-flight bugfixes (#3605-incident)' {
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

    It 'guards against a null or empty current branch before .Trim() (no detached-HEAD NRE)' {
        # Old code: `$branch = (& git -C ... branch --show-current).Trim()` then
        # `$branch -ne 'main'` — a detached HEAD returns empty, `.Trim()` throws
        # a NullReferenceException, and the user sees no actionable context.
        # New code: explicit empty-string guard with a message that points at
        # the most likely cause (RepoRoot auto-detection resolving to a submodule
        # when the working directory inherits a Bash session).
        $preflight | Should -Not -Match '\(\& git -C \$RepoRoot branch --show-current\)\.Trim\(\)'
        $preflight | Should -Match 'IsNullOrEmpty\(\$branch\)'
        $preflight | Should -Match 'detached HEAD'
        $preflight | Should -Match '-RepoRoot'
    }

    It 'reads current branch with explicit git exit-code guard' {
        $preflight | Should -Match 'LASTEXITCODE -ne 0'
        $preflight | Should -Match 'Could not read current branch'
    }

    It 'catch block must guard $_.Exception access before reading .Message' {
        # Old code: `Write-Error "[executor-preflight][BLOCKED] $($_.Exception.Message)"`
        # — when the failing statement throws an ErrorRecord without a wrapped
        # Exception (NativeCommandError, etc.), `$_.Exception` is null and the
        # .Message accessor throws again, masking the original error.
        # New code: a local `$detail` is computed from a guarded test of
        # `$_.Exception` (and `$_.ToString()` as a fallback), then passed to
        # Write-Error. The unguarded `Write-Error "...$($_.Exception.Message)"`
        # pattern is gone.
        $catchBlock = ($preflight -split '\} catch \{', 2)[1]
        $catchCode = ($catchBlock -split "`r?`n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        # Unguarded dereference of .Message directly inside Write-Error is banned.
        $catchCode | Should -Not -Match 'Write-Error\s+"\[executor-preflight\]\[BLOCKED\]\s*\$\(\$_\.Exception\.Message\)'
        # The guarded form is in place.
        $catchCode | Should -Match 'if \(\$_\.Exception\)'
        $catchCode | Should -Match '\$_\.ToString\(\)'
        # Write-Error now receives the local `$detail`, not a direct expression
        # on $_.Exception.
        $catchCode | Should -Match 'Write-Error\s+"\[executor-preflight\]\[BLOCKED\]\s*\$detail"'
    }

    It 'catch block still calls Clear-BlockageState to reset the streak' {
        # Spec #3605: a failed pre-flight must not observe the absorbing form,
        # so the streak must reset even on hard errors.
        $catchBlock = ($preflight -split '\} catch \{', 2)[1]
        $catchClear = $catchBlock.IndexOf('Clear-BlockageState')
        $catchClear | Should -BeGreaterThan -1
        $catchBlock.IndexOf('Write-Error', $catchClear) | Should -BeGreaterThan $catchClear
    }
}
