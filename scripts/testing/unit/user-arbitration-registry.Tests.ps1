<#
.SYNOPSIS
    Guards the user-arbitration question registry contract introduced by #3656,
    extended by the intermediate-replies subsection (#3879, mandate 2026-09-26).

.DESCRIPTION
    Mandate (user, 2026-09-15): no question to user arbitration is asked mid-session.
    Questions go to a per-machine registry file, restituted in block at end of
    session, surviving cron restarts. The harness carrier is
    .claude/configs/user-global-claude.md; escalation-protocol.md level 5 must
    route through the registry now that AskUserQuestion is removed from the
    harness.

    Mandate (user, 2026-09-26): the registry covers agent-to-user questions.
    When the USER opens an exchange mid-session, they get early visible replies
    with initial belief levels -- measured same day: three progress replies
    stayed in reasoning, the user read silence. The verified conclusion stays
    for the final message. The subsection landed in #3879 (ported from
    jsboige/CoursIA#17955) and is guarded here so a future slim pass cannot
    drop it silently.
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
            # #3879 -- intermediate-replies subsection (mandate 2026-09-26). The
            # patterns carry the accents the source carries.
            if ($Text -notmatch 'réponses intermédiaires') { $violations += 'intermediate-replies subsection' }
            if ($Text -notmatch 'niveau de croyance') { $violations += 'initial-belief-level' }
            if ($Text -notmatch 'texte visible') { $violations += 'visible-text form' }
            if ($Text -notmatch 'sans clore le tour') { $violations += 'turn-not-closed form' }
            if ($Text -notmatch 'relancer un user silencieux') { $violations += 'silent-user-no-reping' }
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

    It 'rejects the intermediate-replies subsection being dropped (#3879)' {
        # A future slim pass rewriting "User Arbitration" could drop the
        # mandate-26/09 subsection wholesale; the guard must bite on its most
        # load-bearing phrase, not just on the heading.
        $source = $carriers['.claude/configs/user-global-claude.md']
        $mutant = $source.Replace('relancer un user silencieux', 'relancer le user')
        $mutant | Should -Not -Be $source
        @(Get-ArbitrationContractViolations -Text $mutant) | Should -Contain 'silent-user-no-reping'
    }

    It 'rejects the escalation doc reverting to an AskUserQuestion instruction' {
        $mutant = $escalation.Replace('est retiré du harnais', 'doit etre appele : utiliser l''outil AskUserQuestion')
        $mutant | Should -Not -Be $escalation
        $mutant | Should -Match '(?i)utiliser l.outil AskUserQuestion'
    }
}
