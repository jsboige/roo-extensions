<#
.SYNOPSIS
    Drift-guard for the PS 5.1 parse/encoding class found 2026-09-20 on
    myia-po-2027 (lot 2 follow-up): two independent ways a script that is
    green under pwsh 7 dies under Windows PowerShell 5.1.

    (a) ENCODING: a .ps1 saved UTF-8 WITHOUT BOM is decoded cp1252 by 5.1.
        Any em-dash (E2 80 94) then reads as "a euro-sign + RIGHT DOUBLE
        QUOTATION MARK" -- and 0x94 IS a quote delimiter to PowerShell.
        Inside a double-quoted string it silently CLOSES the string and the
        remainder of the line re-parses as commands: deploy-preop-guard.ps1
        threw CommandNotFoundException 'fail-closed' on EVERY 5.1 call
        (the executor preflight pre-op guard was dead fleet-wide).
    (b) GRAMMAR: pwsh 7 accepts a pipeline whose first segment sits on the
        NEXT line after `|` (leading-pipe continuation); 5.1 rejects it with
        "empty pipeline element". create-worktree.ps1 never parsed under 5.1.

    These assertions are deliberately engine-independent (bytes + regex),
    because the drift-guard itself runs under pwsh/Pester 6 -- the engine
    where both defects are invisible.
#>

Describe 'PS 5.1 parse/encoding class (2026-09-20)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:guardPath = Join-Path $root 'scripts\mcp\deploy-preop-guard.ps1'
        $script:worktreesRoot = Join-Path $root 'scripts\worktrees'

        $script:parseTargets = @(
            $script:guardPath,
            (Join-Path $script:worktreesRoot 'create-worktree.ps1')
        )
        # create-worktree.ps1 joined the targets after #3745 (leading-pipe
        # repair, 1-char backtick) merged — it now parses under 5.1.
        $script:pipeTargets = @(
            $script:guardPath,
            (Join-Path $script:worktreesRoot 'create-worktree.ps1'),
            (Join-Path $script:worktreesRoot 'cleanup-worktree.ps1'),
            (Join-Path $script:worktreesRoot 'check-worktrees.ps1'),
            (Join-Path $script:worktreesRoot 'submit-pr.ps1')
        )
    }

    It 'deploy-preop-guard.ps1 carries a UTF-8 BOM (5.1 decodes no-BOM files as cp1252)' {
        $bytes = [System.IO.File]::ReadAllBytes($script:guardPath)
        $bytes.Length | Should -BeGreaterThan 3
        '{0:X2} {1:X2} {2:X2}' -f $bytes[0], $bytes[1], $bytes[2] | Should -Be 'EF BB BF'
    }

    It 'no script starts a pipeline with a leading pipe (5.1 rejects, pwsh 7 accepts)' {
        foreach ($p in $script:pipeTargets) {
            $lines = Get-Content $p
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^\s*\|\s') {
                    # Legal in 5.1 too when the previous line ends with a
                    # backtick (escape continuation joins the two lines into
                    # one logical line -- the #3745 repair form). A leading
                    # `|` WITHOUT that continuation is the pwsh-7-only form.
                    $prev = if ($i -gt 0) { $lines[$i - 1].TrimEnd() } else { '' }
                    if ($prev -notmatch '`$') {
                        "${p}:$($i + 1) leads with a pipe not preceded by a backtick continuation" |
                            Should -BeNullOrEmpty -Because "previous line: $prev"
                    }
                }
            }
        }
    }

    It 'the repaired file parses cleanly under the running engine' {
        foreach ($p in $script:parseTargets) {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errors) | Out-Null
            @($errors).Count | Should -Be 0
        }
    }
}
