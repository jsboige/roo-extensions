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
    # d'échappement PowerShell) + fixture offline couvrant dispatch, claim-state,
    # fenêtrage [-N:], et caractères spéciaux (pipes, quotes).
    $script:JqExpr = '[.comments[-10:][] | .body | select(contains("[DISPATCH]") or contains("[CLAIMED]") or contains("[RESULT]"))]'
    # Claim-state (step 4 of Claim-GitHubIssue). Since #2428 it selects {body,
    # createdAt} objects — the lock-window/release logic lives in PowerShell
    # (Test-ConcurrentClaimActive, claim-lock.ps1), not in the jq filter.
    $script:JqStateExpr = '[.comments[-20:][] | {body: .body, createdAt: .createdAt}]'
    $script:CommentsJson = @'
{"comments":[
  {"body":"[CLAIMED] po-2023 on it","createdAt":"2026-09-21T08:00:00Z"},
  {"body":"noise: unrelated comment","createdAt":"2026-09-21T09:00:00Z"},
  {"body":"plain update with | pipes | and \"quotes\"","createdAt":"2026-09-21T10:00:00Z"},
  {"body":"[DISPATCH] run audit on scripts/maintenance","createdAt":"2026-09-21T11:00:00Z"},
  {"body":"[CLAIMED] taken by web1","createdAt":"2026-09-21T12:00:00Z"},
  {"body":"[RESULT] success, PR #123 merged","createdAt":"2026-09-21T13:00:00Z"}
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
            # The fix: store jq expression in $jqExpr variable with escaped quotes.
            # The claim-state expression stays variable-based too (#2428 rewrite):
            # it no longer uses jq contains(), but must remain a stored variable.
            ($content -match '\$jqExpr\s*=') | Should -Be $true
            ($content -match '\$jqCommentsExpr\s*=') | Should -Be $true
        }
    }

    Context "jq dispatch parsing (offline fixture)" {

        It "Dispatch jq expression executes without error and selects only tagged bodies" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            # jq -c (compact) : le tableau sort sur UNE ligne, comme le --jq de gh —
            # c'est la forme que le worker consomme réellement.
            $out = @($script:CommentsJson | jq -c $script:JqExpr)
            $LASTEXITCODE | Should -Be 0
            $parsed = @(($out -join "`n") | ConvertFrom-Json)
            # [-10:] window covers the whole fixture: [CLAIMED]@0, [DISPATCH]@3, [CLAIMED]@4, [RESULT]@5
            $parsed.Count | Should -Be 4
            ($parsed -join "`n") | Should -Match '\[DISPATCH\]'
            ($parsed -join "`n") | Should -Not -Match 'unrelated comment'
        }

        It "Dispatch jq result is parseable JSON (compact array, like gh --jq output)" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            $out = @($script:CommentsJson | jq -c $script:JqExpr)
            $LASTEXITCODE | Should -Be 0
            $parsed = @(($out -join "`n") | ConvertFrom-Json)
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

    Context "jq claim-state parsing (offline fixture, #2428)" {

        It "Claim-state jq expression executes without error" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            $out = @($script:CommentsJson | jq -c $script:JqStateExpr)
            $LASTEXITCODE | Should -Be 0
        }

        It "Claim-state jq result carries {body, createdAt} objects for the lock-window check" {
            if (-not $script:JqAvailable) { Set-ItResult -Skipped -Because 'jq not on PATH (preinstalled on ubuntu-latest CI)' }
            # [-20:] covers the whole 6-comment fixture; each entry must carry the
            # two fields Test-ConcurrentClaimActive reads (the [CLAIMED] filter
            # itself moved to PowerShell in #2428).
            $out = @($script:CommentsJson | jq -c $script:JqStateExpr)
            $parsed = @(($out -join "`n") | ConvertFrom-Json)
            $parsed.Count | Should -Be 6
            $props = ($parsed[0].PSObject.Properties.Name | Sort-Object) -join ','
            $props | Should -Be 'body,createdAt'
            # Edition-independent compare: pwsh 7 ConvertFrom-Json deserializes
            # ISO dates to [datetime] (ToString = "...:00.0000000Z"), PS 5.1
            # keeps the raw string. Normalize datetimes back to the wire form.
            $raw = $parsed[4].createdAt
            $norm = if ($raw -is [datetime]) { $raw.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } else { "$raw" }
            $norm | Should -Be '2026-09-21T12:00:00Z'
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
