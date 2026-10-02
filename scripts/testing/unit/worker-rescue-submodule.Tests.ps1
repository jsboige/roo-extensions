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
    $script:fnCreate = Get-WorkerFnBody -Content $script:content -Name 'Create-Worktree'
    $script:fnReset  = Get-WorkerFnBody -Content $script:content -Name 'Reset-WorktreeForMaintenance'

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

        It "Doit garder le verrou d'issue sur les verdicts 'ne pas redispatcher' (#4000, 02/10)" {
            # [RESULT] ferme le verrou dans check_issue_claim.py : les trois verdicts qui disent
            # « ne pas redispatcher » (BLOCKED, rescue, FAIL avec artefacts) le rouvrent par une
            # ligne [CLAIMED] posee APRES le bloc [RESCUE_BRANCH] (dernier marqueur gagne).
            ([regex]::Matches($script:fnMark, '\$HoldLock = \$true')).Count | Should -Be 3
            $rescuePos = $script:fnMark.IndexOf('[RESCUE_BRANCH] #3944')
            $holdPos = $script:fnMark.IndexOf('[CLAIMED] $MachineId -- held')
            $writePos = $script:fnMark.IndexOf('$ResultBodyFile = Join-Path')
            $rescuePos | Should -BeGreaterThan 0
            $holdPos | Should -BeGreaterThan $rescuePos
            $writePos | Should -BeGreaterThan $holdPos
            ($script:fnMark -match 'if \(\$HoldLock -or \$script:RecoveryBranchName\)') | Should -Be $true
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
            # Commit cite via Get-Sha8 (null-safe, run 2) : le JSON marqueur relu au run
            # suivant peut avoir Commit absent — $null.Substring() crasherait le rapport.
            ($script:fnMark.IndexOf('(Get-Sha8 $Ref.Commit)')) | Should -BeGreaterThan 0
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
            # Run 2 : la condition est ETENDUE au marqueur persistant (le flag memoire de
            # session est vide au run suivant — retirer le '-or (Test-PhantomRescueMarker'
            # doit echouer ici aussi).
            ($script:fnGraceful -match 'if \(\$script:PhantomRescueRefused -or \(Test-PhantomRescueMarker') | Should -Be $true
            $guardPos = $script:fnGraceful.IndexOf('if ($script:PhantomRescueRefused')
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

    Context "Run suivant : le worktree conserve SURVIT (review ai-01 30/09 09:25Z)" {

        It "Doit persister la decision REFUSED dans le gitdir (marqueur survives reset+clean)" {
            ($script:content -match 'function Save-PhantomRescueMarker') | Should -Be $true
            ($script:content -match 'function Test-PhantomRescueMarker') | Should -Be $true
            ($script:content -match 'function Get-WorktreeGitDirPath') | Should -Be $true
            # Le marqueur vit dans le gitdir du worktree, pas dans l'arbre : reset --hard
            # et clean -fd n'y touchent pas, Remove-Worktree est le seul a le detruire —
            # c'est precisement ce que les gardes empechent.
            ($script:content -match "PHANTOM-RESCUE-REFUSED\.json") | Should -Be $true
            # Pose DANS le bloc REFUSED, apres le flag, avant le continue.
            $flagPos = $script:fnRescue.IndexOf('$script:PhantomRescueRefused = [pscustomobject]')
            $savePos = $script:fnRescue.IndexOf('Save-PhantomRescueMarker -Ref')
            $flagPos | Should -BeGreaterThan 0
            $savePos | Should -BeGreaterThan $flagPos
        }

        It "Doit refuser le reset de maintenance sous marqueur, avant fetch et reset --hard" {
            ($script:fnReset.Length) | Should -BeGreaterThan 0
            $guardPos = $script:fnReset.IndexOf('if (Test-PhantomRescueMarker -WorktreePath $WorktreePath)')
            $fetchPos = $script:fnReset.IndexOf('fetch origin main')
            $resetPos = $script:fnReset.IndexOf('reset --hard origin/main')
            $guardPos | Should -BeGreaterThan 0
            $fetchPos | Should -BeGreaterThan $guardPos
            $resetPos | Should -BeGreaterThan $guardPos
            # La garde sort AVANT le fetch : le checkout du submodule ne bouge pas.
            $returnPos = $script:fnReset.IndexOf('return $false', $guardPos)
            $returnPos | Should -BeGreaterThan $guardPos
            $returnPos | Should -BeLessThan $fetchPos
        }

        It "Doit ignorer le worktree marque dans Create-Worktree : ni remove, ni reset, ni reutilisation" {
            ($script:fnCreate.Length) | Should -BeGreaterThan 0
            $guardPos = $script:fnCreate.IndexOf('if (Test-PhantomRescueMarker -WorktreePath $ExistingWt.worktreePath)')
            $removePos = $script:fnCreate.IndexOf('Remove-Worktree -WorktreePath')
            $resetPos = $script:fnCreate.IndexOf('Reset-WorktreeForMaintenance -WorktreePath')
            $guardPos | Should -BeGreaterThan 0
            $removePos | Should -BeGreaterThan $guardPos
            $resetPos | Should -BeGreaterThan $guardPos
            # return $null = le run travaille sur le checkout principal ; le premier
            # return $null apres la garde est celui de la garde (les autres viennent
            # des garde-fous ulterieurs).
            $returnPos = $script:fnCreate.IndexOf('return $null', $guardPos)
            $returnPos | Should -BeGreaterThan $guardPos
            $returnPos | Should -BeLessThan $removePos
            $returnPos | Should -BeLessThan $resetPos
        }

        It "Doit rendre tout Substring de commit du flag null-safe via Get-Sha8 (point b)" {
            # Aucune occurrence directe restante : $null.Substring() crasherait le cleanup
            # (ou le rapport) exactement la ou il doit CONSERVER. File-wide : une
            # reintroduction n'importe ou doit echouer.
            ($script:content -match 'function Get-Sha8') | Should -Be $true
            ($script:content -notmatch '\.Commit\.Substring') | Should -Be $true
            # Les 3 sites consommateurs du flag passent par le helper.
            ($script:fnMark.IndexOf('(Get-Sha8 $Ref.Commit)')) | Should -BeGreaterThan 0
            ($script:fnGraceful.IndexOf('Get-Sha8 $script:PhantomRescueRefused.Commit')) | Should -BeGreaterThan 0
            ($script:blockStep8.IndexOf('Get-Sha8 $script:PhantomRescueRefused.Commit')) | Should -BeGreaterThan 0
        }

        It "Doit logger l'echec du fetch origin main de Create-Worktree (point c, suite #3955)" {
            $fetchPos = $script:fnCreate.IndexOf('fetch origin main --quiet')
            $exitPos = $script:fnCreate.IndexOf('$fetchExit = $LASTEXITCODE')
            $warnPos = $script:fnCreate.IndexOf('fetch origin main failed')
            $fetchPos | Should -BeGreaterThan 0
            $exitPos | Should -BeGreaterThan $fetchPos
            $warnPos | Should -BeGreaterThan $exitPos
        }
    }
}