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

    Lot 8 (#4150, doctrine #4604) retire deux sous-classes ENTIERES : les
    lectures du worker passent par les modules REST (gh-issues.ps1,
    gh-pull-requests.ps1), il ne reste en cmd-layer gh que des MUTATIONS
    (claim, [RESULT], POST reviewers — toutes 2>&1). Les tests « discard
    form present » (gh ... 2>nul) et « --search quote-doubled » gardaient
    la présence de formes dont le DERNIER PORTEUR était une jambe convertie
    — supprimés avec le lot ; les gardes de CLASSE (pas de redirect gh hors
    cmd-layer, pas de simple quote, jq doublé, sous-expressions) restent
    et mordent toujours sur les sites survivants.

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
        # Lot 8 : les mutations cmd-layer restantes (claim, [RESULT], POST
        # reviewers) fusionnent toutes en 2>&1 — le discard gh (2>nul) n a
        # plus de porteur depuis la conversion REST des lectures (mesuré :
        # les 2>nul survivants sont tous des appels git). Un futur site gh
        # en 2>nul resterait conforme #3731 — rien ne l interdit ici.
        $script:src | Should -Match 'cmd /c "gh [^\r\n]*2>&1"'
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

    It 'jq expressions inside gh cmd strings are quote-doubled when present (--jq ""..."" — pipes need double quotes)' {
        # Lot 8 convertit les trois lectures REST de Request-StaleReview au
        # module : aucun --jq cmd-layer ne subsiste. Le pin NÉGATIF reste la
        # garde de classe : il examine chaque site jusqu'à sa redirection
        # cmd, y compris quand le --jq tombe sur une ligne suivante (#4645).
        # Les blocs de prompt/here-string ne sont pas des sites cmd réels.
        $callSites = @([regex]::Matches($script:src,
            '(?ms)^[ \t]*&[ \t]+cmd[ \t]+/c[ \t]+"gh .*?(?:2>&1|2>nul)"'))
        $offenders = @($callSites | Where-Object { $_.Value -match "--jq '" })
        @($offenders) | Should -Be @()
    }

    It 'no --search survives in an executable gh cmd string (lot 8: the class left with the last GraphQL leg)' {
        # Lot 8 (#4150) : le dernier `--search` exécutable (réconciliation
        # d artefacts, `#N in:title,body created:>=X`) vit désormais dans le
        # module REST (Get-PullRequestSummary -CreatedSince). Un --search
        # qui reparaîtrait en cmd-layer serait une jambe GraphQL de retour.
        $script:lines | Where-Object { $_ -match '--search' -and -not $_.TrimStart().StartsWith('#') } |
            Should -Be @()
    }

    It 'the multiline [RESULT] comment path uses a temp body-file (a multiline --body cannot cross cmd)' {
        $script:src | Should -Match 'gh issue comment \$\(\$Task\.issueNumber\) --repo jsboige/roo-extensions --body-file ""\$ResultBodyFile"" 2>&1'
    }

    It 'PR titles are quote-stripped before crossing the cmd layer (#3752 F1)' {
        # A double-quote interpolated into `--title ""$Title""` closes the
        # cmd.exe quoting context and mangles the argument list. Task
        # subjects derive from issue titles, which can carry quotes — the
        # strip must happen at construction, not at the call site.
        $script:src | Should -Match '\$CleanSubject = [^\r\n]*-replace ''"'', '''''
    }

    It 'temp body-files are removed in finally blocks (#3752 F2 — no leak if the cmd call throws)' {
        # Straight-line Remove-Item is skipped when the & cmd /c invocation
        # throws; a finally guarantees cleanup on both paths.
        $script:src | Should -Match '\} finally \{\s*\r?\n\s*Remove-Item \$BodyFile'
        $script:src | Should -Match '\} finally \{\s*\r?\n\s*Remove-Item \$ResultBodyFile'
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
