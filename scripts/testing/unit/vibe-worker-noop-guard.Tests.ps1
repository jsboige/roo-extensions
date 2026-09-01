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
            ($guard -match 'exit 0')  | Should -Be $true
            ($guard -match 'exit 75') | Should -Be $false   # 75 = SKIP qui NE consomme pas un dispatch
            ($guard -match 'exit 1')  | Should -Be $false
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
