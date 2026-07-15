# Tests unitaires pour le fix #2834 — reset du worktree réutilisé sur run maintenance
# Le worker réutilise un worktree persistant ; les runs maintenance (source="fallback")
# accumulent du cruft (stray files, auto-commits, phantom M mcps/internal). Le fix reset
# le worktree à origin/main au DÉBUT du run maintenance, MAIS préserve les work-tasks
# (source roosync/github) qui peuvent contenir du travail en cours.
#
# Syntaxe Pester v3 (Windows PowerShell 5.1) — cohérent avec worktree-husk-prevention.Tests.ps1
#
# Usage :
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Import-Module Pester -RequiredVersion 3.4.0 -Force; Invoke-Pester .\scripts\testing\unit\worker-worktree-reset.Tests.ps1"

Describe "Worker Worktree Reset - #2834 maintenance-run reset" {

    $projectRoot = (Resolve-Path -Path "$PSScriptRoot\..\..\..").Path
    $workerScript = Join-Path $projectRoot "scripts\scheduling\start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # ---------------------------------------------------------------------------
    # AC (a) : maintenance run → worktree reset
    # ---------------------------------------------------------------------------

    Context "AC (a) - Reset-WorktreeForMaintenance helper exists and is wired" {

        It "Must define the Reset-WorktreeForMaintenance function" {
            ($content -match 'function Reset-WorktreeForMaintenance') | Should Be $true
        }

        It "Reset must hard-reset to origin/main" {
            ($content -match 'git -C \$WorktreePath reset --hard origin/main') | Should Be $true
        }

        It "Reset must fetch origin/main before resetting" {
            ($content -match 'git -C \$WorktreePath fetch origin main') | Should Be $true
        }

        It "Reset must run git clean to remove cruft" {
            ($content -match 'git -C \$WorktreePath clean -fd') | Should Be $true
        }

        It "Reset must re-align submodules after hard reset" {
            ($content -match 'submodule update --init --recursive') | Should Be $true
        }
    }

    Context "AC (a) - .env and logs preserved by git clean" {

        It "git clean must exclude .env" {
            ($content -match 'clean -fd -e \.env') | Should Be $true
        }

        It "git clean must exclude *.log" {
            ($content -match "-e '\*\.log'") | Should Be $true
        }

        It "git clean must exclude node_modules (perf — junction-linked deps)" {
            ($content -match 'clean -fd -e \.env -e ''\*\.log'' -e node_modules') | Should Be $true
        }
    }

    Context "AC (a) - maintenance task (source=fallback) triggers reset on resume" {

        It "Create-Worktree must detect maintenance task by source=fallback" {
            ($content -match '\$IsMaintenanceTask = \$Task -and \$Task\.source -eq "fallback"') | Should Be $true
        }

        It "Create-Worktree must call Reset-WorktreeForMaintenance for maintenance tasks" {
            ($content -match 'Reset-WorktreeForMaintenance -WorktreePath \$ExistingWt\.worktreePath') | Should Be $true
        }

        It "Maintenance reset must be gated behind #2834 marker for traceability" {
            ($content -match '#2834 RESET worktree maintenance') | Should Be $true
        }

        It "Reset failure must be non-fatal (WARN, not abort)" {
            ($content -match 'Reset a échoué \(non-fatal\)') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # AC (b) : work-task run → worktree NOT reset (work preserved)
    # ---------------------------------------------------------------------------

    Context "AC (b) - work-task (source!=fallback) preserves resume semantics" {

        It "Work-task branch must still emit REPRISE (resume) log" {
            ($content -match 'REPRISE dans worktree existant') | Should Be $true
        }

        It "Work-task branch must still preserve changes (travail préservé)" {
            ($content -match 'changements existants seront préservés') | Should Be $true
        }

        It "Work-task branch must still inject CONTINUATION prompt context" {
            ($content -match 'CONTINUATION FROM PREVIOUS SESSION') | Should Be $true
        }

        It "Reset call must be inside the maintenance (IsMaintenanceTask) branch only" {
            # The reset call appears once (maintenance branch), the REPRISE log appears
            # inside the else (work-task) branch — both gated, no unconditional reset.
            ($content -match 'if \(\$IsMaintenanceTask\)') | Should Be $true
        }
    }

    # ---------------------------------------------------------------------------
    # Regression guard — UseWorktree early-return preserved (not broken by edit)
    # ---------------------------------------------------------------------------

    Context "Regression - Create-Worktree guard intact" {

        It "Create-Worktree must keep the UseWorktree early-return guard" {
            ($content -match 'if \(-not \$UseWorktree\)') | Should Be $true
        }

        It "Create-Worktree must keep the Worktree désactivé message" {
            ($content -match 'Worktree désactivé, travail sur branche principale') | Should Be $true
        }
    }
}
