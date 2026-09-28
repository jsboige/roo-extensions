# purge-shared-state-artifacts.Tests.ps1 — Pester 5 : DryRun par défaut + quarantaine manifestée
#
# Précédent harden-hidden-tasks.Tests.ps1 : l'hôte est pwsh 7 + Pester 5 ; la CIBLE
# tourne en process enfant powershell.exe 5.1, sur une COPIE du script dans un
# fixture jetable ( -SharedStatePath pointé dessus, quarantaine locale au fixture).
#
# Scénarios (audit 27/09, dispatch ai-01 16:05Z) :
#   1. SANS flag : dry-run — rien ne bouge
#   2. -Execute : fichiers déplacés en quarantaine (jamais supprimés), manifeste
#      SHA-256 ; desktop.ini / latest.json / rapports récents / rapports non-PHASE3A
#      restent en place ; les répertoires vidés sont retirés, celui qui garde
#      desktop.ini reste
#
# Exécution : pwsh -NoProfile -File scripts/testing/run-pester-tests.ps1 -Path scripts/gdrive/purge-shared-state-artifacts.Tests.ps1

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
    $script:SourceScript = Join-Path $script:RepoRoot 'scripts\gdrive\purge-shared-state-artifacts.ps1'
    $script:SourceCommon = Join-Path $script:RepoRoot 'scripts\common'
    $script:Fixtures = [System.Collections.Generic.List[string]]::new()
    $script:MachinePSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

    function New-PurgeFixture {
        $fx = Join-Path $env:TEMP ("purge-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path (Join-Path $fx 'scripts\gdrive') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fx 'scripts\common') -Force | Out-Null
        Copy-Item $script:SourceScript -Destination (Join-Path $fx 'scripts\gdrive\purge-shared-state-artifacts.ps1')
        Copy-Item (Join-Path $script:SourceCommon 'quarantine.ps1') -Destination (Join-Path $fx 'scripts\common\quarantine.ps1')

        $ss = Join-Path $fx 'shared-state'
        $ci = Join-Path $ss 'configs\ci-test-machine\sub'
        $tc = Join-Path $ss 'configs\test-machine-custom'
        $rp = Join-Path $ss 'reports'
        foreach ($d in @($ci, $tc, $rp)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

        Set-Content -LiteralPath (Join-Path $ci 'ci-residual.json') -Value '{"ci": 1}' -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $ss 'configs\ci-test-machine\desktop.ini') -Value '[.ShellClassInfo]' -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $tc 'custom.json') -Value '{"custom": 1}' -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $tc 'latest.json') -Value '{"latest": 1}' -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $tc 'desktop.ini') -Value '[.ShellClassInfo]' -Encoding ASCII

        $oldReport = Join-Path $rp 'PHASE3A-ANALYSE-old.md'
        Set-Content -LiteralPath $oldReport -Value '# old analyse' -Encoding ASCII
        (Get-Item $oldReport).LastWriteTime = (Get-Date).AddDays(-10)
        Set-Content -LiteralPath (Join-Path $rp 'PHASE3A-ANALYSE-fresh.md') -Value '# fresh analyse' -Encoding ASCII
        Set-Content -LiteralPath (Join-Path $rp 'OTHER-report.md') -Value '# other' -Encoding ASCII

        $script:Fixtures.Add($fx)
        return @{
            Root       = $fx
            Shared     = $ss
            CiSub      = $ci
            TestCustom = $tc
            Reports    = $rp
            Quarantine = (Join-Path $fx 'quarantine')
        }
    }

    function Invoke-PurgeChild {
        param([string]$Fixture, [string]$SharedState, [string]$Quarantine, [string[]]$ExtraArgs = @())
        $savedPmp = $env:PSModulePath
        try {
            $env:PSModulePath = $script:MachinePSModulePath
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
                (Join-Path $Fixture 'scripts\gdrive\purge-shared-state-artifacts.ps1') `
                -SharedStatePath $SharedState -QuarantineRoot $Quarantine @ExtraArgs 2>&1
            return ($out -join "`n")
        }
        finally {
            $env:PSModulePath = $savedPmp
        }
    }
}

AfterAll {
    foreach ($f in $script:Fixtures) {
        if ($f -and (Test-Path $f)) {
            Remove-Item $f -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
}

Describe 'purge-shared-state-artifacts — DryRun par défaut + quarantaine (child powershell.exe 5.1)' {
    It 'sans flag : dry-run, tout reste en place' {
        $fx = New-PurgeFixture
        $out = Invoke-PurgeChild -Fixture $fx.Root -SharedState $fx.Shared -Quarantine $fx.Quarantine
        $out | Should -Match 'DRY-RUN'
        Test-Path (Join-Path $fx.CiSub 'ci-residual.json') | Should -BeTrue
        Test-Path (Join-Path $fx.TestCustom 'custom.json') | Should -BeTrue
        Test-Path (Join-Path $fx.Reports 'PHASE3A-ANALYSE-old.md') | Should -BeTrue
        Test-Path $fx.Quarantine | Should -BeFalse
    }

    It '-Execute : quarantaine + manifeste SHA-256, fichiers protégés et fraîchement retenus en place' {
        $fx = New-PurgeFixture
        $out = Invoke-PurgeChild -Fixture $fx.Root -SharedState $fx.Shared -Quarantine $fx.Quarantine -ExtraArgs @('-Execute')
        $out | Should -Match 'QUARANTINED'

        # Déplacés (disparus de la source, présents en quarantaine) :
        Test-Path (Join-Path $fx.CiSub 'ci-residual.json') | Should -BeFalse
        Test-Path (Join-Path $fx.TestCustom 'custom.json') | Should -BeFalse
        Test-Path (Join-Path $fx.Reports 'PHASE3A-ANALYSE-old.md') | Should -BeFalse

        # Protégés :
        Test-Path (Join-Path $fx.Shared 'configs\ci-test-machine\desktop.ini') | Should -BeTrue
        Test-Path (Join-Path $fx.TestCustom 'latest.json') | Should -BeTrue
        Test-Path (Join-Path $fx.TestCustom 'desktop.ini') | Should -BeTrue
        Test-Path (Join-Path $fx.Reports 'PHASE3A-ANALYSE-fresh.md') | Should -BeTrue
        Test-Path (Join-Path $fx.Reports 'OTHER-report.md') | Should -BeTrue

        # Répertoire vidé entièrement (sub/) retiré ; celui qui garde desktop.ini reste :
        Test-Path $fx.CiSub | Should -BeFalse
        Test-Path (Join-Path $fx.Shared 'configs\ci-test-machine') | Should -BeTrue

        # Manifeste : 3 entrées, empreintes vérifiables sur un échantillon.
        $manifestFile = Get-ChildItem -Path $fx.Quarantine -Recurse -Filter 'manifest.json'
        $manifestFile.Count | Should -Be 1
        $manifest = (Get-Content $manifestFile[0].FullName -Raw | ConvertFrom-Json)
        $manifest.entries.Count | Should -Be 3
        $sample = $manifest.entries | Where-Object { $_.original -like '*PHASE3A-ANALYSE-old.md' }
        (Get-FileHash $sample.quarantined -Algorithm SHA256).Hash | Should -Be $sample.sha256
        (Get-Content $sample.quarantined -Raw) | Should -Match 'old analyse'
    }

    It '-Execute ET -DryRun ensemble : -DryRun gagne (conservateur)' {
        $fx = New-PurgeFixture
        $out = Invoke-PurgeChild -Fixture $fx.Root -SharedState $fx.Shared -Quarantine $fx.Quarantine -ExtraArgs @('-Execute', '-DryRun')
        $out | Should -Match 'DRY-RUN'
        Test-Path (Join-Path $fx.Reports 'PHASE3A-ANALYSE-old.md') | Should -BeTrue
    }
}
