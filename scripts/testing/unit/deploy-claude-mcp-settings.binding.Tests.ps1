# Pester tests: parameter binding of scripts/deployment/deploy-claude-mcp-settings.ps1
#
# FRICTION myia-po-2023 (14/11/2026): the script had a plain param() block, so an
# unknown parameter such as -DryRun landed silently in $args and the REAL deploy
# ran (~/.claude.json rewritten, runtimes installed). These tests never execute
# the deploy body: they rebuild a script block from the script's own param block
# (attributes included) and bind arguments against it. If the guard regresses,
# the binding succeeds instead of throwing, and nothing is deployed either way.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/deploy-claude-mcp-settings.binding.Tests.ps1 -Output Detailed"

BeforeAll {
    $script:repoRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $script:deployScript = Join-Path $repoRoot 'scripts/deployment/deploy-claude-mcp-settings.ps1'

    $tokens = $null
    $errors = $null
    $script:ast = [System.Management.Automation.Language.Parser]::ParseFile($deployScript, [ref]$tokens, [ref]$errors)
    $script:parseErrors = $errors

    # Param block WITH its attributes, then echo the bound parameters. The
    # ParamBlockAst extent starts at the `param` keyword, so the source is cut
    # from the first attribute's offset (measured: the extent alone dropped
    # [CmdletBinding()] and the unknown parameter bound silently). -MachineId is
    # always passed so the default expression ($env:COMPUTERNAME, absent on
    # Linux runners) is never evaluated.
    $pb = $ast.ParamBlock
    $start = $pb.Extent.StartOffset
    foreach ($a in $pb.Attributes) {
        if ($a.Extent.StartOffset -lt $start) { $start = $a.Extent.StartOffset }
    }
    $source = $ast.Extent.Text
    $paramText = $source.Substring($start, $pb.Extent.EndOffset - $start)
    $script:binder = [scriptblock]::Create("$paramText`n`$PSBoundParameters")
}

Describe 'deploy-claude-mcp-settings.ps1 — strict parameter binding' {

    It 'parses without errors' {
        $parseErrors.Count | Should -Be 0
    }

    It 'declares [CmdletBinding()] on its param block' {
        $names = $ast.ParamBlock.Attributes | ForEach-Object { $_.TypeName.Name }
        $names | Should -Contain 'CmdletBinding'
    }

    It 'rejects an unknown parameter instead of running' {
        { & $binder -MachineId 'test-seat' -NoSuchParameter } | Should -Throw -ErrorId 'NamedParameterNotFound*'
    }

    It 'binds -DryRun to WhatIf' {
        $bound = & $binder -MachineId 'test-seat' -DryRun
        $bound['WhatIf'].IsPresent | Should -BeTrue
    }

    It 'still binds -WhatIf directly' {
        $bound = & $binder -MachineId 'test-seat' -WhatIf
        $bound['WhatIf'].IsPresent | Should -BeTrue
    }
}
