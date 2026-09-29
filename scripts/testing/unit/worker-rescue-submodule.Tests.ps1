# Tests unitaires — preservation du travail submodule avant le revert phantom (#3944)
#
# Reset-PhantomSubmodulePointers (#1156 v2) detecte un HEAD de submodule absent de origin/main
# et le revert par `reset --hard origin/main`. Sur web1 le 2026-09-29 (#3944), le HEAD non
# pousse etait du VRAI travail de worker (~450 lignes) : le reset l'a efface (reflog seul) et
# le run a ensuite rapporte « PASS — no code changes needed ». Le correctif preserve d'abord
# (branche worker-rescue/<task-id>-<horodatage> poussee sur le remote du submodule), revert
# ensuite — et ne revert JAMAIS si le push echoue.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` via
# scripts/testing/run-pester-tests.ps1. Assertions purement statiques sur le texte du worker
# (la fonction passe par `cmd /c`, inexecutable sur le runner Linux).
#
# Controle positif : retirer la preservation (bloc rev-list + branche + push) doit faire
# echouer les tests de ce fichier — verifie par mutation sur la branche de la PR.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-rescue-submodule.Tests.ps1 -Output Detailed"

BeforeAll {
    # Pester 6 : un helper defini AU TOP-LEVEL du fichier de test fait echouer le container
    # (« break/continue escaped », Pester#2669) — le definir ICI, dans le BeforeAll.
    function Get-WorkerFnBody([string]$Content, [string]$Name) {
        $pos = $Content.IndexOf("function $Name")
        if ($pos -lt 0) { return "" }
        $body = $Content.Substring($pos)
        $next = $body.IndexOf("`nfunction ", 1)
        if ($next -gt 0) { $body = $body.Substring(0, $next) }
        return $body
    }

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $script:content = Get-Content $workerScript -Raw

    # Fenetres = corps des fonctions citees : un marqueur ailleurs dans le worker ne doit pas
    # pouvoir faire passer ces tests.
    $script:fnRescue = Get-WorkerFnBody -Content $script:content -Name 'Reset-PhantomSubmodulePointers'
    $script:fnMark   = Get-WorkerFnBody -Content $script:content -Name 'Mark-TaskAsComplete'
    $script:fnReport = Get-WorkerFnBody -Content $script:content -Name 'Report-Results'
}

Describe "Worker - le revert phantom ne detruit plus le travail submodule (#3944)" {

    Context "Les fonctions ciblees existent et sont bien isolees" {

        It "Doit definir Reset-PhantomSubmodulePointers et isoler son corps" {
            ($script:content -match 'function Reset-PhantomSubmodulePointers') | Should -Be $true
            ($script:fnRescue -match 'PHANTOM POINTER DETECTED') | Should -Be $true
        }

        It "Doit definir Mark-TaskAsComplete et isoler son corps" {
            ($script:fnMark -match '\[RESULT\] \$MachineId') | Should -Be $true
        }

        It "Doit definir Report-Results et isoler son corps" {
            ($script:fnReport -match 'Livraison v') | Should -Be $true
        }
    }

    Context "La preservation precede le revert" {

        It "Doit compter les commits uniques avant de decider (rev-list origin/main..NewHead)" {
            ($script:fnRescue -match 'rev-list origin/main\.\.\$NewHead --count') | Should -Be $true
        }

        It "Doit creer une branche worker-rescue horodatee, par task-id" {
            ($script:fnRescue -match 'worker-rescue/\$RescueTaskId-') | Should -Be $true
            ($script:fnRescue -match 'yyyyMMdd-HHmmss') | Should -Be $true
        }

        It "Doit pousser la branche de sauvetage vers le remote du submodule" {
            ($script:fnRescue -match 'push origin \$RescueBranch') | Should -Be $true
        }

        It "Doit creer et pousser la branche AVANT le reset --hard" {
            $branchPos = $script:fnRescue.IndexOf('branch -f $RescueBranch')
            $pushPos = $script:fnRescue.IndexOf('push origin $RescueBranch')
            $resetPos = $script:fnRescue.IndexOf('reset --hard origin/main')
            $branchPos | Should -BeGreaterThan 0
            $pushPos | Should -BeGreaterThan 0
            $resetPos | Should -BeGreaterThan 0
            $branchPos | Should -BeLessThan $resetPos
            $pushPos | Should -BeLessThan $resetPos
        }

        It "Doit refuser le revert et sortir de l'iteration si le push echoue" {
            $pushPos = $script:fnRescue.IndexOf('push origin $RescueBranch')
            $resetPos = $script:fnRescue.IndexOf('reset --hard origin/main')
            $refusePos = $script:fnRescue.IndexOf('REFUSED phantom-pointer revert')
            $refusePos | Should -BeGreaterThan $pushPos
            $refusePos | Should -BeLessThan $resetPos
            $refuseBlock = $script:fnRescue.Substring($refusePos)
            $nextReset = $refuseBlock.IndexOf('reset --hard origin/main')
            if ($nextReset -gt 0) { $refuseBlock = $refuseBlock.Substring(0, $nextReset) }
            ($refuseBlock -match 'continue') | Should -Be $true
            ($refuseBlock -match '"ERROR"') | Should -Be $true
        }

        It "Doit consigner la branche sauvee pour le rapport (RescuedSubmoduleBranches)" {
            ($script:fnRescue -match '\$script:RescuedSubmoduleBranches \+= \[pscustomobject\]') | Should -Be $true
        }

        It "Doit garder le reset nominal pour un pointeur phantom sans travail" {
            # Le reset --hard origin/main reste le chemin nominal (compte == 0 unique commit).
            ($script:fnRescue -match 'reset --hard origin/main') | Should -Be $true
        }
    }

    Context "Le verdict ne peut plus mentir" {

        It "Doit conditionner le PASS au cas rescue, avant le message 'no code changes needed'" {
            $condPos = $script:fnMark.IndexOf('elseif ($Success -and $script:RescuedSubmoduleBranches.Count -gt 0)')
            $noChangePos = $script:fnMark.IndexOf('no code changes needed')
            $condPos | Should -BeGreaterThan 0
            $noChangePos | Should -BeGreaterThan $condPos
        }

        It "Doit emettre un tag [RESCUE_BRANCH] citant la branche poussee dans le [RESULT]" {
            ($script:fnMark -match '\[RESCUE_BRANCH\]') | Should -Be $true
            ($script:fnMark -match '\$\(\$_\.Branch') | Should -Be $true
        }

        It "Doit porter le bloc de preservation dans le rapport (Report-Results)" {
            ($script:fnReport -match 'Travail submodule pr') | Should -Be $true
            ($script:fnReport -match '\(#3944\)') | Should -Be $true
            ($script:fnReport -match '\$\(\$_\.Branch') | Should -Be $true
        }
    }
}