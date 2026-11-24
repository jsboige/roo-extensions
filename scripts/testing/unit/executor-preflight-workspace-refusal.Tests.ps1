<#
.SYNOPSIS
    executor-preflight.ps1 names what a failed freshness run was (roo-extensions #4918).

.DESCRIPTION
    ensure-build-fresh.ps1 exits 1 for two situations with two different remedies: it
    REFUSED the workspace install because live RSM hosts are there (nothing was built; the
    hosts have to go first), or a step of the build chain failed (the workspace install, the
    @vibesync/core build, the server build). Until #4918 the pre-flight reported both as
    "ensure-build-fresh.ps1 could not guarantee freshness (exit 1)": a reader told that asks
    for the wrong remedy, or none.

    A failed server build is not an [ERROR] in the helper: it is a [WARN] (the previous
    build stays usable; only -RequireFresh turns it into exit 1). It is a failed build step
    all the same, and is named like one.

    The REAL classifier (Get-FreshnessFailure) and the REAL exit block (`if ($freshExit -ne 0)`)
    are extracted from executor-preflight.ps1 and run here against helper lines written in
    the helper's own output format, which the structure checks tie to the helper's real wording.

    This file guards these in CODE: a refusal reaches the reader as [WS-INSTALL-REFUSED] with
    "No build was attempted" and the remedy that stops the hosts; a failed step reaches the
    reader as [BUILD-FAILED] with "No server vintage was published"; an exit code the helper
    did not explain keeps the generic sentence, with its exit number; the helper's first
    explaining line travels with both named verdicts.

.NOTES
    Requires Pester 5+. The fixtures carry "-" where the helper prints an em dash: no
    assertion depends on that character, and the file stays ASCII.
#>

Describe 'executor-preflight names the freshness failure (#4918)' {

    BeforeAll {
        # Forward slashes on purpose: these paths reach raw .NET APIs, which do not treat
        # "\" as a separator on the ubuntu runner. Windows accepts "/" as well.
        $preflightPath = Join-Path $PSScriptRoot '../../../scripts/claude/executor-preflight.ps1'
        $helperPath    = Join-Path $PSScriptRoot '../../../scripts/claude/ensure-build-fresh.ps1'
        $preflight     = [System.IO.File]::ReadAllText($preflightPath)
        $helper        = [System.IO.File]::ReadAllText($helperPath)

        # Same extraction as ensure-build-fresh.workspace-install.Tests.ps1: the block that
        # opens on the first line matching the pattern, to the brace that closes it.
        function Get-BlockText([string]$Text, [string]$FirstLinePattern) {
            $lines  = $Text -split "`r?`n"
            $start  = -1
            for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match $FirstLinePattern) { $start = $i; break } }
            if ($start -lt 0) { throw "no line matches '$FirstLinePattern'" }
            $depth = 0
            for ($i = $start; $i -lt $lines.Count; $i++) {
                $depth += ([regex]::Matches($lines[$i], '\{')).Count
                $depth -= ([regex]::Matches($lines[$i], '\}')).Count
                if ($i -gt $start -and $depth -le 0) { return ($lines[$start..$i] -join "`n") }
            }
            throw "closing brace not found after '$FirstLinePattern'"
        }
        $script:helperLineText = Get-BlockText $preflight '^function Get-FreshnessHelperLine \{'
        $script:classifyText   = Get-BlockText $preflight '^function Get-FreshnessFailure \{'
        $script:freshExitText  = Get-BlockText $preflight '^\s*if \(\$freshExit -ne 0\) \{'

        # Helper lines as the pre-flight reads them. Write-Result prints one status tag and
        # one message; cmd /c splits the message's own newlines into separate elements, so
        # the tail of a failing command arrives as lines WITHOUT a helper prefix.
        $script:notRun   = 'The server build did not run: this run published no vintage and rewrote no build/.'
        $script:refusal  = '[ensure-build-fresh][ERROR] Workspace install is missing or stale, so ''npm ci'' is required in D:\dev\roo-extensions\mcps\internal -- REFUSED while 3 RSM host process(es) are alive (npm would remove and reinstall the dependency trees those processes use; on Windows a locked native .node aborts it after a partial removal). The hot path of #4918 does not open on this tree either: npm would REPLACE servers/roo-state-manager/node_modules/typescript: the installed entry and the lockfile entry differ. Remedy: stop the RSM hosts (full-quit VS Code on an interactive seat), then run scripts/claude/executor-preflight.ps1 again, or run ''npm ci'' in mcps/internal yourself with VS Code closed. No install was attempted and no host was touched. ' + $script:notRun
        $script:ciFailed = @(
            '[ensure-build-fresh][ERROR] ''npm ci'' failed (exit 1) in D:\dev\roo-extensions\mcps\internal - NOT continuing to a build that would compile against a half-installed tree. Tail:'
            'npm error code ELIFECYCLE'
            'npm error errno 1'
        )
        $script:installFailed = @(
            '[ensure-build-fresh][ERROR] ''npm install'' failed (exit 1) in D:\dev\roo-extensions\mcps\internal - NOT continuing to a build that would compile against a half-installed tree. Tail:'
            'npm error code EACCES'
        )
        $script:coreFailed = @(
            '[ensure-build-fresh][ERROR] Core build FAILED (exit 2) - refusing to publish a server build against the previous @vibesync/core/dist (the seat would read STALE again on the next run and republish forever). Same exit path as a failed server build. Tail:'
            'tsc error TS2307: Cannot find module'
        )
        $script:serverBuildWarn = @(
            '[ensure-build-fresh][WARN] Build FAILED (exit 2) - proceeding on existing build. Tail:'
            'tsc error TS1005: expected'
        )

        # The real helper-line picker and the real classifier, as the pre-flight runs them:
        # dot-sourced in a scope of their own, so the exit block below resolves them and
        # only the arguments decide the outcome.
        function Invoke-FreshnessExit([string[]]$Lines, [int]$ExitCode = 1) {
            . ([scriptblock]::Create($script:helperLineText))
            . ([scriptblock]::Create($script:classifyText))
            $freshExit    = $ExitCode
            $helperOutput = $Lines
            try {
                & ([scriptblock]::Create($script:freshExitText))
                return 'NO THROW'
            } catch {
                return $_.Exception.Message
            }
        }
    }

    Context 'Get-FreshnessFailure: what the helper said, from its own lines' {

        It 'Classifies "<Name>" as <Expected>' -TestCases @(
            @{ Name = 'the refusal under live hosts';                Expected = 'install-refused'
                Lines = { @($script:refusal) } }
            @{ Name = 'a refusal with npm noise echoed before it';   Expected = 'install-refused'
                Lines = { @('> mcps/internal@1.0.0 prepare', 'npm WARN deprecated', $script:refusal) } }
            @{ Name = 'a failed npm ci with no host alive';          Expected = 'step-failed'
                Lines = { $script:ciFailed } }
            @{ Name = 'a failed hot npm install';                   Expected = 'step-failed'
                Lines = { $script:installFailed } }
            @{ Name = 'a failed @vibesync/core build';              Expected = 'step-failed'
                Lines = { $script:coreFailed } }
            @{ Name = 'a failed server build, which the helper reports as a WARN'; Expected = 'step-failed'
                Lines = { $script:serverBuildWarn } }
            @{ Name = 'an unrelated WARN only';                     Expected = 'unexplained'
                Lines = { @('[ensure-build-fresh][WARN] [guard] deploy-preop-guard.ps1 introuvable, pre-op desactive.') } }
            @{ Name = 'the refusal wording on a helper WARN line beside an unrelated ERROR line'; Expected = 'step-failed'
                Lines = { @('[ensure-build-fresh][WARN] something quoting: REFUSED while 3 RSM host process(es) are alive', $script:coreFailed[0]) } }
            @{ Name = 'only informational lines';                   Expected = 'unexplained'
                Lines = { @('[ensure-build-fresh][FRESH] ensure-build-fresh: build is fresh.', '[ensure-build-fresh][OK] Workspace install is current with the lockfile (content check, not mtime) - no ''npm ci'' needed.') } }
            @{ Name = 'the refusal wording on a line that is not a helper line'; Expected = 'unexplained'
                Lines = { @('[executor-preflight] helper said: REFUSED while 3 RSM host process(es) are alive', 'npm ERR! code 1') } }
            @{ Name = 'no line at all';                             Expected = 'unexplained'
                Lines = { @() } }
        ) {
            param($Name, $Expected, $Lines)
            . ([scriptblock]::Create($script:helperLineText))
            . ([scriptblock]::Create($script:classifyText))
            $verdict = Get-FreshnessFailure -HelperOutput @(& $Lines)
            $verdict | Should -Be $Expected -Because $Name
            $verdict | Should -BeOfType [string] -Because $Name
        }
    }

    Context 'The exit block: the verdict, its remedy and the helper''s own words reach the reader' {

        It 'A refusal is not reported as a build failure: nothing was built, and the remedy stops the hosts' {
            $message = Invoke-FreshnessExit -Lines @($script:refusal)
            $message | Should -Match '^\[WS-INSTALL-REFUSED\] No build was attempted: ensure-build-fresh\.ps1 REFUSED the workspace install in mcps/internal'
            $message | Should -Match 'because live RSM hosts are running'
            $message | Should -Match 'Remedy: full-quit VS Code on an interactive seat to stop the RSM hosts, run scripts/claude/executor-preflight\.ps1 again'
            $message | Should -Match 'the hot path of #4918 does not open on this tree either: npm would REPLACE servers/roo-state-manager/node_modules/typescript'
            $message | Should -Not -Match 'could not guarantee freshness'
        }

        It 'A failed npm ci is reported as a build failure, with the helper line and not the raw tail' {
            $message = Invoke-FreshnessExit -Lines $script:ciFailed
            $message | Should -Match '^\[BUILD-FAILED\] A step of the build chain failed \(exit 1\)'
            $message | Should -Match 'No server vintage was published\. Remedy: '
            $message | Should -Match 'Helper said: \[ensure-build-fresh\]\[ERROR\] ''npm ci'' failed \(exit 1\)'
            $message | Should -Not -Match 'WS-INSTALL-REFUSED'
            $message | Should -Not -Match 'npm error errno 1'
        }

        It 'A failed hot install is a build failure too: it is not the refusal the hot path replaced' {
            $message = Invoke-FreshnessExit -Lines $script:installFailed
            $message | Should -Match '^\[BUILD-FAILED\]'
            $message | Should -Match 'Helper said: \[ensure-build-fresh\]\[ERROR\] ''npm install'' failed'
        }

        It 'A failed server build reaches the reader with the WARN line the helper wrote' {
            $message = Invoke-FreshnessExit -Lines $script:serverBuildWarn
            $message | Should -Match '^\[BUILD-FAILED\] A step of the build chain failed \(exit 1\)'
            $message | Should -Match 'Helper said: \[ensure-build-fresh\]\[WARN\] Build FAILED \(exit 2\)'
        }

        It 'An exit the helper did not explain keeps the generic sentence, with its exit number' {
            $message = Invoke-FreshnessExit -Lines @('[ensure-build-fresh][OK] Workspace install is current with the lockfile (content check, not mtime) - no ''npm ci'' needed.') -ExitCode 2
            $message | Should -BeExactly 'ensure-build-fresh.ps1 could not guarantee freshness (exit 2).'
        }

        It 'The exit number travels on a named verdict as well' {
            $message = Invoke-FreshnessExit -Lines $script:coreFailed -ExitCode 7
            $message | Should -Match '^\[BUILD-FAILED\] A step of the build chain failed \(exit 7\)'
            $message | Should -Match 'Helper said: \[ensure-build-fresh\]\[ERROR\] Core build FAILED \(exit 2\)'
        }

        It 'Only the helper''s first explaining line travels, whatever follows it' {
            $lines = @(
                '[ensure-build-fresh][ERROR] ''npm install'' failed (exit 1) in D:\dev\roo-extensions\mcps\internal. Tail:'
                '[ensure-build-fresh][ERROR] a second error line, which must not be repeated'
            )
            $message = Invoke-FreshnessExit -Lines $lines
            $message | Should -Match 'Helper said: \[ensure-build-fresh\]\[ERROR\] ''npm install'' failed'
            $message | Should -Not -Match 'a second error line'
        }
    }

    Context 'Structure: the verdicts are wired to the helper''s real wording' {

        It 'The pre-flight and the helper parse under this engine, and carry no PS7-only syntax' {
            foreach ($text in @($preflight, $helper)) {
                $tokens = $null; $errors = $null
                [void][System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
                @($errors).Count | Should -Be 0
                @($tokens | Where-Object { $_.Kind -in @('QuestionQuestion', 'QuestionColon') }).Count | Should -Be 0
            }
        }

        It 'Picks the line, then classifies, then throws, and the generic sentence stays the last resort' {
            $pickIdx     = $preflight.IndexOf('$helperError = @(Get-FreshnessHelperLine -HelperOutput $helperOutput)')
            $classifyIdx = $preflight.IndexOf('$failure = Get-FreshnessFailure -HelperOutput $helperOutput')
            $refusedIdx  = $preflight.IndexOf('throw "[WS-INSTALL-REFUSED]')
            $failedIdx   = $preflight.IndexOf('throw "[BUILD-FAILED]')
            $genericIdx  = $preflight.IndexOf('throw "ensure-build-fresh.ps1 could not guarantee freshness')
            $pickIdx     | Should -BeGreaterThan 0
            $classifyIdx | Should -BeGreaterThan $pickIdx
            $refusedIdx  | Should -BeGreaterThan $classifyIdx
            $failedIdx   | Should -BeGreaterThan $refusedIdx
            $genericIdx  | Should -BeGreaterThan $failedIdx
        }

        It 'Both named verdicts throw only inside the non-zero exit block, each once' {
            ([regex]::Matches($preflight, [regex]::Escape('throw "[WS-INSTALL-REFUSED]'))) | Should -HaveCount 1
            ([regex]::Matches($preflight, [regex]::Escape('throw "[BUILD-FAILED]'))) | Should -HaveCount 1
            ([regex]::Matches($preflight, [regex]::Escape('throw "ensure-build-fresh.ps1 could not guarantee freshness'))) | Should -HaveCount 1
            ([regex]::Matches($script:freshExitText, [regex]::Escape('throw "'))) | Should -HaveCount 3
        }

        It 'The refusal verdict says that nothing was built and names the live hosts; the build verdict carries the exit and the publication' {
            $refusedThrow = [regex]::Match($preflight, '(?s)throw "\[WS-INSTALL-REFUSED\][^"]*"').Value
            $refusedThrow | Should -Match 'No build was attempted'
            $refusedThrow | Should -Match 'live RSM hosts'
            $refusedThrow | Should -Match 'Remedy: full-quit VS Code'
            $failedThrow = [regex]::Match($preflight, '(?s)throw "\[BUILD-FAILED\][^"]*"').Value
            $failedThrow | Should -Match 'exit \$freshExit'
            $failedThrow | Should -Match 'No server vintage was published'
            $failedThrow | Should -Match 'Helper said: \$\(\$helperError -join'
        }

        It 'Reads only lines the helper prefixed, and both patterns match the helper''s real wording' {
            # Two sites read helper lines with this prefix: the picker and the refusal test.
            ([regex]::Matches($preflight, [regex]::Escape('''^\[ensure-build-fresh\]\[ERROR\] '''))) | Should -HaveCount 2
            ([regex]::Matches($preflight, [regex]::Escape('''^\[ensure-build-fresh\]\[WARN\] '''))) | Should -HaveCount 1
            $preflight.Contains("'REFUSED while \d+ RSM host process'") | Should -BeTrue
            $preflight.Contains("'Build FAILED \(exit \d+\)|Build invocation threw'") | Should -BeTrue

            $tokens = $null; $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseInput($helper, [ref]$tokens, [ref]$errors)
            @($errors).Count | Should -Be 0
            $refusalTokens = @($tokens | Where-Object { $_.Kind -like 'String*' -and $_.Text -cmatch 'REFUSED while ' })
            $refusalTokens | Should -HaveCount 1
            # The helper prints "[ensure-build-fresh][ERROR] " then its message, with the host
            # count where its variable stands.
            $asPrinted = '[ensure-build-fresh][ERROR] ' + ($refusalTokens[0].Value -replace '\$wsAlive\b', '3')
            $asPrinted | Should -Match '^\[ensure-build-fresh\]\[ERROR\] Workspace install is missing or stale, so ''npm ci'' is required in .* -- REFUSED while \d+ RSM host process\(es\) are alive'
            $asPrinted -split "`n" | Should -HaveCount 1

            $warnTokens = @($tokens | Where-Object { $_.Kind -like 'String*' -and $_.Text -cmatch 'Build FAILED \(exit ' })
            $warnTokens | Should -HaveCount 1
            $warnAsPrinted = '[ensure-build-fresh][WARN] ' + ($warnTokens[0].Value -replace '\$buildExit\b', '2')
            $warnAsPrinted | Should -Match '^\[ensure-build-fresh\]\[WARN\] Build FAILED \(exit \d+\)'
            @($tokens | Where-Object { $_.Kind -like 'String*' -and $_.Text -cmatch 'Build invocation threw' }) | Should -HaveCount 1
        }
    }
}