# Tests unitaires pour le guard préventif anti-worktree-imbriqué du worker script (#2351)
# Guard: Create-Worktree refuse `git worktree add` si le chemin cible est imbriqué
# dans un répertoire de submodule (mcps/internal, mcps/external/win-cli/server, roo-code, ...).
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Fonctionne sur pwsh Windows ET Linux
# (chemins en slashes, aucune dépendance disque/git).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/nested-worktree-guard.Tests.ps1 -Output Detailed"
#
# Contexte : la règle .claude/rules/pr-mandatory.md (Anti-Nested Worktrees, #2123)
# interdit les worktrees imbriqués dans un submodule. Le guard #2351 applique cette
# règle AVANT la création (prévention), au lieu du cleanup post-hoc Remove-NestedSubmoduleWorktrees.

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw
}

Describe "Nested Worktree Guard - #2351 (preventive, creation-time)" {

    # ---------------------------------------------------------------------------
    # Structure : le guard est présent, bien placé, et défensif
    # ---------------------------------------------------------------------------

    Context "Guard structure - #2351 marker and placement" {

        It "Must contain the #2351 guard marker" {
            ($content -match 'Guard #2351') | Should -Be $true
        }

        It "Guard must live inside the Create-Worktree function" {
            $funcPos  = $content.IndexOf('function Create-Worktree')
            $guardPos = $content.IndexOf('Guard #2351')
            $funcPos  | Should -BeGreaterThan 0
            $guardPos | Should -BeGreaterThan $funcPos
        }

        It "Guard must run BEFORE the git worktree add call (prevention, not cleanup)" {
            $guardPos    = $content.IndexOf('Guard #2351')
            $worktreeAdd = $content.IndexOf('git -C $RepoRoot worktree add')
            $guardPos    | Should -BeGreaterThan 0
            $worktreeAdd | Should -BeGreaterThan 0
            $worktreeAdd | Should -BeGreaterThan $guardPos
        }

        It "Guard must read submodule paths from .gitmodules (dynamic, not hardcoded)" {
            ($content -match 'config --file \.gitmodules --get-regexp path') | Should -Be $true
        }

        It "Guard must normalize backslashes to forward slashes before comparison" {
            $guardPos = $content.IndexOf('Guard #2351')
            $window   = $content.Substring($guardPos, 700)
            ($window -match "replace '\\\\', '/'") | Should -Be $true
        }

        It "Guard must refuse with a descriptive REFUSED (#2351) message" {
            ($content -match 'REFUSED \(#2351\)') | Should -Be $true
        }

        It "Refusal must be logged at ERROR level" {
            $guardPos = $content.IndexOf('Guard #2351')
            $window   = $content.Substring($guardPos, 1200)
            ($window -match 'Write-Log "REFUSED \(#2351\).*"\s+"ERROR"') | Should -Be $true
        }

        It "Guard must return `$null on refusal (clean exit, no creation attempt)" {
            $guardPos = $content.IndexOf('Guard #2351')
            $window   = $content.Substring($guardPos, 1200)
            ($window -match 'return \$null') | Should -Be $true
        }

        It "Guard must be non-fatal on check failure (try/catch with WARN)" {
            $guardPos = $content.IndexOf('Guard #2351')
            $window   = $content.Substring($guardPos, 1200)
            ($window -match 'catch') | Should -Be $true
            ($window -match 'non-fatal') | Should -Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Comportement : le prédicat de nesting refuse les imbriqués et laisse passer
    # les worktrees légitimes. Réimplémente exactement la logique du guard
    # (StartsWith "$sm/" OU égalité) pour valider le refus sans exécuter le worker.
    # ---------------------------------------------------------------------------

    Context "Nesting predicate behaviour - refusal logic (#2351)" {

        BeforeAll {
            # Réplique fidèle de la logique du guard (start-claude-worker.ps1)
            function Test-IsNested {
                param([string]$WorktreePath, [string[]]$SubmodulePaths, [string]$RepoRoot)
                $normalizedWt = ($WorktreePath -replace '\\', '/').TrimEnd('/')
                foreach ($smPath in $SubmodulePaths) {
                    $fullSmPath   = Join-Path $RepoRoot $smPath
                    $normalizedSm = ($fullSmPath -replace '\\', '/').TrimEnd('/')
                    if ($normalizedWt.StartsWith("$normalizedSm/") -or $normalizedWt -eq $normalizedSm) {
                        return $true
                    }
                }
                return $false
            }

            $repoRoot = 'D:/dev/roo-extensions'
            $subs     = @('mcps/internal', 'mcps/external/win-cli/server', 'roo-code')
        }

        It "REFUSES a path nested inside mcps/internal" {
            Test-IsNested 'D:/dev/roo-extensions/mcps/internal/.claude/worktrees/wt-x' $subs $repoRoot | Should -Be $true
        }

        It "REFUSES a path nested inside roo-code" {
            Test-IsNested 'D:/dev/roo-extensions/roo-code/wt-y' $subs $repoRoot | Should -Be $true
        }

        It "REFUSES a path exactly equal to a submodule directory" {
            Test-IsNested 'D:/dev/roo-extensions/mcps/internal' $subs $repoRoot | Should -Be $true
        }

        It "REFUSES a path nested inside a deep submodule (win-cli/server)" {
            Test-IsNested 'D:/dev/roo-extensions/mcps/external/win-cli/server/sub/wt-z' $subs $repoRoot | Should -Be $true
        }

        It "ALLOWS the legitimate parent worktree path (.claude/worktrees/...)" {
            Test-IsNested 'D:/dev/roo-extensions/.claude/worktrees/wt-foo' $subs $repoRoot | Should -Be $false
        }

        It "ALLOWS a sibling directory outside the working tree" {
            Test-IsNested 'D:/dev/roo-extensions-wt/wt-foo' $subs $repoRoot | Should -Be $false
        }

        It "ALLOWS a path that only shares a submodule name as a substring prefix (no false positive)" {
            # 'mcps/internal-tools' must NOT be treated as nested in 'mcps/internal'
            Test-IsNested 'D:/dev/roo-extensions/mcps/internal-tools/wt' $subs $repoRoot | Should -Be $false
        }

        It "Handles backslash-style Windows paths identically" {
            Test-IsNested 'D:\dev\roo-extensions\mcps\internal\wt-x' $subs $repoRoot | Should -Be $true
            Test-IsNested 'D:\dev\roo-extensions\.claude\worktrees\wt-foo' $subs $repoRoot | Should -Be $false
        }
    }

    # ---------------------------------------------------------------------------
    # Non-régression : le cleanup post-hoc et la fonction Create-Worktree restent
    # ---------------------------------------------------------------------------

    Context "Guard interaction - prevention complements (not replaces) cleanup" {

        It "Create-Worktree function still exists" {
            ($content -match 'function Create-Worktree') | Should -Be $true
        }

        It "Post-hoc Remove-NestedSubmoduleWorktrees cleanup still present (defence in depth)" {
            ($content -match 'Remove-NestedSubmoduleWorktrees') | Should -Be $true
        }
    }
}
