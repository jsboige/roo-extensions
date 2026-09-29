# Tests unitaires — garde « le worktree est-il encore un worktree ? » avant l'auto-commit
#
# Test-WorktreeHasChanges fait Push-Location dans le worktree puis lance des commandes git
# nues (`git status`, `git add`, `git commit`). Un worktree que la session a elle-meme retire
# (desenregistre, vide jusqu'a son dossier) vit DANS le checkout principal
# (.claude/worktrees/...) : sans entree .git a lui, git remonte et toutes ces commandes
# s'adressent au checkout PRINCIPAL. Mesure sur ai-01 le 2026-09-29
# (worker-20260929-124410.log l.148-149) : l'auto-commit a cree dd4c92a4 sur `main` du
# checkout principal, avec un .vscode/settings.json local de l'utilisateur.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` via
# scripts/testing/run-pester-tests.ps1. Assertions purement statiques sur le texte du
# worker (la fonction passe par `cmd /c`, inexecutable sur le runner Linux).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-autocommit-worktree-guard.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # Fenetre = corps de Test-WorktreeHasChanges : un test .git ailleurs dans le worker
    # (Find-ExistingWorktree en a un) ne doit pas pouvoir faire passer ces tests.
    $fnPos = $content.IndexOf('function Test-WorktreeHasChanges')
    $script:fnBody = $content.Substring($fnPos)
    $nextFn = $script:fnBody.IndexOf("`nfunction ", 1)
    if ($nextFn -gt 0) { $script:fnBody = $script:fnBody.Substring(0, $nextFn) }
}

Describe "Worker - pas d'auto-commit hors d'un worktree vivant" {

    Context "La fonction ciblee existe et est bien isolee" {

        It "Doit definir Test-WorktreeHasChanges" {
            ($content -match 'function Test-WorktreeHasChanges') | Should -Be $true
        }

        It "Le corps isole doit contenir l'auto-commit (sinon la fenetre est fausse)" {
            ($script:fnBody -match 'Auto-commit uncommitted worker changes') | Should -Be $true
        }
    }

    Context "La garde existe" {

        It "Doit tester l'entree .git du dossier courant" {
            ($script:fnBody -match "Test-Path -LiteralPath \(Join-Path \`$Here '\.git'\)") | Should -Be $true
        }

        It "Doit refuser en rendant `$false apres avoir restaure le repertoire" {
            $guard = $script:fnBody.Substring($script:fnBody.IndexOf("Join-Path `$Here '.git'"))
            $guard = $guard.Substring(0, $guard.IndexOf('return $false') + 'return $false'.Length)
            ($guard -match 'REFUSED auto-commit') | Should -Be $true
            ($guard -match 'Pop-Location') | Should -Be $true
        }
    }

    Context "La garde precede toute commande git" {

        It "Doit venir apres le Push-Location dans le worktree" {
            $script:fnBody.IndexOf('Push-Location $WorktreePath') |
                Should -BeLessThan $script:fnBody.IndexOf("Join-Path `$Here '.git'")
        }

        It "Doit venir avant la reinitialisation des pointeurs de submodule" {
            # -BeGreaterThan 0 d'abord : sans garde, IndexOf rend -1, « avant » tout.
            $guardPos = $script:fnBody.IndexOf("Join-Path `$Here '.git'")
            $guardPos | Should -BeGreaterThan 0
            $guardPos | Should -BeLessThan $script:fnBody.IndexOf('Reset-PhantomSubmodulePointers')
        }

        It "Doit venir avant le premier git status et le commit" {
            $guardPos = $script:fnBody.IndexOf("Join-Path `$Here '.git'")
            $guardPos | Should -BeGreaterThan 0
            $guardPos | Should -BeLessThan $script:fnBody.IndexOf('git status --porcelain')
            $guardPos | Should -BeLessThan $script:fnBody.IndexOf('git commit -m')
        }
    }
}
