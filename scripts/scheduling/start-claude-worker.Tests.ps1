# Pester tests for start-claude-worker.ps1 — #3905 (claude_code_version_too_old surfacing).
#
# The worker is a 5000-line monolith with network side effects: not drivable from a
# bench. What IS provable without executing it:
#   - the DETECTION regex actually shipped in the file (extracted, not re-typed — a
#     bench that matches its own prose proves nothing) runs against the incident's
#     real emission form and REJECTS the prose false-positive class;
#   - the WIRING: flag flows into the $Result hashtable and the worker report
#     template, and the run log carries the CLI version line (demand 1, already in
#     place via Test-ClaudeCLI).
#
# Run:  pwsh -File scripts/testing/run-pester-tests.ps1 -Path scripts/scheduling/start-claude-worker.Tests.ps1

BeforeAll {
    $target = Join-Path $PSScriptRoot 'start-claude-worker.ps1'
    $script:src = Get-Content -LiteralPath $target -Raw

    # Extract the SHIPPED regex: '$ClaudeCodeVersionTooOld = $JoinedIterationOutput -match '<pat>''
    $m = [regex]::Match($script:src, "\`$ClaudeCodeVersionTooOld = \`$JoinedIterationOutput -match '([^']+)'")
    $script:versionPattern = if ($m.Success) { $m.Groups[1].Value } else { $null }
}

Describe 'start-claude-worker.ps1 — #3905 claude_code_version_too_old detection' {
    It 'the detection regex is present and extractable from the source (denominator)' {
        $script:versionPattern | Should -Not -BeNullOrEmpty
        $script:versionPattern | Should -Match 'claude_code_version_too_old'
        $script:versionPattern | Should -Match 'API Error'
    }

    It 'matches the incident emission (API Error 400 … version_too_old on one line)' {
        $sample = @(
            'Some prior worker output line.'
            'API Error 400 … claude_code_version_too_old ("Claude Code 2.1.17 does not support this model; version 2.1.280 or newer is required")'
            'Following output line.'
        ) -join "`n"
        $sample | Should -Match $script:versionPattern
    }

    It 'matches the emission with an [ERROR] log prefix' {
        $sample = "[ERROR] API Error 400 claude_code_version_too_old (`"2.1.41 does not support this model`")"
        $sample | Should -Match $script:versionPattern
    }

    It 'REJECTS prose quoting the token (issue title / task body — not an emission)' {
        $sample = @(
            '## Issue Description'
            'Echecs opus silencieux sur CLI < 2.1.280 (claude_code_version_too_old) — rendre la cause visible dans le rapport worker'
            'The worker should surface claude_code_version_too_old when it appears.'
        ) -join "`n"
        $sample | Should -Not -Match $script:versionPattern
    }

    It 'REJECTS an API Error emission WITHOUT the version token (stays #2968-generic)' {
        $sample = 'API Error 429: rate limit exceeded, retry after 60s'
        $sample | Should -Not -Match $script:versionPattern
    }
}

Describe 'start-claude-worker.ps1 — #3905 wiring (flag reaches log, result, report)' {
    It 'flag is assigned into the returned $Result hashtable' {
        $script:src | Should -Match 'claudeCodeVersionTooOld = \$ClaudeCodeVersionTooOld'
    }

    It 'worker report template carries a dedicated CLI-too-old line keyed on the flag' {
        $script:src | Should -Match '\$Result\.claudeCodeVersionTooOld'
        $script:src | Should -Match 'CLI trop ancien'
    }

    It 'demand 1: the run log records the CLI version (Test-ClaudeCLI, called from main pre-flight)' {
        $script:src | Should -Match 'Write-Log "Claude CLI: \$Version"'
        $script:src | Should -Match 'if \(-not \(Test-ClaudeCLI\)\)'
    }
}

# --- Re-request review after CHANGES_REQUESTED fixes (dispatch ai-01 2026-10-05) ---
#
# The rule: « une review plus ancienne que le dernier commit est la dette du
# reviewer ». The decision core (Get-StaleReviewers) is pure — extracted from
# the SHIPPED source like claim-lock/Hide-SecretLikeArgs suites, never
# re-typed — and driven here with gh-shaped review JSON. The I/O wrapper
# (Request-StaleReview) and its hook in the #2157 re-push branch are asserted
# on the raw source.

Describe 'start-claude-worker.ps1 — Get-StaleReviewers decision core (behavioral)' {
    BeforeAll {
        # Extract the SHIPPED function (first column-0 closing brace = its own end).
        $m = [regex]::Match($script:src, '(?s)(function Get-StaleReviewers \{.*?\r?\n\})')
        if (-not $m.Success) { throw 'Get-StaleReviewers not found in start-claude-worker.ps1' }
        Invoke-Expression $m.Groups[1].Value
    }

    It 'CHANGES_REQUESTED older than head commit → reviewer re-requested (the debt case)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @('reviewer-a')
    }

    It 'APPROVED newer than head commit → excluded (verdict describes the head, no debt)' {
        $json = '[{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'APPROVED older than head commit → included (stale verdict re-opens the debt on ANY state)' {
        $json = '[{"state":"APPROVED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @('reviewer-a')
    }

    It 'latest verdict wins per login — fresh APPROVED supersedes an older CHANGES_REQUESTED from the same reviewer' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T08:00:00Z","user":{"login":"reviewer-a"}},{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'excludes the self login (re-requesting the login that pushed is a no-op)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"worker"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'COMMENTED-only login excluded (a comment carries no verdict)' {
        $json = '[{"state":"COMMENTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'mixed fleet: only stale, non-self, verdict-carrying logins returned' {
        $json = @(
            '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"stale-one"}}'
            ',{"state":"APPROVED","submitted_at":"2026-10-05T13:00:00Z","user":{"login":"fresh-one"}}'
            ',{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T09:00:00Z","user":{"login":"worker"}}'
            ',{"state":"COMMENTED","submitted_at":"2026-10-05T09:30:00Z","user":{"login":"commenter"}}'
            ',{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T09:00:00Z","user":{"login":"stale-two"}}]'
        ) -join ''
        $r = @(Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker')
        $r.Count | Should -Be 2
        $r | Should -Contain 'stale-one'
        $r | Should -Contain 'stale-two'
    }

    It 'unparseable head date → fail-open @() (a bad date never triggers a re-request)' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = Get-StaleReviewers -ReviewsJson $json -HeadCommitDate 'not-a-date' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'unparseable review date → that review skipped, other reviewers still served' {
        $json = '[{"state":"CHANGES_REQUESTED","submitted_at":"garbage","user":{"login":"broken-date"}},{"state":"CHANGES_REQUESTED","submitted_at":"2026-10-05T10:00:00Z","user":{"login":"reviewer-a"}}]'
        $r = @(Get-StaleReviewers -ReviewsJson $json -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker')
        $r | Should -Be @('reviewer-a')
    }

    It 'empty reviews json → @()' {
        $r = Get-StaleReviewers -ReviewsJson '' -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }

    It 'malformed json → @() (catch = fail-open, never throws)' {
        $r = Get-StaleReviewers -ReviewsJson 'not-json-at-all' -HeadCommitDate '2026-10-05T12:00:00Z' -SelfLogin 'worker'
        @($r) | Should -Be @()
    }
}

Describe 'start-claude-worker.ps1 — Request-StaleReview wiring (re-push branch)' {
    It 'both functions are defined before New-WorkerPR' {
        $script:src | Should -Match '(?s)function Get-StaleReviewers \{.*?function Request-StaleReview \{.*?function New-WorkerPR \{'
    }

    It 'hook: the #2157 existing-PR branch calls Request-StaleReview before returning the PR url' {
        $script:src | Should -Match '(?s)PR already exists for branch.*?Request-StaleReview -PrUrl "\$ExistingPR"\.Trim\(\).*?return "\$ExistingPR"\.Trim\(\)'
    }

    It 're-request goes through the requested_reviewers endpoint (POST)' {
        $script:src | Should -Match 'requested_reviewers'
        $script:src | Should -Match '-X POST'
    }

    It 'never stacks a second nudge: skips when reviewRequests already pending' {
        $script:src | Should -Match 'reviewRequests'
        $script:src | Should -Match 'Re-review skip'
    }

    It 'never fatal: wrapper failure logs WARN, not throw' {
        $script:src | Should -Match '(?s)function Request-StaleReview \{.*?Write-Log "Request-StaleReview non-fatal failure.*?"WARN"'
    }

    It 'policy doc carries the rule: une review plus ancienne que le dernier commit est la dette du reviewer' {
        $policy = Join-Path $PSScriptRoot '..\..\docs\harness\coordinator-specific\pr-review-policy.md'
        (Get-Content -LiteralPath $policy -Raw) | Should -Match 'dette du reviewer'
    }
}

# --- Test-SkAgentAvailable: the handshake must reach a healthy server intact ---
#
# Measured ai-01 2026-11-01: 14 worker runs with "sk-agent pre-flight FAILED" since
# 02/10, 0 OK, while sk-agent answered in 12 s from pwsh 7. Under powershell.exe 5.1
# on a UTF-8 system code page (ACP 65001), `$Request | & cmd ...` writes EF BB BF
# before the request; the MCP parser rejects '﻿{...' as invalid JSON. The
# SHIPPED function is extracted and run in a powershell.exe 5.1 child (the engine
# the worker runs under) against a stub server that answers only a request whose
# first stdin byte is '{'. The BOM reproduces on a 65001 seat; a 1252 runner
# cannot produce it, so there the first case is a non-regression of the redirect.

Describe 'start-claude-worker.ps1 — Test-SkAgentAvailable handshake (behavioral, PS 5.1 child)' {
    BeforeAll {
        $script:ps51 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $script:canRun = $env:WINDIR -and (Test-Path -LiteralPath $script:ps51)
        $m = [regex]::Match($script:src, '(?s)(function Test-SkAgentAvailable \{.*?\r?\n\})')
        if (-not $m.Success) { throw 'Test-SkAgentAvailable not found in start-claude-worker.ps1' }
        $script:fnText = $m.Groups[1].Value

        function script:Invoke-Preflight([string]$StubBody) {
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $skDir = Join-Path $root 'mcps\internal\servers\sk-agent'
            New-Item -ItemType Directory -Path $skDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $skDir 'sk_agent_config.json') -Value '{}' -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $skDir 'run-sk-agent.ps1') -Value $StubBody -Encoding ASCII
            $log = Join-Path $root 'worker.log'
            $harness = @"
`$RepoRoot = '$root'
function Write-Log { param(`$Message, `$Level = 'INFO') Add-Content -LiteralPath '$log' -Value "[`$Level] `$Message" }
$($script:fnText)
`$r = Test-SkAgentAvailable -TimeoutSeconds 60
"RESULT=`$r"
"@
            $hp = Join-Path $root 'harness.ps1'
            # BOM: powershell.exe 5.1 reads a BOM-less script as ANSI, and the
            # extracted function carries non-ASCII comments.
            [System.IO.File]::WriteAllText($hp, $harness, (New-Object System.Text.UTF8Encoding $true))
            $out = & $script:ps51 -NoProfile -ExecutionPolicy Bypass -File $hp 2>&1
            [pscustomobject]@{
                Result = (@($out) -match '^RESULT=' | Select-Object -Last 1)
                Log    = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }
            }
        }

        # Answers JSON-RPC only when the first stdin byte is '{' (0x7B); otherwise
        # reports the first bytes it got, like the real parser error does.
        $script:healthyStub = @'
$s = [Console]::OpenStandardInput(); $buf = New-Object byte[] 4096; $n = $s.Read($buf, 0, 4096)
if ($n -gt 0 -and $buf[0] -eq 0x7B) { [Console]::Out.WriteLine('{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05"}}') }
else { [Console]::Out.WriteLine('stub: Invalid JSON, stdin starts with ' + (($buf[0..([Math]::Max(0, [Math]::Min($n, 3) - 1))] | ForEach-Object { '{0:x2}' -f $_ }) -join '')) }
'@
        $script:brokenStub = @'
[Console]::Out.WriteLine('stub-marker-4471: validation error for JSONRPCMessage')
'@
    }

    It 'a healthy server answers: the request reaches its stdin starting with "{" and the verdict is OK' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-Preflight $script:healthyStub
        $r.Result | Should -Be 'RESULT=True'
        $r.Log | Should -Match 'sk-agent pre-flight OK'
    }

    It 'a server that never answers "result" fails, and the FAILED line names what was received' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-Preflight $script:brokenStub
        $r.Result | Should -Be 'RESULT=False'
        $r.Log | Should -Match 'pre-flight FAILED.*stub-marker-4471'
    }
}

# --- #4651: Get-IssueProjectFields must run graphql under an identity WITH read:project ---
#
# Measured ai-01 11/11: the machine's ACTIVE gh account (jsboige) lacks read:project,
# so every project-fields read died on INSUFFICIENT_SCOPES and the worker picked
# NOTHING for 26 passes while reporting exit 0 « propre ». The SHIPPED functions are
# extracted and driven in a powershell.exe 5.1 child (the worker's engine) against a
# gh.cmd shim placed FIRST on PATH:
#   - `gh auth status` lists an ACTIVE account WITHOUT the scope + others;
#   - `gh api graphql` fails INSUFFICIENT_SCOPES unless GH_TOKEN carries the scoped
#     account's token — so a green eligibility result PROVES the token was pinned;
#   - `gh auth token --user X` serves the scoped token (or fails, per scenario).
# On the pre-fix code (92688ada) the same harness gets INSUFFICIENT_SCOPES → NULL.

Describe 'start-claude-worker.ps1 — #4651 project-fields identity (behavioral, PS 5.1 child + gh shim)' {
    BeforeAll {
        $script:ps51 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $script:canRun = $env:WINDIR -and (Test-Path -LiteralPath $script:ps51)
        $script:token = 'shim-ghp-project-reader-4651'
        $script:envToken = 'shim-ghp-env-reader-4651'

        # Extract by NEXT top-level 'function' boundary — Get-IssueProjectFields holds
        # a column-0 '}' inside its GraphQL here-string, so a lazy 'first \n\}' regex
        # would truncate it.
        function script:Get-FunctionChunk([string]$Name, [string]$Source) {
            $start = $Source.IndexOf("function $Name ")
            if ($start -lt 0) { return $null }
            $end = $Source.IndexOf("`nfunction ", $start + 10)
            if ($end -lt 0) { return $null }
            return $Source.Substring($start, $end - $start + 1)
        }
        $script:fnFields = Get-FunctionChunk 'Get-IssueProjectFields' $script:src
        if (-not $script:fnFields) { throw 'Get-IssueProjectFields not found in start-claude-worker.ps1' }
        # $null on the pre-fix base (92688ada) — the harness then runs the legacy
        # function as-is and MUST go red behaviorally (INSUFFICIENT_SCOPES → NULL).
        $script:fnResolver = Get-FunctionChunk 'Resolve-ProjectGhReader' $script:src
        if ($null -eq $script:fnResolver) { $script:fnResolver = '' }

        $script:fieldsJson = '{"data":{"repository":{"issue":{"projectItems":{"nodes":[{"fieldValues":{"nodes":[{"name":"myia-po-2024","field":{"name":"Machine"}},{"name":"worker","field":{"name":"Execution"}}]}}]}}}}}'

        # Active account has NO scope; project-reader HAS it and serves a token.
        # graphql only answers the token-bearing caller — everything else
        # INSUFFICIENT_SCOPES, like the real API answers a scope-less token.
        $script:shimEligible = @"
@echo off
if "%1"=="auth" goto auth
goto api

:auth
if not "%2"=="status" goto token
echo github.com
echo   Logged in to github.com account active-no-scope ^(keyring^)
echo   - Active account: true
echo   - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
echo github.com
echo   Logged in to github.com account project-reader ^(keyring^)
echo   - Active account: false
echo   - Token scopes: 'gist', 'read:org', 'read:project', 'repo', 'workflow'
exit /b 0

:token
if not "%4"=="project-reader" goto tokenfail
echo $script:token
exit /b 0
:tokenfail
echo no token for user %4
exit /b 1

:api
if not defined GH_TOKEN goto scopesfail
if "%GH_TOKEN%"=="$script:token" goto gql
goto scopesfail

:gql
echo $script:fieldsJson
exit /b 0

:scopesfail
echo {"errors":[{"type":"INSUFFICIENT_SCOPES","message":"shim 4651: read:project required, got GH_TOKEN state mismatch"}]}
exit /b 1
"@

        # No account carries read:project anywhere.
        $script:shimNoScope = @"
@echo off
if "%1"=="auth" goto auth
goto api

:auth
if not "%2"=="status" goto token
echo github.com
echo   Logged in to github.com account active-no-scope ^(keyring^)
echo   - Active account: true
echo   - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
echo github.com
echo   Logged in to github.com account second-no-scope ^(keyring^)
echo   - Active account: false
echo   - Token scopes: 'gist', 'read:org', 'repo'
exit /b 0

:token
echo no token for user %4
exit /b 1

:api
echo {"errors":[{"type":"INSUFFICIENT_SCOPES","message":"shim 4651: read:project required"}]}
exit /b 1
"@

        # Scan would find scan-scoped (token fetch FAILS); the env override names
        # env-project-reader, whose token works. Proves the override outranks the scan.
        $script:shimEnvOverride = @"
@echo off
if "%1"=="auth" goto auth
goto api

:auth
if not "%2"=="status" goto token
echo github.com
echo   Logged in to github.com account active-no-scope ^(keyring^)
echo   - Active account: true
echo   - Token scopes: 'gist', 'read:org', 'repo', 'workflow'
echo github.com
echo   Logged in to github.com account scan-scoped ^(keyring^)
echo   - Active account: false
echo   - Token scopes: 'gist', 'read:org', 'read:project', 'repo'
exit /b 0

:token
if not "%4"=="env-project-reader" goto tokenfail
echo $script:envToken
exit /b 0
:tokenfail
echo no token for user %4
exit /b 1

:api
if not defined GH_TOKEN goto scopesfail
if "%GH_TOKEN%"=="$script:envToken" goto gql
goto scopesfail

:gql
echo {"data":{"repository":{"issue":{"projectItems":{"nodes":[{"fieldValues":{"nodes":[{"name":"via-env-override","field":{"name":"Machine"}}]}}]}}}}}
exit /b 0

:scopesfail
echo {"errors":[{"type":"INSUFFICIENT_SCOPES","message":"shim 4651: read:project required"}]}
exit /b 1
"@

        # po-204 measured case 11/11: the ACTIVE account carries the WRITE scope
        # 'project' (implies read) — zero INSUFFICIENT_SCOPES emissions there.
        # A scan matching only 'read:project' would find nobody and REGRESS this
        # seat from working to fail-closed.
        $script:shimWriteScope = @"
@echo off
if "%1"=="auth" goto auth
goto api

:auth
if not "%2"=="status" goto token
echo github.com
echo   Logged in to github.com account active-write-scope ^(keyring^)
echo   - Active account: true
echo   - Token scopes: 'gist', 'project', 'read:org', 'repo', 'workflow'
exit /b 0

:token
if not "%4"=="active-write-scope" goto tokenfail
echo shim-ghp-active-project-4651
exit /b 0
:tokenfail
echo no token for user %4
exit /b 1

:api
if not defined GH_TOKEN goto scopesfail
if "%GH_TOKEN%"=="shim-ghp-active-project-4651" goto gql
goto scopesfail

:gql
echo {"data":{"repository":{"issue":{"projectItems":{"nodes":[{"fieldValues":{"nodes":[{"name":"via-active-project-scope","field":{"name":"Machine"}}]}}]}}}}}
exit /b 0

:scopesfail
echo {"errors":[{"type":"INSUFFICIENT_SCOPES","message":"shim 4651: read:project required"}]}
exit /b 1
"@

        # Runs the shipped functions in a PS 5.1 child with the shim first on PATH.
        function script:Invoke-ProjectFieldsRead {
            param([string]$GhCmdText, [int[]]$Issues = @(4651), [hashtable]$EnvSet = @{})

            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
            $bin = Join-Path $root 'bin'
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            [System.IO.File]::WriteAllText((Join-Path $bin 'gh.cmd'), $GhCmdText, (New-Object System.Text.ASCIIEncoding))
            $log = Join-Path $root 'worker.log'

            $envLines = ($EnvSet.GetEnumerator() | ForEach-Object { '$env:{0} = ''{1}''' -f $_.Key, $_.Value }) -join "`r`n"
            $harness = @'
[Environment]::SetEnvironmentVariable('GH_TOKEN', $null, 'Process')
$env:PATH = '{BIN};' + $env:PATH
{ENV}
function Write-Log { param([string]$Message, [string]$Level = 'INFO') Add-Content -LiteralPath '{LOG}' -Value "[$Level] $Message" -Encoding UTF8 }
{RESOLVER}
{FIELDS}
foreach ($n in @({ISSUES})) {
    $f = Get-IssueProjectFields -IssueNumber $n
    if ($null -eq $f) { "FIELDS|$n|NULL" } else { "FIELDS|$n|" + (($f.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ',') }
}
if ($null -ne [Environment]::GetEnvironmentVariable('GH_TOKEN','Process')) { 'GH_TOKEN_AFTER=defined' } else { 'GH_TOKEN_AFTER=undefined' }
'@
            $harness = $harness.Replace('{BIN}', $bin).Replace('{LOG}', $log).Replace('{ENV}', $envLines).Replace('{RESOLVER}', $script:fnResolver).Replace('{FIELDS}', $script:fnFields).Replace('{ISSUES}', ($Issues -join ','))
            $hp = Join-Path $root 'harness.ps1'
            # BOM: powershell.exe 5.1 reads a BOM-less script as ANSI, and the
            # shipped functions carry non-ASCII comments.
            [System.IO.File]::WriteAllText($hp, $harness, (New-Object System.Text.UTF8Encoding $true))
            $out = & $script:ps51 -NoProfile -ExecutionPolicy Bypass -File $hp 2>&1
            [pscustomobject]@{
                Out = ($out -join "`n")
                Log = if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log -Raw } else { '' }
            }
        }
    }

    It 'AC1: active account lacks read:project, another carries it → fields read, issue ELIGIBLE (red on 92688ada)' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimEligible -Issues @(4651)
        $r.Out | Should -Match 'FIELDS\|4651\|.*Machine=myia-po-2024'
        $r.Out | Should -Not -Match 'FIELDS\|4651\|NULL'
        $r.Log | Should -Match 'Identité Project \(read:project\) : project-reader'
        $r.Log | Should -Not -Match 'INSUFFICIENT_SCOPES'
    }

    It 'AC1 (pinning is per-call): GH_TOKEN is undefined again once the graphql call returns' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimEligible -Issues @(4651)
        $r.Out | Should -Match 'FIELDS\|4651\|.*Machine=myia-po-2024'
        $r.Out | Should -Match 'GH_TOKEN_AFTER=undefined'
    }

    It 'resolution happens ONCE per pass: two issues read, a single identity INFO line' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimEligible -Issues @(4651, 4652)
        $r.Out | Should -Match 'FIELDS\|4651\|.*Machine=myia-po-2024'
        $r.Out | Should -Match 'FIELDS\|4652\|.*Machine=myia-po-2024'
        @([regex]::Matches($r.Log, 'Identité Project')).Count | Should -Be 1
    }

    It 'AC2: NO account with read:project → exactly ONE ERROR line per pass, issues stay skipped (fail-closed)' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimNoScope -Issues @(4651, 4652)
        $r.Out | Should -Match 'FIELDS\|4651\|NULL'
        $r.Out | Should -Match 'FIELDS\|4652\|NULL'
        @([regex]::Matches($r.Log, '\[ERROR\]')).Count | Should -Be 1
        $r.Log | Should -Match 'aucun compte gh avec read:project : le worker ne peut piocher aucune issue'
        # The ERROR line REPLACES the per-issue WARN repetition, it does not stack on it
        $r.Log | Should -Not -Match 'INSUFFICIENT_SCOPES'
    }

    It 'AC3: the pinned token never appears in any log line nor on stdout' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimEligible -Issues @(4651)
        $r.Log | Should -Not -Match [regex]::Escape($script:token)
        $r.Out | Should -Not -Match [regex]::Escape($script:token)
    }

    It 'CLAUDE_WORKER_PROJECT_GH_USER outranks the gh auth status scan' {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimEnvOverride -Issues @(4651) -EnvSet @{ CLAUDE_WORKER_PROJECT_GH_USER = 'env-project-reader' }
        $r.Out | Should -Match 'FIELDS\|4651\|.*Machine=via-env-override'
        $r.Log | Should -Match 'Identité Project \(read:project\) : env-project-reader'
        $r.Log | Should -Not -Match 'scan-scoped'
        $r.Log | Should -Not -Match [regex]::Escape($script:envToken)
    }

    It "scope 'project' (write, implies read) qualifies — po-204 measured case, 0 emission there" {
        if (-not $script:canRun) { Set-ItResult -Skipped -Because 'powershell.exe 5.1 absent'; return }
        $r = Invoke-ProjectFieldsRead -GhCmdText $script:shimWriteScope -Issues @(4651)
        $r.Out | Should -Match 'FIELDS\|4651\|.*Machine=via-active-project-scope'
        $r.Log | Should -Match 'Identité Project \(read:project\) : active-write-scope'
        $r.Log | Should -Not -Match 'INSUFFICIENT_SCOPES'
    }
}
