<#
.SYNOPSIS
    Drift-guard for the git binary-family conversion of the #3731 PS-5.1
    stderr class in start-claude-worker.ps1 (lot 2, delivered 2026-09-20
    on myia-po-2027).

    Background (#3731): a PS-level `2>&1` / `2>$null` on a NATIVE command
    makes PowerShell mint ErrorRecords from stderr lines; under
    $ErrorActionPreference = 'Stop' (start-claude-worker.ps1 L69) the first
    minted record terminates the worker. The fix merges/discards stderr at
    the cmd.exe layer: `& cmd /c "git ... 2>&1"` (merge) / `2>nul` (discard).

    Quoting discipline (#3740, ai-01-measured): moving the redirect into the
    cmd string changes argument passing — every FILE PATH interpolation
    inside the cmd string MUST be quote-doubled (`""$Path""`), while git refs
    (no spaces by git's own rules) and integers stay bare.

    The multi-line auto-commit message cannot cross the cmd layer as a single
    -m: it is expressed as two -m flags, which git joins with a blank line —
    byte-identical to the previous `title`n`n`trailer` single -m.

    Assertions are engine-independent (regex over raw text) because the
    drift-guard itself runs under pwsh/Pester 6 — the engine where the
    underlying defect is invisible.
#>

Describe 'start-claude-worker git-family stderr class (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:scwPath = Join-Path $root 'scripts\scheduling\start-claude-worker.ps1'
        $script:src = Get-Content -LiteralPath $script:scwPath -Raw
        $script:lines = Get-Content -LiteralPath $script:scwPath
    }

    It 'no PS-level git stderr redirect survives outside the cmd.exe layer' {
        $bare = @()
        for ($i = 0; $i -lt $script:lines.Count; $i++) {
            $ln = $script:lines[$i]
            if ($ln -match '\bgit\b' -and $ln -match '2>&1|2>\$null' -and
                $ln -notmatch 'cmd /c' -and -not $ln.TrimStart().StartsWith('#')) {
                $bare += ('{0}: {1}' -f ($i + 1), $ln.Trim())
            }
        }
        # gh/claude/node/powershell sites and PS cmdlets are other families —
        # this guard scopes to the git binary family only.
        @($bare) | Should -Be @()
    }

    It 'merge form present: git stderr merged at the cmd.exe layer (2>&1 inside the cmd string)' {
        # [^\r\n]* (not [^"]*): the cmd string legitimately contains doubled
        # quotes (""$Path"") between `git` and the redirect.
        $script:src | Should -Match 'cmd /c "git [^\r\n]*2>&1"'
    }

    It 'discard form present: git stderr discarded at the cmd.exe layer (2>nul)' {
        $script:src | Should -Match 'cmd /c "git [^\r\n]*2>nul"'
    }

    It 'quoting discipline: every `git -C` target inside a cmd string is quote-doubled' {
        $offenders = @([regex]::Matches($script:src, 'cmd /c "git (-C|--git-dir) (..)') |
            Where-Object { $_.Groups[2].Value -ne '""' })
        @($offenders) | Should -Be @()
    }

    It 'no single-quoted argument inside a git cmd string (single quotes survive cmd literally — po-204 review, PR #3748)' {
        # PowerShell strips single quotes at parse time; cmd does NOT. A
        # 'arg' inside a cmd /c "git …" string reaches git WITH its quotes:
        # pathspec magic (':!path') dies with exit 128, and exclude patterns
        # (-e '*.log') match nothing — the exclusion silently dies (probed
        # firsthand in scratch repos under 5.1, 2026-09-20).
        # The cmd-string CONTENT is extracted (up to the trailing 2>&1"/2>nul")
        # so single quotes in downstream PS code after the string don't
        # produce false positives.
        $contents = @([regex]::Matches($script:src, 'cmd /c "git (.*?)(?: 2>&1| 2>nul)"') |
            ForEach-Object { $_.Groups[1].Value })
        $offenders = @($contents | Where-Object { $_ -match "'" })
        $contents.Count | Should -BeGreaterThan 0
        @($offenders) | Should -Be @()
    }

    It 'auto-commit message uses two -m flags (a multiline -m cannot cross the cmd layer)' {
        $script:src | Should -Match 'git commit -m ""[^"]+"" -m ""'
    }

    It 'the converted file parses cleanly under the running engine' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scwPath, [ref]$null, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}
