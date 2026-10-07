# eval-harness-verdicts.Tests.ps1 — garde : un run storm-guardé ne doit pas lire comme PASS.
#
# Régression gardée ici (mesurée le 2026-10-08 sur ai-01) : le backend d'embeddings a rendu
# 500, le storm guard a tiré, chaque scénario a court-circuité au vert, et le wrapper a
# résumé le run « 7 PASS / 0 FAIL » avec exit 0 — un banc qui n'a rien mesuré qui rapporte un
# succès. Les fixtures ci-dessous recréent cette forme de log (marqueurs de fichier vitest +
# marqueur [INCONCLUSIVE] sous son entête de flux).
#
# Exécution : pwsh -NoProfile -File scripts/testing/run-pester-tests.ps1 -Path scripts/claude/eval-harness-verdicts.Tests.ps1

BeforeAll {
    $script:HelperPath = Join-Path $PSScriptRoot 'eval-harness-verdicts.ps1'
    $script:WrapperPath = Join-Path $PSScriptRoot 'run-eval-harness.ps1'
    . $script:HelperPath

    # Les quatre scénarios de la fixture, dans l'ordre du $scenarioMap du wrapper.
    $script:AllFiles = @(
        'roosync-search.eval.test.ts'
        'codebase-search.eval.test.ts'
        'conversation-browser.eval.test.ts'
        'v2-block-granularity.eval.test.ts'
    )

    $script:ScenarioMap = [ordered]@{}
    foreach ($f in $script:AllFiles) { $script:ScenarioMap[$f] = @{ label = $f; tool = '' } }

    # Fabrique de lignes de log AUTO-CONTENUE : ni $script: ni appel croisé entre fonctions
    # définies dans BeforeAll (leur portée ne se résout pas de façon fiable sous Pester).
    # Renvoie un tableau de lignes, à concaténer avec `+=`.
    function New-EvalLogLine {
        param(
            [Parameter(Mandatory)][string]$File,
            [Parameter(Mandatory)][ValidateSet('storm', 'pass', 'fail')][string]$Kind
        )
        $marker = [string][char]0x2713
        switch ($Kind) {
            'storm' {
                @(
                    "stdout | tests/eval-harness/tools/$File > some test > case"
                    '[INCONCLUSIVE] Storm guard active: Qdrant index not healthy (status=degraded). Errors: Erreur OpenAI: 500 500 Internal Server Error'
                    ''
                    " $marker tests/eval-harness/tools/$File (1 test) 500ms"
                )
            }
            'pass' { @(" $marker tests/eval-harness/tools/$File (1 test) 500ms") }
            'fail' { @("FAIL tests/eval-harness/tools/$File (1 test | 1 failed)") }
        }
    }

    function New-StormGuardedLog {
        $reason = '[INCONCLUSIVE] Storm guard active: Qdrant index not healthy (status=degraded). Errors: Erreur OpenAI: 500 500 Internal Server Error'
        $marker = [string][char]0x2713
        $files = @(
            'roosync-search.eval.test.ts'
            'codebase-search.eval.test.ts'
            'conversation-browser.eval.test.ts'
            'v2-block-granularity.eval.test.ts'
        )
        $lines = @()
        foreach ($f in $files) {
            $lines += "stdout | tests/eval-harness/tools/$f > some test > case"
            $lines += $reason
            $lines += ''
            $lines += " $marker tests/eval-harness/tools/$f (1 test) 500ms"
        }
        return , $lines
    }

    function Get-RunSuccess {
        param($Result)
        return Test-EvalHarnessRunSuccess -PassCount $Result.PassCount -FailCount $Result.FailCount `
            -InconclusiveCount $Result.InconclusiveCount -MissingCount $Result.MissingCount
    }
}

Describe 'Get-EvalHarnessScenarioResults — le storm guard ne doit pas lire comme PASS' {

    It 'un run entièrement storm-guardé classe chaque scénario INCONCLUSIVE, aucun PASS' {
        $r = Get-EvalHarnessScenarioResults -LogLines (New-StormGuardedLog) -ScenarioMap $script:ScenarioMap

        $r.PassCount | Should -Be 0
        $r.InconclusiveCount | Should -Be 4
        $r.FailCount | Should -Be 0
        $r.MissingCount | Should -Be 0
        @($r.Scenarios | Where-Object { $_.Verdict -ne 'INCONCLUSIVE' }).Count | Should -Be 0
    }

    It 'un run entièrement storm-guardé n_est PAS un succès' {
        $r = Get-EvalHarnessScenarioResults -LogLines (New-StormGuardedLog) -ScenarioMap $script:ScenarioMap

        Get-RunSuccess -Result $r | Should -BeFalse
    }

    It 'porte la raison du storm guard en détail, pour le résumé dashboard' {
        $r = Get-EvalHarnessScenarioResults -LogLines (New-StormGuardedLog) -ScenarioMap $script:ScenarioMap

        @($r.Scenarios | Where-Object { $_.Verdict -eq 'INCONCLUSIVE' -and $_.Detail -like '*500 Internal Server Error*' }).Count | Should -Be 4
    }

    It 'attribue le marqueur au fichier nommé par l_entête de flux la plus proche (pas à tous)' {
        $lines = @()
        $lines += (New-EvalLogLine -File 'v2-block-granularity.eval.test.ts' -Kind 'storm')
        foreach ($f in @('roosync-search.eval.test.ts', 'codebase-search.eval.test.ts', 'conversation-browser.eval.test.ts')) {
            $lines += (New-EvalLogLine -File $f -Kind 'pass')
        }

        $r = Get-EvalHarnessScenarioResults -LogLines $lines -ScenarioMap $script:ScenarioMap

        $r.InconclusiveCount | Should -Be 1
        $r.PassCount | Should -Be 3
        @($r.Scenarios | Where-Object { $_.File -eq 'v2-block-granularity.eval.test.ts' }).Verdict | Should -Be 'INCONCLUSIVE'
        @($r.Scenarios | Where-Object { $_.File -eq 'roosync-search.eval.test.ts' }).Verdict | Should -Be 'PASS'
    }

    It 'un storm partiel garde les scénarios sains en PASS et le run en succès' {
        $lines = @()
        $lines += (New-EvalLogLine -File 'v2-block-granularity.eval.test.ts' -Kind 'storm')
        foreach ($f in @('roosync-search.eval.test.ts', 'codebase-search.eval.test.ts', 'conversation-browser.eval.test.ts')) {
            $lines += (New-EvalLogLine -File $f -Kind 'pass')
        }

        $r = Get-EvalHarnessScenarioResults -LogLines $lines -ScenarioMap $script:ScenarioMap
        $r.PassCount | Should -Be 3
        $r.InconclusiveCount | Should -Be 1
        $r.MissingCount | Should -Be 0

        Get-RunSuccess -Result $r | Should -BeTrue
    }

    It 'un FAIL réel reste FAIL (la garde ne masque pas un vrai rouge)' {
        $lines = @()
        $lines += (New-EvalLogLine -File 'codebase-search.eval.test.ts' -Kind 'fail')
        foreach ($f in @('roosync-search.eval.test.ts', 'conversation-browser.eval.test.ts', 'v2-block-granularity.eval.test.ts')) {
            $lines += (New-EvalLogLine -File $f -Kind 'pass')
        }

        $r = Get-EvalHarnessScenarioResults -LogLines $lines -ScenarioMap $script:ScenarioMap

        $r.FailCount | Should -Be 1
        $r.PassCount | Should -Be 3
        $r.InconclusiveCount | Should -Be 0
        @($r.Scenarios | Where-Object { $_.File -eq 'codebase-search.eval.test.ts' }).Verdict | Should -Be 'FAIL'
        Get-RunSuccess -Result $r | Should -BeFalse
    }

    It 'un scénario absent du log est MISSING et fait échouer le run' {
        $lines = @( (New-EvalLogLine -File 'roosync-search.eval.test.ts' -Kind 'pass') )

        $r = Get-EvalHarnessScenarioResults -LogLines $lines -ScenarioMap $script:ScenarioMap

        $r.MissingCount | Should -Be 3
        Get-RunSuccess -Result $r | Should -BeFalse
    }

    It 'un timeout fait échouer le run quels que soient les compteurs' {
        Test-EvalHarnessRunSuccess -PassCount 7 -FailCount 0 -InconclusiveCount 0 -MissingCount 0 -TimedOut | Should -BeFalse
    }

    It 'un run entièrement vert est un succès' {
        Test-EvalHarnessRunSuccess -PassCount 7 -FailCount 0 -InconclusiveCount 0 -MissingCount 0 | Should -BeTrue
    }
}

Describe 'câblage du wrapper (statique)' {

    It 'run-eval-harness.ps1 dot-source le classifieur et l_utilise pour le résumé et l_exit' {
        $src = Get-Content -Path $script:WrapperPath -Raw -Encoding UTF8

        $src | Should -Match ([regex]::Escape('. "$PSScriptRoot\eval-harness-verdicts.ps1"'))
        $src | Should -Match 'Get-EvalHarnessScenarioResults'
        $src | Should -Match 'Test-EvalHarnessRunSuccess'
        $src | Should -Match 'INCONCLUSIVE'
    }
}
