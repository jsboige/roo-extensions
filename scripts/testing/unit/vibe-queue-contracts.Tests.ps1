<#
.SYNOPSIS
    Guards the multi-contract Vibe grain queue (#16472, GO ai-01 17/09 —
    mandat user « résoudre définitivement le pb d'approvisionnement » ;
    #13410 densité, dispatch ai-01 18/09 02:02Z).
#>

Describe 'Vibe queue multi-contrats (#16472, #13410)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $refresherPath = Join-Path $root 'scripts\scheduling\refresh-vibe-queue.py'
        $pyTestsPath = Join-Path $root 'scripts\testing\python\test_refresh_vibe_queue.py'

        $refresher = Get-Content $refresherPath -Raw

        $script:Python = $null
        $candidates = if ($env:OS -eq 'Windows_NT') { @('python', 'py') } else { @('python3', 'python') }
        foreach ($candidate in $candidates) {
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) { $script:Python = $cmd.Source; break }
        }
    }

    Context 'Registre de contrats (anti-dépendance à un détecteur unique)' {
        It 'déclare les trois contrats actifs avec scan, payload et axe de regroupement' {
            $refresher | Should -Match '15719:\s*\{"scan": scan_md_table'
            $refresher | Should -Match '16472:\s*\{"scan": scan_md_hierarchy'
            $refresher | Should -Match '13410:\s*\{"scan": scan_pedagogy_density'
            $refresher | Should -Match '"group": 2'
        }

        It 'le défaut de --issue couvre TOUS les contrats actifs (multi-détecteurs au tick)' {
            $refresher | Should -Match 'args\.issue or sorted\(CONTRACTS\)'
        }

        It 'le payload #16472 porte la convention CoursIA (demote + reassessment + rebaseline)' {
            $refresher | Should -Match 'demote_md_asides\.py'
            $refresher | Should -Match 'fix_hint_headings\.py'
            $refresher | Should -Match 'REASSESSMENT OBLIGATOIRE'
            $refresher | Should -Match 'update-baseline'
        }
    }

    Context 'Contrat #13410 densité — règle de taille propre, pas le moule findings' {
        It 'porte floor=1 / max_files=2 (grain 1-2 notebooks, 1,67 fichier/PR mesuré)' {
            $refresher | Should -Match '"floor": 1, "max_files": 2'
        }

        It 'main() passe la taille du contrat à plan() (le moule FLOOR=10 n exprime pas #13410)' {
            $refresher | Should -Match 'floor=contract\.get\("floor"\)'
            $refresher | Should -Match 'max_files=contract\.get\("max_files"\)'
        }

        It 'le payload #13410 porte les garde-fous éditoriaux de l incident 02/09 (30/41 accents détruits)' {
            $refresher | Should -Match 'UTF-8 sans repli ASCII'
            $refresher | Should -Match 'forme liste'
            $refresher | Should -Match 'AUCUNE re-execution'
            $refresher | Should -Match 'detect_solution_leaks'
            $refresher | Should -Match 'JAMAIS fabriquer un chiffre'
            $refresher | Should -Match '1200'
        }

        It 'le scan densité consomme pedagogy_density.py --json (advisory, exemptions du scanner)' {
            $refresher | Should -Match 'pedagogy_density\.py'
            $refresher | Should -Match 'below_threshold'
        }
    }

    Context 'Angle mort census résorbé (95 flaggés / 89 résolus, mesuré 18/09)' {
        It 'la regex findings est ÉPINGLÉE aux codes du contrat #16472' {
            $refresher | Should -Match 'HIERARCHY_CONTRACTED = \("HINT-AS-HEADING", "HEADING-IN-LIST"\)'
        }

        It 'les exclusions H1 (MULTI-H1/H1-DEEP) sont comptées et rapportées, pas avalées' {
            $refresher | Should -Match 'HIERARCHY_ANY_FINDING'
            $refresher | Should -Match 'findings hors contrat'
        }
    }

    Context 'Déconfliction (PRs ET claims sans PR — leçon #16472 fournée 1)' {
        It 'soustrait les fichiers tenus par une PR de tout contrat actif, quel qu il soit' {
            $refresher | Should -Match 'Cross-contract'
            $refresher | Should -Match 'any\(p\.search'
        }

        It 'parse les commentaires [CLAIMED...] en chemins soustraits de la file' {
            $refresher | Should -Match 'def claimed_paths'
            $refresher | Should -Match 'def issue_claims'
            $refresher | Should -Match 'p not in claims'
        }

        It 'limite la liste PR à 300 (100+ PRs ouvertes mesurées sur CoursIA)' {
            $refresher | Should -Match '"--limit", "300"'
        }
    }

    Context 'Behavioural harness (unittest, parsing pur)' {
        It 'runs the unittest suite covering census parsing, claims, grouping, payloads' {
            if (-not $script:Python) { Set-ItResult -Skipped -Because 'python not available' }
            else {
                # System.Diagnostics.Process, pas '& ... 2>&1' : sous PS 5.1, stderr natif
                # fusionne en ErrorRecords et fait echouer sur les points de progression
                # unittest (mesure po-2025 16/09).
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $script:Python
                $psi.Arguments = '"' + $pyTestsPath + '"'
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.UseShellExecute = $false
                $proc = [System.Diagnostics.Process]::Start($psi)
                $stdout = $proc.StandardOutput.ReadToEnd()
                $stderr = $proc.StandardError.ReadToEnd()
                $proc.WaitForExit()
                $proc.ExitCode | Should -Be 0 -Because "unittest output: $stdout $stderr"
            }
        }
    }
}
