# Tests unitaires pour les expressions jq du worker script
# Valide que les expressions jq utilisées par start-claude-worker.ps1 fonctionnent
# correctement (parsing dispatch/claim des commentaires d'issue).
#
# Syntaxe Pester v5 — exécuté en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1.
#
# NOTE (#3216) : les appels live `gh issue view` d'origine sont remplacés par un
# fixture JSON offline exécuté par le binaire jq directement — déterministe, sans
# réseau ni auth gh (l'ancienne version dépendait du contenu vivant des issues
# #1065/#1061 : un commentaire édité aurait fait rougir la CI pour rien). jq est
# préinstallé sur ubuntu-latest ; les Its sont Skipped (visibles, pas silencieux)
# si jq est absent du PATH local.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/worker-jq-expressions.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $workerScript = Join-Path $projectRoot "scripts/scheduling/start-claude-worker.ps1"
    $content = Get-Content $workerScript -Raw

    # Répliques exactes des expressions du worker (guillemets jq doubles, pas
    # d'échappement PowerShell) + fixture offline couvrant dispatch, claim,
    # fenêtrage [-N:], et caractères spéciaux (pipes, quotes).
    $script:JqExpr = '[.comments[-10:][] | .body | select(contains("[DISPATCH]") or contains("[CLAIMED]") or contains("[RESULT]"))]'
    $script:JqClaimExpr = '[.comments[-5:][] | .body | select(contains("[CLAIMED]"))]'
    $script:CommentsJson = @'
{"comments":[
  {"body":"[CLAIMED] po-2023 on it"},
  {"body":"noise: unrelated comment"},
  {"body":"plain update with | pipes | and \"quotes\""},
  {"body":"[DISPATCH] run audit on scripts/maintenance"},
  {"body":"[CLAIMED] taken by web1"},
  {"body":"[RESULT] success, PR #123 merged"}
]}
'@
    $script:JqAvailable = [bool](Get-Command jq -ErrorAction SilentlyContinue)
}

Describe "Worker Script - jq Expressions" {

    Context "Script file validation" {
        It "start-claude-worker.ps1 must exist" {
            Test-Path $workerScript | Should -Be $true
        }

        It "Must NOT use inline jq test() with bracket escapes (regression guard)" {
            # Inline test() with \[ breaks with new jq versions AND PowerShell quoting
            ($content -match "--jq '.*test\(") | Should -Be $false
        }

        It "Must use variable-based jq expressions for contains()" {
            # The fix: store jq expression in $jqExpr variable with escaped quotes
            ($content -match '\$jqExpr\s*=') | Should -Be $true
            ($content -match '\$jqClaimExpr\s*=') | Should -Be $true
        }
    }

    Context "jq dispatch parsing (offline fixture)" {

        It "Dispatch jq expression executes without error and selects only tagged bodies" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            $out = @($script:CommentsJson | jq -c $script:JqExpr)
            $LASTEXITCODE | Should -Be 0
            # [-10:] window covers the whole fixture: [CLAIMED]@0, [DISPATCH]@3, [CLAIMED]@4, [RESULT]@5
            $out.Count | Should -Be 4
            ($out -join "`n") | Should -Match '\[DISPATCH\]'
            ($out -join "`n") | Should -Not -Match 'unrelated comment'
        }

        It "Dispatch jq result is parseable JSON (one JSON string per line)" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            $out = @($script:CommentsJson | jq -c $script:JqExpr)
            $LASTEXITCODE | Should -Be 0
            $parsed = @($out | ForEach-Object { $_ | ConvertFrom-Json })
            $parsed.Count | Should -Be 4
            $parsed | Should -Contain '[DISPATCH] run audit on scripts/maintenance'
        }

        It "Must handle special characters in comment bodies (pipes, quotes — ex-live #1061)" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            # A body with embedded quotes/pipes must not break jq nor leak into selection
            $out = @($script:CommentsJson | jq -c $script:JqExpr)
            $LASTEXITCODE | Should -Be 0
            ($out -join "`n") | Should -Not -Match 'pipes'
        }
    }

    Context "jq claim parsing (offline fixture)" {

        It "Claim jq expression executes without error" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            $out = @($script:CommentsJson | jq -c $script:JqClaimExpr)
            $LASTEXITCODE | Should -Be 0
        }

        It "Claim jq result respects the [-5:] window (late claim only, early claim excluded)" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            # comments[-5:] = indices 1..5 → only the late [CLAIMED]@4 is selected;
            # the early [CLAIMED]@0 proves the window actually truncates.
            $out = @($script:CommentsJson | jq -c $script:JqClaimExpr)
            $out.Count | Should -Be 1
            $out[0] | ConvertFrom-Json | Should -Be '[CLAIMED] taken by web1'
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
