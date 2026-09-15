<#
.SYNOPSIS
    Regression coverage for targeted WAKE-CLAUDE routing (#3647).

.DESCRIPTION
    Extracts the production parsers by AST. A multi-tag instruction used in the
    live dashboard (`[WAKE-CLAUDE][TASK] machine:workspace`) previously returned
    null for both fields, which the listener interprets as broadcast.
#>

Describe 'Dashboard listener targeted wake routing' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $listenerPath = Join-Path $repoRoot 'scripts/dashboard-scheduler/dashboard-listener.ps1'
        $parseErrors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $listenerPath,
            [ref]$tokens,
            [ref]$parseErrors
        )
        @($parseErrors) | Should -BeNullOrEmpty

        foreach ($name in @('Get-WakeTargetMachine', 'Get-WakeTargetWorkspace')) {
            $definition = $ast.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
                },
                $true
            ) | Where-Object Name -EQ $name | Select-Object -First 1
            if (-not $definition) { throw "$name not found in $listenerPath" }

            $body = $definition.Body.Extent.Text
            $inner = $body.Substring(1, $body.Length - 2)
            $parameters = $definition.Parameters | ForEach-Object {
                '$' + $_.Name.VariablePath.UserPath
            }
            if ($parameters.Count -gt 0) {
                $inner = 'param(' + ($parameters -join ', ') + ")`n" + $inner
            }
            Set-Item -Path "function:\$name" -Value ([ScriptBlock]::Create($inner))
        }
    }

    It 'routes the documented single-tag machine and workspace form' {
        $content = '[WAKE-CLAUDE] myia-po-2026:roo-extensions'
        Get-WakeTargetMachine $content | Should -Be 'myia-po-2026'
        Get-WakeTargetWorkspace $content | Should -Be 'roo-extensions'
    }

    It 'routes a Markdown header with one intermediate tag' {
        $content = '## [WAKE-CLAUDE][TASK] myia-po-2026:roo-extensions'
        Get-WakeTargetMachine $content | Should -Be 'myia-po-2026'
        Get-WakeTargetWorkspace $content | Should -Be 'roo-extensions'
    }

    It 'routes multiple intermediate tags and an arrow' {
        $content = '### [WAKE-CLAUDE][FOLLOW-UP][REVIEW] -> myia-po-2025:CoursIA'
        Get-WakeTargetMachine $content | Should -Be 'myia-po-2025'
        Get-WakeTargetWorkspace $content | Should -Be 'CoursIA'
    }

    It 'routes a targeted instruction after unrelated lines' {
        $content = "Context only`n[WAKE-CLAUDE][DEEP-QUEUE] → MYIA-PO-2023:IISManagement"
        Get-WakeTargetMachine $content | Should -Be 'myia-po-2023'
        Get-WakeTargetWorkspace $content | Should -Be 'IISManagement'
    }

    It 'keeps an explicit broadcast without a machine untargeted' {
        $content = '[WAKE-CLAUDE][TASK] 02:01 — fleet coordination'
        Get-WakeTargetMachine $content | Should -BeNullOrEmpty
        Get-WakeTargetWorkspace $content | Should -BeNullOrEmpty
    }

    It 'does not route a prose citation of the tag' {
        $content = 'The `[WAKE-CLAUDE][TASK] myia-po-2026:roo-extensions` form is documented.'
        Get-WakeTargetMachine $content | Should -BeNullOrEmpty
        Get-WakeTargetWorkspace $content | Should -BeNullOrEmpty
    }
}
