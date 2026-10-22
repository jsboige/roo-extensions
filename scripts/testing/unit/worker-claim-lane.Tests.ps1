# Tests unitaires — identité de lane des marqueurs de claim du worker (#4114, côté producteur)
#
# start-claude-worker.ps1 écrit [CLAIMED]/[RELEASED]/[RESULT] machine-seuls depuis
# l'origine : le garde (check_issue_claim.py, #4114/#4122) les classe LEGACY_CLAIM,
# c'est-à-dire fail-closed FOREIGN pour toute lane de la même machine. Préjudice
# mesuré le 20/10 sur #4247 (po-2024) : le siège désigné était verrouillé par une
# machine hors d'état de traiter l'issue.
#
# Ces tests exigent que TOUS les marqueurs GitHub du worker portent la lane
# `machine:workspace` (workspace = basename du repo root — la même dérivation que
# le garde), SANS toucher l'adressage [TASK] qui reste machine-niveau (contrat B14,
# #4131 : le worker planifié consomme les [TASK] adressés à `machine` seule).
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# Usage :
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-claim-lane.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $script:Content = Get-Content $workerScript -Raw

    # claim-lock.ps1 est dot-sourcé aussi par le worker — comportement réel,
    # pas une réplique de regex (le lock-window doit rester compatible lane).
    . (Join-Path $projectRoot "scripts/scheduling/claim-lock.ps1")

    # Réplique exacte du corps de claim que le worker doit désormais produire
    # (template :929) — utilisée pour les tests comportementaux ci-dessous.
    $script:SampleLane = 'myia-po-2025:roo-extensions'
    $script:SampleClaim = "[CLAIMED] by claude on $($script:SampleLane) at 2026-10-22T05:00:00Z"
    # -Now figé : le lock-window (30 min) rendrait les fixtures time-dépendantes.
    $script:Now      = [datetime]'2026-10-22T05:05:00Z'
    $script:TClaim   = [datetime]'2026-10-22T05:00:00Z'
    $script:TRelease = [datetime]'2026-10-22T05:02:00Z'
}

Describe "Worker claim markers carry lane identity (#4114 producer)" {

    It "dérive une lane script-scope machine:workspace (COMPUTERNAME + basename repo root)" {
        # Même dérivation que check_issue_claim.py : machine + basename du toplevel.
        $script:Content | Should -Match '(?m)^\$script:ClaimLane\s*=.*Split-Path -Leaf \$RepoRoot'
        $script:Content | Should -Match '(?m)^\$script:ClaimLane\s*=.*COMPUTERNAME\.ToLower\(\)'
        $script:Content | Should -Not -Match '(?m)^\$script:ClaimLane\s*=.*CoursIA'
    }

    It "le corps [CLAIMED] porte la lane, plus machine-seul" {
        $script:Content | Should -Match '\[CLAIMED\] by \$AgentType on \$script:ClaimLane at \$Timestamp'
        $script:Content | Should -Not -Match '\[CLAIMED\] by \$AgentType on \$MachineId at'
    }

    It "les deux corps [RELEASED] portent la lane" {
        $releasedCount = ([regex]::Matches($script:Content, '\[RELEASED\] by \$AgentType on \$script:ClaimLane')).Count
        $releasedCount | Should -Be 2
        $script:Content | Should -Not -Match '\[RELEASED\] by \$AgentType on \$MachineId'
    }

    It "le bloc [RESULT] github utilise la lane (RESULT ferme le claim du même token)" {
        # :1128 — le [RESULT] machine-seul ne fermerait PAS un claim lane :
        # false-block 24h jusqu'à péremption (classe de régression documentée
        # par le garde, CLOSE_MARKERS attribués par token de lane).
        $script:Content | Should -Match '(?m)^\s+\$MachineId = \$script:ClaimLane\s*$'
    }

    It "la ligne de hold post-RESULT hérite de la même variable locale" {
        # La ligne `[CLAIMED] $MachineId -- held:` doit réutiliser $MachineId
        # APRÈS sa réassignation lane — vérifiée par l'ordre : réassignation
        # présente, et le template hold inchangé (il interpole la même variable).
        $script:Content | Should -Match '\[CLAIMED\] \$MachineId -- held:'
    }

    It "l'adressage [TASK] reste machine-niveau (contrat B14, #4131)" {
        # Get-NextTask default + filtre messages : NE DOIT PAS devenir lane.
        $script:Content | Should -Match '\[string\]\$MachineId = \$env:COMPUTERNAME\.ToLower\(\),'
        $script:Content | Should -Match '\$_\.to -eq \$MachineId -or \$_\.to -eq "all"'
    }
}

Describe "claim-lock.ps1 stays lane-compatible (behavior)" {

    It "Get-CommentMachine extrait la machine depuis un claim lane-suffixé" {
        Get-CommentMachine $script:SampleClaim | Should -Be 'myia-po-2025'
    }

    It "un claim lane de SA machine n'est pas une compétition (sous-chaîne machine)" {
        $own = [pscustomobject]@{ body = $script:SampleClaim; createdAt = $script:TClaim }
        Test-ConcurrentClaimActive -Comments @($own) -MachineId 'myia-po-2025' -Now $script:Now |
            Should -BeFalse
    }

    It "un claim lane d'une AUTRE machine reste une compétition active" {
        $other = [pscustomobject]@{ body = $script:SampleClaim; createdAt = $script:TClaim }
        Test-ConcurrentClaimActive -Comments @($other) -MachineId 'myia-web2' -Now $script:Now |
            Should -BeTrue
    }

    It "une release nommant la lane libère le claim (machine = sous-chaîne)" {
        $claim = [pscustomobject]@{ body = $script:SampleClaim; createdAt = $script:TClaim }
        $release = [pscustomobject]@{
            body = "[RELEASED] by claude on $($script:SampleLane) — race condition detected, yielding to other claimer."
            createdAt = $script:TRelease
        }
        Test-ConcurrentClaimActive -Comments @($claim, $release) -MachineId 'myia-web2' -Now $script:Now |
            Should -BeFalse
    }
}
