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
    $script:fnGraceful = Get-WorkerFnBody -Content $script:content -Name 'Invoke-GracefulShutdown'

    # Fenetre etape 8 : bloc de cleanup final du script PRINCIPAL (pas une fonction —
    # fenetrage par marqueurs). Chaines ASCII uniquement : un fichier sans BOM decode en
    # CP1252 sous PS 5.1 perd les accents, le worker (BOM) les garde.
    $step8Pos = $script:content.IndexOf('# 8. Cleanup worktree')
    $step8End = $script:content.IndexOf('WORKER TERMIN', $step8Pos)
    if ($step8Pos -ge 0 -and $step8End -gt $step8Pos) {
        $script:blockStep8 = $script:content.Substring($step8Pos, $step8End - $step8Pos)
    } else {
        $script:blockStep8 = ''
    }
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
            ($script:fnReport -match '\(#3944') | Should -Be $true
            ($script:fnReport -match '\$\(\$_\.Branch') | Should -Be $true
        }
    }

    Context "La branche refusee ne peut plus etre effacee ni mentie (review #3946)" {

        It "Doit poser le flag PhantomRescueRefused dans le bloc REFUSED, avant le continue" {
            $refusePos = $script:fnRescue.IndexOf('REFUSED phantom-pointer revert')
            $refuseBlock = $script:fnRescue.Substring($refusePos)
            $nextReset = $refuseBlock.IndexOf('reset --hard origin/main')
            if ($nextReset -gt 0) { $refuseBlock = $refuseBlock.Substring(0, $nextReset) }
            ($refuseBlock -match '\$script:PhantomRescueRefused = \[pscustomobject\]') | Should -Be $true
            $flagPos = $refuseBlock.IndexOf('$script:PhantomRescueRefused')
            $continuePos = $refuseBlock.IndexOf('continue')
            $flagPos | Should -BeGreaterThan 0
            $continuePos | Should -BeGreaterThan $flagPos
        }

        It "Doit verifier le flag AVANT le fallback PASS-no-changes et rendre un verdict BLOCKED nommant chemin et commit" {
            $condPos = $script:fnMark.IndexOf('elseif ($Success -and $script:PhantomRescueRefused)')
            $noChangePos = $script:fnMark.IndexOf('no code changes needed')
            $condPos | Should -BeGreaterThan 0
            $noChangePos | Should -BeGreaterThan $condPos
            ($script:fnMark -match 'BLOCKED') | Should -Be $true
            ($script:fnMark -match 'submodule work NOT preserved remotely') | Should -Be $true
            ($script:fnMark.IndexOf('($Ref.WorktreePath)')) | Should -BeGreaterThan 0
            ($script:fnMark.IndexOf('($Ref.Commit.Substring(0, 8))')) | Should -BeGreaterThan 0
        }

        It "Doit verifier le flag a l'etape 8 avant TOUT appel Remove-Worktree et conserver le worktree" {
            ($script:blockStep8.Length) | Should -BeGreaterThan 0
            $flagPos = $script:blockStep8.IndexOf('$script:PhantomRescueRefused')
            $firstRemove = $script:blockStep8.IndexOf('Remove-Worktree -WorktreePath')
            $flagPos | Should -BeGreaterThan 0
            $firstRemove | Should -BeGreaterThan $flagPos
            ($script:blockStep8 -match 'CONSERV') | Should -Be $true
        }

        It "Doit conserver le worktree dans Invoke-GracefulShutdown : garde et return avant tout Remove-Worktree (review #3946, ai-01 30/09)" {
            # GracefulShutdown est appele par le finally, le watchdog, Ctrl+C et Exiting —
            # ses 3 Remove-Worktree (auto-commit-only / push-ok / arbre propre) sont des
            # chemins de destruction que le flag doit couvrir en tete du bloc de cleanup.
            ($script:fnGraceful.Length) | Should -BeGreaterThan 0
            # La CONDITION elle-meme, pas une occurrence du flag : le corps de la garde
            # reference le flag dans son log — neutraliser le if en '$false' doit echouer
            # ici (lecon #3774 : le discriminant n'est pas une valeur ecrite par la garde).
            ($script:fnGraceful -match 'if \(\$script:PhantomRescueRefused\)') | Should -Be $true
            $guardPos = $script:fnGraceful.IndexOf('if ($script:PhantomRescueRefused)')
            $firstRemove = $script:fnGraceful.IndexOf('Remove-Worktree -WorktreePath')
            $guardPos | Should -BeGreaterThan 0
            $firstRemove | Should -BeGreaterThan $guardPos
            # Le return de la garde coupe le cleanup AVANT le premier Remove-Worktree
            # (les return des garde-fous d'entree precedent la garde, IndexOf part d'elle).
            $returnPos = $script:fnGraceful.IndexOf('return', $guardPos)
            $returnPos | Should -BeGreaterThan $guardPos
            $returnPos | Should -BeLessThan $firstRemove
            ($script:fnGraceful -match 'CONSERV') | Should -Be $true
        }
    }
}