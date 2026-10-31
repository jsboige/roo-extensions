# measure-gdrive-write-freeze.Tests.ps1 — Phase D : le verdict lit l'age BRUT, pas l'arrondi
#
# Precedent scan-store-forks.Tests.ps1 (#4441) : l'hote est pwsh 7 + Pester 5 ;
# la CIBLE tourne en process enfant powershell.exe 5.1, sur le store d'un fixture
# jetable (-SharedPath pointe dessus).
#
# ASSERTIONS EN `throw` (et non `Should -Be`) : le DSL `Should` a change de forme
# entre Pester 3.4 (dispo en PS 5.1), Pester 5 (CI) et Pester 6 (exige PS 7).
# Un `throw` dans un bloc It est un echec de test dans les TROIS versions.
#
# MESURE le 30/10/2026 sur ce siege (scan-store-forks, meme hote/enfant) :
# Pester 6.2.0 charge sous PowerShell 5.1.26100.9711 -> 9/9.
#
# Scenarios (review ai-01 de #4451, 30/10) -- chaque cas epingle un chemin qui
# rendait un verdict FAUX avant le fix :
#   (a) trois familles gelees (+ jumeaux)      -> exit 0, la ligne MET liste les familles vues
#   (b) un fichier CHAUD dans un jumeau        -> exit 1, NOT-MET nomme le jumeau
#   (c) une famille absente (zero instance)    -> exit 2, la sortie NOMME la famille
#   (d) age brut 23 h 58 (affiche 24,0) a 24 h -> exit 1 : la decision lit le brut, l'arrondi n'est que l'affichage
#
# Execution : powershell -NoProfile -ExecutionPolicy Bypass -File scripts/testing/run-pester-tests.ps1 -Path scripts/diagnostic/measure-gdrive-write-freeze.Tests.ps1

Describe 'measure-gdrive-write-freeze (Phase D #4131)' {
    BeforeAll {
        $script:RepoRoot = (git -C "$PSScriptRoot\..\.." rev-parse --show-toplevel).Trim()
        $script:SourceScript = Join-Path $script:RepoRoot 'scripts\diagnostic\measure-gdrive-write-freeze.ps1'
        $script:Fixtures = New-Object System.Collections.Generic.List[string]

        function Assert-That {
            param([bool]$Condition, [string]$Message)
            if (-not $Condition) { throw $Message }
        }

        # Store fige : les 3 familles + jumeaux, tout ecrit il y a $AgeHours h.
        function New-FrozenStore {
            param([double]$AgeHours = 30)
            $fx = Join-Path $env:TEMP ("gdrivefreeze-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
            New-Item -ItemType Directory -Path (Join-Path $fx 'inventories') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fx 'inventories (2)') -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $fx 'messages') -Force | Out-Null
            $stamp = [DateTime]::UtcNow.AddHours(-$AgeHours)
            foreach ($rel in @('inventories\ai-01.json', 'inventories (2)\po-2025.json',
                               'messages\m1.json', '.machine-registry.json', '.machine-registry (1).json')) {
                $p = Join-Path $fx $rel
                Set-Content -LiteralPath $p -Value '{}' -Encoding ASCII
                (Get-Item -LiteralPath $p).LastWriteTimeUtc = $stamp
            }
            $script:Fixtures.Add($fx)
            return $fx
        }

        function Invoke-Measure {
            param([string]$Store, [double]$FreezeHours = 24)
            $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script:SourceScript `
                -SharedPath $Store -FreezeHours $FreezeHours 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output   = ($out | Out-String)
            }
        }

        function Set-FileAge {
            param([string]$Path, [double]$AgeHours)
            (Get-Item -LiteralPath $Path).LastWriteTimeUtc = [DateTime]::UtcNow.AddHours(-$AgeHours)
        }
    }

    AfterAll {
        foreach ($fx in $script:Fixtures) {
            if (Test-Path -LiteralPath $fx) {
                Remove-Item -LiteralPath $fx -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }


    It '(a) trois familles gelees (+ jumeaux) rendent MET, avec les familles vues' {
        $fx = New-FrozenStore
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 0) "exit code attendu 0 (FROZEN), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] MET') "ligne MET absente de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories, messages, .machine-registry')) "la ligne MET ne liste pas les familles vues"
    }

    It '(b) un fichier chaud dans un jumeau rend NOT-MET en nommant le jumeau' {
        $fx = New-FrozenStore
        Set-FileAge -Path (Join-Path $fx 'inventories (2)\po-2025.json') -AgeHours 1
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1 (ACTIVE), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente de la sortie"
        Assert-That ($r.Output -match [regex]::Escape('inventories (2)')) "le jumeau chaud n'est pas nomme dans la sortie"
    }

    It '(c) une famille sans aucune instance rend exit 2 en la NOMMANT (jamais MET silencieux)' {
        $fx = New-FrozenStore
        Remove-Item -LiteralPath (Join-Path $fx 'messages') -Recurse -Force
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 2) "exit code attendu 2 (instrument), obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match [regex]::Escape('messages')) "la famille absente n'est pas nommee dans la sortie"
    }

    It '(d) age brut 23 h 58 sous un seuil de 24 h reste ACTIVE (l''arrondi n''est que l''affichage)' {
        $fx = New-FrozenStore
        Set-FileAge -Path (Join-Path $fx 'messages\m1.json') -AgeHours (23 + 58/60)
        $r = Invoke-Measure -Store $fx
        Assert-That ($r.ExitCode -eq 1) "exit code attendu 1 (ACTIVE) : 23 h 58 brut < 24 h meme si l'arrondi affiche 24,0 -- obtenu $($r.ExitCode) -- sortie: $($r.Output)"
        Assert-That ($r.Output -match 'PHASE-D\] NOT-MET') "ligne NOT-MET absente de la sortie"
    }
}
