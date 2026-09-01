<#
.SYNOPSIS
    Guard test: sync-claude-settings.ps1 must NOT clobber role-model mapping keys (#3361).

.DESCRIPTION
    sync-claude-settings.ps1 harmonizes ~/.claude/settings.json across the fleet. The
    ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU,FABLE}_MODEL* keys (and their *_NAME/_DESCRIPTION
    metadata) are MACHINE/PROVIDER choices set by Switch-Provider.ps1 from the
    provider.claudish/zai templates (e.g. sonnet -> glm-5.1 on an executor).

    Before #3361 these keys were NOT in $OnlyIfAbsent, so the harmonizer overwrote a correct
    provider mapping (glm-5.1) with a native-Anthropic model ID (claude-sonnet-5[1m]). The hub
    then routed that ID via its '*' rule to an unprovisioned provider (Mistral) -> HTTP 402,
    breaking every Agent(..., model="sonnet") fan-out on the machine.

    This test asserts the invariant: the role-model keys are protected (only bootstrapped when
    absent, never overwritten). It fails BEFORE the fix and passes AFTER.

.NOTES
    Issue #3361
    Requires Pester 5+ and PowerShell 7+
#>

Describe 'sync-claude-settings protected model keys (#3361)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\scripts\deployment\sync-claude-settings.ps1'
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

        # Extract the string literals of the $OnlyIfAbsent array assignment. The RHS is
        # a CommandExpressionAst wrapping the array, so collect its string-literal descendants.
        $protected = @()
        $assigns = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $n.Left.VariablePath.UserPath -eq 'OnlyIfAbsent'
            }, $true)
        foreach ($a in $assigns) {
            $strings = $a.Right.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.StringConstantExpressionAst]
                }, $true)
            foreach ($s in $strings) {
                $protected += $s.Value
            }
        }
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Finds a non-empty $OnlyIfAbsent list' {
        $protected.Count | Should -BeGreaterThan 0
    }

    # The role-model mapping keys (+ metadata) are machine/provider choices and must never be
    # overwritten by an harmonizer reference value. Use -TestCases to bind $key per-iteration
    # (a foreach + closure would see a stale $key in Pester).
    $roleModelKeys = @(
        'ANTHROPIC_DEFAULT_OPUS_MODEL',
        'ANTHROPIC_DEFAULT_OPUS_MODEL_NAME',
        'ANTHROPIC_DEFAULT_OPUS_MODEL_DESCRIPTION',
        'ANTHROPIC_DEFAULT_SONNET_MODEL',
        'ANTHROPIC_DEFAULT_SONNET_MODEL_NAME',
        'ANTHROPIC_DEFAULT_SONNET_MODEL_DESCRIPTION',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL_NAME',
        'ANTHROPIC_DEFAULT_HAIKU_MODEL_DESCRIPTION',
        'ANTHROPIC_DEFAULT_FABLE_MODEL',
        'ANTHROPIC_DEFAULT_FABLE_MODEL_NAME',
        'ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION'
    )
    foreach ($key in $roleModelKeys) {
        It "Protects '<key>' from clobbering" -TestCases @{ key = $key } {
            param($key)
            $protected -contains $key | Should -BeTrue
        }
    }

    # Explicit regression assertion for the reported defect.
    It "Protects ANTHROPIC_DEFAULT_SONNET_MODEL so sonnet follows the machine routing policy" {
        $protected -contains 'ANTHROPIC_DEFAULT_SONNET_MODEL' | Should -BeTrue
    }

    It 'Does NOT protect ANTHROPIC_AUTH_TOKEN (token handling is a separate concern)' {
        # Guard against over-broadening: an empty reference token must still be reconcilable.
        $protected -contains 'ANTHROPIC_AUTH_TOKEN' | Should -BeFalse
    }
}
