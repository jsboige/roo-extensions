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

Describe 'frontiere de jour -- le log de la veille porte les evenements du jour' {

    # Defaut mesure le 2026-11-01 a 01:00 locales : l hote RSM lie son FICHIER de log
    # au demarrage du PROCESSUS, pas au changement de jour. Le fichier du 31/10
    # (4,28 Mo, toujours en croissance) portait deja des evenements [2026-11-01 ...],
    # et l instrument cherchait roosync-20261101.log, absent. Resultat :
    # pgSamples=0 window=1.0h verdict=OK -- l instrument se declarait sain sans avoir
    # rien lu, chaque nuit, a deux jours de la bascule PG.
    #
    # TROIS familles de mutants sont tuees ici (reviews r1 po-2027 + po-2024) :
    #   A. retirer le repli sur le fichier le plus recent -> test 1 (plus rien lu) ;
    #   B. le garder SANS le filtre -Since -> test 2 (24 h de la veille comptees dans
    #      un taux horaire, le chiffre devient faux dans l autre sens) ;
    #   C. comparer le minuit LOCAL aux champs UTC des en-tetes (au lieu d instants)
    #      -> test 2 : l evenement 23:30Z (00:30 locales) doit RENTRER ;
    #   D. dropper un en-tete illisible -> test 3 : il doit etre COMPTE ;
    #   E. ne lire qu un fichier de rotation (une journee active en produit plusieurs,
    #      -44 mesures chez po-2024) -> test 4 : tous les chunks entrent.

    # Convention des fixtures de ce Describe : les horodatages entre crochets sont
    # des en-tetes RSM, donc UTC (mesure po-2027 : en-tete 00:12:20, horloge locale
    # 01:12:20). Le siege de reference est UTC+1 : minuit LOCAL du 01/11 = 23:00Z
    # du 31/10. C est ce -Since (un instant UTC) que le main reel construit via
    # $midnight.ToUniversalTime().

    It 'resout le fichier de la veille quand celui du jour n existe pas encore' {
        $dir = Join-Path $TestDrive 'logs-boundary'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $yesterday = Join-Path $dir 'roosync-20261031.log'
        New-RsmHealthFixtureLog -Path $yesterday -Lines @(
            '[2026-11-01 00:01:08] [INFO] [dashboard-pg] dashboard served from PG in 22ms (global, 12 messages)'
        )

        $files = @(Get-DefaultRsmLogPaths -DayStamp '20261101' -LogDir $dir)

        # Le fichier absent du jour ne laisse plus d entree fantome (Test-Path la
        # sautait de toute facon) ; seul le vivant de la veille est rendu. Sans le
        # repli sur son stamp, l instrument ne lisait RIEN : c est le mutant A.
        $files.Count | Should -Be 1
        $files[0] | Should -Match 'roosync-20261031\.log$'
        $metrics = Get-RsmLogMetrics -Files $files -Since ([datetime]'2026-10-31 23:00:00')
        $metrics.LogFiles | Should -Be 1
        $metrics.PgLatencies.Count | Should -Be 1
    }

    It 'tronque avant minuit LOCAL en comparant des instants, pas des champs UTC (mutants B et C)' {
        $log = Join-Path $TestDrive 'boundary-trim.log'
        New-RsmHealthFixtureLog -Path $log -Lines @(
            '[2026-10-31 09:00:00] [WARN] Inbox file read timed out (cloud-only?): vieux.md',
            '[2026-10-31 22:30:00] [WARN] Inbox file read timed out (cloud-only?): 23h30-locales-31-10.md',
            '[2026-10-31 23:00:00] [WARN] Inbox file read timed out (cloud-only?): minuit-local-pile.md',
            '[2026-10-31 23:30:00] [WARN] [pg-cold-pool-resume] [pg-resume] connection timeout (cold pool)',
            '[2026-11-01 00:02:00] [INFO] [dashboard-pg] dashboard served from PG in 41ms (global, 12 messages)'
        )
        # Minuit local du 01/11 sur un siege UTC+1 = 23:00Z la veille.
        $since = [datetime]::SpecifyKind([datetime]'2026-10-31 23:00:00', [datetimekind]::Utc)

        $trimmed = Get-RsmLogMetrics -Files @($log) -Since $since

        # 22:30Z = 23:30 locales le 31/10 : dehors. 23:00Z = minuit local PILE :
        # dedans (borne stricte, nit 3 de la review -- un -le l exclurait). 23:30Z =
        # 00:30 locales le 01/11 : DEDANS -- c est le mutant C : une comparaison de
        # champs (23:30 « le 31/10 » < « 01/11 00:00 ») le jetait a tort avec les 671
        # evenements mesures par po-2027 sur le fichier de bascule.
        $trimmed.CloudOnly | Should -Be 1
        $trimmed.ConnectionTimeouts | Should -Be 1
        $trimmed.PgLatencies.Count | Should -Be 1

        # Sans -Since, le comportement d avant ce grain est preserve a l identique
        # (lecture explicite d un vieux fichier pour un post-mortem).
        $unfiltered = Get-RsmLogMetrics -Files @($log)
        $unfiltered.CloudOnly | Should -Be 3
        $unfiltered.ConnectionTimeouts | Should -Be 1
    }

    It 'compte un en-tete illisible sous -Since actif (mutant D : cacher un evenement)' {
        # L invariant du grain : un en-tete qui commence par [ mais ne parse pas est
        # COMPTE, pas droppé -- cacher un evenement est exactement le defaut que ce
        # grain supprime. Le mutant `else { continue }` apres le if ($stamp.Success)
        # survit a la suite entiere sans ce test (mesure po-2024, trou B).
        $log = Join-Path $TestDrive 'unparseable-header.log'
        New-RsmHealthFixtureLog -Path $log -Lines @(
            '[2026-10-31 23:40:00] [WARN] [pg-resume] connection timeout -- en-tete valide',
            '[channel-pg-breaker] connection timeout -- en-tete sans horodatage, doit etre compte',
            '    "detail": "ligne indentee, ignoree par le filtre ^[ habituel"'
        )
        $since = [datetime]::SpecifyKind([datetime]'2026-10-31 23:00:00', [datetimekind]::Utc)

        $m = Get-RsmLogMetrics -Files @($log) -Since $since

        $m.ConnectionTimeouts | Should -Be 2
    }

    It 'lit TOUS les chunks de rotation de la veille, pas seulement le plus recent (mutant E)' {
        # logger.ts tourne a 10 Mo SANS renommer le canonique : une journee active
        # produit roosync-<jour>.log + -2.log + -3.log... (44 chunks mesures chez
        # po-2024 le 31/10). Ne lire que le plus recent sous-compte silencieusement
        # (1 evenement sur 3 dans la repro po-2024).
        $dir = Join-Path $TestDrive 'logs-rotation'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-RsmHealthFixtureLog -Path (Join-Path $dir 'roosync-20261031.log') -Lines @(
            '[2026-10-31 23:50:00] [INFO] [dashboard-pg] dashboard served from PG in 20ms (canonique)',
            '[2026-10-31 23:55:00] [INFO] [dashboard-pg] dashboard served from PG in 21ms (canonique)'
        )
        New-RsmHealthFixtureLog -Path (Join-Path $dir 'roosync-20261031-2.log') -Lines @(
            '[2026-11-01 00:05:00] [INFO] [dashboard-pg] dashboard served from PG in 22ms (chunk -2)'
        )
        # Leurre ecrit en DERNIER (donc le plus recent par mtime) : suffixe non
        # numerique -- un repli « fichier le plus recent » nu le prendrait, la regex
        # de chunk doit le refuser (nit po-2027 : roosync-<autre>.log).
        New-RsmHealthFixtureLog -Path (Join-Path $dir 'roosync-20261031-migration.log') -Lines @(
            '[2026-11-01 00:06:00] [INFO] [dashboard-pg] dashboard served from PG in 99ms (leurre)'
        )

        $files = @(Get-DefaultRsmLogPaths -DayStamp '20261101' -LogDir $dir)

        $files.Count | Should -Be 2
        ($files -join ';') | Should -Match 'roosync-20261031\.log'
        ($files -join ';') | Should -Match 'roosync-20261031-2\.log'
        ($files -join ';') | Should -Not -Match 'migration'

        # Les 3 evenements des deux fichiers legitimes sont lus ; le leurre ne l est pas.
        $m = Get-RsmLogMetrics -Files $files -Since ([datetime]::SpecifyKind([datetime]'2026-10-31 23:00:00', [datetimekind]::Utc))
        $m.LogFiles | Should -Be 2
        $m.PgLatencies.Count | Should -Be 3
    }

    It 'ne duplique pas le fichier quand le log du jour EST le plus recent' {
        $dir = Join-Path $TestDrive 'logs-same'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-RsmHealthFixtureLog -Path (Join-Path $dir 'roosync-20261101.log') -Lines @(
            '[2026-11-01 00:05:00] [INFO] [dashboard-pg] dashboard served from PG in 9ms (global, 1 messages)'
        )

        $files = @(Get-DefaultRsmLogPaths -DayStamp '20261101' -LogDir $dir)

        # Une seule entree : deux fois le meme chemin doublerait chaque evenement.
        $files.Count | Should -Be 1
    }

    It 'la decision fichiers+troncature est une valeur, pas une ligne de bloc principal' {
        # Mutant B (le repli est garde MAIS la troncature disparait) n etait tuable par
        # aucun test : Pester dot-source le script, donc le bloc principal ne tourne
        # jamais et un -Since retire la restait invisible. La decision devient une
        # fonction pure, resolvable ici, et le cablage est asserte plus bas.
        $dir = Join-Path $TestDrive 'logs-plan'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-RsmHealthFixtureLog -Path (Join-Path $dir 'roosync-20261031.log') -Lines @(
            '[2026-11-01 00:01:08] [INFO] [dashboard-pg] dashboard served from PG in 22ms (global, 12 messages)'
        )
        $midnight = [datetime]::SpecifyKind([datetime]'2026-10-31 23:00:00', [datetimekind]::Utc)

        $plan = Resolve-RsmLogPlan -DayStamp '20261101' -Midnight $midnight -LogDir $dir

        ($plan.Files -join ';') | Should -Match 'roosync-20261031\.log'
        $plan.Since | Should -Be $midnight

        # Un -LogPath explicite reste une lecture deliberee : aucune troncature.
        $explicit = Resolve-RsmLogPlan -LogPath @('C:\somewhere\old.log') -DayStamp '20261101' -Midnight $midnight
        $explicit.Since | Should -Be ([datetime]::MinValue)
        @($explicit.Files).Count | Should -Be 1
    }

    It 'le bloc principal passe bien la troncature a l agregateur, en UTC (cablage)' {
        # Meme idiome que l assertion stdout de cette suite : ce qui ne peut pas etre
        # execute en processus est lu dans le code, commentaires retires. L ancrage
        # ToUniversalTime() est le mutant C vu DU bloc principal : sans lui, la
        # conversion peut disparaitre du cablage alors que les fonctions restent
        # correctes et que toute la suite reste verte.
        $instrument = Get-Content (Join-Path $projectRoot 'scripts/diagnostic/measure-rsm-health.ps1') -Raw
        $code = (@(($instrument -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")

        $code | Should -Match 'Resolve-RsmLogPlan -LogPath \$LogPath -DayStamp \$DayStamp -Midnight \(\$midnight\.ToUniversalTime\(\)\)'
        $code | Should -Match 'Get-RsmLogMetrics -Files \$plan\.Files -Since \$plan\.Since'
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

    It 'emet la ligne sur stdout quel que soit le verdict (review #4388 r2, CRITICAL 1)' {
        # Write-Warning pose un prefixe localise ("AVERTISSEMENT : ") et replie les
        # lignes longues : le grep ancre du pre-vol ne capte alors jamais un WARN, et
        # le post part en "instrument error" en perdant les mesures. Le verdict passe
        # par le code de sortie, la ligne par stdout.
        $instrument = Get-Content (Join-Path $projectRoot 'scripts/diagnostic/measure-rsm-health.ps1') -Raw
        $instrumentCode = (@(($instrument -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
        $instrumentCode | Should -Match 'Write-Output \$line'
        $instrumentCode | Should -Not -Match 'Write-Warning\s+\$line'
    }

    It 'ne passe jamais un id de message a la surface machine (le CLI le refuse)' {
        # Mesure 28/10 par l'acceptance WARN forcee : sur la surface machine, le CLI
        # sort en usage error et le post primaire degradait silencieusement en
        # commentaire GitHub a chaque run. Le mode par defaut genere son propre id ;
        # la cadence quotidienne est portee par un marqueur machine-local.
        $preflight = Get-Content (Join-Path $projectRoot 'scripts/claude/executor-preflight.ps1') -Raw
        $preflightCode = (@(($preflight -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
        $preflightCode | Should -Not -Match '--message-id'
        $preflightCode | Should -Match 'rsm-health-posted-'
    }

    It 'un echec d ecriture de marqueur ou de body-file reste local, et seul un WARN livre consomme le marqueur (review r3)' {
        # Deux trous de la review #4388 r3 : (1) une WriteAllText qui jette atteint
        # le catch externe et le pre-vol sort en echec -- un WARN ne bloque JAMAIS ;
        # (2) un instrument-error qui reussit son post consommait le marqueur du
        # jour, et le vrai WARN suivant etait etouffe. Les deux ecritures vivent
        # desormais dans un try/catch local avec leur propre ligne de warning, et
        # la porte du marqueur exige le verdict WARN ET la livraison.
        $preflight = Get-Content (Join-Path $projectRoot 'scripts/claude/executor-preflight.ps1') -Raw
        $preflightCode = (@(($preflight -split "`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
        # (1) les echecs d ecriture ont leur propre filet, message inclus.
        $preflightCode | Should -Match 'body-file write failed'
        $preflightCode | Should -Match 'marker write failed'
        # (2) la porte du marqueur combine livraison ET verdict WARN : un mutant qui
        # retire l une ou l autre condition fait echouer l ancrage exact.
        $preflightCode | Should -Match 'if \(\$delivered -and \$rsmHealthExit -eq 2\)'
        # La double porte est bien CELLE du marqueur : le WriteAllText du marqueur
        # suit la porte dans les lignes qui restent (commentaires retires).
        $gate = [regex]::Match($preflightCode, "(?s)if \(\`$delivered -and \`$rsmHealthExit -eq 2\).*?WriteAllText\(\`$postedMarker")
        $gate | Should -Not -BeNullOrEmpty
    }
}
