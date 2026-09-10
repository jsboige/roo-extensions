# Tests unitaires pour les watchguards D4/D13 (#3381, PR #3561 corrections)
# - flag-discussion-without-pr.ps1 : pagination de la timeline + contrat de
#   reporting (une PR de rapport ne doit pas dé-flagger ce qu'elle mesure)
# - production-attribution.ps1 : le résumé shared-identity compte le set
#   COMPLET des auteurs de commits, pas le premier
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Payloads 100% fictifs : aucun réseau,
# aucune auth gh, aucun credential (gh est mocké au niveau Pester).
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/watchguard-d4-d13.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/github/flag-discussion-without-pr.ps1")
    . (Join-Path $projectRoot "scripts/github/production-attribution.ps1")

    # --- Fixtures D4 (fictives) -------------------------------------------
    # Issue #100 : timeline > 100 événements. Page 1 = 100 événements sans
    # cross-ref ; le cross-ref PR vit sur la PAGE 2 (le bug d'origine lisait
    # la page 1 seule et rendait 0).
    $filler = @(1..100 | ForEach-Object { [pscustomobject]@{ event = 'commented' } })
    $execCrossRef = [pscustomobject]@{
        event  = 'cross-referenced'
        source = @{ issue = @{ number = 55; title = 'fix: real execution work'; pull_request = @{ url = 'https://api.github.com/repos/jsboige/roo-extensions/pulls/55' } } }
    }
    $reportCrossRef = [pscustomobject]@{
        event  = 'cross-referenced'
        source = @{ issue = @{ number = 61; title = 'watchguard: D4 report 2026-09-10'; pull_request = @{ url = 'https://api.github.com/repos/jsboige/roo-extensions/pulls/61' } } }
    }
    $script:D4_100_P1 = ConvertTo-Json $filler -Compress -Depth 6
    $script:D4_100_P2 = ConvertTo-Json (@($filler[0..48]) + @($execCrossRef)) -Compress -Depth 6
    # Issue #200 : timeline courte (40 événements) — une seule page doit être lue.
    $script:D4_200 = ConvertTo-Json (@($filler[0..38]) + @($reportCrossRef)) -Compress -Depth 6
    # Issue #300 : cross-ref UNIQUEMENT d'une PR de rapport watchguard → ignorée.
    $script:D4_300 = ConvertTo-Json @($reportCrossRef, $filler[0]) -Compress -Depth 6
    # Issue #400 : cross-ref d'une PR d'exécution → comptée.
    $script:D4_400 = ConvertTo-Json @($execCrossRef, $filler[0]) -Compress -Depth 6
}

Describe 'flag-discussion-without-pr — timeline pagination (PR #3561 review §1)' {
    BeforeEach {
        Mock gh {
            $call = $args -join ' '
            # Ancres $ obligatoires : "per_page=100" contient la sous-chaîne
            # "page=1" — sans ancre, la page 2 matcherait la règle de la page 1.
            if ($call -match 'issues/100/timeline.+[&?]page=1$') { return $script:D4_100_P1 }
            if ($call -match 'issues/100/timeline.+[&?]page=2$') { return $script:D4_100_P2 }
            if ($call -match 'issues/200/timeline') { return $script:D4_200 }
            return '[]'
        }
    }

    It 'compte un cross-ref PR qui vit sur la page 2 (>100 événements)' {
        Get-CrossReferencedPrCount -Number 100 | Should -Be 1
    }

    It 'ne lit pas de 2e page quand la 1re est incomplète (<100 événements)' {
        Get-CrossReferencedPrCount -Number 200 | Should -Be 0
        Should -Invoke gh -Exactly 1
    }
}

Describe 'flag-discussion-without-pr — reporting contract, anti self-unflag (PR #3561 review §2)' {
    BeforeEach {
        Mock gh {
            $call = $args -join ' '
            if ($call -match 'issues/300/timeline') { return $script:D4_300 }
            if ($call -match 'issues/400/timeline') { return $script:D4_400 }
            return '[]'
        }
    }

    It 'ignore les cross-refs des PRs de rapport watchguard (l''issue reste flaggée)' {
        Get-CrossReferencedPrCount -Number 300 | Should -Be 0
    }

    It 'compte toujours les cross-refs des PRs d''exécution (l''issue est dé-flaggée)' {
        Get-CrossReferencedPrCount -Number 400 | Should -Be 1
    }
}

Describe 'production-attribution — Test-SharedIdentityCandidate compte le set complet (PR #3561 review §3)' {
    It 'flagge un set mixte quand l''auteur PR est aussi premier committer (cas #3553)' {
        Test-SharedIdentityCandidate -PrAuthor 'jsboige' -CommitAuth 'jsboige <jsboige@example.invalid>; Claude <claude@example.invalid>' | Should -Be $true
    }

    It 'ne flagge pas un auteur unique cohérent avec le login PR' {
        Test-SharedIdentityCandidate -PrAuthor 'jsboige' -CommitAuth 'jsboige <jsboige@example.invalid>' | Should -Be $false
    }

    It 'flagge un auteur de commit totalement différent du login PR' {
        Test-SharedIdentityCandidate -PrAuthor 'myia-web1' -CommitAuth 'po-2023 <po2023@example.invalid>' | Should -Be $true
    }

    It 'entrées vides = jamais candidate' {
        Test-SharedIdentityCandidate -PrAuthor '' -CommitAuth '' | Should -Be $false
        Test-SharedIdentityCandidate -PrAuthor 'jsboige' -CommitAuth '' | Should -Be $false
    }
}
