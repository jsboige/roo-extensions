#!/usr/bin/env pwsh
# Pester 5+ tests for the idle queue picker (start-vibe-worker.ps1, 06/09 lane
# pérenne — GO user). Contract: a scheduled tick without a WAKE payload picks
# the oldest open <label> issue from the profile's queue and injects it as
# VIBE_WAKE_PAYLOAD (JSON {content}); guards = daily cap + same-issue retry
# delay; no queue configured or empty pool => $false (historical SKIP).

Describe 'Vibe worker idle queue picker' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/scheduling/start-vibe-worker.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse with AST — cannot dot-source (side effects: lock, heartbeat, exit)
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    $funcDefs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    )

    foreach ($name in @('Get-QueueState', 'Save-QueueState', 'Invoke-IdleQueuePick')) {
        $fd = $funcDefs | Where-Object { $_.Name -eq $name }
        if (-not $fd) { throw "$name not found in $resolvedPath" }
        $bodyText = $fd.Body.Extent.Text
        $inner = $bodyText.Substring(1, $bodyText.Length - 2)
        if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
            $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
            $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
            $inner = $paramBlock + "`n" + $inner
        }
        Set-Item -Path "function:\$name" -Value ([ScriptBlock]::Create($inner))
    }

    # Script-level dependencies resolved dynamically by the extracted functions.
    function Write-Log { param([string]$Message, [string]$Level = "INFO") $script:pickerLog += "$Message`n" }
    $script:pickerLog = ''
    $script:QueueRetrySameIssueHours = 6
    $script:TestStateDir = Join-Path ([System.IO.Path]::GetTempPath()) ("vibe-picker-tests-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $script:TestStateDir -Force | Out-Null
    $script:QueueStateDir = $script:TestStateDir
    $script:Workspace = 'CoursIA'
}

BeforeEach {
    $script:pickerLog = ''
    $env:VIBE_WAKE_PAYLOAD = $null
    # Fresh profile: queue enabled, cap 2/day
    $script:profileObj = '{"queue":{"repo":"jsboige/CoursIA","label":"vibe-target","maxIdleRunsPerDay":2}}' | ConvertFrom-Json
    # Fresh state: none
    Remove-Item (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -Force -ErrorAction SilentlyContinue
}

AfterAll {
    Remove-Item $script:TestStateDir -Recurse -Force -ErrorAction SilentlyContinue
}

It 'Returns false (historical SKIP) when the profile has no queue — and never calls gh' {
    $script:profileObj = '{}' | ConvertFrom-Json
    Mock gh { throw 'gh must not be called without a queue configured' }
    Invoke-IdleQueuePick | Should -Be $false
}

It 'Returns false when the pool is empty' {
    Mock gh { '[]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:pickerLog | Should -Not -Match '\[PICK\]'
}

It 'Picks the OLDEST issue and injects a JSON {content} payload' {
    $newer = '2026-09-06T10:00:00Z'
    $older = '2026-09-01T10:00:00Z'
    Mock gh { '[{"number":41,"title":"Newer target","body":"Body N","updatedAt":"' + $newer + '"},{"number":7,"title":"Older target","body":"Body O","updatedAt":"' + $older + '"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $env:VIBE_WAKE_PAYLOAD | Should -Not -BeNullOrEmpty
    $payload = $env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json
    $payload.content | Should -Match 'Issue #7: Older target'
    $payload.content | Should -Not -Match 'Issue #41'
    $script:pickerLog | Should -Match '\[PICK\] idle-picker: issue #7'
}

It 'Writes picker state (idleRuns=1, lastIssueNumber) on a successful pick' {
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
    $statePath = Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json'
    Test-Path $statePath | Should -Be $true
    $st = Get-Content $statePath -Raw | ConvertFrom-Json
    $st.idleRuns | Should -Be 1
    $st.lastIssueNumber | Should -Be 7
}

It 'Skips when the daily cap is reached (no gh call)' {
    $today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $today; idleRuns = 2; lastIssueNumber = 7; lastRunAt = '2026-01-01T00:00:00.0000000Z' }
    Mock gh { throw 'gh must not be called once the daily cap is reached' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:pickerLog | Should -Match 'daily cap reached \(2/2\)'
}

It 'Skips the same issue re-picked inside the retry window (anti-hammer)' {
    $now = (Get-Date).ToUniversalTime()
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $now.ToString('yyyy-MM-dd'); idleRuns = 1; lastIssueNumber = 7; lastRunAt = $now.AddHours(-1).ToString('o') }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $false
    $script:pickerLog | Should -Match 'already picked'
}

It 'Re-picks the same issue once the retry window has expired' {
    $now = (Get-Date).ToUniversalTime()
    Save-QueueState -Path (Join-Path $script:TestStateDir 'vibe-queue-CoursIA.json') -State @{ date = $now.ToString('yyyy-MM-dd'); idleRuns = 1; lastIssueNumber = 7; lastRunAt = $now.AddHours(-7).ToString('o') }
    Mock gh { '[{"number":7,"title":"T","body":"B","updatedAt":"2026-09-01T10:00:00Z"}]' }
    Invoke-IdleQueuePick | Should -Be $true
}

It 'Truncates an oversized issue body to keep the payload bounded' {
    $bigBody = ('x' * 5000)
    Mock gh { ('[{"number":7,"title":"T","body":"' + $bigBody + '","updatedAt":"2026-09-01T10:00:00Z"}]') }
    Invoke-IdleQueuePick | Should -Be $true
    $payload = $env:VIBE_WAKE_PAYLOAD | ConvertFrom-Json
    $payload.content.Length | Should -BeLessThan 4400
}
}
