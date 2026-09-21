<#
.SYNOPSIS
    Drift-guard for the gh binary-family conversion of the #3731 PS-5.1
    stderr class in start-claude-worker.ps1 (lot 2, delivered 2026-09-20
    on myia-po-2027).

    Background (#3731): a PS-level `2>&1` / `2>$null` on a NATIVE command
    makes PowerShell mint ErrorRecords from stderr lines; under
    $ErrorActionPreference = 'Stop' (start-claude-worker.ps1) the first
    minted record terminates the worker. The fix merges/discards stderr at
    the cmd.exe layer: `& cmd /c "gh ... 2>&1"` (merge) / `2>nul` (discard).

    gh-specific subclasses probed firsthand under PS 5.1 (2026-09-20):
    - jq expressions must be quote-doubled (`--jq "".[0].url""`): single
      quotes do NOT cross the cmd layer, and pipes inside the expression
      are only protected from cmd inside double quotes.
    - `--search` values carry spaces — same quote-doubling.
    - Em-dashes in single-line --body args survive (UTF-16 command line),
      but MULTILINE bodies cannot cross the cmd layer at all — the [RESULT]
      comment path must use a temp --body-file.
    - Property-access arguments ($Task.issueNumber, $Issue.number) must be
      subexpressions in a string ($($Task.issueNumber)) — a bare
      $Obj.prop in a double-quoted string interpolates the object, not the
      property.

    Assertions are engine-independent (regex over raw text) because the
    drift-guard itself runs under pwsh/Pester 6 — the engine where the
    underlying defect is invisible.
#>

Describe 'start-claude-worker gh-family stderr class (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:scwPath = Join-Path $root 'scripts\scheduling\start-claude-worker.ps1'
        $script:src = Get-Content -LiteralPath $script:scwPath -Raw
        $script:lines = Get-Content -LiteralPath $script:scwPath
    }

    It 'no PS-level gh stderr redirect survives outside the cmd.exe layer' {
        $bare = @()
        for ($i = 0; $i -lt $script:lines.Count; $i++) {
            $ln = $script:lines[$i]
            if ($ln -match '\bgh\b' -and $ln -match '2>&1|2>\$null' -and
                $ln -notmatch 'cmd /c' -and -not $ln.TrimStart().StartsWith('#')) {
                $bare += ('{0}: {1}' -f ($i + 1), $ln.Trim())
            }
        }
        @($bare) | Should -Be @()
    }

    It 'merge form present: gh stderr merged at the cmd.exe layer (2>&1 inside the cmd string)' {
        $script:src | Should -Match 'cmd /c "gh [^\r\n]*2>&1"'
    }

    It 'discard form present: gh stderr discarded at the cmd.exe layer (2>nul)' {
        $script:src | Should -Match 'cmd /c "gh [^\r\n]*2>nul"'
    }

    It 'no single-quoted argument inside a gh cmd string (single quotes survive cmd literally)' {
        # PowerShell strips single quotes at parse time; cmd does NOT. A
        # '--jq ''.state''' or '--search ''is:open ...'' inside a cmd string
        # reaches gh WITH its quotes: jq evaluates a string literal, and a
        # spaced search query splinters into separate arguments. The
        # cmd-string CONTENT is extracted so single quotes in downstream PS
        # code don't produce false positives.
        $contents = @([regex]::Matches($script:src, 'cmd /c "gh (.*?)(?: 2>&1| 2>nul)"') |
            ForEach-Object { $_.Groups[1].Value })
        $offenders = @($contents | Where-Object { $_ -match "'" })
        $contents.Count | Should -BeGreaterThan 0
        @($offenders) | Should -Be @()
    }

    It 'jq expressions inside gh cmd strings are quote-doubled (--jq ""..."" — pipes need double quotes)' {
        $script:src | Should -Match '--jq "".+""'
        $script:src | Should -Not -Match "--jq '"
    }

    It 'search values inside gh cmd strings are quote-doubled (--search ""..."")' {
        $script:src | Should -Match '--search "".+""'
        $script:src | Should -Not -Match "--search '"
    }

    It 'the multiline [RESULT] comment path uses a temp body-file (a multiline --body cannot cross cmd)' {
        $script:src | Should -Match 'gh issue comment \$\(\$Task\.issueNumber\) --repo jsboige/roo-extensions --body-file ""\$ResultBodyFile"" 2>&1'
    }

    It 'property-access gh arguments are subexpressions in the cmd string' {
        # `$Task.issueNumber` bare in a double-quoted string interpolates the
        # object, not the property — the issue number would arrive garbage.
        $script:src | Should -Match 'gh (issue (view|edit|comment)|pr list) \$\(\$\w+\.\w+\)'
        $script:src | Should -Not -Match 'gh (issue|pr) \w+ \$\w+\.\w+ '
    }

    It 'the worker-report subject is quote-stripped before crossing the cmd layer (#3752 F3)' {
        # Same class as F1, node send-CLI site (worker-report): $Task.subject
        # derives from issue titles, and a " would close the cmd.exe quoting
        # context of --subject. Pinned here beside F1/F2 as the F-series home.
        $script:src | Should -Match '\$Subject = "Worker Report - \$\(\$Task\.subject -replace ''"'', ''''\)"'
    }

    It 'the converted file parses cleanly under the running engine' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:scwPath, [ref]$null, [ref]$errors) | Out-Null
        @($errors).Count | Should -Be 0
    }
}
