<#
.SYNOPSIS
    Pester tests for Get-WakeTargetMachine and Get-WakeTargetWorkspace (#2240).

.DESCRIPTION
    Tests the wake routing patterns:
      - machine-only: [WAKE-CLAUDE] myia-po-2023 → machine matched, workspace null
      - machine+workspace: [WAKE-CLAUDE] myia-po-2025:roo-extensions → both matched
      - arrow prefix: [WAKE-CLAUDE] → myia-po-2026:Embeddings → both matched
      - header markdown: ## [WAKE-CLAUDE] myia-po-2025:claudish → both matched
      - prose inline (backtick-quoted): no match (preserved)

.NOTES
    Issue #2240
    Requires Pester 5+ and PowerShell 7+
#>

Describe 'Get-WakeTargetMachine' {
    BeforeAll {
        function Get-WakeTargetMachine($content) {
            if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*(myia-[a-z0-9]+(?:-[a-z0-9]+)*)(?::([a-zA-Z0-9_.-]+))?') {
                return $Matches[1].ToLowerInvariant()
            }
            return $null
        }
    }

    It 'Matches machine-only pattern' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] myia-po-2023' | Should -Be 'myia-po-2023'
    }

    It 'Matches machine with :workspace suffix' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] myia-po-2025:roo-extensions' | Should -Be 'myia-po-2025'
    }

    It 'Matches arrow prefix variant' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] → myia-po-2026:Embeddings' | Should -Be 'myia-po-2026'
    }

    It 'Matches ASCII arrow prefix variant' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] -> myia-po-2026:Embeddings' | Should -Be 'myia-po-2026'
    }

    It 'Matches header markdown variant' {
        Get-WakeTargetMachine '## [WAKE-CLAUDE] myia-po-2025:claudish' | Should -Be 'myia-po-2025'
    }

    It 'Matches with trailing dash and text' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] myia-po-2023 — urgent task' | Should -Be 'myia-po-2023'
    }

    It 'Returns null for prose inline (backtick-quoted)' {
        Get-WakeTargetMachine 'the `[WAKE-CLAUDE]` myia-po-2025 pattern' | Should -BeNullOrEmpty
    }

    It 'Returns null when no WAKE-CLAUDE tag present' {
        Get-WakeTargetMachine 'just a regular message' | Should -BeNullOrEmpty
    }

    It 'Matches machine-only with workspace present (machine extraction ignores workspace)' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] myia-po-2025:roo-extensions — check this' | Should -Be 'myia-po-2025'
    }

    It 'Returns lowercase machine ID regardless of input case' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] MYIA-PO-2023' | Should -Be 'myia-po-2023'
    }

    It 'Returns null for invalid machine name format' {
        Get-WakeTargetMachine '[WAKE-CLAUDE] invalid-machine' | Should -BeNullOrEmpty
    }
}

Describe 'Get-WakeTargetWorkspace' {
    BeforeAll {
        function Get-WakeTargetWorkspace($content) {
            if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*myia-[a-z0-9]+(?:-[a-z0-9]+)*:([a-zA-Z0-9_.-]+)') {
                return $Matches[1]
            }
            return $null
        }
    }

    It 'Returns null when no workspace suffix' {
        Get-WakeTargetWorkspace '[WAKE-CLAUDE] myia-po-2025' | Should -BeNullOrEmpty
    }

    It 'Extracts workspace from machine:workspace pattern' {
        Get-WakeTargetWorkspace '[WAKE-CLAUDE] myia-po-2025:roo-extensions' | Should -Be 'roo-extensions'
    }

    It 'Extracts workspace with arrow prefix' {
        Get-WakeTargetWorkspace '[WAKE-CLAUDE] → myia-po-2026:Embeddings' | Should -Be 'Embeddings'
    }

    It 'Extracts workspace from header markdown' {
        Get-WakeTargetWorkspace '## [WAKE-CLAUDE] myia-po-2025:claudish' | Should -Be 'claudish'
    }

    It 'Preserves workspace case' {
        Get-WakeTargetWorkspace '[WAKE-CLAUDE] myia-po-2025:MyWorkspace' | Should -Be 'MyWorkspace'
    }

    It 'Handles workspace with dots and underscores' {
        Get-WakeTargetWorkspace '[WAKE-CLAUDE] myia-po-2025:my.project_v2' | Should -Be 'my.project_v2'
    }

    It 'Returns null for prose inline (backtick-quoted)' {
        Get-WakeTargetWorkspace 'the `[WAKE-CLAUDE]` myia-po-2025:roo-extensions pattern' | Should -BeNullOrEmpty
    }
}

Describe 'Workspace filtering in wake routing' {
    It 'Broadcast message (no workspace) should match any local workspace' {
        $content = '[WAKE-CLAUDE] myia-po-2025'
        $targetWs = if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*myia-[a-z0-9]+(?:-[a-z0-9]+)*:([a-zA-Z0-9_.-]+)') { $Matches[1] } else { $null }
        $targetWs | Should -BeNullOrEmpty
        # null workspace = broadcast, so always passes workspace filter
        ($null -eq $targetWs -or $targetWs -eq 'roo-extensions') | Should -BeTrue
    }

    It 'Targeted workspace matches local workspace' {
        $content = '[WAKE-CLAUDE] myia-po-2025:roo-extensions'
        $targetWs = if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*myia-[a-z0-9]+(?:-[a-z0-9]+)*:([a-zA-Z0-9_.-]+)') { $Matches[1] } else { $null }
        $targetWs | Should -Be 'roo-extensions'
        ($null -eq $targetWs -or $targetWs -eq 'roo-extensions') | Should -BeTrue
    }

    It 'Targeted workspace does NOT match different local workspace' {
        $content = '[WAKE-CLAUDE] myia-po-2025:claudish'
        $targetWs = if ($content -match '\[WAKE-CLAUDE\]\s*(?:→|->)?\s*myia-[a-z0-9]+(?:-[a-z0-9]+)*:([a-zA-Z0-9_.-]+)') { $Matches[1] } else { $null }
        $targetWs | Should -Be 'claudish'
        ($null -eq $targetWs -or $targetWs -eq 'roo-extensions') | Should -BeFalse
    }
}
