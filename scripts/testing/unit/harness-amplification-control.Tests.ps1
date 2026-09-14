<#
.SYNOPSIS
    Guards the turn-local routing and observation contract introduced by #3647.
#>

Describe 'Harness amplification control contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $carrierPaths = @(
            '.claude/commands/coordinate.md',
            '.claude/commands/executor.md',
            '.claude/skills/executor/SKILL.md',
            '.claude/configs/user-global-claude.md'
        )
        $carriers = @{}
        foreach ($relativePath in $carrierPaths) {
            $carriers[$relativePath] = Get-Content (Join-Path $repoRoot $relativePath) -Raw
        }
        $script:ci = Get-Content (Join-Path $repoRoot '.github/workflows/ci.yml') -Raw

        function Get-AmplificationContractViolations {
            param([Parameter(Mandatory = $true)][string]$Text)

            $violations = @()
            if ($Text -match '(?i)2\s*-\s*3\s+t[aâ]ches\s+substantielles.*session\s+minimum') {
                $violations += 'numeric task quota'
            }
            if ($Text -notmatch '(?i)always-pick-next') { $violations += 'always-pick-next' }
            if ($Text -notmatch 'WAIT_FOR' -or $Text -notmatch 'RESUME_WHEN') { $violations += 'named resume condition' }
            if ($Text -notmatch '(?i)un seul observateur') { $violations += 'single observer' }
            if ($Text -notmatch '(?i)(pas de polling|aucun polling|ne (jamais poller|pas ajouter de polling))') { $violations += 'no concurrent polling' }
            if ($Text -notmatch '(?i)(cancelled|annulation)' -or
                $Text -notmatch '(?i)timeout' -or
                $Text -notmatch '(?i)terminaison inattendue') {
                $violations += 'terminal outcomes'
            }
            if ($Text -notmatch 'session_id') { $violations += 'session attribution' }
            if ($Text -notmatch '(?i)(parent_session_id|parent/sous-agent)') { $violations += 'parent/subagent attribution' }
            if ($Text -notmatch '3-5 lignes par defaut') { $violations += 'bounded communication' }
            return $violations
        }
    }

    It 'enforces the complete contract in every active carrier' {
        foreach ($relativePath in $carrierPaths) {
            $violations = @(Get-AmplificationContractViolations -Text $carriers[$relativePath])
            $violations | Should -BeNullOrEmpty -Because "$relativePath is loaded independently"
        }
    }

    It 'makes every guarded carrier retrigger unit-pester on main pushes' {
        foreach ($trigger in @(
            "'.claude/commands/**'",
            "'.claude/skills/**'",
            "'.claude/configs/user-global-claude.md'"
        )) {
            $ci | Should -Match ([regex]::Escape($trigger))
        }
    }

    It 'rejects a reintroduced numeric production quota' {
        $mutant = $carriers['.claude/commands/executor.md'] + "`nObjectif : 2-3 taches substantielles par session minimum.`n"
        @(Get-AmplificationContractViolations -Text $mutant) | Should -Contain 'numeric task quota'
    }

    It 'rejects concurrent polling in place of the single observer' {
        $source = $carriers['.claude/skills/executor/SKILL.md']
        $mutant = $source.Replace('un seul observateur', 'plusieurs observateurs')
        $mutant | Should -Not -Be $source
        @(Get-AmplificationContractViolations -Text $mutant) | Should -Contain 'single observer'
    }

    It 'rejects machine-only attribution' {
        $source = $carriers['.claude/configs/user-global-claude.md']
        $mutant = $source.Replace('session_id', 'machine_id')
        $mutant | Should -Not -Be $source
        @(Get-AmplificationContractViolations -Text $mutant) | Should -Contain 'session attribution'
    }
}
