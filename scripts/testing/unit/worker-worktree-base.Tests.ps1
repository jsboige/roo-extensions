# Worker worktree base — le worktree du worker part d'origin/main, pas du HEAD local (#3951).
#
# Incident po-2025 30/09 (auto-PR #3951, fermée doublon de #3931) : le checkout principal
# portait une branche locale en fusion à moitié faite (2 commits du 29/09 non poussés).
# `git worktree add <path> -b <branch>` SANS commit-ish part du HEAD de ce checkout —
# la branche worker a hérité des 2 commits préexistants et l'auto-PR les a poussés
# pendant que le run concluait « aucun changement repo → aucune PR requise ».
#
# Ces tests verrouillent la base explicite : la commande worktree add doit citer
# origin/main (fetch fraîchement exécuté dans la même fonction), jamais s'appuyer
# implicitement sur le HEAD local.
#
# Run:
#   powershell -ExecutionPolicy Bypass -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-worktree-base.Tests.ps1 -Output Detailed"

BeforeAll {
    # Pester 6 : un helper défini AU TOP-LEVEL du fichier de test fait échouer le container
    # (« break/continue escaped », Pester#2669) — le définir ICI, dans le BeforeAll.
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
    $script:fnCreate = Get-WorkerFnBody -Content $script:content -Name 'Create-Worktree'
}

Describe "Worker - le worktree worker part d'origin/main, pas du HEAD local (#3951)" {

    Context "Base explicite a la creation" {

        It "Doit citer origin/main comme base du worktree add" {
            ($script:fnCreate.Length) | Should -BeGreaterThan 0
            ($script:fnCreate -match 'worktree add') | Should -Be $true
            # La base explicite dans la COMMANDE : sans elle, git part du HEAD du
            # checkout principal — branche locale en fusion = commits préexistants
            # poussés par l'auto-PR (cas po-2025 30/09).
            ($script:fnCreate -match '-b \$BranchName origin/main') | Should -Be $true
        }

        It "Doit fetcher origin/main avant la creation (base explicite fraiche)" {
            $fetchPos = $script:fnCreate.IndexOf('fetch origin main')
            $addPos = $script:fnCreate.IndexOf('worktree add')
            $fetchPos | Should -BeGreaterThan 0
            $addPos | Should -BeGreaterThan $fetchPos
        }
    }
}
