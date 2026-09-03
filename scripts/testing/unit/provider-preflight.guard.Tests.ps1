<#
.SYNOPSIS
    Guard test: provider-preflight.ps1 must keep its #3361 contracts (probe, diagnostic, no secret leak).

.DESCRIPTION
    provider-preflight.ps1 is the repo-side answer to the remaining #3361 acceptance criteria:
    a provider health check usable BEFORE a sub-agent fan-out, with an actionable diagnostic
    naming the config to fix when the provider answers 401/402/403 (the incident codes), and
    visibility (never silence) when a role maps to a native-Anthropic ID through the hub.

    This is a STRUCTURAL guard (AST + content): the unit CI must not perform network calls.
    It asserts:
      - the script parses,
      - the 401/402/403 classification exists,
      - the diagnostic names the settings keys (ANTHROPIC_BASE_URL / ANTHROPIC_AUTH_TOKEN)
        and the remediation command (Switch-Provider.ps1 -Provider claudish),
      - the fleet policy note (no native Anthropic on executors) is present,
      - the exit-code contract (0 healthy, 2 auth/billing, 3 unreachable, 4 routing mismatch),
      - the token is never echoed (no Write-* command interpolates $token / $apiKey).

.NOTES
    Issue #3361
    Requires Pester 5+
#>

Describe 'provider-preflight guard (#3361)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\provider-preflight.ps1'
        $content = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Classifies the incident codes 401/402/403 as auth/billing failures' {
        $content | Should -Match '401,\s*402,\s*403'
        $content | Should -Match '402'
    }

    It 'Names the settings keys in the diagnostic (config to fix is named, not just the provider)' {
        $content | Should -Match 'env\.ANTHROPIC_BASE_URL'
        $content | Should -Match 'env\.ANTHROPIC_AUTH_TOKEN'
    }

    It 'Gives the remediation: Switch-Provider.ps1 -Provider claudish' {
        $content | Should -Match 'Switch-Provider\.ps1 -Provider claudish'
    }

    It 'States the fleet policy: no native Anthropic on executor machines' {
        $content | Should -Match 'native Anthropic to myia-ai-01'
    }

    It 'Keeps the exit-code contract (0/2/3/4 documented and implemented)' {
        foreach ($code in 0, 2, 3, 4) {
            $content | Should -Match ("exit {0}" -f $code)
        }
    }

    It 'Detects the #3361 wildcard signature (model ID not in the routable list)' {
        $content | Should -Match 'NOT LISTED'
        $content | Should -Match 'wildcard'
    }

    It 'Never echoes the token (no Write-* command interpolates the token variable)' {
        # Collect every Write-* / Out-* command argument that contains a $token/$apiKey
        # variable reference - a leak would show up here.
        $leaks = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.CommandAst] -and
                ($n.GetCommandName() -like 'Write-*' -or $n.GetCommandName() -like 'Out-*')
            }, $true) | ForEach-Object {
            $_.FindAll({
                    param($m)
                    $m -is [System.Management.Automation.Language.VariableExpressionAst] -and
                        $m.VariablePath.UserPath -match '^(token|apiKey)$'
                }, $true)
        }
        @($leaks).Count | Should -Be 0
    }
}
