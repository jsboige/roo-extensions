<#
.SYNOPSIS
    Drift-guard for the small native binary families (powershell x2, node x1,
    python x1) of the #3731 PS-5.1 stderr class in start-claude-worker.ps1
    (lot 2, delivered 2026-09-20 on myia-po-2027). Companion of
    scw-git-stderr-class.Tests.ps1 (git family) — same class, same fix:
    merge/discard stderr at the cmd.exe layer, quote-double path
    interpolations inside the cmd string (#3740 discipline).

    Explicitly OUT of class (asserted only negatively where relevant):
    - the `npx vitest ... 2>&1 | tail -100` occurrence is PROMPT TEXT inside
      a here-string sent to Claude, not a PowerShell redirect — the scanner
      below does not match it (no powershell/node/python token).
    - `& $CleanupScript ... 2>&1` / `& $BranchCleanupScript ... 2>&1` invoke
      .ps1 scripts (PowerShell, not native): the minting mechanism of #3731
      is native-specific. Owned by no PR.
    - claude CLI sites (3) and gh sites (13+7) are remaining families.

    Engine-independent assertions (regex over raw text) — the guard runs
    under pwsh/Pester 6, the engine where the class is invisible.
#>

Describe 'start-claude-worker misc-native families stderr class (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:scwPath = Join-Path $root 'scripts\scheduling\start-claude-worker.ps1'
        $script:lines = Get-Content -LiteralPath $script:scwPath
        $script:src = Get-Content -LiteralPath $script:scwPath -Raw
    }

    It 'no PS-level powershell/node/python stderr redirect survives outside the cmd.exe layer' {
        $bare = @()
        for ($i = 0; $i -lt $script:lines.Count; $i++) {
            $ln = $script:lines[$i]
            if ($ln -match '\b(powershell|pwsh|node|python)\b' -and $ln -match '2>&1|2>\$null' -and
                $ln -notmatch 'cmd /c' -and -not $ln.TrimStart().StartsWith('#')) {
                $bare += ('{0}: {1}' -f ($i + 1), $ln.Trim())
            }
        }
        @($bare) | Should -Be @()
    }

    It 'stdin-pipe site converted without losing the pipe (sk-agent handshake)' {
        $script:src | Should -Match '\$Request \| & cmd /c "powershell [^\r\n]*2>&1"'
    }

    It 'the converted file parses cleanly under the running engine' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scwPath, [ref]$null, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}
