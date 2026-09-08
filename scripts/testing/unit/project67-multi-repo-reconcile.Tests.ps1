<#
.SYNOPSIS
    Guard: Project #67 reconcile must track BOTH repositories, and must key on repo+number.

.DESCRIPTION
    Project #67 is the dispatch board for the whole system, but part of the work lives in the
    submodule repository (jsboige/jsboige-mcp-servers). MEASURED 2026-09-08 on ai-01: 29 open
    issues there, ZERO of them on the board -- sync-project.yml only ever reconciled its own
    repository, and sync-issues-to-project.ps1 defaulted to it.

    Two independent defects, so two independent guards:

      1. The workflow reconciled ONE repository. Fixed by looping over a list.
      2. The dedup key was the bare issue NUMBER, parsed from the item URL with the repository
         segment discarded. Harmless with one repository; with two it collapses
         roo-extensions#N and jsboige-mcp-servers#N onto one key, so the second one read is
         silently treated as "already in project" and never added -- a gap that reports
         nothing. Measured the day of the fix: 735 issue items, 735 distinct repo#number keys,
         0 collisions yet. LATENT, not triggered -- which is exactly why a test is worth more
         than the observation.

    The key guard is BEHAVIOURAL, not textual: it extracts the regex the script actually uses
    and runs it against the two colliding URLs. A textual assertion would pass on any string
    that merely mentions a repository.

.NOTES
    Follow-up to #1835 (Project #67 automation).
#>

Describe 'Project #67 reconcile covers both repositories (#1835 follow-up)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '../../..'
        $script:sync     = Get-Content (Join-Path $root 'scripts/github/sync-issues-to-project.ps1') -Raw
        $script:workflow = Get-Content (Join-Path $root '.github/workflows/sync-project.yml') -Raw
    }

    It 'The workflow reconciles the submodule repository as well as this one' {
        $workflow | Should -Match "foreach \(\`$repo in @\('roo-extensions', 'jsboige-mcp-servers'\)\)"
        $workflow | Should -Match 'sync-issues-to-project\.ps1 -Repo \$repo'
    }

    It 'A failing repository fails the step instead of being swallowed by the next iteration' {
        # `exit 1` from a called .ps1 does NOT throw under ErrorActionPreference=Stop.
        $workflow | Should -Match '\$LASTEXITCODE -ne 0'
        $workflow | Should -Match 'throw "reconcile failed for'
    }

    It 'The URL parser keeps the repository, so two same-numbered issues yield two keys' {
        # Extract the pattern the script really uses, and exercise it.
        $m = [regex]::Match($sync, '\$url -match "(?<pat>[^"]+)"')
        $m.Success | Should -BeTrue -Because 'the URL match in Phase 1 must be findable'
        $pattern = $m.Groups['pat'].Value

        $a = 'https://github.com/jsboige/roo-extensions/issues/1120'
        $b = 'https://github.com/jsboige/jsboige-mcp-servers/issues/1120'

        $keyOf = {
            param($u)
            $mm = [regex]::Match($u, $pattern)
            if (-not $mm.Success) { return $null }
            # Every capture group, in order -- the same material the script builds its key from.
            (1..($mm.Groups.Count - 1) | ForEach-Object { $mm.Groups[$_].Value }) -join '#'
        }

        $ka = & $keyOf $a
        $kb = & $keyOf $b
        $ka | Should -Not -BeNullOrEmpty
        $kb | Should -Not -BeNullOrEmpty
        $ka | Should -Not -Be $kb -Because 'the pre-fix pattern yielded "1120" for both'

        # Negative control: the pre-fix pattern really does collapse them, so this test is
        # capable of failing. Without it, a pattern that matched nothing would also "pass".
        $preFix = '/issues/(\d+)$'
        $pa = [regex]::Match($a, $preFix).Groups[1].Value
        $pb = [regex]::Match($b, $preFix).Groups[1].Value
        $pa | Should -Be $pb -Because 'this is the collision the fix removes'
    }

    It 'The gap lookup is keyed by repository too, not by number alone' {
        $sync | Should -Match '\$issuesInProject\.ContainsKey\("\$Repo#'
        $sync.Contains('$issuesInProject.ContainsKey([int]$_.number)') | Should -BeFalse
        # positive control: the predicate bites on the pre-fix shape
        '-not $issuesInProject.ContainsKey([int]$_.number)'.Contains('$issuesInProject.ContainsKey([int]$_.number)') | Should -BeTrue
    }
}
