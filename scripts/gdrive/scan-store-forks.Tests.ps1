# scan-store-forks.Tests.ps1 — la sonde est un INVENTAIRE, jamais une mutation
#
# Précedent purge-shared-state-artifacts.Tests.ps1 : l'hôte est pwsh 7 + Pester 5 ;
# la CIBLE tourne en process enfant powershell.exe 5.1, sur le store d'un fixture
# jetable ( -SharedStatePath pointé dessus).
#
# ASSERTIONS EN `throw` (et non `Should -Be`) : le DSL `Should` a changé de forme
# entre Pester 3.4 (dispo en PS 5.1), Pester 5 (CI) et Pester 6 (exige PS 7).
# Un `throw` dans un bloc It est un echec de test dans les TROIS versions, et le
# siege (po-2028) n'a pas pwsh : la suite doit etre executable partout.
#
# Scénarios (grain G2, po-2028, 30/10/2026) :
#   1. un jumeau sans canonique  -> état 'canonical-absent'
#   2. un canonique vide + un jumeau plein -> état 'canonical-empty'
#   3. canonique et jumeaux pleins -> état 'content-split'
#   4. un nom SANS marqueur de conflit n'est jamais un jumeau
#   5. le fixture est BIT POUR BIT identique après le passage (contrat lecture seule)
#   6. -Hash calcule l'empreinte SHA-256 d'un jumeau FICHIER
#   7. -Json rend un JSON exploitable ; code de sortie 1 (fork) / 0 (aucun) / 2 (chemin absent)
#
# Exécution : pwsh -NoProfile -File scripts/testing/run-pester-tests.ps1 -Path scripts/gdrive/scan-store-forks.Tests.ps1
#             (ou, sur un siege sans pwsh : powershell -NoProfile -Command "Invoke-Pester -Path scripts\gdrive\scan-store-forks.Tests.ps1")

Describe 'scan-store-forks (G2)' {
    BeforeAll {
        $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
        $script:SourceScript = Join-Path $script:RepoRoot 'scripts\gdrive\scan-store-forks.ps1'
        $script:Fixtures = New-Object System.Collections.Generic.List[string]

        function Assert-That {
            param([bool]$Condition, [string]$Message)
            if (-not $Condition) { throw $Message }
        }

        function New-ForkFixture {
            $fx = Join-Path $env:TEMP ("forkscan-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
            $ss = Join-Path $fx 'shared-state'
            New-Item -ItemType Directory -Path (Join-Path $ss 'messages') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $ss 'messages (1)') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $ss 'messages (2)') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $ss 'inventories') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $ss 'inventories (1)') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $ss 'dashboards') -Force | Out-Null

            # 1. jumeau seul, canonique absent
            Set-Content -LiteralPath (Join-Path $ss '.machine-registry (1).json') -Value '{"machines":{}}' -Encoding ASCII
            # 3. messages : canonique (1 fichier) + jumeaux (2 puis 0)
            Set-Content -LiteralPath (Join-Path $ss 'messages\a.json') -Value '{"id":"a"}' -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $ss 'messages (1)\b.json') -Value '{"id":"b"}' -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $ss 'messages (1)\c.json') -Value '{"id":"c"}' -Encoding ASCII
            # 2. inventories : canonique VIDE + jumeau plein
            Set-Content -LiteralPath (Join-Path $ss 'inventories (1)\i1.json') -Value '{"id":"i1"}' -Encoding ASCII
            # 4. nom sans marqueur de conflit -> jamais un jumeau
            Set-Content -LiteralPath (Join-Path $ss 'notes.md') -Value '# notes' -Encoding ASCII
            Set-Content -LiteralPath (Join-Path $ss 'dashboards\workspace-x.md') -Value '# x' -Encoding ASCII

            $script:Fixtures.Add($fx)
            return $ss
        }

        function Get-TreeFingerprint {
            param([string]$Root)
            $lines = @(Get-ChildItem -LiteralPath $Root -Recurse -Force -File | Sort-Object FullName | ForEach-Object {
                $h = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
                "{0}|{1}|{2}" -f $_.FullName.Substring($Root.Length), $_.Length, $h
            })
            return ($lines -join "`n")
        }

        function Invoke-Scan {
            param([string]$SharedState, [string[]]$ExtraArgs = @())
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:SourceScript `
                -SharedStatePath $SharedState @ExtraArgs 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($out | Out-String)
            }
        }
    }

    AfterAll {
        foreach ($fx in $script:Fixtures) {
            if (Test-Path -LiteralPath $fx) {
                Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }


    It 'detecte un jumeau dont le canonique est ABSENT' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1 (fork detecte), obtenu $($r.ExitCode)"
        Assert-That ($r.Output -match 'CANONICAL-ABSENT') "etat canonical-absent absent de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('.machine-registry.json')) "le nom canonique du registre absent de la sortie"
    }

    It 'classe un canonique vide et un jumeau plein en canonical-empty' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss
        Assert-That ($r.Output -match 'CANONICAL-EMPTY') "etat canonical-empty absent de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories')) "le groupe inventories absent de la sortie"
    }

    It 'classe deux moities pleines en content-split et compte les jumeaux' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss
        Assert-That ($r.Output -match 'CONTENT-SPLIT') "etat content-split absent de la sortie"
        Assert-That ($r.Output -match 'jumeau \(1\)') "le jumeau (1) absent de la sortie"
        Assert-That ($r.Output -match 'jumeau \(2\)') "le jumeau (2) absent de la sortie"
    }

    It 'ne traite jamais un nom sans marqueur de conflit comme un jumeau' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss
        Assert-That (-not ($r.Output -match 'notes\.md')) "notes.md ne doit pas etre signale comme jumeau"
        Assert-That (-not ($r.Output -match 'workspace-x')) "workspace-x ne doit pas etre signale comme jumeau"
    }

    It 'ne modifie RIEN : le fixture est identique avant et apres (contrat lecture seule)' {
        $ss = New-ForkFixture
        $before = Get-TreeFingerprint -Root $ss
        $null = Invoke-Scan -SharedState $ss
        $after = Get-TreeFingerprint -Root $ss
        Assert-That ($after -eq $before) "la sonde a modifie le store : le contrat lecture seule est rompu"
    }

    It 'calcule l''empreinte SHA-256 d''un jumeau FICHIER avec -Hash' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss -ExtraArgs @('-Hash')
        Assert-That ($r.Output -match 'sha256=[0-9A-F]{64}') "aucune empreinte SHA-256 dans la sortie"
    }

    It 'rend un JSON exploitable (groupCount + etats)' {
        $ss = New-ForkFixture
        $r = Invoke-Scan -SharedState $ss -ExtraArgs @('-Json')
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1, obtenu $($r.ExitCode)"
        $payload = $r.Output | ConvertFrom-Json
        Assert-That ($payload.groupCount -eq 3) "groupCount attendu 3, obtenu $($payload.groupCount)"
        Assert-That ($payload.byState.'canonical-absent' -eq 1) "1 groupe canonical-absent attendu"
        Assert-That ($payload.byState.'canonical-empty' -eq 1) "1 groupe canonical-empty attendu"
        Assert-That ($payload.byState.'content-split' -eq 1) "1 groupe content-split attendu"
        Assert-That (-not [string]::IsNullOrEmpty($payload.groups[0].canonicalRel)) "canonicalRel vide"
    }

    It 'rend 0 sur un store sans aucun jumeau' {
        $fx = Join-Path $env:TEMP ("forkscan-clean-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        $script:Fixtures.Add($fx)
        Set-Content -LiteralPath (Join-Path $fx 'notes.md') -Value '# notes' -Encoding ASCII
        $r = Invoke-Scan -SharedState $fx
        Assert-That ($r.ExitCode -eq 0) "exit code attendu 0, obtenu $($r.ExitCode)"
        Assert-That ($r.Output -match 'aucune copie de conflit') "la sortie ne devrait pas annoncer de fork"
    }

    It 'rend 2 quand le chemin du store est absent (erreur d''instrument, pas « aucun fork »)' {
        $r = Invoke-Scan -SharedState (Join-Path $env:TEMP ("absent-" + [guid]::NewGuid().ToString('N')))
        Assert-That ($r.ExitCode -eq 2) "exit code attendu 2, obtenu $($r.ExitCode)"
    }
}
