# Tests unitaires pour les lectures de commentaires du worker script.
# Historique : cette suite validait les expressions jq `gh issue view --json
# comments --jq ...` de start-claude-worker.ps1 sur un fixture offline (#3216).
# Lot 8 (#4150) : les fenêtres jq [-5:]/[-10:]/[-20:] ont disparu avec la
# conversion REST — les commentaires passent par le module gh-issues.ps1
# (Get-IssueComments) et la fenêtre est un Select-Object -Last N. La classe de
# bug que cette suite gardait (quoting des expressions jq inline sous PS 5.1,
# #3045 : les guillemets internes mangés par cmd /c) disparaît AVEC le jq ; ce
# qui reste gardé : ne pas réintroduire de sous-commande `gh issue view`, et le
# câblage module + fenêtre côté PowerShell. Les expressions jq du module sont
# testées dans gh-issues-rest.Tests.ps1.
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-jq-expressions.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw
}

Describe "Worker Script - comment reads" {

    Context "Script file validation" {
        It "start-claude-worker.ps1 must exist" {
            Test-Path $workerScript | Should -Be $true
        }

        It "Must NOT use inline jq test() with bracket escapes (regression guard)" {
            # Inline test() with \[ breaks with new jq versions AND PowerShell quoting
            ($content -match "--jq '.*test\(") | Should -Be $false
        }

        It "Comment reads go through the REST module, never `gh issue view` (lot 8)" {
            # Lot 8 (#4150, doctrine #4604) : les lectures de commentaires sont
            # déléguées à Get-IssueComments (module REST, 0 point GraphQL) et les
            # fenêtres [-N:] de l'ancien jq sont des Select-Object -Last N.
            ($content -match 'Get-IssueComments') | Should -Be $true
            ($content -match 'Select-Object -Last \d+') | Should -Be $true
            # Anti-régression : la sous-commande GraphQL-consommatrice ne revient
            # pas — ni en code, ni en prose (le scan de harness du fichier lit tout).
            ($content -match 'gh issue view') | Should -Be $false
        }
    }
}

Describe "Worker Script - Model Guard" {

    Context "Harness size documentation" {
        It "Must NOT reference 114K tokens (obsolete)" {
            ($content -match '114K tokens') | Should -Be $false
        }

        It "Must reference updated harness size (~24K tokens)" {
            ($content -match '24K tokens') | Should -Be $true
        }
    }

    Context "Minimum model configuration" {
        # The assignment became conditional in #2144 (idle-coverage→sonnet exception
        # + IdleMinModel override): `$MinimumModel = if ($script:IdleMinModel) {...}`.
        # The old literal-form assertion (`$MinimumModel = "haiku"`) went permanently
        # red after that. Assert the guard exists (variable assigned + model hierarchy
        # for comparison), independent of the assignment form — so the test survives
        # future conditional-form changes while still catching removal of the guard.
        It "MinimumModel guard must be defined (#747 context-window overflow prevention)" {
            ($content -match '\$MinimumModel\s*=') | Should -Be $true
        }

        It "Model hierarchy must be defined for minimum-model comparison" {
            ($content -match '\$ModelHierarchy\s*=\s*@\{') | Should -Be $true
        }
    }
}
