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
            (Get-Item $lock).LastWriteTimeUtc = [DateTime]::UtcNow
            (Get-Item (Join-Path $modules '.package-lock.json')).LastWriteTimeUtc = [DateTime]::UtcNow.AddMinutes(5)
            Test-WorkspaceInstallCurrent -LockPath $lock -ModulesPath $modules -ServerPath $server | Should -BeFalse
        }

        It 'Returns true when the lockfile is newer by mtime only: a checkout that rewrites an identical lock must not re-run npm ci' {
            '{"packages":{"":{"name":"root"},"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath $lock -Encoding utf8 -NoNewline
            '{"packages":{"node_modules/a":{"version":"1.0.0"},"node_modules/b":{"version":"2.0.0"}}}' | Set-Content -LiteralPath (Join-Path $modules '.package-lock.json') -Encoding utf8 -NoNewline
            (Get-Item $lock).LastWriteTimeUtc = [DateTime]::UtcNow.AddMinutes(5)
            (Get-Item (Join-Path $modules '.package-lock.json')).LastWriteTimeUtc = [DateTime]::UtcNow
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
}
