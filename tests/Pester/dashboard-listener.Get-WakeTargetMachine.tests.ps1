#!/usr/bin/env pwsh
# Pester 5+ tests for Get-WakeTargetMachine function
# Issue #2117: Machine targeting filter for dashboard-listener WAKE-CLAUDE messages

Describe 'Get-WakeTargetMachine' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/dashboard-scheduler/dashboard-listener.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse with AST — cannot dot-source (side effects: FileSystemWatcher, exit)
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

    $fd = $funcDefs | Where-Object { $_.Name -eq 'Get-WakeTargetMachine' }
    if (-not $fd) { throw "Get-WakeTargetMachine not found in $resolvedPath" }

    $bodyText = $fd.Body.Extent.Text
    $inner = $bodyText.Substring(1, $bodyText.Length - 2)

    # Reconstruct param() block from function signature parameters
    if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
        $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
        $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
        $inner = $paramBlock + "`n" + $inner
    }

    Set-Item -Path "function:\Get-WakeTargetMachine" -Value ([ScriptBlock]::Create($inner))
}

It 'Extracts target machine from WAKE-CLAUDE message' {
    $content = '[WAKE-CLAUDE] myia-po-2023 — inactif depuis 4h23 min'
    $result = Get-WakeTargetMachine $content
    $result | Should -Be 'myia-po-2023'
}

It 'Extracts po-2024 target' {
    $content = '[WAKE-CLAUDE] myia-po-2024 — stall detection, no activity'
    $result = Get-WakeTargetMachine $content
    $result | Should -Be 'myia-po-2024'
}

It 'Extracts ai-01 target' {
    $content = '[WAKE-CLAUDE] myia-ai-01 — review required'
    $result = Get-WakeTargetMachine $content
    $result | Should -Be 'myia-ai-01'
}

It 'Extracts web1 target' {
    $content = '[WAKE-CLAUDE] myia-web1 — context explosion detected'
    $result = Get-WakeTargetMachine $content
    $result | Should -Be 'myia-web1'
}

It 'Returns null for broadcast (no target machine)' {
    $content = '[WAKE-CLAUDE] 02:01 — Stall detection active, no specific machine'
    $result = Get-WakeTargetMachine $content
    $result | Should -BeNullOrEmpty
}

It 'Returns null for content without WAKE-CLAUDE tag' {
    $content = '[ACK] myia-po-2024 — Received but wrong machine'
    $result = Get-WakeTargetMachine $content
    $result | Should -BeNullOrEmpty
}

It 'Returns null for empty content' {
    $result = Get-WakeTargetMachine ''
    $result | Should -BeNullOrEmpty
}

It 'Handles uppercase machine name in message (returns lowercase)' {
    $content = '[WAKE-CLAUDE] MYIA-PO-2023 — test uppercase'
    $result = Get-WakeTargetMachine $content
    # PowerShell -match is case-insensitive; ToLowerInvariant normalizes output
    $result | Should -Be 'myia-po-2023'
}

}
