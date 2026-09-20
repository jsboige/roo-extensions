<#
.SYNOPSIS
    Drift-guard for the claude CLI family conversion of the #3731 PS-5.1
    stderr class in start-claude-worker.ps1 (lot 2, final family,
    delivered 2026-09-21 on myia-po-2027).

    Background (#3731): a PS-level `2>&1` on a NATIVE command makes
    PowerShell mint ErrorRecords from stderr lines; under
    $ErrorActionPreference = 'Stop' the first minted record terminates the
    worker. The fix merges stderr at the cmd.exe layer.

    claude-family specifics probed firsthand under PS 5.1 (2026-09-21):
    - STDIN passthrough: `Get-Content -Raw | & cmd /c "claude ... -p -"`
      delivers the prompt payload to the child intact (200 KB probe,
      exact length + tail fidelity). The prompt MUST keep entering via
      stdin (cycle-42 bug fix — never as an argument).
    - PATH resolution: cmd resolves `claude` identically to PowerShell
      wherever the binary is on PATH (probe: both forms returned
      2.1.273, exit 0). No absolute-path hardcoding.

    Assertions are engine-independent (regex over raw text).
#>

Describe 'start-claude-worker claude-CLI-family stderr class (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:scwPath = Join-Path $root 'scripts\scheduling\start-claude-worker.ps1'
        $script:src = Get-Content -LiteralPath $script:scwPath -Raw
        $script:lines = Get-Content -LiteralPath $script:scwPath
    }

    It 'no PS-level claude stderr redirect survives outside the cmd.exe layer' {
        $bare = @()
        for ($i = 0; $i -lt $script:lines.Count; $i++) {
            $ln = $script:lines[$i]
            if ($ln -match '\bclaude\b' -and $ln -match '2>&1|2>\$null' -and
                $ln -notmatch 'cmd /c' -and -not $ln.TrimStart().StartsWith('#')) {
                $bare += ('{0}: {1}' -f ($i + 1), $ln.Trim())
            }
        }
        # Prose mentions (DryRun log lines, comments) carry no redirect and
        # are excluded by the redirect predicate itself.
        @($bare) | Should -Be @()
    }

    It 'merge form present: claude stderr merged at the cmd.exe layer' {
        $script:src | Should -Match 'cmd /c "claude [^\r\n]*2>&1"'
    }

    It 'the stream-json invocation keeps entering via STDIN through the cmd wrapper (cycle-42 invariant)' {
        # The prompt crosses as `Get-Content -Raw | & cmd /c "claude ... -p - ..."`
        # — piped stdin, never an argument. Converting the redirect must not
        # turn the prompt into a command-line argument.
        $script:src | Should -Match 'Get-Content \$PromptFile -Raw \| & cmd /c "claude [^\r\n]*-p -[^\r\n]*2>&1"'
    }

    It 'the model token stays a bare argument inside the cmd string (no quoting drift)' {
        $script:src | Should -Match 'cmd /c "claude [^\r\n]*--model \$ModelToUse[ "]'
    }

    It 'the converted file parses cleanly under the running engine' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scwPath, [ref]$null, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}
