# Tests unitaires pour l'exclusion des labels gated dans start-claude-worker.ps1
# et .roo/scheduler-workflow-executor.md (suite #4045, dispatch ai-01 c1853).
#
# #4045 a ferme le trou COTE PICKER (co-occurrence grain+gated servie au tirage) ;
# le meme trou existait COTE WORKER : le filtre aval de Get-GitHubTask ne skippait
# que `needs-approval` — une issue `blocked-on-gate` (+ label actionnable ou non)
# restait prenable par le worker autonome, contournant la porte que le label pose.
# Mesure ai-01 03/10 : 3 issues ouvertes portent `blocked-on-gate` aujourd'hui.
#
# Content-guards Pester v5 — exécutés en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Les regex sont ancrées aux formes réelles
# du code (skip `$LabelNames -contains`, requête gh `-label:`) pour ne pas passer
# sur une mention morte en commentaire.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-gated-labels.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw
    $rooWorkflow = Join-Path $projectRoot ".roo/scheduler-workflow-executor.md"
    $rooContent = Get-Content $rooWorkflow -Raw
}

Describe "Worker Script - labels gated (suite #4045)" {

    Context "Filtre aval Get-GitHubTask" {
        It "Skip les issues needs-approval ET blocked-on-gate (classe attente humaine/gate)" {
            ($content -match '\$LabelNames\s+-contains\s+"needs-approval"') | Should -Be $true
            ($content -match '\$LabelNames\s+-contains\s+"blocked-on-gate"') | Should -Be $true
        }

        It "Les deux labels gated sont skips dans le MEME garde (une seule porte, pas deux)" {
            # La regression originelle etait un garde qui ne couvrait qu'un label de la classe ;
            # exiger les deux dans la meme condition `if` evite le retour d'un skip partiel.
            ($content -match 'if\s*\(\s*\$LabelNames\s+-contains\s+"needs-approval"\s+-or\s+\$LabelNames\s+-contains\s+"blocked-on-gate"\s*\)') | Should -Be $true
        }
    }

    Context "Commentaire de la requete serveur (l.682+)" {
        It "Ne cite plus la reference de ligne perimee (en aval l.656)" {
            # La ref « l.656 » datait d'une revision anterieure : le filtre aval a
            # demenage. Une ref de ligne brute pourrit — elle doit nommer le filtre, pas la ligne.
            ($content -match 'en aval l\.656') | Should -Be $false
        }
    }
}

Describe "Roo scheduler workflow - vivier dispatch" {

    Context "Requete de l'etape 1b-2" {
        It "La requete gh exclut blocked-on-gate" {
            ($rooContent -match '-label:blocked-on-gate') | Should -Be $true
        }

        It "La requete gh garde les exclusions historiques (anti-suppression accidentelle)" {
            foreach ($lbl in @('claude-only', 'needs-approval', 'harness-change', 'deferred', 'epic', 'frozen')) {
                ($rooContent -match [regex]::Escape("-label:$lbl")) | Should -Be $true
            }
        }
    }
}
