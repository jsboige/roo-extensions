# Tests unitaires — healthcheck read-only de la chaine MCP (arbitrage #3495, option 1)
#
# Le livrable #3495 impose trois exigences (ai-01, arbitrage du 07/09 03:18Z) :
#   1. le silence doit etre distinguable de la sante (battement observable) ;
#   2. pas de bruit : une sonde non applicable est rapportee UNE fois puis se tait ;
#   3. read-only STRUCTUREL : "pas un flag qu'on peut retirer — le script ne doit
#      contenir AUCUN chemin de reparation".
#
# Ces tests verifient le contrat en statique (pattern worker-dirty-worktree-guard) :
# le (3) est garde contre la regression future — ajouter une ligne de reparation au
# healthcheck fait rougir la CI, pas seulement la review.
#
# Syntaxe Pester v5 — execute en CI par le job `unit-pester` (#3216) via
# scripts/testing/run-pester-tests.ps1. Assertions statiques sur le texte : fonctionne
# sur pwsh Windows ET Linux, sans node ni repo de test.
#
# Usage:
#   pwsh -NoProfile -Command "Invoke-Pester -Path ./scripts/testing/unit/mcp-chain-healthcheck.Tests.ps1 -Output Detailed"

BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    $healthcheckScript = Join-Path $projectRoot "scripts/mcp-watchdog/mcp-chain-healthcheck.ps1"
    $installScript = Join-Path $projectRoot "scripts/mcp-watchdog/install-mcp-chain-healthcheck-schtask.ps1"
    $script:hc = Get-Content $healthcheckScript -Raw
    $script:inst = Get-Content $installScript -Raw
    # Fenetre isolee du corps de Publish-HealthNote (Test-E2E contient legitiment
    # un header Authorization — la publication, elle, ne doit jamais en dependre).
    $fnPos = $script:hc.IndexOf('function Publish-HealthNote')
    $script:pubBody = ''
    if ($fnPos -ge 0) {
        $body = $script:hc.Substring($fnPos)
        $nextFn = $body.IndexOf("`nfunction ", 1)
        if ($nextFn -gt 0) { $body = $body.Substring(0, $nextFn) }
        $script:pubBody = $body
    }
}

Describe "Healthcheck - read-only STRUCTUREL (exigence 3, arbitrage #3495)" {
    It "Ne doit contenir aucune invocation de reparation en debut de ligne executable" {
        # Les hints textuels ('cd ... && npm run build' apres Hint =) ne sont pas des
        # executions : ils ne figurent jamais en debut de ligne. Toute invocation
        # reelle de cmdlet de reparation/arret en debut de ligne fait rougir.
        $script:hc | Should -Not -Match '(?m)^\s*(Start-ScheduledTask|Stop-ScheduledTask|Unregister-ScheduledTask|Restart-Computer|Stop-Process|Remove-Item|Restart-Service|npm\s+run|npm\s+ci|git\s+(submodule|checkout|reset|clean)|docker\s|&\s+docker)\b'
    }

    It "Ne doit jamais referencer le script d'auto-repair (meme en suggestion)" {
        $script:hc | Should -Not -Match 'mcp-chain-watchdog\.ps1'
    }

    It "Doit declarer le read-only structurel (commentaire de contrat)" {
        $script:hc | Should -Match 'NO repair path by construction'
    }
}

Describe "Healthcheck - battement observable (exigence 1)" {
    It "Doit definir le mode -Scheduled" {
        $script:hc | Should -Match '\[switch\]\$Scheduled'
    }

    It "Doit ecrire le fichier d'etat a CHAQUE tick (battement local par mtime)" {
        $script:hc | Should -Match 'timestamp\s+='
        $script:hc | Should -Match 'Write-HealthState -State \$tickState'
    }

    It "Doit definir un intervalle de battement (HeartbeatMinutes, defaut 60)" {
        $script:hc | Should -Match '\[int\]\$HeartbeatMinutes\s*=\s*60'
    }

    It "Doit publier un battement GREEN periodique (branche heartbeat)" {
        $script:hc | Should -Match "publishReason = 'heartbeat'"
    }
}

Describe "Healthcheck - sonde non applicable rapportee UNE fois (exigence 2)" {
    It "Doit marquer naReported et cesser de publier en NA" {
        $script:hc | Should -Match 'naReported'
        $script:hc | Should -Match 'if \(-not \$prevNA\)'
    }

    It "Les couches host doivent etre conditionnelles au marqueur host-of-bus (schtask MCP-Proxy-RSM)" {
        $script:hc | Should -Match 'MCP-Proxy-RSM'
        $script:hc | Should -Match 'Applicable\s*=\s*\$IsHostOfBus'
    }

    It "L'E2E sans bot .env doit etre N/A, pas FAIL (consumer sans bearer)" {
        $script:hc | Should -Match "no bot \.env on this machine"
    }
}

Describe "Healthcheck - portabilite consumer-side" {
    It "Les chemins du wrapper doivent etre resolus relativement au script (pas de D:\\ hardcode)" {
        $layerFn = [regex]::Match($script:hc, 'function Test-LocalWrapper[\s\S]*?\n\}')
        $layerFn.Value | Should -Not -Match "'D:\\"
        $layerFn.Value | Should -Match 'Join-Path \$RsmServerDir'
    }

    It "Le repo root doit etre resolu via PSScriptRoot" {
        $script:hc | Should -Match '\$RepoRoot = Split-Path \(Split-Path \$PSScriptRoot -Parent\) -Parent'
    }
}

Describe "Healthcheck - publication idempotente (pattern #3276)" {
    It "Doit construire un messageId avec bucket 15 min et empreinte du texte" {
        $script:hc | Should -Match '/ 900'
        $script:hc | Should -Match 'healthcheck-\$env:COMPUTERNAME'
    }

    It "Doit publier via tools/call roosync_dashboard append machine (spawn stdio)" {
        $script:hc | Should -Match "name\s*=\s*'roosync_dashboard'"
        $script:hc | Should -Match "type\s*=\s*'machine'"
    }

    It "Publish-HealthNote ne doit contenir AUCUN header bearer (spawn stdio, pas proxy HTTP)" {
        # Test-E2E contient legitiment un header Authorization (couche 4, probe du bus).
        # La fenetre isole le corps de Publish-HealthNote : la publication consumer-side
        # ne doit dependre d'aucun bearer proxy.
        $script:pubBody | Should -BeGreaterThan '' -Because 'fenetre Publish-HealthNote introuvable'
        $script:pubBody | Should -Not -Match 'Authorization|Bearer'
    }

    It "La lecture de la reponse ne doit pas fermer stdin avant reception (EOF kill cascade du wrapper)" {
        # Mesure comportementale 07/09 : pipe + fermeture stdin -> le wrapper tue le
        # serveur (shutdown 10 s) avant que l'append dashboard (~10-45 s) ne reponde —
        # note perdue SILENCIEUSEusement. La garde exige le pattern lecture-asynchrone-avec-deadline.
        $script:pubBody | Should -Match 'ReadLineAsync'
        $script:pubBody | Should -Not -Match 'StandardInput\.Close\('
    }
}

Describe "Install schtask - contrat du deploiement" {
    It "Doit brancher mcp-chain-healthcheck.ps1 avec -Scheduled" {
        $script:inst | Should -Match 'mcp-chain-healthcheck\.ps1'
        $script:inst | Should -Match '-Scheduled"'
    }

    It "Trigger par defaut : toutes les 5 minutes" {
        $script:inst | Should -Match '\[int\]\$IntervalMinutes\s*=\s*5'
    }

    It "Principal utilisateur courant (GDriveFS + .env), pas SYSTEM" {
        $script:inst | Should -Match '-UserId \$env:USERNAME'
        $script:inst | Should -Match '-LogonType Interactive'
        $script:inst | Should -Not -Match "'NT AUTHORITY\\SYSTEM'|'SYSTEM'\s*`$|#\s*UserId\s*=\s*'SYSTEM'"
    }

    It "ScriptPath resolu relativement (aucun chemin de lecteur hardcode)" {
        $script:inst | Should -Match 'Join-Path \$PSScriptRoot ''mcp-chain-healthcheck\.ps1'''
        $script:inst | Should -Not -Match "'D:\\roo-extensions|'C:\\dev"
    }

    It "L'install ne doit contenir aucune sequence de reparation de composants (docker, MCP-Proxy-RSM)" {
        $script:inst | Should -Not -Match 'docker'
        $script:inst | Should -Not -Match 'MCP-Proxy-RSM'
    }
}
