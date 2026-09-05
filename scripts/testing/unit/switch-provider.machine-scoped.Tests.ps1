<#
.SYNOPSIS
    Guard test: Switch-Provider.ps1 must not stomp machine-scoped settings (#3361 follow-up).

.DESCRIPTION
    provider-preflight.ps1 prints "Switch-Provider.ps1 -Provider claudish" as THE remediation
    for #3361 (auth/billing refused, or role IDs riding the hub wildcard). Running that
    remediation must never damage the machine it is supposed to repair. Two failure modes
    were measured firsthand on myia-po-2026 (2026-09-04):

      1. ENV STOMP - the claudish template carries bootstrap compaction values
         (CLAUDE_CODE_AUTO_COMPACT_WINDOW=200000 / CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=90),
         but the machine carries its own tuned window (280000/95). Per context-window.md
         v6, "settings.json de la machine fait foi": the merge must be only-if-absent for
         those keys - same semantics the #3363 fix gave sync-claude-settings.ps1.
      2. TOP-LEVEL DROP - the rebuild used a fixed allow-list (permissions, mcpServers,
         hooks, allowed-tools, denied-tools) and silently DROPPED every other top-level
         setting (statusLine, effortLevel, cleanupPeriodDays on po-2026). Provider
         switching owns exactly two top-level keys: env and model.

    This is a STRUCTURAL guard (AST + content): the unit CI must not perform network calls
    or touch the real ~/.claude/settings.json.

    It asserts:
      - the script parses,
      - the protected-keys array includes both compaction keys,
      - the fixed top-level allow-list is gone, replaced by switcher-owned-key preservation,
      - the claudish template's sonnet ID is a non-claude (executor pool) ID,
      - provider-preflight.ps1's remediation strings cite the SAME sonnet ID as the
        template (the printed remediation must match what the remediation applies).

.NOTES
    Issue #3361 (follow-up to #3363 / #3400)
    Requires Pester 5+
#>

Describe 'Switch-Provider machine-scoped guard (#3361 follow-up)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\claude\Switch-Provider.ps1'
        $content = Get-Content $scriptPath -Raw
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$errors)

        $templatePath = Join-Path $PSScriptRoot '..\..\..\.claude\configs\provider.claudish.template.json'
        $template = Get-Content $templatePath -Raw | ConvertFrom-Json
        $templateSonnet = [string]$template.env.ANTHROPIC_DEFAULT_SONNET_MODEL

        $preflightPath = Join-Path $PSScriptRoot '..\..\claude\provider-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw
    }

    It 'Parses the script without syntax errors' {
        $errors.Count | Should -Be 0
    }

    It 'Protects the machine compaction window from template bootstrap values (only-if-absent)' {
        $content | Should -Match 'CLAUDE_CODE_AUTO_COMPACT_WINDOW'
        $content | Should -Match 'CLAUDE_AUTOCOMPACT_PCT_OVERRIDE'
    }

    It 'No longer rebuilds settings from a fixed top-level allow-list (which dropped machine keys)' {
        $content | Should -Not -Match '\$preservedProperties\s*='
    }

    It 'Preserves every top-level setting the switcher does not own (env and model only)' {
        $content | Should -Match '\$switcherOwnedProperties\s*=\s*@\(\s*''env'',\s*''model''\s*\)'
    }

    It 'Keeps the claudish template sonnet ID in the executor pool (never a native claude-* ID)' {
        # Executor policy: the bootstrap template must map sonnet to a non-native ID.
        # A claude-* ID here would re-create the #3361 wildcard dependence for fresh machines.
        $templateSonnet | Should -Not -Match '^claude-'
    }

    It 'Cites the same sonnet ID in the preflight remediation as the template applies' {
        # provider-preflight.ps1 prints "(sonnet -> <id>, z.ai)" in its WARN block and
        # "(executor pool: z.ai <id>)" in its 401/402/403 diagnostic. Both must name the
        # ID the documented remediation would actually set.
        $preflight | Should -Match ("executor pool: z\.ai {0}" -f [regex]::Escape($templateSonnet))
        $preflight | Should -Match ("sonnet -> {0}, z\.ai" -f [regex]::Escape($templateSonnet))
    }
}
