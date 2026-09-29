# Tests unitaires — garde « le worktree est-il encore un worktree ? » dans le probe OnlyAutoCommits
#
# Test-OnlyAutoCommits fait Push-Location dans le worktree puis lance un `git log main..HEAD`
# nu. Un worktree que la session a elle-meme retire (desenregistre, vide jusqu'a son dossier)
# vit DANS le checkout principal (.claude/worktrees/...) : sans entree .git a lui, git remonte
# et le log lit le checkout PRINCIPAL — liste d'avance vide, verdict $false « du vrai travail »,
# et les deux appelants poussent ou conservent un dossier que git ne doit jamais adresser.
# Meme idiom que la garde #3933 (Test-WorktreeHasChanges), refuse-and-clean : $true.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` via
# scripts/testing/run-pester-tests.ps1. Assertions purement statiques sur le texte du
# worker (la fonction passe par `cmd /c`, inexecutable sur le runner Linux).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-onlyautocommits-guard.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # Fenetre = corps de Test-OnlyAutoCommits : un test .git ailleurs dans le worker
    # (Test-WorktreeHasChanges et Find-ExistingWorktree en ont un) ne doit pas pouvoir
    # faire passer ces tests.
    $fnPos = $content.IndexOf('function Test-OnlyAutoCommits')
    $script:fnBody = $content.Substring($fnPos)
    $nextFn = $script:fnBody.IndexOf("`nfunction ", 1)
    if ($nextFn -gt 0) { $script:fnBody = $script:fnBody.Substring(0, $nextFn) }
}

Describe "Worker - probe OnlyAutoCommits jamais hors d'un worktree vivant" {

    Context "La fonction ciblee existe et est bien isolee" {

        It "Doit definir Test-OnlyAutoCommits" {
            ($content -match 'function Test-OnlyAutoCommits') | Should -Be $true
        }

        It "Le corps isole doit contenir le probe git log (sinon la fenetre est fausse)" {
            ($script:fnBody -match 'git log main\.\.HEAD') | Should -Be $true
        }
    }

    Context "La garde existe" {

        It "Doit tester l'entree .git du dossier courant" {
            ($script:fnBody -match "Test-Path -LiteralPath \(Join-Path \`$Here '\.git'\)") | Should -Be $true
        }

        It "Doit refuser en rendant `$true (refuse-and-clean, pas `$false qui fait pousser)" {
            $guard = $script:fnBody.Substring($script:fnBody.IndexOf("Join-Path `$Here '.git'"))
            $guard = $guard.Substring(0, $guard.IndexOf('return $true') + 'return $true'.Length)
            ($guard -match 'REFUSED OnlyAutoCommits probe') | Should -Be $true
        }
    }

    Context "La garde precede le probe git" {

        It "Doit venir apres le Push-Location dans le worktree" {
            $script:fnBody.IndexOf('Push-Location $WorktreePath') |
                Should -BeLessThan $script:fnBody.IndexOf("Join-Path `$Here '.git'")
        }

        It "Doit venir avant le git log main..HEAD" {
            # -BeGreaterThan 0 d'abord : sans garde, IndexOf rend -1, « avant » tout.
            $guardPos = $script:fnBody.IndexOf("Join-Path `$Here '.git'")
            $guardPos | Should -BeGreaterThan 0
            $guardPos | Should -BeLessThan $script:fnBody.IndexOf('git log main..HEAD')
        }

        It "Le return `$true de la garde doit preceder le return `$true nominal (fin de parcours)" {
            # La garde est la PREMIERE sortie $true du corps : la sortie nominale (tous
            # auto-commits) reste la derniere. Si une sortie $true apparaissait avant la
            # garde, la fenetre ou le placement seraient faux.
            $guardPos = $script:fnBody.IndexOf("Join-Path `$Here '.git'")
            $guardPos | Should -BeLessThan $script:fnBody.IndexOf('return $true')
        }
    }
}
