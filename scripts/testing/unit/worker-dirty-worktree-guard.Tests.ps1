# Tests unitaires — garde anti-force sur worktree de submodule SALE
#
# Remove-NestedSubmoduleWorktrees classait orphelin tout worktree de submodule non
# imbrique dans un worktree parent vivant, puis le supprimait en `worktree remove --force`.
# Ce placement est pourtant celui que le depot prescrit (.claude/rules/pr-mandatory.md
# #2123 : "OK : ../roo-extensions-wt/wt-foo, en dehors du repo") et que
# scripts/worktrees/create-worktree.ps1 produit par defaut. Consequence mesuree sur ai-01
# le 2026-09-06 (worker-20260906-124412.log l.29-30) : le correctif client PG #2427 et ses
# tests ont ete detruits dans wt-pg-highwater pendant la session qui les ecrivait.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Assertions purement statiques sur le texte du
# worker : fonctionne sur pwsh Windows ET Linux, sans git ni depot de test.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-dirty-worktree-guard.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # Fenetre = corps de Remove-NestedSubmoduleWorktrees. Toutes les assertions
    # positionnelles portent dessus, pas sur le fichier entier : un `git status`
    # ailleurs dans le worker ne doit pas pouvoir faire passer ces tests.
    $fnPos = $content.IndexOf('function Remove-NestedSubmoduleWorktrees')
    $script:fnBody = $content.Substring($fnPos)
    $nextFn = $script:fnBody.IndexOf("`nfunction ", 1)
    if ($nextFn -gt 0) { $script:fnBody = $script:fnBody.Substring(0, $nextFn) }
}

Describe "Worker - garde anti-force sur worktree de submodule SALE" {

    Context "La fonction ciblee existe et est bien isolee" {

        It "Doit definir Remove-NestedSubmoduleWorktrees" {
            ($content -match 'function Remove-NestedSubmoduleWorktrees') | Should -Be $true
        }

        It "Le corps isole doit contenir le retrait en --force (sinon la fenetre est fausse)" {
            ($script:fnBody -match 'worktree remove --force \$smWtPath') | Should -Be $true
        }
    }

    Context "Le garde existe" {

        It "Doit interroger l'etat du worktree avant de le retirer" {
            ($script:fnBody -match 'git -C \$smWtPath status --porcelain') | Should -Be $true
        }

        It "Doit capturer le code de retour du status" {
            # Sans ca, un repertoire absent (git en erreur) serait lu comme "propre"
            # ou comme "sale" selon le bruit de stderr, au lieu d'etre retire.
            ($script:fnBody -match '\$smWtStatusRc = \$LASTEXITCODE') | Should -Be $true
        }

        It "Ne doit traiter comme SALE que si le status a REUSSI et rend des lignes" {
            ($script:fnBody -match '\$smWtStatusRc -eq 0 -and \$smWtStatus\.Count -gt 0') | Should -Be $true
        }

        It "Doit sauter le worktree sale au lieu de le supprimer" {
            $guardPos = $script:fnBody.IndexOf('$smWtStatusRc -eq 0 -and')
            $guardPos | Should -BeGreaterThan 0
            $window = $script:fnBody.Substring($guardPos, 420)
            ($window -match 'continue') | Should -Be $true
            ($window -match 'DIRTY submodule worktree') | Should -Be $true
        }

        It "Doit restaurer ErrorActionPreference sur le chemin du saut" {
            # Le `continue` sort de la boucle sans passer par la restauration
            # placee apres le retrait : elle doit etre dupliquee dans le garde.
            $guardPos = $script:fnBody.IndexOf('$smWtStatusRc -eq 0 -and')
            $window = $script:fnBody.Substring($guardPos, 420)
            ($window -match '\$ErrorActionPreference = \$prevPref') | Should -Be $true
        }
    }

    Context "Le garde precede reellement le retrait (c'est l'ordre qui protege)" {

        It "Le status doit etre interroge AVANT le worktree remove --force" {
            $statusPos = $script:fnBody.IndexOf('git -C $smWtPath status --porcelain')
            $removePos = $script:fnBody.IndexOf('worktree remove --force $smWtPath')
            $statusPos | Should -BeGreaterThan 0
            $removePos | Should -BeGreaterThan 0
            $statusPos | Should -BeLessThan $removePos
        }

        It "Le WARN 'Removing' ne doit etre emis qu'APRES le garde" {
            # Sinon le journal annonce une suppression qui n'a pas lieu, et le
            # diagnostic d'un incident futur repart sur une fausse piste.
            $guardPos  = $script:fnBody.IndexOf('$smWtStatusRc -eq 0 -and')
            $removeLog = $script:fnBody.IndexOf('ORPHAN SUBMODULE WORKTREE (#2123)')
            $guardPos  | Should -BeGreaterThan 0
            $removeLog | Should -BeGreaterThan 0
            $guardPos  | Should -BeLessThan $removeLog
        }
    }

    Context "Non-regression #2123 : un worktree PROPRE est toujours retire" {

        It "Le retrait en --force doit etre conserve pour le cas propre" {
            # Le correctif est additif : il n'enleve pas le --force, il refuse
            # seulement de l'appliquer a un worktree qui porte du travail.
            ($script:fnBody -match 'worktree remove --force \$smWtPath') | Should -Be $true
        }

        It "Le saut #2501 (parent vivant) doit rester intact et rester le premier filtre" {
            $skipPos  = $script:fnBody.IndexOf('has valid parent')
            $guardPos = $script:fnBody.IndexOf('$smWtStatusRc -eq 0 -and')
            $skipPos  | Should -BeGreaterThan 0
            $skipPos  | Should -BeLessThan $guardPos
        }
    }
}
