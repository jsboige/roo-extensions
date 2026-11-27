<#
.SYNOPSIS
    Guard + behavioural test: the workspace install and the shared-package build are ENSURED, not advised (#4886 / PR #4893 review).

.DESCRIPTION
    ms#1882 turns mcps/internal into an npm workspace: a seat that has not installed it since the
    bump has no local `tsc`, and the RSM build compiles against @vibesync/core/dist, which it never
    rebuilds itself. ensure-build-fresh.ps1 ensures both before the server rebuild.

    The coordinator review (ai-01, 2026-11-23 20:10Z) found the first version fail-open and
    destructive under load:
      1. a failed `npm ci` or a failed core build was a WARN, so under -RequireFresh the run could
         exit 0 while the seat republished a server build linked to a stale core forever;
      2. `npm ci` deletes the hoisted node_modules the live RSM hosts run from; on Windows a locked
         native .node aborts it AFTER a partial removal.
    The repair pass (2026-11-24) closed three more points of the same review, each found by
    running the first repair on an isolated tree:
      3. the install question is a CONTENT comparison (lockfile vs npm's on-disk stamp), never an
         mtime one -- a checkout that rewrites an identical lockfile must not re-run `npm ci`;
      4. a refused `npm ci` exits 1 whatever -RequireFresh: a 0 reads as "install not needed";
      5. the workspace decision is taken BEFORE the ARM guard and the dry-run exits: a refused
         run owes no restart (the categorical ARM line printed first, then the refusal), and
         -DryRun / -WhatIf name the steps a real run would take.

    The hot path (roo-extensions #4918, 2026-11-24): the first deployment of the workspace ADDS a
    whole root tree, and `npm ci` -- refused under live hosts -- is not the only way to install
    it. `npm install` reconciles: it adds, removes and replaces. Where a read of every installed
    tree shows that it would only add to the root tree -- the one no live RSM host resolves into
    -- the helper takes that path instead of the refusal. The guard that decides it is exercised
    here on throwaway trees, together with the rule that keeps the refusal closed: a lockfile
    that removes or changes an installed package, or adds anywhere but the root tree.

    This file guards these in CODE (token level: a comment quoting the wording must not make a raw
    -Match green), and exercises the REAL functions extracted from the script against throwaway
    files -- no Get-CimInstance, no Windows path, so it runs under the Linux pwsh of the
    `unit-pester` CI job. It does NOT run the script itself: that needs Win32_Process, and would
    touch the live install. The exit codes of Exit-WorkspaceStepFailed are measured in a CHILD
    engine (the one running this suite), because the helper calls `exit`.

.NOTES
    Requires Pester 5+.
#>

Describe 'ensure-build-fresh workspace install + core build (#4886, PR #4893 review)' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $content = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

        # Code tokens only: comments are Kind Comment, strings are String*.
        $codeStrings = @($tokens | Where-Object { $_.Kind -like 'String*' } | ForEach-Object { $_.Text })

        # Extract the REAL function bodies, so this test cannot drift from what ships.
        # The install check delegates its JSON reading to ConvertFrom-JsonToDictionary: both
        # must be dot-sourced, in definition order, or the extracted function cannot resolve it.
        function Get-ScriptFunctionText([string]$Name) {
            $lines = $content -split "`r?`n"
            $start = -1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match "^function $Name\s*\{") { $start = $i; break }
            }
            if ($start -lt 0) { throw "$Name not found in ensure-build-fresh.ps1" }
            $depth = 0
            $end = -1
            for ($i = $start; $i -lt $lines.Count; $i++) {
                $depth += ([regex]::Matches($lines[$i], '\{')).Count
                $depth -= ([regex]::Matches($lines[$i], '\}')).Count
                if ($i -gt $start -and $depth -le 0) { $end = $i; break }
            }
            if ($end -lt 0) { throw "closing brace of $Name not found" }
            return ($lines[$start..$end] -join "`n")
        }
        . ([scriptblock]::Create((Get-ScriptFunctionText 'ConvertFrom-JsonToDictionary')))
        . ([scriptblock]::Create((Get-ScriptFunctionText 'Test-WorkspaceInstallCurrent')))
        # Read-only like the two above, so dot-sourced the same way (#4918).
        . ([scriptblock]::Create((Get-ScriptFunctionText 'Test-WorkspaceInstallReconcileSafe')))
        # Both guards ask the lockfile what npm leaves out on this platform (#4918, npm 11.11).
        . ([scriptblock]::Create((Get-ScriptFunctionText 'Get-LockfileInertKeys')))
        # The platform comes from node through Get-NpmPlatform. A stub stands in for it, so the
        # verdicts do not depend on the engine running this suite (Linux pwsh in CI); the real
        # function is exercised on its own, in a child scope, by the context that tests it.
        $script:npmPlatform = @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
        function Get-NpmPlatform { return $script:npmPlatform }
        # The exit helper calls `exit`, which would end this very run: its body is handed to a
        # child engine by the context below, never dot-sourced here.
        $script:exitHelperText = Get-ScriptFunctionText 'Exit-WorkspaceStepFailed'
    }

    Context 'Structural guards (token level)' {

        It 'Parses the script without syntax errors' {
            $errors.Count | Should -Be 0
        }

        It 'Carries no PS7-only syntax: the fleet runs it under Windows PowerShell 5.1 (#2368)' {
            # Ternary and null-coalescing operators do not exist in 5.1: they kill the script at parse.
            $tokens | Where-Object { $_.Kind -eq 'QuestionQuestion' -or $_.Kind -eq 'QuestionColon' } | Should -HaveCount 0
        }

        It 'A failed npm ci or a failed core build is never a bare WARN: both exit through the fail-closed helper' {
            $installFail = @($codeStrings | Where-Object { $_ -match "'npm ci' failed" })
            $coreFail    = @($codeStrings | Where-Object { $_ -match 'Core build FAILED' })
            $installFail | Should -HaveCount 1
            $coreFail    | Should -HaveCount 1
            # Neither message is passed to Write-Result 'WARN'
            $content | Should -Not -Match "Write-Result 'WARN' [^\r\n]*'npm ci' failed"
            $content | Should -Not -Match "Write-Result 'WARN'[^\r\n]*Core build FAILED"
            # Both are passed to the helper, which fails under -RequireFresh
            $content | Should -Match "Exit-WorkspaceStepFailed `"'npm ci' failed"
            $content | Should -Match "Exit-WorkspaceStepFailed `"Core build FAILED"
        }

        It 'The fail-closed helper exits 1 under -RequireFresh' {
            $content | Should -Match 'function Exit-WorkspaceStepFailed'
            $helperBody = [regex]::Match($content, '(?s)function Exit-WorkspaceStepFailed \{.*?\r?\n\}').Value
            $helperBody | Should -Not -BeNullOrEmpty
            $helperBody | Should -Match 'if \(\$Refused -or \$RequireFresh\) \{ exit 1 \}'
        }

        It 'Refuses npm ci while RSM hosts are alive, exits non-zero, and says the remedy' {
            $refusals = @($codeStrings | Where-Object { $_ -cmatch "REFUSED while" })
            $refusals | Should -HaveCount 1
            $refusals[0] | Should -Match 'full-quit VS Code'
            $refusals[0] | Should -Match 'No install was attempted'
            $content | Should -Match "Exit-WorkspaceStepFailed -Refused `"Workspace install is missing or stale"
            $content | Should -Match 'if \(\$Refused -or \$RequireFresh\) \{ exit 1 \}'
            # the refusal exits through the helper BEFORE any `npm ci` runs
            $refuseIdx = $content.IndexOf('REFUSED while')
            $ciIdx     = $content.IndexOf('cmd /c "npm ci 2>&1"')
            $refuseIdx | Should -BeGreaterThan 0
            $ciIdx     | Should -BeGreaterThan $refuseIdx
        }

        It 'Refusal covers legacy and versioned children and wrappers, without a combined role probe' {
            # The measured live shape on po-2024: 12 wrappers + 12 build-<hash>/index.js children,
            # zero legacy build/index.js. A probe restricted to legacy children misses them.
            $content | Should -Match 'roo-state-manager\[\\\\/\]\(build\[\\\\/\]index\\\.js\)'
            $content | Should -Match '\$vintageHosts\s*=\s*@\(Get-CimInstance Win32_Process'
            $content | Should -Match 'roo-state-manager\[\\\\/\]build-\[0-9a-f\]\{16\}\[\\\\/\]index\\\.js'
            $content | Should -Match '\$wsAlive\s*=\s*@\(\$indexHosts \+ \$vintageHosts \+ \$wrapperHosts\)\.Count'
            # ...but $liveHosts must NOT be widened to the three roles: it feeds the ARM
            # session count and two informational lines that describe LEGACY hosts only.
            $content | Should -Match '\$liveHosts = @\(\$indexHosts \+ \$wrapperHosts\)'
            $content.Contains('$liveHosts = @($indexHosts + $vintageHosts + $wrapperHosts)') | Should -BeFalse
            # Positive control: the predicate bites on the widened shape.
            '$liveHosts = @($indexHosts + $vintageHosts + $wrapperHosts)'.Contains('$liveHosts = @($indexHosts + $vintageHosts + $wrapperHosts)') | Should -BeTrue
            $content.Contains('index\.js|mcp-wrapper\.cjs') | Should -BeFalse
        }

        It 'Both dry exits carry the workspace plan, computed BEFORE them' {
            # Review finding: '-DryRun never announces the npm ci step'. The first fix put the
            # announcement INSIDE the workspace block -- unreachable, because -DryRun exits at
            # the gate and -WhatIf is declined by ShouldProcess, both ABOVE that block. So the
            # plan is computed before the dry exits and appended to their own messages.
            # Measured on the raw CALL LINES: the parser splits an interpolated string at its
            # ${...} holes, so no single token text holds the whole message (a token-level
            # StartWith('-DryRun') filter matched ZERO tokens on the real file).
            $dryLines = @($content -split "`r?`n" | Where-Object { $_ -match "Exit-NotFresh 'SKIP' " })
            $dry1 = @($dryLines | Where-Object { $_ -like '*"-DryRun set: would run*' })
            $dry2 = @($dryLines | Where-Object { $_ -like '*"ShouldProcess declined*' })
            $dry1 | Should -HaveCount 1
            $dry2 | Should -HaveCount 1
            $dry1[0] | Should -Match '\$wsPlan"'
            $dry2[0] | Should -Match '\$wsPlan"'
            $planIdx = $content.IndexOf('$wsWillRefuse = $wsApplies -and $wsNeedsInstall -and $wsAlive -gt 0')
            $dryIdx  = $content.IndexOf('Exit-NotFresh ''SKIP'' "-DryRun set:')
            $whatIdx = $content.IndexOf('Exit-NotFresh ''SKIP'' "ShouldProcess declined')
            $planIdx | Should -BeGreaterThan 0
            $dryIdx  | Should -BeGreaterThan $planIdx
            $whatIdx | Should -BeGreaterThan $planIdx
            # The plan is decided by a CONTENT check, not by an mtime comparison.
            $planSection = $content.Substring($content.IndexOf('# --- Workspace plan (#4886)'), $dryIdx - $content.IndexOf('# --- Workspace plan (#4886)'))
            $planSection | Should -Match 'Test-WorkspaceInstallCurrent'
            $planSection | Should -Not -Match 'LastWriteTime'
            # Positive control: the pre-fix dry messages carried no plan at all.
            ('-DryRun set: would run ''npm run build'' in $McpServerPath.' -match '\$wsPlan"') | Should -BeFalse
        }

        It 'Builds nothing before the dry exits and nothing after a refusal' {
            $dry1Idx  = $content.IndexOf('Exit-NotFresh ''SKIP'' "-DryRun set:')
            $dry2Idx  = $content.IndexOf('Exit-NotFresh ''SKIP'' "ShouldProcess declined')
            $ciIdx    = $content.IndexOf('cmd /c "npm ci 2>&1"')
            $coreIdx  = $content.IndexOf('cmd /c "npm run build --workspace @vibesync/core 2>&1"')
            $buildIdx = $content.IndexOf('cmd /c "npm run build 2>&1"')
            $ciIdx    | Should -BeGreaterThan $dry1Idx
            $ciIdx    | Should -BeGreaterThan $dry2Idx
            $coreIdx  | Should -BeGreaterThan $ciIdx
            $buildIdx | Should -BeGreaterThan $coreIdx
            # A refusal must precede the pre-op backup as well: nothing is snapshotted,
            # installed or published by a run that is going to be refused.
            $preopIdx = $content.IndexOf('# --- Pre-op guard (#3712)')
            $content.IndexOf('REFUSED while') | Should -BeLessThan $preopIdx
            $preopIdx | Should -BeGreaterThan $coreIdx
        }

        It 'Never claims the restart is OWED on a run that will be refused (#4893 review, measured)' {
            # Measured 2026-11-24 on an isolated legacy-shape tree with a stale install and live
            # hosts: the categorical 'THE RESTART IS OWED' line printed FIRST, then the refusal --
            # a run that rebuilt nothing announced a restart debt it had not incurred. The same
            # rule the dry-run branch already applies, through the other door.
            $content | Should -Match 'if \(\$wsWillRefuse\) \{'
            $refuseArm = @($codeStrings | Where-Object { $_ -like '*NOTHING was rebuilt and NOTHING is armed*' -and $_ -like '*No restart is owed*' })
            $refuseArm | Should -HaveCount 1
            $refuseArm[0] | Should -Match 'this run does not reach the server build'
            # Measured on TOKENS: a comment quoting the claim must not satisfy this.
            $owedToken = $tokens | Where-Object { $_.Kind -ne 'Comment' -and $_.Text -like '*THE RESTART IS OWED*' } | Select-Object -First 1
            $owedToken | Should -Not -BeNullOrEmpty
            $content.IndexOf('if ($wsWillRefuse) {') | Should -BeLessThan $owedToken.Extent.StartOffset
            $content.IndexOf('elseif ($noRebuildThisRun) {') | Should -BeLessThan $owedToken.Extent.StartOffset
            $content.IndexOf('elseif ($noRebuildThisRun) {') | Should -BeGreaterThan $content.IndexOf('if ($wsWillRefuse) {')
            # The helper's own line also says the server build never ran, so a reader of the
            # LAST line cannot inherit the claim of an earlier one.
            (@($codeStrings | Where-Object { $_ -like '*The server build did not run*' })) | Should -HaveCount 1
        }

        It 'Reads the lockfile through the portable helper, with exactly one engine-specific pipe' {
            # The class guard pwsh-engine-portability.Tests.ps1 requires this exact helper name
            # on any .ps1 that pipes into ConvertFrom-Json -AsHashtable: under PS 5.1 the pipe is
            # a runtime error (the switch does not exist), and the executor-preflight invokes
            # this helper through powershell.exe. Measured: the class guard named this file.
            $content | Should -Match 'function ConvertFrom-JsonToDictionary \{'
            ([regex]::Matches($content, '\|\s*ConvertFrom-Json\s+-AsHashtable')) | Should -HaveCount 1
            $content | Should -Match '\$PSVersionTable\.PSVersion\.Major -ge 7'
            $content | Should -Match 'Add-Type -AssemblyName System\.Web\.Extensions'
            # Anchor on the real instantiation, not on the type name: the class comment above
            # also says "JavaScriptSerializer lives in System.Web.Extensions" (counted 2 raw
            # occurrences where the code has 1 -- a comment must not satisfy a code assertion).
            ([regex]::Matches($content, 'New-Object System\.Web\.Script\.Serialization\.JavaScriptSerializer')) | Should -HaveCount 1
            ([regex]::Matches($content, '\$serializer\.DeserializeObject\(')) | Should -HaveCount 1
            # The full body the helper is meant to share with spawn-claude.ps1, measured.
            $helperBody = [regex]::Match($content, '(?s)function ConvertFrom-JsonToDictionary \{.*?\r?\n\}').Value
            $helperBody | Should -Match 'if \(\$PSVersionTable\.PSVersion\.Major -ge 7\) \{\s*\r?\n\s*return \$Json \| ConvertFrom-Json -AsHashtable\s*\r?\n\s*\}'
            $helperBody | Should -Match '\$serializer\.MaxJsonLength = \[int\]::MaxValue'
            # The comparison table is ORDINAL: two package paths differing only by case are two
            # packages (npm's own tree, and both JSON readers, agree). A default hashtable would
            # merge them and a missing one would read as 'current'.
            # Escaped with [regex]::Escape: a hand-written pattern with unescaped [brackets]
            # matches a character class instead of the constructor (measured: 0 hits on the file).
            $content.Contains('[System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)') | Should -BeTrue
            $content | Should -Match ([regex]::Escape('$versions = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)'))
            # Discriminator, measured 2026-11-24: the plain cmdlet REJECTS npm's root key under
            # PS 5.1 ("la valeur de l'argument name n'est pas valide") -- the reason this helper
            # exists. PS 7 accepts the document, which is why only 5.1 needs the serializer.
            if ($PSVersionTable.PSVersion.Major -lt 7) {
                { '{"packages":{"":{"version":"1.0.0"}}}' | ConvertFrom-Json } | Should -Throw
            }
        }
    }

    Context 'Behaviour: Test-WorkspaceInstallCurrent (content question, not an mtime one)' {

        BeforeAll {
            $fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ebf-ws-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
            $script:lock = Join-Path $fixtureRoot 'package-lock.json'
            $script:modules = Join-Path $fixtureRoot 'node_modules'
            $script:server = Join-Path $fixtureRoot 'server'
            New-Item -ItemType Directory -Path (Join-Path $modules '.package-lock') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $modules 'typescript/bin') -Force | Out-Null
            New-Item -ItemType File -Path (Join-Path $modules 'typescript/bin/tsc') -Force | Out-Null
            # Baseline, so each test states only its own delta: lock and stamp agree on a+b.
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
        }

        BeforeEach {
            # Deterministic order: a missing-toolchain test must not depend on the tsc file
            # having been deleted by an earlier one.
            New-Item -ItemType File -Path (Join-Path $modules 'typescript/bin/tsc') -Force | Out-Null
        }

        AfterAll {
            if ($fixtureRoot -and (Test-Path $fixtureRoot)) { Remove-Item -Recurse -Force $fixtureRoot }
        }

        It 'Returns false when node_modules is missing' {
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath (Join-Path $fixtureRoot 'absent') -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the stamp is missing' {
            $noStamp = Join-Path $fixtureRoot 'nostamp'
            New-Item -ItemType Directory -Path $noStamp -Force | Out-Null
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $noStamp -ServerPath $server | Should -BeFalse
        }

        It 'Returns true for the measured npm shape: identical package keys/versions, source root entry omitted' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeTrue
        }

        It 'Returns false when an installed version no longer matches the lockfile' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.1"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the lockfile dropped a package the tree still holds' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the lockfile GREW after the install, regardless of mtime' {
            # lock has root + a + b, stamp has a only -> the added key proves staleness.
            # Deliberately give the LOCK an older mtime: no timestamp fallback may mask it.
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            # .NET, not Get-Item: on unix a name that starts with a dot is a hidden file, and
            # Get-Item without -Force throws "Could not find item" on it (PR #4893 CI on
            # cc346b65, both engines agree with a Set-Content on the same file).
            [System.IO.File]::SetLastWriteTimeUtc($lock, [DateTime]::UtcNow)
            [System.IO.File]::SetLastWriteTimeUtc((Join-Path $modules '.package-lock.json'), [DateTime]::UtcNow.AddMinutes(5))
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns true when the lockfile is newer by mtime only: a checkout that rewrites an identical lock must not re-run npm ci' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            # Same .NET call as above: Get-Item throws on a dot-prefixed file on unix without -Force.
            [System.IO.File]::SetLastWriteTimeUtc($lock, [DateTime]::UtcNow.AddMinutes(5))
            [System.IO.File]::SetLastWriteTimeUtc((Join-Path $modules '.package-lock.json'), [DateTime]::UtcNow)
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeTrue
        }

        It 'Returns false when the toolchain is gone although the stamps agree' {
            Remove-Item -LiteralPath (Join-Path $modules 'typescript/bin/tsc') -Force
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the lockfile is absent or is not JSON' {
            Test-WorkspaceInstallCurrent -LockPath (Join-Path $fixtureRoot 'no-such-lock.json') -ModulesPath $modules -ServerPath $server | Should -BeFalse
            'not json' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the stamp is not JSON or holds no packages object' {
            'not json' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
            '{"name":"stamp","other":{}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when an installed entry carries no version' {
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"resolved":"kept-only"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns false when the tree lacks a package whose path differs from another only by case' {
            # Discriminating case for the ORDINAL comparison table: a case-insensitive one merges
            # `node_modules/A` and `node_modules/a` on both sides, the versions agree, and the
            # verdict would be "current" with a package missing -- the fail-open direction.
            '{"packages":{"":{"name":"root"},"node_modules/A":{"version":"1.0.0"},"node_modules/a":{"version":"1.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/A":{"version":"1.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
            # Control: both packages present, both versions equal -> current.
            '{"packages":{"node_modules/A":{"version":"1.0.0"},"node_modules/a":{"version":"1.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeTrue
        }

        It 'Returns true for the npm 11.11 shape: the stamp leaves out only a package npm skips on this platform (#4918)' {
            # Measured on ai-01 (npm 11.11.0, 2026-11-27): the stamp holds no entry, ideallyInert or
            # not, for an optional package of another platform. Here a Linux-only binary on win32.
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"},"node_modules/@esbuild/linux-x64":{"version":"0.1.0","optional":true,"os":["linux"],"cpu":["x64"]}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            $script:npmPlatform = @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeTrue
            # The same absence on the platform the binary is for is a package npm would install.
            $script:npmPlatform = @{ Os = 'linux'; Cpu = 'x64'; Libc = 'glibc' }
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
            $script:npmPlatform = @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
        }

        It 'Returns false when the stamp lacks an optional package npm installs here, or when the platform cannot be read' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"},"node_modules/opt":{"version":"1.0.0","optional":true}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
            # Unknown platform: nothing is known to be left out, so any gap reads as stale.
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"},"node_modules/@esbuild/linux-x64":{"version":"0.1.0","optional":true,"os":["linux"],"cpu":["x64"]}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            $script:npmPlatform = $null
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
            $script:npmPlatform = @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
        }
    }

    Context 'Behaviour: Get-LockfileInertKeys (what npm leaves out on this platform, read from the lockfile -- #4918)' {

        BeforeAll {
            # One lockfile, each rule npm applies (arborist optionalSet + gatherDepSet, npm-install-checks
            # checkList): a cpu-excluded binding and the chain only it needs, a dependency it shares with
            # an installed package, an os pair, a libc-only package, a negated os, a REQUIRED package
            # with a foreign cpu, and a skipped binding nested under a workspace tree whose dependency
            # resolves there (node's lookup) while a package of the same name at the root is required.
            $json = '{"packages":{' +
                '"":{"name":"ws","devDependencies":{"host":"1","helper":"2"}},' +
                '"node_modules/host":{"version":"1.0.0","dependencies":{"shared":"1","required-foreign":"1"},"optionalDependencies":{"@scope/binding-wasm":"1","@esbuild/linux-x64":"1","@esbuild/win32-x64":"1","glibc-only":"1","not-on-windows":"1"}},' +
                '"node_modules/@scope/binding-wasm":{"version":"1.0.0","optional":true,"cpu":["wasm32"],"dependencies":{"runtime":"1","shared":"1"}},' +
                '"node_modules/runtime":{"version":"1.0.0","optional":true,"dependencies":{"leaf":"1"}},' +
                '"node_modules/leaf":{"version":"1.0.0","optional":true},' +
                '"node_modules/shared":{"version":"1.0.0"},' +
                '"node_modules/@esbuild/linux-x64":{"version":"1.0.0","optional":true,"os":["linux"],"cpu":["x64"]},' +
                '"node_modules/@esbuild/win32-x64":{"version":"1.0.0","optional":true,"os":["win32"],"cpu":["x64"]},' +
                '"node_modules/glibc-only":{"version":"1.0.0","optional":true,"libc":["glibc"]},' +
                '"node_modules/not-on-windows":{"version":"1.0.0","optional":true,"os":["!win32"]},' +
                '"node_modules/required-foreign":{"version":"1.0.0","cpu":["arm"]},' +
                '"node_modules/helper":{"version":"2.0.0"},' +
                '"node_modules/ws-server":{"resolved":"server","link":true},' +
                '"server":{"name":"server","version":"0.0.0","dependencies":{"thing":"1"}},' +
                '"server/node_modules/thing":{"version":"1.0.0","optionalDependencies":{"bin-arm64":"1"}},' +
                '"server/node_modules/bin-arm64":{"version":"1.0.0","optional":true,"cpu":["arm64"],"dependencies":{"helper":"1"}},' +
                '"server/node_modules/helper":{"version":"1.0.0","optional":true}' +
                '}}'
            $script:inertPackages = (ConvertFrom-JsonToDictionary -Json $json)['packages']
            function Get-SortedInert($Platform) {
                # The function returns the set as ONE pipeline object; enumerate it before sorting.
                $set = Get-LockfileInertKeys -Packages $script:inertPackages -Platform $Platform
                return ((@($set) | Sort-Object) -join ',')
            }
        }

        It 'On win32 x64, marks exactly what npm leaves out: foreign os, cpu and libc, a negated os, and the chain only a skipped binding needs' {
            $expected = @('node_modules/@scope/binding-wasm', 'node_modules/runtime', 'node_modules/leaf', 'node_modules/@esbuild/linux-x64',
                'node_modules/glibc-only', 'node_modules/not-on-windows', 'server/node_modules/bin-arm64', 'server/node_modules/helper')
            Get-SortedInert @{ Os = 'win32'; Cpu = 'x64'; Libc = '' } | Should -Be (($expected | Sort-Object) -join ',')
        }

        It 'Follows the platform: on linux x64 glibc the same lockfile skips the Windows binary and keeps the Linux ones' {
            $expected = @('node_modules/@scope/binding-wasm', 'node_modules/runtime', 'node_modules/leaf', 'node_modules/@esbuild/win32-x64',
                'server/node_modules/bin-arm64', 'server/node_modules/helper')
            Get-SortedInert @{ Os = 'linux'; Cpu = 'x64'; Libc = 'glibc' } | Should -Be (($expected | Sort-Object) -join ',')
        }

        It 'Keeps what an installed package needs: the shared dependency, a required package whatever its cpu, the root package of a nested name' {
            $inert = Get-LockfileInertKeys -Packages $script:inertPackages -Platform @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
            $inert.Contains('node_modules/shared') | Should -BeFalse
            $inert.Contains('node_modules/required-foreign') | Should -BeFalse
            $inert.Contains('node_modules/helper') | Should -BeFalse
            $inert.Contains('node_modules/@esbuild/win32-x64') | Should -BeFalse
        }

        It 'Returns the set itself, never its unrolled items, and an empty one when the platform is unknown' {
            $one = Get-LockfileInertKeys -Packages ((ConvertFrom-JsonToDictionary -Json '{"packages":{"node_modules/x":{"version":"1.0.0","optional":true,"os":["aix"]}}}')['packages']) -Platform @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
            ($one -is [System.Collections.Generic.HashSet[string]]) | Should -BeTrue
            $one.Count | Should -Be 1
            $none = Get-LockfileInertKeys -Packages $script:inertPackages -Platform $null
            ($none -is [System.Collections.Generic.HashSet[string]]) | Should -BeTrue
            $none.Count | Should -Be 0
        }

        It 'Get-NpmPlatform names the os and cpu as node does' -Skip:(-not (Get-Command node -ErrorAction SilentlyContinue)) {
            # The real function, in a child scope: the stub of this suite keeps its own name.
            $platform = & ([scriptblock]::Create((Get-ScriptFunctionText 'Get-NpmPlatform') + "`nGet-NpmPlatform"))
            $platform.Os | Should -Be ([string](& node -p process.platform)).Trim()
            $platform.Cpu | Should -Be ([string](& node -p process.arch)).Trim()
        }
    }

    Context 'Behaviour: ConvertFrom-JsonToDictionary (engine-portable reader, measured on PS 5.1 and pwsh 7)' {

        It 'Returns an IDictionary on this engine, carries npm''s empty root key, and keeps case-distinct keys apart' {
            # Measured 2026-11-24 with this very body on 5.1.26100.9818 and 7.6.10: 6/6 verdicts
            # identical. The engines return different types (Dictionary`2 / OrderedHashtable), so
            # every check goes through the IDictionary interface.
            $d = ConvertFrom-JsonToDictionary -Json '{"packages":{"":{"version":"1.0.0"},"node_modules/a":{"version":"1.0.0"},"node_modules/A":{"version":"2.0.0"}}}'
            $d -is [System.Collections.IDictionary] | Should -BeTrue
            $d['packages'] -is [System.Collections.IDictionary] | Should -BeTrue
            $d['packages'].ContainsKey('') | Should -BeTrue
            $d['packages'].Count | Should -Be 3
            $d['packages']['node_modules/A']['version'] | Should -Be '2.0.0'
            $d['packages']['node_modules/a']['version'] | Should -Be '1.0.0'
        }

        It 'Reads a missing key as null and throws on malformed JSON' {
            $d = ConvertFrom-JsonToDictionary -Json '{"packages":{}}'
            $null -eq $d['packages']['nope'] | Should -BeTrue
            { ConvertFrom-JsonToDictionary -Json 'not json' } | Should -Throw
        }

        It 'Reads a lockfile-sized document: the measured real one holds 1648 package entries' {
            $entries = 1..2000 | ForEach-Object { '"node_modules/p' + $_ + '":{"version":"1.0.' + $_ + '"}' }
            $d = ConvertFrom-JsonToDictionary -Json ('{"packages":{"":{"name":"root"},' + ($entries -join ',') + '}}')
            $d['packages'].Count | Should -Be 2001
        }
    }

    Context 'Behaviour: Exit-WorkspaceStepFailed (exit code per mode)' {

        BeforeAll {
            # `exit` ends the calling process, so each case runs in a CHILD engine -- the one
            # running this suite -- with the REAL function text and a stub for Write-Result.
            $fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('ebf-exit-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
            $script:runner = Join-Path $fixtureRoot 'runner.ps1'
            $prelude = @'
param([switch]$Refused, [switch]$Strict)
$RequireFresh = [bool]$Strict
function Write-Result {
    param($Level, $Message)
    Write-Output "[$Level] $Message"
}
'@
            Set-Content -LiteralPath $runner -Value ($prelude + $script:exitHelperText + "`n" + 'Exit-WorkspaceStepFailed -Message ''probe'' -Refused:$Refused') -Encoding utf8
            $script:engine = (Get-Process -Id $PID).Path
        }

        AfterAll {
            if ($fixtureRoot -and (Test-Path $fixtureRoot)) { Remove-Item -Recurse -Force $fixtureRoot }
        }

        It 'Exits 1 on a REFUSAL in both modes, and on a failed step under -RequireFresh only' {
            # Review finding 1: a failed `npm ci` or core build used to be a WARN, so a strict run
            # could exit 0. The refusal (finding 2) fails in BOTH modes: a 0 there reads as
            # "install not needed" to anyone scripting this helper. The legacy 0 of a failed step
            # in default mode is the pre-existing server-build contract of the two -Headless callers.
            $cases = @(
                @{ Name = 'refusal, default mode';       Arguments = @('-Refused');          Expected = 1 }
                @{ Name = 'refusal, -RequireFresh';     Arguments = @('-Refused', '-Strict'); Expected = 1 }
                @{ Name = 'failed step, default mode';  Arguments = @();                    Expected = 0 }
                @{ Name = 'failed step, -RequireFresh'; Arguments = @('-Strict');          Expected = 1 }
            )
            foreach ($case in $cases) {
                $arguments = $case.Arguments
                $output = & $script:engine -NoProfile -ExecutionPolicy Bypass -File $runner @arguments 2>&1
                $LASTEXITCODE | Should -Be $case.Expected -Because "case '$($case.Name)'"
                ($output -join "`n") | Should -Match '^\[ERROR\] probe The server build did not run: this run published no vintage and rewrote no build/\.$' -Because "case '$($case.Name)'"
            }
        }
    }

    Context 'Structural guards: the hot path of #4918 (token level)' {

        It 'Consults the reconcile guard in the plan section, before the refusal is decided, and only where there is something to reconcile under live hosts' {
            $content | Should -Match 'function Test-WorkspaceInstallReconcileSafe \{'
            $planIdx  = $content.IndexOf('# --- Workspace plan (#4886)')
            $guardIdx = $content.IndexOf('$verdict = @(Test-WorkspaceInstallReconcileSafe -LockPath $WorkspaceLock')
            $willIdx  = $content.IndexOf('$wsWillRefuse = $wsApplies -and $wsNeedsInstall -and $wsAlive -gt 0 -and -not $wsReconcileSafe')
            $planIdx  | Should -BeGreaterThan 0
            $guardIdx | Should -BeGreaterThan $planIdx
            $willIdx  | Should -BeGreaterThan $guardIdx
            $planSection = $content.Substring($planIdx, $willIdx - $planIdx)
            $planSection | Should -Match 'if \(\$wsNeedsInstall -and \$wsAlive -gt 0\) \{'
            $planSection.IndexOf('if ($wsNeedsInstall -and $wsAlive -gt 0) {') | Should -BeLessThan $planSection.IndexOf('$verdict = @(Test-WorkspaceInstallReconcileSafe')
        }

        It 'The guard itself is read-only: it installs, builds, writes and removes nothing' {
            $guardText = Get-ScriptFunctionText 'Test-WorkspaceInstallReconcileSafe'
            $guardText | Should -Not -Match 'cmd /c|Start-Process|& npm'
            $guardText | Should -Not -Match 'Set-Content|Add-Content|Out-File|WriteAllText|AppendAllText|Remove-Item|New-Item|Copy-Item|Move-Item'
            $guardText | Should -Not -Match '\[System\.IO\.(File|Directory)\]::(Write|Delete|Create|Move|Copy|Append)'
            # Positive control: the execution block that DOES install trips the first pattern.
            $execStart = $content.IndexOf('# --- Workspace install + shared package build (#4886)')
            $execText  = $content.Substring($execStart, $content.IndexOf('# --- Pre-op guard (#3712)') - $execStart)
            $execText | Should -Match 'cmd /c'
        }

        It 'The refusal and the hot install are two branches of one question, and the guard decides between them' {
            $content | Should -Match 'if \(\$wsAlive -gt 0 -and -not \$wsReconcileSafe\) \{\r?\n\s*Exit-WorkspaceStepFailed -Refused '
            ([regex]::Matches($content, [regex]::Escape('if ($wsAlive -gt 0 -and -not $wsReconcileSafe) {'))) | Should -HaveCount 1
            ([regex]::Matches($content, [regex]::Escape('} elseif ($wsAlive -gt 0) {'))) | Should -HaveCount 1
            $refuseIdx = $content.IndexOf('if ($wsAlive -gt 0 -and -not $wsReconcileSafe) {')
            $hotIdx    = $content.IndexOf('} elseif ($wsAlive -gt 0) {')
            $refuseIdx | Should -BeGreaterThan 0
            $hotIdx    | Should -BeGreaterThan $refuseIdx
        }

        It 'Only exactly one boolean true opens the hot path' {
            $content.Contains('$wsReconcileSafe = ($verdict.Count -eq 1 -and $verdict[0] -is [bool] -and $verdict[0])') | Should -BeTrue
            # The closed initial value, and the verdict: no third assignment.
            ([regex]::Matches($content, '\$wsReconcileSafe\s*=')) | Should -HaveCount 2
        }

        It 'The hot install runs only under live hosts, after the dry exits, and nothing is built before it is verified' {
            ([regex]::Matches($content, [regex]::Escape('cmd /c "npm install 2>&1"'))) | Should -HaveCount 1
            $dry1Idx = $content.IndexOf('Exit-NotFresh ''SKIP'' "-DryRun set:')
            $dry2Idx = $content.IndexOf('Exit-NotFresh ''SKIP'' "ShouldProcess declined')
            $hotIdx  = $content.IndexOf('cmd /c "npm install 2>&1"')
            # Every anchor is asserted present: an absent one reads as -1 and would pass by default.
            $dry1Idx | Should -BeGreaterThan 0
            $dry2Idx | Should -BeGreaterThan 0
            $hotIdx  | Should -BeGreaterThan $dry1Idx
            $hotIdx  | Should -BeGreaterThan $dry2Idx
            $branchStart = $content.IndexOf('} elseif ($wsAlive -gt 0) {')
            $branchStart | Should -BeGreaterThan 0
            $coreIdx = $content.IndexOf('cmd /c "npm run build --workspace @vibesync/core 2>&1"', $hotIdx)
            $coreIdx | Should -BeGreaterThan $hotIdx
            $branch = $content.Substring($branchStart, $coreIdx - $branchStart)
            # Three ways out of the branch, all through the fail-closed helper: npm failed; npm
            # rewrote the lockfile this run planned against; the install still does not read current.
            $branch | Should -Match 'Exit-WorkspaceStepFailed "''npm install'' failed'
            $branch | Should -Match 'Exit-WorkspaceStepFailed "''npm install'' exited 0 in \$WorkspaceRoot but rewrote package-lock\.json'
            $branch | Should -Match 'Exit-WorkspaceStepFailed "''npm install'' exited 0 in \$WorkspaceRoot but the workspace install is still not current'
            # The order inside the branch: install, lockfile unchanged, install current.
            $installIdx = $branch.IndexOf('cmd /c "npm install 2>&1"')
            $lockIdx    = $branch.IndexOf('.Hash -ne $lockHash')
            $currentIdx = $branch.IndexOf('if (-not (Test-WorkspaceInstallCurrent')
            $installIdx | Should -BeGreaterThan 0
            $lockIdx    | Should -BeGreaterThan $installIdx
            $currentIdx | Should -BeGreaterThan $lockIdx
            # Nothing between the hot install and its verification starts the core build.
            ([regex]::Matches($branch.Substring(0, $currentIdx), 'npm run build')) | Should -HaveCount 0
        }

        It 'The refusal says why the hot path stayed closed on this tree' {
            $refusals = @($codeStrings | Where-Object { $_ -cmatch 'REFUSED while' })
            $refusals | Should -HaveCount 1
            $refusals[0] | Should -Match 'The hot path of #4918 does not open on this tree either: \$wsReconcileWhy Remedy: '
        }
    }

    Context 'Behaviour: Test-WorkspaceInstallReconcileSafe (hot path of #4918: additive at the root, nothing removed or replaced)' {

        BeforeAll {
            # --- Fixture helpers of the reconcile guard (#4918) ---
            # JSON is written as built and never parsed back: the plain ConvertFrom-Json of PS 5.1 rejects
            # npm's empty root key. Paths go through .NET or -LiteralPath, so the fixtures behave the same
            # under the Linux pwsh of the unit-pester job (a dot-prefixed name is hidden there).
            function Write-FixtureJson([string]$Path, [string]$Json) {
                $directory = [System.IO.Path]::GetDirectoryName($Path)
                if (-not ([System.IO.Directory]::Exists($directory))) { [void][System.IO.Directory]::CreateDirectory($directory) }
                [System.IO.File]::WriteAllText($Path, $Json)
            }

            function Add-FixturePackage([string]$Tree, [string]$Relative, [string]$Version) {
                Write-FixtureJson (Join-Path $Tree "$Relative/package.json") ('{"name":"x","version":"' + $Version + '"}')
            }

            # The lockfile of the first deployment: the workspace's own entries, the server tree as it was
            # installed, and the whole root tree the workspace adds (two packages and the two workspace
            # links npm makes, recorded like the real ones: resolved relative to the workspace root).
            function New-ReconcileLock([string[]]$Entries) {
                return '{"name":"ws","lockfileVersion":3,"packages":{"":{"name":"ws","version":"0.0.0"},"packages/vibesync-core":{"name":"@vibesync/core","version":"0.1.0"},"server":{"name":"server","version":"0.0.0"},' + ($Entries -join ',') + '}}'
            }

            # The baseline entries without the one named by $Key, plus $With (nothing when it is empty).
            function Get-LockEntries([string]$Key, [string]$With) {
                $kept = @($script:entries.Values | Where-Object { $_ -notlike ('"' + $Key + '":*') })
                if (-not [string]::IsNullOrEmpty($With)) { $kept += $With }
                return $kept
            }

            # The first-deployment shape, measured on po-204 (2026-11-24): the server tree installed by
            # `npm ci`, the root tree not installed at all. A fresh directory per call, so every test
            # states only its own delta.
            function Reset-ReconcileFixture {
                $script:root   = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
                $script:server = Join-Path $script:root 'server'
                $script:lock   = Join-Path $script:root 'package-lock.json'
                Write-FixtureJson $script:lock (New-ReconcileLock @($script:entries.Values))
                Write-FixtureJson (Join-Path $script:server 'node_modules/.package-lock.json') (
                    '{"name":"server","lockfileVersion":3,"packages":{"":{"name":"server","version":"0.0.0"},' +
                    '"node_modules/kept":{"version":"1.0.0","resolved":"https://registry.example/kept","integrity":"sha256-kk"},' +
                    '"node_modules/@scope/scoped":{"version":"2.0.0"},' +
                    '"node_modules/@scope/inert":{"version":"9.9.9","optional":true,"ideallyInert":true}}}')
                Add-FixturePackage $script:server 'node_modules/kept' '1.0.0'
                Add-FixturePackage $script:server 'node_modules/@scope/scoped' '2.0.0'
                # npm's own dot-directories are not packages, in either tree.
                New-Item -ItemType Directory -Path (Join-Path $script:server 'node_modules/.bin'), (Join-Path $script:root 'node_modules/.vite') -Force | Out-Null
            }

            # A directory link as npm makes a workspace link: a junction on Windows (no privilege needed
            # under 5.1), a symbolic link on Linux.
            function New-FixtureLink([string]$Path, [string]$Target) {
                # A junction tolerates a missing parent; a Linux symlink does not (symlink(2)
                # returns ENOENT). npm creates the scope folder anyway, so the fixture does too.
                $parent = [System.IO.Path]::GetDirectoryName($Path)
                if (-not [System.IO.Directory]::Exists($parent)) { [void][System.IO.Directory]::CreateDirectory($parent) }
                if ([System.IO.Path]::DirectorySeparatorChar -eq '\') {
                    New-Item -ItemType Junction -Path $Path -Target $Target | Out-Null
                } else {
                    New-Item -ItemType SymbolicLink -Path $Path -Target $Target | Out-Null
                }
                $script:allLinks += $Path
            }

            # The link itself is deleted, never its target.
            function Remove-FixtureLink([string]$Path) {
                [System.IO.Directory]::Delete($Path, $false)
            }

            # The reconciled shape (the tree after `npm install`): the root tree installed, its stamp
            # recording every lockfile entry, and the two workspace links on disk.
            function Add-ReconciledRoot {
                Write-FixtureJson (Join-Path $script:root 'node_modules/.package-lock.json') ('{"name":"ws","lockfileVersion":3,"packages":{"":{"name":"ws"},' + ((@('"server":{"name":"server","version":"0.0.0"}') + @($script:entries.Values)) -join ',') + '}}')
                Add-FixturePackage $script:root 'node_modules/added' '3.0.0'
                Add-FixturePackage $script:root 'node_modules/@scope/added-too' '4.0.0'
                Add-FixturePackage $script:root 'packages/vibesync-core' '0.1.0'
                New-FixtureLink (Join-Path $script:root 'node_modules/@vibesync/core') (Join-Path $script:root 'packages/vibesync-core')
                New-FixtureLink (Join-Path $script:root 'node_modules/ws-server') $script:server
            }

            # The verdict as the helper reads it: one array, whatever the function returned.
            function Get-ReconcileVerdict([string]$ServerPath = $script:server) {
                $script:reason = 'unset'
                return ,@(Test-WorkspaceInstallReconcileSafe -LockPath $script:lock -WorkspaceRoot $script:root -WorkspaceModulesPath (Join-Path $script:root 'node_modules') -ServerPath $ServerPath -Reason ([ref]$script:reason))
            }

            # Lockfile entries as literal JSON, by short name.
            $script:entries = @{
                RootAdded  = '"node_modules/added":{"version":"3.0.0","resolved":"https://registry.example/added","integrity":"sha256-aa"}'
                RootScoped = '"node_modules/@scope/added-too":{"version":"4.0.0"}'
                LinkCore   = '"node_modules/@vibesync/core":{"resolved":"packages/vibesync-core","link":true}'
                LinkServer = '"node_modules/ws-server":{"resolved":"server","link":true}'
                Kept       = '"server/node_modules/kept":{"version":"1.0.0","resolved":"https://registry.example/kept","integrity":"sha256-kk"}'
                Scoped     = '"server/node_modules/@scope/scoped":{"version":"2.0.0"}'
                Inert      = '"server/node_modules/@scope/inert":{"version":"9.9.9","optional":true,"ideallyInert":true}'
            }
            $script:fixtureBase = Join-Path ([System.IO.Path]::GetTempPath()) ('ebf-reconcile-' + [guid]::NewGuid().ToString('N'))
            # Every link ever made under the base, across the fixtures: each one is deleted itself.
            $script:allLinks = @()
            New-Item -ItemType Directory -Path $script:fixtureBase -Force | Out-Null
        }

        BeforeEach { Reset-ReconcileFixture }

        AfterAll {
            if ($script:fixtureBase -and ([System.IO.Directory]::Exists($script:fixtureBase))) {
                # Each link is deleted itself, never followed into its target (a recursive removal
                # of the base would otherwise walk a link into what it points at). A link a test
                # replaced by a directory is left to the removal of the base.
                foreach ($link in $script:allLinks) {
                    try { $isLink = (([System.IO.File]::GetAttributes($link)) -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 } catch { $isLink = $false }
                    if ($isLink) { Remove-FixtureLink $link }
                }
                Remove-Item -LiteralPath $script:fixtureBase -Recurse -Force
            }
        }

        It 'Answers exactly one true, with no reason, on the first-deployment shape: the server tree installed, the whole root tree still to add' {
            $verdict = Get-ReconcileVerdict
            $verdict.Count | Should -Be 1
            $verdict[0] -is [bool] | Should -BeTrue
            $verdict[0] | Should -BeTrue
            $script:reason | Should -Be ''
        }

        It 'Tolerates, as npm does, exactly the packages the stamp marks ideallyInert and the install left out' {
            # Baseline: `inert` is recorded, has no directory and carries the mark -- accepted above.
            # The same absent package WITHOUT the mark is one npm would add back under the server tree.
            $stampPath = Join-Path $script:server 'node_modules/.package-lock.json'
            Write-FixtureJson $stampPath ([System.IO.File]::ReadAllText($stampPath).Replace('"optional":true,"ideallyInert":true', '"optional":true'))
            $verdict = Get-ReconcileVerdict
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Be 'npm would ADD server/node_modules/@scope/inert back: it is recorded as installed here and its directory is gone.'
        }

        It 'Reads the disk under a root stamp too: a package no record knows is a removal' {
            # npm accepts a hidden lockfile only after walking the tree itself (arborist
            # assertNoNewer): a stamp present does not mean the disk is spared.
            Add-ReconciledRoot
            Add-FixturePackage $script:root 'node_modules/stray' '1.0.0'
            $verdict = Get-ReconcileVerdict
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Be 'npm would REMOVE node_modules/stray: it is on disk and in no install record.'
        }

        It 'Accepts the reconciled shape and never follows a link' {
            # After `npm install`: the root tree is installed, its stamp records the whole lockfile,
            # and npm made two workspace links. `node_modules/ws-server` points at the server tree,
            # whose packages are recorded under `server/…` only: followed, they would read as
            # `node_modules/ws-server/node_modules/…`, in no record, and the guard would refuse a
            # tree npm leaves alone.
            Add-ReconciledRoot
            $verdict = Get-ReconcileVerdict
            $verdict.Count | Should -Be 1
            $verdict[0] | Should -BeTrue
            $script:reason | Should -Be ''
        }

        It 'Refuses, naming the package, when the lockfile would remove or replace a recorded package' {
            $differ = 'npm would REPLACE server/node_modules/kept: the installed entry and the lockfile entry differ.'
            $cases = @(
                @{ Name = 'another version';      With = '"server/node_modules/kept":{"version":"1.0.1"}'; Reason = $differ }
                @{ Name = 'another resolved URL'; With = '"server/node_modules/kept":{"version":"1.0.0","resolved":"https://registry.example/other","integrity":"sha256-kk"}'; Reason = $differ }
                @{ Name = 'another integrity';    With = '"server/node_modules/kept":{"version":"1.0.0","resolved":"https://registry.example/kept","integrity":"sha256-zz"}'; Reason = $differ }
                @{ Name = 'the package dropped';  With = ''; Reason = 'npm would REMOVE server/node_modules/kept: it is installed here and absent from the lockfile.' }
            )
            foreach ($case in $cases) {
                Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key 'server/node_modules/kept' -With $case.With))
                $verdict = Get-ReconcileVerdict
                $verdict.Count | Should -Be 1 -Because $case.Name
                $verdict[0] | Should -BeFalse -Because $case.Name
                $script:reason | Should -Be $case.Reason -Because $case.Name
            }
        }

        It 'Refuses a package the ROOT stamp records when the lockfile drops it' {
            Add-ReconciledRoot
            Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key 'node_modules/added' -With ''))
            $verdict = Get-ReconcileVerdict
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Be 'npm would REMOVE node_modules/added: it is installed here and absent from the lockfile.'
        }

        It 'Refuses when the lockfile adds anything outside the root tree, wherever it lands' {
            $outside = ' outside the root node_modules tree.'
            $cases = @(
                @{ Name = 'under the server tree';            With = '"server/node_modules/newcomer":{"version":"5.0.0"}'; Reason = 'npm would ADD server/node_modules/newcomer' + $outside }
                @{ Name = 'under a scope of the server tree'; With = '"server/node_modules/@scope/newcomer":{"version":"5.0.0"}'; Reason = 'npm would ADD server/node_modules/@scope/newcomer' + $outside }
                @{ Name = 'under a package of the server tree'; With = '"server/node_modules/kept/node_modules/newcomer":{"version":"5.0.0"}'; Reason = 'npm would ADD server/node_modules/kept/node_modules/newcomer' + $outside }
            )
            foreach ($case in $cases) {
                Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key '' -With $case.With))
                $verdict = Get-ReconcileVerdict
                $verdict[0] | Should -BeFalse -Because $case.Name
                $script:reason | Should -Be $case.Reason -Because $case.Name
            }
        }

        It 'Accepts, as npm 11.11 records it, a package npm leaves out on this platform: in the lockfile under the server tree, in no stamp, on no disk (#4918)' {
            # Measured on ai-01 (2026-11-27): 119 such entries under the server tree, none in its stamp.
            Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key '' -With '"server/node_modules/@scope/binding-wasm":{"version":"1.0.0","optional":true,"cpu":["wasm32"]}'))
            $verdict = Get-ReconcileVerdict
            $verdict.Count | Should -Be 1
            $verdict[0] | Should -BeTrue
            $script:reason | Should -Be ''
        }

        It 'Still refuses an optional package npm installs here, and a skipped one when the platform cannot be read' {
            $outside = ' outside the root node_modules tree.'
            Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key '' -With '"server/node_modules/optional-here":{"version":"1.0.0","optional":true}'))
            $verdict = Get-ReconcileVerdict
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Be ('npm would ADD server/node_modules/optional-here' + $outside)
            Write-FixtureJson $script:lock (New-ReconcileLock @(Get-LockEntries -Key '' -With '"server/node_modules/@scope/binding-wasm":{"version":"1.0.0","optional":true,"cpu":["wasm32"]}'))
            $script:npmPlatform = $null
            try {
                $verdict = Get-ReconcileVerdict
            } finally {
                $script:npmPlatform = @{ Os = 'win32'; Cpu = 'x64'; Libc = '' }
            }
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Be ('npm would ADD server/node_modules/@scope/binding-wasm' + $outside)
        }

        It 'Refuses when the disk disagrees with the records, in every tree' {
            $unrecorded = ': it is on disk and in no install record.'
            $gone = ': it is recorded as installed here and its directory is gone.'
            $cases = @(
                @{ Name = 'a directory no record knows'; Act = { Add-FixturePackage $script:server 'node_modules/stray' '1.0.0' }; Reason = 'npm would REMOVE server/node_modules/stray' + $unrecorded }
                @{ Name = 'the same under a scope'; Act = { Add-FixturePackage $script:server 'node_modules/@scope/stray' '1.0.0' }; Reason = 'npm would REMOVE server/node_modules/@scope/stray' + $unrecorded }
                @{ Name = 'the same under a nested node_modules'; Act = { Add-FixturePackage $script:server 'node_modules/kept/node_modules/dep' '1.0.0' }; Reason = 'npm would REMOVE server/node_modules/kept/node_modules/dep' + $unrecorded }
                @{ Name = 'a recorded directory gone'; Act = { [System.IO.Directory]::Delete((Join-Path $script:server 'node_modules/@scope/scoped'), $true) }; Reason = 'npm would ADD server/node_modules/@scope/scoped back' + $gone }
                @{ Name = 'a package.json that says another version'; Act = { Add-FixturePackage $script:server 'node_modules/kept' '1.0.1' }; Reason = 'npm would REPLACE server/node_modules/kept: the package.json on disk does not say version 1.0.0.' }
            )
            foreach ($case in $cases) {
                Reset-ReconcileFixture
                & $case.Act
                $verdict = Get-ReconcileVerdict
                $verdict[0] | Should -BeFalse -Because $case.Name
                $script:reason | Should -Be $case.Reason -Because $case.Name
            }
        }

        It 'Refuses when a record is missing or unreadable, and says which' {
            $cases = @(
                @{ Name = 'no server stamp'; Act = { [System.IO.File]::Delete([System.IO.Path]::Combine($script:server, 'node_modules', '.package-lock.json')) }
                    Reason = { 'npm left no install record at ' + [System.IO.Path]::Combine($script:server, 'node_modules', '.package-lock.json') + ', so the tree the live RSM hosts resolve into cannot be compared with the lockfile.' } }
                @{ Name = 'no lockfile'; Act = { [System.IO.File]::Delete($script:lock) }
                    Reason = 'the lockfile is absent, unreadable or holds no packages object.' }
                @{ Name = 'a lockfile that is not JSON'; Act = { Write-FixtureJson $script:lock 'not json' }
                    Reason = 'the lockfile is absent, unreadable or holds no packages object.' }
                @{ Name = 'a server stamp that is not JSON'; Act = { Write-FixtureJson ([System.IO.Path]::Combine($script:server, 'node_modules', '.package-lock.json')) 'not json' }
                    Reason = { 'the install record at ' + [System.IO.Path]::Combine($script:server, 'node_modules', '.package-lock.json') + ' is unreadable or holds no packages object.' } }
                @{ Name = 'a root stamp without a packages object'; Act = { Add-ReconciledRoot; Write-FixtureJson ([System.IO.Path]::Combine($script:root, 'node_modules', '.package-lock.json')) '{"name":"ws","other":{}}' }
                    Reason = { 'the install record at ' + [System.IO.Path]::Combine($script:root, 'node_modules', '.package-lock.json') + ' is unreadable or holds no packages object.' } }
            )
            foreach ($case in $cases) {
                Reset-ReconcileFixture
                & $case.Act
                $verdict = Get-ReconcileVerdict
                $verdict[0] | Should -BeFalse -Because $case.Name
                $expected = if ($case.Reason -is [scriptblock]) { & $case.Reason } else { $case.Reason }
                $script:reason | Should -Be $expected -Because $case.Name
            }
        }

        It 'Refuses a server folder that is not below the workspace root' {
            $elsewhere = Join-Path $script:fixtureBase ([guid]::NewGuid().ToString('N'))
            $verdict = Get-ReconcileVerdict -ServerPath $elsewhere
            $verdict[0] | Should -BeFalse
            $script:reason | Should -BeLike ($elsewhere + ' is not a directory below *, so its packages cannot be located in the lockfile.')
        }

        It 'Refuses a link it cannot vouch for' {
            $cases = @(
                @{ Name = 'a link no record made'
                    Act    = { New-FixtureLink (Join-Path $script:root 'node_modules/stray-link') $script:server }
                    Reason = 'node_modules/stray-link is a link and no install record made it to the target the lockfile names, so what npm would do with it is not evaluated.' }
                @{ Name = 'a link to another target than the lockfile names'
                    Act    = { Add-ReconciledRoot; Remove-FixtureLink (Join-Path $script:root 'node_modules/ws-server'); New-FixtureLink (Join-Path $script:root 'node_modules/ws-server') (Join-Path $script:root 'packages/vibesync-core') }
                    Reason = 'npm would REPLACE the link node_modules/ws-server: it points at * and the lockfile wants server.' }
                @{ Name = 'a directory where the record holds a link'
                    Act    = { Add-ReconciledRoot; Remove-FixtureLink (Join-Path $script:root 'node_modules/ws-server'); Add-FixturePackage $script:root 'node_modules/ws-server' '1.0.0' }
                    Reason = 'npm would REPLACE node_modules/ws-server: the install record holds a link there and the disk holds a directory.' }
            )
            foreach ($case in $cases) {
                Reset-ReconcileFixture
                & $case.Act
                $verdict = Get-ReconcileVerdict
                $verdict[0] | Should -BeFalse -Because $case.Name
                $script:reason | Should -BeLike $case.Reason -Because $case.Name
            }
        }

        It 'Leaves no stale reason behind: the next verdict starts from an empty one' {
            $verdict = Get-ReconcileVerdict -ServerPath (Join-Path $script:fixtureBase 'elsewhere')
            $verdict[0] | Should -BeFalse
            $script:reason | Should -Not -Be ''
            $verdict = Get-ReconcileVerdict
            $verdict[0] | Should -BeTrue
            $script:reason | Should -Be ''
        }
    }
}
