# Tests unitaires -- mesure de sante RSM du siege (#4289, grain h-RSM).
#
# Le pre-vol imprime une ligne [RSM-HEALTH] par siege : nombre d hotes RSM,
# memoire privee max, evenements (cloud-only?) et connection timeout du jour,
# latence mediane [dashboard-pg]. Au-dela du seuil la ligne devient un WARN que
# la lane relaie -- elle ne bloque jamais (#3169).
#
# Ce que ces tests epinglent, et pourquoi chacun tue un mutant precis :
#   1. COMPTAGE EVENEMENT / LIGNE : le log ecrit un en-tete puis des lignes JSON
#      indentees qui repetent les memes mots. Compter les lignes brutes gonfle le
#      chiffre (mesure 27/10 : 298 lignes pour 95 evenements). Un mutant qui
#      retire le filtre '^\[' fait echouer le test 1.
#   2. MEDIANE, PAS MOYENNE : un p99 a 187 s sur 7000 lectures ne doit pas faire
#      passer un siege sain pour malade. Un mutant qui remplace la mediane par une
#      moyenne fait echouer le test 2.
#   3. SEUILS : strictement superieur pour la memoire, au moins egal pour le taux.
#   4. WARN NE BLOQUE PAS : le verdict est une donnee, pas un exit code impose a
#      l appelant -- c est l exit 2 qui le porte, et le pre-vol le traduit en
#      Write-Warning (assertion statique sur executor-preflight.ps1).
#
# Aucun processus, aucun fichier reel sans fixture : les tests tournent sur
# n importe quel OS (lesson pester-ubuntu-ci-portability).
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $scriptPath = Join-Path $projectRoot "scripts/diagnostic/measure-rsm-health.ps1"
    . $scriptPath

    function New-RsmHealthFixtureLog {
        param([string]$Path, [string[]]$Lines)
        Set-Content -LiteralPath $Path -Value $Lines -Encoding UTF8
    }
}

Describe 'Get-RsmLogMetrics -- evenements, pas lignes de log' {

    It 'compte UN connection timeout quand trois lignes portent le motif' {
        $log = Join-Path $TestDrive 'one-event.log'
        New-RsmHealthFixtureLog -Path $log -Lines @(
            '[2026-10-27 00:28:59] [WARN] [pg-cold-pool-resume] [pg-resume] connection timeout (cold pool) -- one bounded retry before GDrive fallback',
            '    "error": "Error: Connection terminated due to connection timeout"',
            '    "errorStack": "Error: Connection terminated due to connection timeout\n    at pool.js:12"'
        )

        $m = Get-RsmLogMetrics -Files @($log)

        $m.ConnectionTimeouts | Should -Be 1
        $m.LogFiles | Should -Be 1
    }

    It 'compte les evenements cloud-only? et ignore leurs lignes de detail' {
        $log = Join-Path $TestDrive 'cloud-only.log'
        New-RsmHealthFixtureLog -Path $log -Lines @(
            '[2026-10-27 02:00:00] [WARN] Inbox file read timed out (cloud-only?): inbox-a.md',
            '    "errorMessage": "Inbox file read timed out (cloud-only?): inbox-a.md"',
            '[2026-10-27 03:00:00] [WARN] Inbox file read timed out (cloud-only?): inbox-b.md'
        )

        $m = Get-RsmLogMetrics -Files @($log)

        $m.CloudOnly | Should -Be 2
    }

    It 'extrait les latences PG et laisse la mediane a l agregateur' {
        $log = Join-Path $TestDrive 'pg-latency.log'
        New-RsmHealthFixtureLog -Path $log -Lines @(
            '[2026-10-27 04:00:00] [INFO] [dashboard-pg] dashboard served from PG in 120ms (workspace-roo-extensions, 12 messages)',
            '[2026-10-27 04:00:01] [INFO] [dashboard-pg] dashboard served from PG in 480ms (workspace-roo-extensions, 3 messages)',
            '[2026-10-27 04:00:02] [INFO] unrelated line without the marker'
        )

        $m = Get-RsmLogMetrics -Files @($log)

        @($m.PgLatencies).Count | Should -Be 2
        ($m.PgLatencies -contains 120) | Should -BeTrue
        ($m.PgLatencies -contains 480) | Should -BeTrue
    }

    It 'ne jette pas quand le log du jour est absent (jour sans activite RSM)' {
        $missing = Join-Path $TestDrive 'does-not-exist.log'

        $m = Get-RsmLogMetrics -Files @($missing)

        $m.CloudOnly | Should -Be 0
        $m.ConnectionTimeouts | Should -Be 0
        @($m.PgLatencies).Count | Should -Be 0
        $m.LogFiles | Should -Be 0
    }
}

Describe 'Get-RsmHealthReport -- mediane et seuils' {

    It 'rend la MEDIANE, pas la moyenne (un p99 ne fait pas un siege malade)' {
        $metrics = [pscustomobject]@{
            CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1
            PgLatencies = @(139, 140, 141, 187410)
        }

        $r = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 18

        # moyenne de ces quatre valeurs = 46957 ; mediane = (140 + 141) / 2 = 140,5
        $r.PgMedianMs | Should -Be 140.5
        $r.PgSamples | Should -Be 4
    }

    It 'rend null sans echantillon de latence (pas zero, qui se lirait comme excellent)' {
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 0; PgLatencies = @() }

        $r = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 1

        $r.PgMedianMs | Should -BeNullOrEmpty
    }

    It 'verdict OK sous les deux seuils' {
        $hosts = @(
            [pscustomobject]@{ ProcessId = 1; PrivateMB = 700 },
            [pscustomobject]@{ ProcessId = 2; PrivateMB = 900 }
        )
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 20; LogFiles = 1; PgLatencies = @(100) }

        $r = Get-RsmHealthReport -Hosts $hosts -LogMetrics $metrics -HoursObserved 10

        $r.Verdict | Should -Be 'OK'
        $r.HostCount | Should -Be 2
        $r.MaxPrivateMB | Should -Be 900
        @($r.Reasons).Count | Should -Be 0
    }

    It 'WARN au-dela de 1.5 Go sur UN SEUL hote (max, pas moyenne)' {
        $hosts = @(
            [pscustomobject]@{ ProcessId = 1; PrivateMB = 24 },
            [pscustomobject]@{ ProcessId = 2; PrivateMB = 3988 }
        )
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @() }

        $r = Get-RsmHealthReport -Hosts $hosts -LogMetrics $metrics -HoursObserved 18

        $r.Verdict | Should -Be 'WARN'
        $r.MaxPrivateMB | Should -Be 3988
        ($r.Reasons -join '; ') | Should -Match 'max-memory'
    }

    It 'le seuil memoire est STRICTEMENT superieur (1536 Mo pile ne declenche pas)' {
        $atThreshold = @([pscustomobject]@{ ProcessId = 1; PrivateMB = 1536 })
        $above = @([pscustomobject]@{ ProcessId = 1; PrivateMB = 1537 })
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @() }

        (Get-RsmHealthReport -Hosts $atThreshold -LogMetrics $metrics -HoursObserved 1).Verdict | Should -Be 'OK'
        (Get-RsmHealthReport -Hosts $above -LogMetrics $metrics -HoursObserved 1).Verdict | Should -Be 'WARN'
    }

    It 'WARN a partir de 1 cloud-only? par heure observee' {
        $metrics = [pscustomobject]@{ CloudOnly = 2; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @() }

        $twoInTwoHours = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 2
        $twoInFourHours = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 4

        $twoInTwoHours.Verdict | Should -Be 'WARN'
        $twoInTwoHours.CloudOnlyPerHour | Should -Be 1
        $twoInFourHours.Verdict | Should -Be 'OK'
    }
}

Describe 'Get-RsmHealthReport -- RAM totale et connTimeout juges (review #4388)' {

    It 'po-2023 (27/10) : WARN sur free-ram et conn-timeout alors qu aucun hote n est gras' {
        # Snapshot mesure 17:4xZ, cite par la review : 24 hotes, 16.9 Go prives AU
        # TOTAL (aucun hote ne depasse 1536 -- le mutant qui juge le max au lieu du
        # total ne peut pas voir ce siege), 0.7 Go de RAM libre, 95 cold-pool
        # timeouts sur 18.1 h = 5.25/h.
        $hosts = @(1..24 | ForEach-Object { [pscustomobject]@{ ProcessId = $_; PrivateMB = 704 } })
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 95; LogFiles = 1; PgLatencies = @() }
        $ram = [pscustomobject]@{ FreeRamMB = 717; TotalRamMB = 32768 }

        $r = Get-RsmHealthReport -Hosts $hosts -LogMetrics $metrics -RamMetrics $ram -HoursObserved 18.1

        $r.Verdict | Should -Be 'WARN'
        $r.MaxPrivateMB | Should -Be 704
        $r.TotalPrivateMB | Should -Be 16896
        ($r.Reasons -join '; ') | Should -Match 'free-ram: 717MB free of 32768MB \(2\.2%\)'
        ($r.Reasons -join '; ') | Should -Match 'conn-timeout: 5\.25/h >= 5/h'
        ($r.Reasons -join '; ') | Should -Not -Match 'max-memory'
    }

    It 'ai-01 (27/10) : OK -- 74 hotes, 8.2 Go au total, 28% de RAM libre, 0 timeout' {
        # L autre snapshot de la review : le total eleve n est PAS un defaut quand la
        # machine a de la marge (55 Go libres sur 192).
        $hosts = @([pscustomobject]@{ ProcessId = 1; PrivateMB = 770 })
        foreach ($i in 2..74) { $hosts += [pscustomobject]@{ ProcessId = $i; PrivateMB = 102 } }
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @(3) }
        $ram = [pscustomobject]@{ FreeRamMB = 55194; TotalRamMB = 196301 }

        $r = Get-RsmHealthReport -Hosts $hosts -LogMetrics $metrics -RamMetrics $ram -HoursObserved 18.1

        $r.Verdict | Should -Be 'OK'
        $r.TotalPrivateMB | Should -Be 8216
        $r.FreeRamMB | Should -Be 55194
        $r.ConnTimeoutPerHour | Should -Be 0
        @($r.Reasons).Count | Should -Be 0
    }

    It 'free-ram : juge sur le pourcentage OU le plancher, bornes strictes' {
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 0; PgLatencies = @() }

        # 19631 MB = 10.0005% du total : PAS sous 10%, PAS sous 4096 -> OK.
        $atMargin = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -RamMetrics ([pscustomobject]@{ FreeRamMB = 19631; TotalRamMB = 196301 }) -HoursObserved 1
        $atMargin.Verdict | Should -Be 'OK'
        ($atMargin.Reasons -join '; ') | Should -Not -Match 'free-ram'
        # Un MB de moins : sous 10% du total -> WARN (9.9995% s affiche 10).
        $underPercent = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -RamMetrics ([pscustomobject]@{ FreeRamMB = 19629; TotalRamMB = 196301 }) -HoursObserved 1
        $underPercent.Verdict | Should -Be 'WARN'
        ($underPercent.Reasons -join '; ') | Should -Match 'free-ram: 19629MB free of 196301MB \(10%\)'
        # 4000 MB sur 32 Go = 12.2% (pas sous 10%) mais sous le plancher 4096 -> WARN
        # par le plancher SEUL : c est le cas po-2023 sans que le total soit en jeu.
        $underFloor = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -RamMetrics ([pscustomobject]@{ FreeRamMB = 4000; TotalRamMB = 32768 }) -HoursObserved 1
        $underFloor.Verdict | Should -Be 'WARN'
        ($underFloor.Reasons -join '; ') | Should -Match 'free-ram: 4000MB free of 32768MB \(12\.2%\)'
        # 4096 exactement sur 32 Go : pas sous 10%, PAS sous 4096 (strict) -> OK.
        $atFloor = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -RamMetrics ([pscustomobject]@{ FreeRamMB = 4096; TotalRamMB = 32768 }) -HoursObserved 1
        $atFloor.Verdict | Should -Be 'OK'
    }

    It 'conn-timeout : au seuil exact (=) s allume, un dixieme en dessous reste eteint' {
        $atThreshold = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 50; LogFiles = 1; PgLatencies = @() }
        $below = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 49; LogFiles = 1; PgLatencies = @() }
        $ram = [pscustomobject]@{ FreeRamMB = 55194; TotalRamMB = 196301 }

        $warn = Get-RsmHealthReport -Hosts @() -LogMetrics $atThreshold -RamMetrics $ram -HoursObserved 10
        $warn.Verdict | Should -Be 'WARN'
        ($warn.Reasons -join '; ') | Should -Match 'conn-timeout: 5/h >= 5/h'

        $ok = Get-RsmHealthReport -Hosts @() -LogMetrics $below -RamMetrics $ram -HoursObserved 10
        $ok.Verdict | Should -Be 'OK'
    }

    It 'RAM inconnue (non-Windows) : free-ram ne juge pas, la ligne dit n/a' {
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @() }

        $r = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 1

        $r.Verdict | Should -Be 'OK'
        $r.FreeRamMB | Should -BeNullOrEmpty
        (Format-RsmHealthLine -Report $r) | Should -Match 'freeRamMB=n/a'
    }
}

Describe 'Format-RsmHealthLine -- contrat de ligne' {

    It 'emet une ligne unique greppable avec tous les champs demandes' {
        $hosts = @([pscustomobject]@{ ProcessId = 7; PrivateMB = 3988 })
        $metrics = [pscustomobject]@{ CloudOnly = 1; ConnectionTimeouts = 95; LogFiles = 1; PgLatencies = @(139) }
        $r = Get-RsmHealthReport -Hosts $hosts -LogMetrics $metrics -HoursObserved 18

        $line = Format-RsmHealthLine -Report $r

        $line | Should -Match '^\[RSM-HEALTH\] hosts=1 '
        $line | Should -Match 'maxPrivMB=3988'
        $line | Should -Match 'totalPrivMB=3988'
        $line | Should -Match 'freeRamMB=n/a'
        $line | Should -Match 'cloudOnly=1'
        $line | Should -Match 'connTimeout=95'
        $line | Should -Match 'pgMedianMs=139'
        $line | Should -Match 'verdict=WARN'
        $line | Should -Match 'max-memory'
        # Une seule ligne : le coordinateur grep, il ne lit pas un tableau.
        ($line -split "`n").Count | Should -Be 1
    }

    It 'ecrit n/a quand aucune latence n a ete observee' {
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 0; PgLatencies = @() }
        $r = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 1

        (Format-RsmHealthLine -Report $r) | Should -Match 'pgMedianMs=n/a'
    }

    It 'reste a point decimal sous culture francaise (139,5 casserait le contrat key=value)' {
        $metrics = [pscustomobject]@{ CloudOnly = 0; ConnectionTimeouts = 0; LogFiles = 1; PgLatencies = @(139, 140) }
        $r = Get-RsmHealthReport -Hosts @() -LogMetrics $metrics -HoursObserved 1

        $line = Format-RsmHealthLine -Report $r

        $line | Should -Match 'pgMedianMs=139\.5'
    }
}

Describe 'executor-preflight.ps1 -- branchement de la ligne [RSM-HEALTH]' {

    It 'appelle l instrument et relaie un WARN sans jamais bloquer le cycle' {
        $preflightPath = Join-Path $projectRoot 'scripts/claude/executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw

        $preflight | Should -Match 'measure-rsm-health\.ps1'
        # Meme idiome que #3169/#4340/#4336 : absent = ancien checkout, on saute.
        $preflight | Should -Match 'Test-Path \$rsmHealth'
        # Exit 2 = WARN -> Write-Warning ; le pre-vol ne sort pas sur ce code.
        $preflight | Should -Match 'rsmHealthExit -eq 2'
        # Aucun `exit` ni `throw` dans la branche de sante : WARN, pas BLOCKED.
        # On lit le CODE, pas la prose : le commentaire de la branche cite lui-meme
        # " exit 2 is relayed as a Write-Warning " et ferait matcher une assertion
        # naive sur le texte brut.
        $branch = [regex]::Match($preflight, "(?s)# #4289.*?Write-Host '\[executor-preflight\]\[READY\]").Value
        $branch | Should -Not -BeNullOrEmpty
        $branchCode = (@($branch -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        $branchCode | Should -Not -Match '\bthrow\b'
        $branchCode | Should -Not -Match '(?m)^\s*exit\s+(?!0)'
    }
}
