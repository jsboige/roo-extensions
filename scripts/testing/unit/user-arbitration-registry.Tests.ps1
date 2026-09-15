<#
.SYNOPSIS
    Guards the user-arbitration question registry contract introduced by #3656.

.DESCRIPTION
    Mandate (user, 2026-09-15): no question to user arbitration is asked mid-session.
    Questions go to a per-machine registry file, restituted in block at end of
    session, surviving cron restarts. The harness carrier is
    .claude/configs/user-global-claude.md; escalation-protocol.md level 5 must
    route through the registry now that AskUserQuestion is removed from the
    harness.
#>

Describe 'User arbitration registry contract' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
        $carrierPaths = @(
            '.claude/configs/user-global-claude.md'
        )
        $carriers = @{}
        foreach ($relativePath in $carrierPaths) {
            $carriers[$relativePath] = Get-Content (Join-Path $repoRoot $relativePath) -Raw
        }
        $script:escalation = Get-Content (Join-Path $repoRoot 'docs/harness/reference/escalation-protocol.md') -Raw
        $script:ci = Get-Content (Join-Path $repoRoot '.github/workflows/ci.yml') -Raw

        function Get-ArbitrationContractViolations {
            param([Parameter(Mandatory = $true)][string]$Text)

            $violations = @()
            if ($Text -notmatch '(?i)aucune question.+en cours de session') { $violations += 'mid-session question ban' }
            if ($Text -notmatch 'user-question-registry\.md') { $violations += 'canonical registry file name' }
            if ($Text -notmatch '(?i)par pull, pas par push') { $violations += 'pull-not-push rationale' }
            if ($Text -notmatch '(?i)restitu\w+.*en bloc') { $violations += 'block restitution' }
            if ($Text -notmatch '(?i)cycle suivant') { $violations += 'cron-cycle re-presentation' }
            if ($Text -notmatch '(?i)attendu du user') { $violations += 'expected-from-user field' }
            if ($Text -notmatch '(?i)est morte') { $violations += 'death-check field' }
            if ($Text -notmatch '(?i)repondues') { $violations += 'answered-exit section' }
            if ($Text -notmatch '(?i)scratchpad') { $violations += 'plan scratchpad' }
            if ($Text -notmatch '(?i)chemin') { $violations += 'path-not-plan rendering' }
            if ($Text -notmatch '(?i)le tag signale') { $violations += 'tag-signals wiring' }
            if ($Text -notmatch '(?i)le registre porte') { $violations += 'registry-carries-state wiring' }
            return $violations
        }
    }

    It 'enforces the complete contract in every active carrier' {
        foreach ($relativePath in $carrierPaths) {
            $violations = @(Get-ArbitrationContractViolations -Text $carriers[$relativePath])
            $violations | Should -BeNullOrEmpty -Because "$relativePath is the machine-global carrier, loaded in every workspace"
        }
    }

    It 'routes level-5 user escalation through the registry, not AskUserQuestion' {
        $escalation | Should -Match 'user-question-registry\.md' -Because 'level 5 must name the canonical registry file (#3656)'
        $escalation | Should -Not -Match '(?i)utiliser l.outil AskUserQuestion' -Because 'the tool is removed from the harness (#3656)'
        $escalation | Should -Match 'user-arbitration--registre-des-questions' -Because 'level 5 must link the detail section'
    }

    It 'makes every guarded path retrigger unit-pester on main pushes' {
        foreach ($trigger in @(
            "'.claude/configs/user-global-claude.md'",
            "'docs/harness/reference/escalation-protocol.md'"
        )) {
            $ci | Should -Match ([regex]::Escape($trigger))
        }
    }

    It 'rejects a registry entry spec without the death-check field' {
        $source = $carriers['.claude/configs/user-global-claude.md']
        $mutant = $source.Replace("comment verifier qu'elle est morte", "comment verifier qu'elle est traitee")
        $mutant | Should -Not -Be $source
        @(Get-ArbitrationContractViolations -Text $mutant) | Should -Contain 'death-check field'
    }

    It 'rejects answered questions staying in the open list' {
        $source = $carriers['.claude/configs/user-global-claude.md']
        $mutant = $source.Replace('repondues', 'archivees')
        $mutant | Should -Not -Be $source
        @(Get-ArbitrationContractViolations -Text $mutant) | Should -Contain 'answered-exit section'
    }

    It 'rejects the mid-session question ban being dropped' {
        $source = $carriers['.claude/configs/user-global-claude.md']
        $mutant = $source.Replace("aucune question a l'arbitrage user n'est posee en cours de session", 'les questions arbitrables peuvent etre posees en cours de session')
        $mutant | Should -Not -Be $source
        @(Get-ArbitrationContractViolations -Text $mutant) | Should -Contain 'mid-session question ban'
    }

    It 'rejects the escalation doc reverting to an AskUserQuestion instruction' {
        $mutant = $escalation.Replace('est retiré du harnais', 'doit etre appele : utiliser l''outil AskUserQuestion')
        $mutant | Should -Not -Be $escalation
        $mutant | Should -Match '(?i)utiliser l.outil AskUserQuestion'
    }
}
