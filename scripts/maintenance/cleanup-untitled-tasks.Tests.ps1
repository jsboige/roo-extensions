# cleanup-untitled-tasks.Tests.ps1 — Pester 5 : DryRun par défaut + quarantaine manifestée
#
# Précédent harden-hidden-tasks.Tests.ps1 : l'hôte est pwsh 7 + Pester 5 ; la CIBLE
# tourne en process enfant powershell.exe 5.1, sur une COPIE du script dans un
# fixture jetable (APPDATA/LOCALAPPDATA du process enfant redirigés vers le fixture
# via l'environnement — Get-GlobalStoragePath lit $env:APPDATA).
#
# Scénarios (audit 27/09, dispatch ai-01 16:05Z) :
#   1. SANS flag : dry-run — rien ne bouge (le défaut est non destructeur)
#   2. -Execute : la tâche "Untitled" est DÉPLACÉE en quarantaine (jamais supprimée),
#      manifest.json porte le SHA-256 du fichier, le contenu quarantiné est intact
#   3. une tâche non-Untitled reste en place même avec -Execute
#
# Exécution : pwsh -NoProfile -File scripts/testing/run-pester-tests.ps1 -Path scripts/maintenance/cleanup-untitled-tasks.Tests.ps1

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
    $script:SourceScript = Join-Path $script:RepoRoot 'scripts\maintenance\cleanup-untitled-tasks.ps1'
    $script:SourceCommon = Join-Path $script:RepoRoot 'scripts\common'
    $script:Fixtures = [System.Collections.Generic.List[string]]::new()
    # Valeur Machine du PSModulePath : un enfant powershell.exe 5.1 spawné depuis un
    # hôte pwsh 7 hérite d'un PSModulePath pollué — Get-FileHash y devient « non
    # reconnu » (mesuré 26/09). On repart de la valeur machine.
    $script:MachinePSModulePath = [Environment]::GetEnvironmentVariable('PSModulePath', 'Machine')

    function New-UtxFixture {
        $fx = Join-Path $env:TEMP ("utx-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        # Copie du script + des helpers qu'il dot-source (chemins relatifs à $PSScriptRoot).
        New-Item -ItemType Directory -Path (Join-Path $fx 'scripts\maintenance') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fx 'scripts\common') -Force | Out-Null
        Copy-Item $script:SourceScript -Destination (Join-Path $fx 'scripts\maintenance\cleanup-untitled-tasks.ps1')
        Copy-Item (Join-Path $script:SourceCommon 'extension-paths.ps1') -Destination (Join-Path $fx 'scripts\common\extension-paths.ps1')
        Copy-Item (Join-Path $script:SourceCommon 'quarantine.ps1') -Destination (Join-Path $fx 'scripts\common\quarantine.ps1')

        # Faux APPDATA/LOCALAPPDATA avec le stockage Roo (chemin 1 = APPDATA via
        # Get-GlobalStoragePath, chemin 2 = LOCALAPPDATA direct).
        $extId = 'rooveterinaryinc.roo-cline'
        $gsBase = Join-Path (Join-Path (Join-Path (Join-Path $fx 'rooAppData') 'Code\User') 'globalStorage') $extId
        $fxData = Join-Path $gsBase 'data'
        New-Item -ItemType Directory -Path $fxData -Force | Out-Null

        $untitled = Join-Path $fxData 'Untitled Task 42'
        New-Item -ItemType Directory -Path $untitled -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $untitled 'ui_messages.json') -Value '{"title": "Untitled Task"}' -Encoding ASCII

        $legit = Join-Path $fxData 'Real Task 7'
        New-Item -ItemType Directory -Path $legit -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $legit 'ui_messages.json') -Value '{"title": "Real work"}' -Encoding ASCII

        $script:Fixtures.Add($fx)
        return @{
            Root       = $fx
            Data       = $fxData
            Untitled   = $untitled
            Legit      = $legit
            Quarantine = (Join-Path $fx 'quarantine')
        }
    }

    function Invoke-UtxChild {
        param([string]$Fixture, [string[]]$ExtraArgs = @())
        $savedPath = $env:PATH
        $savedAppData = $env:APPDATA
        $savedLocalAppData = $env:LOCALAPPDATA
        $savedPmp = $env:PSModulePath
        try {
            $env:PSModulePath = $script:MachinePSModulePath
            $env:APPDATA = Join-Path $Fixture 'rooAppData'
            $env:LOCALAPPDATA = Join-Path $Fixture 'rooLocalAppData'
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
                (Join-Path $Fixture 'scripts\maintenance\cleanup-untitled-tasks.ps1') @ExtraArgs 2>&1
            return ($out -join "`n")
        }
        finally {
            $env:PATH = $savedPath
            $env:APPDATA = $savedAppData
            $env:LOCALAPPDATA = $savedLocalAppData
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

Describe 'cleanup-untitled-tasks — DryRun par défaut + quarantaine (child powershell.exe 5.1)' {
    It 'sans flag : dry-run, la tâche Untitled reste en place' {
        $fx = New-UtxFixture
        $out = Invoke-UtxChild -Fixture $fx.Root
        $out | Should -Match '\[DRY RUN\]'
        Test-Path $fx.Untitled | Should -BeTrue
        (Get-ChildItem (Join-Path $fx.Untitled '*')).Count | Should -Be 1
    }

    It '-Execute : tâche déplacée en quarantaine, manifeste SHA-256, contenu intact' {
        $fx = New-UtxFixture
        $out = Invoke-UtxChild -Fixture $fx.Root -ExtraArgs @('-Execute', '-QuarantineRoot', $fx.Quarantine)
        $out | Should -Match 'Quarantine complete'
        Test-Path $fx.Untitled | Should -BeFalse

        $manifestFile = Get-ChildItem -Path $fx.Quarantine -Recurse -Filter 'manifest.json'
        $manifestFile.Count | Should -Be 1
        $manifest = (Get-Content $manifestFile[0].FullName -Raw | ConvertFrom-Json)
        $manifest.entries.Count | Should -Be 1
        $entry = $manifest.entries[0]
        $entry.original | Should -Match 'Untitled Task 42'

        $quarantinedFile = Get-ChildItem -Path $fx.Quarantine -Recurse -Filter 'ui_messages.json'
        $quarantinedFile.Count | Should -Be 1
        (Get-FileHash $quarantinedFile[0].FullName -Algorithm SHA256).Hash | Should -Be $entry.sha256
        (Get-Content $quarantinedFile[0].FullName -Raw) | Should -Match 'Untitled Task'
    }

    It '-Execute : une tâche non-Untitled reste en place' {
        $fx = New-UtxFixture
        $out = Invoke-UtxChild -Fixture $fx.Root -ExtraArgs @('-Execute', '-QuarantineRoot', $fx.Quarantine)
        Test-Path $fx.Legit | Should -BeTrue
        (Get-ChildItem (Join-Path $fx.Legit '*')).Count | Should -Be 1
    }
}
