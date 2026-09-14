# Tests unitaires pour la garde no-op du tick Vibe planifie (#3296).
# Script sous test : scripts/scheduling/start-vibe-worker.ps1
#
# Syntaxe Pester v5 -- execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1, sur ubuntu-latest. Assertions purement
# STATIQUES sur le texte du worker, comme worker-pr-guards / nested-worktree-guard :
# start-vibe-worker.ps1 dot-source `..\common\worker-heartbeat.ps1` avec un
# antislash et ne s'execute donc pas sous pwsh Linux.
#
# CE QUE CES TESTS PROUVENT, ET CE QU'ILS NE PROUVENT PAS
# -------------------------------------------------------
# Ils prouvent que la garde est TOUJOURS LA et garde toujours les memes
# proprietes -- c'est une regression, pas une validation.
# La preuve de COMPORTEMENT a ete faite a la main sous pwsh Windows (31/08),
# en trois etats qui se distinguent :
#   * version d'origine        -> exit=1, aucun SKIP  (le defaut #3296 reproduit)
#   * garde mutee (--wakeMUTANT) -> exit=1, aucun SKIP  (l'assertion mord)
#   * garde en place           -> exit=0, SKIP loggue, aucun lock laisse
# Un test statique seul ne distinguerait aucun de ces trois etats : ne pas le
# lire comme une preuve que le tick se comporte bien.
#
# Cette preuve du 31/08 porte sur la garde AVANT #3646, qui n'avait qu'une issue
# (exit 0). Le picker idle y a ajoute une seconde issue, l'echec d'infrastructure
# (exit 1) : elle est epinglee STATIQUEMENT ici, pas re-prouvee en comportement.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/vibe-worker-noop-guard.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $vibeScript  = Join-Path $projectRoot "scripts/scheduling/start-vibe-worker.ps1"
    $content     = Get-Content $vibeScript -Raw
}

Describe "Vibe worker - garde no-op du tick planifie (#3296)" {

    Context "La garde existe et couvre les deux sources de payload" {

        It "porte le marqueur d'issue" {
            ($content -match 'NO-OP GUARD \(#3296\)') | Should -Be $true
        }

        It "ne se declenche que sur une commande harnais --wake" {
            ($content -match '\$wakeOnly\s*=.*--wake') | Should -Be $true
        }

        It "exige que les DEUX sources de payload soient vides" {
            # -MessagePayloadFile (chemin listener) ET VIBE_WAKE_PAYLOAD (env ambiant,
            # ce que le driver lit reellement) : en manquer une laisse un faux SKIP.
            ($content -match 'IsNullOrWhiteSpace\(\$MessagePayloadFile\)')     | Should -Be $true
            ($content -match 'IsNullOrWhiteSpace\(\$env:VIBE_WAKE_PAYLOAD\)')  | Should -Be $true
        }

        It "n'avale pas une commande qui porte un --prompt explicite" {
            # vibe-acp-driver.py l.149 : --prompt/--prompt-file battent le payload.
            # Une telle commande marche sans WAKE et ne doit pas etre sautee.
            # .Contains plutot qu'un -match : la clause CONTIENT elle-meme une regex,
            # et la re-echapper une seconde fois n'ajoute que des occasions de se tromper.
            ($content -match 'notmatch.*--prompt')      | Should -Be $true
            $content.Contains('--prompt(-file)?')       | Should -Be $true
        }
    }

    Context "Les proprietes de sortie -- celles qu'une edition future peut casser en silence" {

        It "sort en 0 : un no-op est une operation normale, pas un echec" {
            $guard = [regex]::Match($content, '(?s)NO-OP GUARD \(#3296\).*?\n\}').Value
            $guard | Should -Not -BeNullOrEmpty
            # Forme ANCRÉE (`^\s*exit 0\s*$`), pas `exit 0` nu : le message de SKIP
            # contient lui-même la mention `(exit 0)` et le commentaire d'en-tête une
            # seconde -- un `-match 'exit 0'` restait donc vert la sortie supprimée.
            ($guard -match "(?m)^\s*exit 0\s*$") | Should -Be $true
            ($guard -match 'exit 75')             | Should -Be $false  # 75 = SKIP qui NE consomme pas un dispatch
            # ...et cette sortie 0 est bien celle du chemin no-op, pas une occurrence orpheline.
            ($guard -match "(?ms)no WAKE payload pending.*?^\s*exit 0\s*$") | Should -Be $true
        }

        It "sort en 1 sur un refus d'infrastructure, et sur celui-la seulement" {
            # #3646 : le picker idle ajoute une SECONDE issue a ce bloc. Un refus
            # d'infrastructure (workspacePath non resolu, base illisible, worktree add en
            # echec, branche existante porteuse de travail) n'est pas un tick sans travail :
            # il doit sortir NON-ZERO la ou le no-op genuin sort a 0 -- exigence explicite de
            # la review ai-01 du 14/09 (« infrastructure refusal terminates non-zero while
            # genuine pool/cap/anti-hammer no-ops remain zero »).
            #
            # L'assertion precedente -- `exit 1` absent de la garde -- encodait la propriete
            # #3296 par un PROXY, valide tant que la garde n'avait qu'une issue. Elle est
            # remplacee par la propriete reelle : les deux sorties restent DISTINCTES, et
            # l'echec est conditionne par l'outcome type publie par le picker.
            #
            # Limite assumee (mesuree) : ce test STATIQUE lit le texte, il ne prouve pas que
            # la condition GATE reellement la sortie -- remplacer `-eq 'infrastructure'` par
            # `-eq 'infrastructure' -or $true` laisse la suite VERTE. Ce qu'il attrape : une
            # sortie 1 absente, en double, ou non conditionnee textuellement dans la garde.
            $guard = [regex]::Match($content, '(?s)NO-OP GUARD \(#3296\).*?\n\}').Value
            $guard | Should -Not -BeNullOrEmpty
            # Exactement une sortie 1 : en ajouter une seconde, hors condition, rougit ici.
            ([regex]::Matches($guard, "(?m)^\s*exit 1\s*$")).Count | Should -Be 1
            # ...et elle est sous la condition, pas dans le chemin no-op.
            ($guard -match "(?ms)IdlePickOutcome -eq 'infrastructure'.*?^\s*exit 1\s*$") | Should -Be $true
        }

        It "ecrit le heartbeat avant de sortir" {
            # Sans lui le worker paraitrait mort entre deux WAKE, qui sont rares.
            # Convention declaree l.96 du script : EVERY exit path can heartbeat.
            $guard = [regex]::Match($content, '(?s)NO-OP GUARD \(#3296\).*?\n\}').Value
            ($guard -match 'Write-WorkerHeartbeat') | Should -Be $true
        }

        It "est placee AVANT la prise du lock" {
            # Un tick qui ne fera rien n'a aucune raison de prendre le lock, et sortir
            # apres l'avoir pris laisserait un lock orphelin : le `finally` qui le
            # relache ne couvre que le bloc d'execution, plus bas.
            $iGuard = $content.IndexOf('NO-OP GUARD (#3296)')
            $iLock  = $content.IndexOf('if (-not (Open-WorkerLock))')
            $iGuard | Should -BeGreaterThan 0
            $iLock  | Should -BeGreaterThan 0
            $iGuard | Should -BeLessThan $iLock
        }

        It "est placee APRES le court-circuit -DryRun" {
            $iDry   = $content.IndexOf('if ($DryRun)')
            $iGuard = $content.IndexOf('NO-OP GUARD (#3296)')
            $iDry   | Should -BeGreaterThan 0
            $iGuard | Should -BeGreaterThan $iDry
        }
    }
}
