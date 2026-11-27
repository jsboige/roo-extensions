<#
.SYNOPSIS
    Resume no longer precedes the issue claim (#4953).

.DESCRIPTION
    The Claude-Worker's resume path (Test-WaitStateReady) tested `resumeWhen`
    but never consulted check_issue_claim.py: a ready wait-state on an issue
    held by ANOTHER lane resumed anyway (measured 2026-11-27 on #4596, two
    iterations, an 11.5 MB journal for a null result). A second defect, same
    switch: the worker prompt advertises `dashboard_message`, but the regex
    only knew `intercom_message`, so such a wait-state fell to `default` and
    slept until the 7-day purge.

    These tests extract the REAL Test-WaitStateReady (and the claim verdict
    helpers) via AST -- no worker dot-source (which would run its top-level
    code and need gh/Claude), no real gh/Claude CLI -- and stub its
    dependencies. The claim guard itself is stubbed here: the contract under
    test is that Test-WaitStateReady CONSULTS it and honours its verdict. The
    real exit-code semantics are tested separately (ConvertTo-ClaimGuardBlocked).

    `dashboard_message` and the foreign-claim block are RED on main (e2801827)
    and GREEN after the fix; the positive control proves a clear issue still
    resumes.

.NOTES
    Pester 5+, Windows PowerShell 5.1. ASCII-only on purpose (PS 5.1 decodes a
    BOM-less file with the active code page; plain ASCII cannot mis-decode).
#>

# Bound data for `It -ForEach`: MUST be at file scope (Pester reads it during
# DISCOVERY, before BeforeAll runs).
$script:ExitCases = @(
    @{ code = 0; blocked = $false; label = 'exit 0 (clear)' }
    @{ code = 1; blocked = $true;  label = 'exit 1 (foreign claim / closed issue)' }
    @{ code = 2; blocked = $true;  label = 'exit 2 (instrument unreadable)' }
    @{ code = 3; blocked = $true;  label = 'exit 3 (repo ambiguity)' }
)

Describe 'Worker resume honours the issue claim (#4953)' {

    BeforeAll {
        $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:WorkerScript = Join-Path $projectRoot 'scripts/scheduling/start-claude-worker.ps1'

        $tokens = $null; $errors = $null
        $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WorkerScript, [ref]$tokens, [ref]$errors)
        $script:ParseErrors = $errors

        function Get-FnText([string]$Name) {
            $fn = $script:Ast.FindAll({
                param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                          $n.Name -eq $Name
            }, $true) | Select-Object -First 1
            if ($fn) { return $fn.Extent.Text }
            return ''
        }

        # Dot-source only the pure helpers and the function under test; the
        # worker's top-level code never runs.
        foreach ($name in @('Get-WaitStateIssueNumber', 'ConvertTo-ClaimGuardBlocked', 'Test-WaitStateReady')) {
            $text = Get-FnText $name
            if ($text) { . ([scriptblock]::Create($text)) }
        }
        $script:HasWaitStateReady = [bool](Get-FnText 'Test-WaitStateReady')

        # Isolated wait-states directory: Test-WaitStateReady reads
        # "$RepoRoot\.claude\scheduler\wait-states\$TaskId.json".
        $script:RepoRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("worker-resume-claim-guard-" + [guid]::NewGuid().ToString('N'))
        $script:WaitStatesDir = Join-Path $script:RepoRoot '.claude\scheduler\wait-states'
        New-Item -ItemType Directory -Path $script:WaitStatesDir -Force | Out-Null

        # Per-test switches read by the stubs below.
        $script:ClaimBlocked   = $false
        $script:GitHubReady    = $false
        $script:DashboardReady = $false

        # ---- Dependencies stubbed in this scope (inherited by the extracted function) ----
        function Write-Log { param([string]$Message, [string]$Level = 'INFO') }
        function Remove-WaitState {
            param([string]$TaskId)
            $f = Join-Path $script:WaitStatesDir "$TaskId.json"
            if (Test-Path $f) { Remove-Item $f -Force }
        }
        function Get-IssueDetail {
            param($Repo, $Number)
            [pscustomobject]@{ Ok = $true; Item = [pscustomobject]@{ state = 'OPEN' } }
        }
        function Test-UserApproval       { param($TaskId, $WaitState) return $false }
        function Test-RooSyncResponse    { param($TaskId, $WaitState) return $false }
        function Test-GitHubDecision     { param($TaskId, $WaitState) return $script:GitHubReady }
        function Test-DashboardMessage    { param($TaskId, $WaitState) return $script:DashboardReady }
        # Stubbed deliberately: the contract is that Resume CONSULTS this guard
        # and honours its verdict. Real exit-code semantics are covered below.
        function Test-IssueClaimBlocksResume { param([string]$TaskId) return $script:ClaimBlocked }

        function New-WaitStateFile {
            param([string]$TaskId, [string]$ResumeWhen)
            $obj = @{
                taskId     = $TaskId
                timestamp  = (Get-Date).ToUniversalTime().ToString('o')
                reason     = 'REASON-SENTINEL'
                waitFor    = 'WAITFOR-SENTINEL'
                resumeWhen = $ResumeWhen
                context    = @{ mode = 'mode-SENTINEL'; model = 'model-SENTINEL'; iteration = 1; outputSnippet = 'SNIP' }
            }
            $file = Join-Path $script:WaitStatesDir "$TaskId.json"
            [System.IO.File]::WriteAllText($file, ($obj | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
            return $file
        }
    }

    AfterAll {
        if ($script:RepoRoot -and (Test-Path $script:RepoRoot)) {
            Remove-Item -Path $script:RepoRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Parses the worker script without syntax errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'Extracts and defines the real Test-WaitStateReady function' {
        $script:HasWaitStateReady | Should -BeTrue
    }

    Context 'A ready wait-state whose issue is held elsewhere is NOT resumed' {

        It 'Skips the resume and KEEPS the wait-state (red on main, green after)' {
            $script:GitHubReady  = $true
            $script:ClaimBlocked = $true
            $taskId = 'github-4596'
            $file = New-WaitStateFile -TaskId $taskId -ResumeWhen 'github_comment'

            $result = Test-WaitStateReady -TaskId $taskId

            $result | Should -BeNullOrEmpty          # not resumed
            (Test-Path $file) | Should -BeTrue        # wait-state survives the pass
        }

        It 'Positive control: a clear issue resumes as before' {
            $script:GitHubReady  = $true
            $script:ClaimBlocked = $false
            $taskId = 'github-4596'
            $file = New-WaitStateFile -TaskId $taskId -ResumeWhen 'github_comment'

            $result = Test-WaitStateReady -TaskId $taskId

            $result | Should -Not -BeNullOrEmpty
            $result.reason | Should -Be 'REASON-SENTINEL'
            (Test-Path $file) | Should -BeTrue        # readiness does not consume it here
        }
    }

    Context 'dashboard_message reaches the dashboard condition' {

        It 'Is recognised instead of falling to the unknown-condition default (red on main, green after)' {
            $script:DashboardReady = $true
            $script:ClaimBlocked   = $false
            $taskId = 'dashboard-xyz'                 # non-issue task: no claim lookup
            New-WaitStateFile -TaskId $taskId -ResumeWhen 'dashboard_message' | Out-Null

            $result = Test-WaitStateReady -TaskId $taskId

            $result | Should -Not -BeNullOrEmpty
            $result.reason | Should -Be 'REASON-SENTINEL'
        }

        It 'intercom_message still reaches the same condition' {
            $script:DashboardReady = $true
            $script:ClaimBlocked   = $false
            $taskId = 'dashboard-xyz'
            New-WaitStateFile -TaskId $taskId -ResumeWhen 'intercom_message' | Out-Null

            (Test-WaitStateReady -TaskId $taskId) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Claim verdict is fail-closed (only exit 0 clears)' {

        It 'ConvertTo-ClaimGuardBlocked maps <label> to blocked=<blocked>' -ForEach $script:ExitCases {
            ConvertTo-ClaimGuardBlocked -ExitCode $_.code | Should -Be $_.blocked
        }
    }

    Context 'Issue number extraction from wait-state task ids' {

        It 'reads github-N and issue-N, ignores non-issue ids' {
            (Get-WaitStateIssueNumber -TaskId 'github-4596') | Should -Be 4596
            (Get-WaitStateIssueNumber -TaskId 'issue-12')    | Should -Be 12
            (Get-WaitStateIssueNumber -TaskId 'dashboard-x') | Should -BeNullOrEmpty
            (Get-WaitStateIssueNumber -TaskId 'fallback-maintenance') | Should -BeNullOrEmpty
        }
    }

    Context 'Structural guard' {

        It 'Test-WaitStateReady consults the claim guard (red on main, green after)' {
            (Get-FnText 'Test-WaitStateReady') | Should -Match 'Test-IssueClaimBlocksResume'
        }
    }
}
