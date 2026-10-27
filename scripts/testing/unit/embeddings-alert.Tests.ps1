# Tests de COMPORTEMENT du helper d alerte embeddings (embeddings-alert.ps1)
#
# Incident 27/10 : `check-embeddings.ps1` spawnait un `claude -p` par tir en
# echec. Mesure du jour : 35 lignes FAIL => jusqu a 35 agents pour UN incident.
# Ces tests n epinglent pas la forme du code : ils appellent la fonction avec
# un CLI factice (qui journalise son argv) et verifient ce qui PART.
#
#   1. le post passe par rsm-dashboard-append.mjs, sur la surface fleet ;
#   2. le contenu sort [TAG]-prefixe (contrat validateTaggedContent du CLI) ;
#   3. la clef d idempotence est stable par machine+kind+jour UTC, et change
#      quand le kind change (une panne differente est une information neuve) ;
#   4. AUCUN agent n est spawné : un faux `claude` en tete de PATH ecrirait un
#      marqueur si le helper l appelait ; le marqueur doit rester absent.
#   5. un CLI absent ne fait pas echouer la sonde : retour $false, pas d exception.
#
# Les motifs sont ecrits entre apostrophes simples (pas d interpolation du $),
# et sans apostrophe interne.
BeforeAll {
    $projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
    . (Join-Path $projectRoot "scripts/monitoring/embeddings-alert.ps1")

    # Les fichiers CITENT l incident en prose (« un claude -p par tir »). Une
    # assertion nue sur le motif matcherait donc les commentaires et ne dirait
    # rien du code. On retire les blocs <# ... #> et les lignes # avant
    # d asserter : le test doit mordre sur un APPEL, pas sur la phrase qui le
    # raconte. Le Describe de controle verifie que ce detourage mord lui-meme.
    function Get-EmbAlertCodeOnly {
        param([string]$Text)
        $stripped = [regex]::Replace($Text, '(?s)<#.*?#>', '')
        return (($stripped -split "\r?\n" | Where-Object { $_ -notmatch '^\s*#' }) -join "`n")
    }

    $script:tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("emb-alert-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:tmp -Force | Out-Null

    # CLI factice : journalise son argv (JSON par ligne) et rend le JSON de succes.
    $fakeRoot = Join-Path $script:tmp 'rsm'
    $scriptsDir = Join-Path $fakeRoot 'scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    $body = 'import { appendFileSync } from "fs";' +
        'appendFileSync(process.env.EMB_ALERT_CLI_LOG, JSON.stringify(process.argv.slice(2)) + "\n");' +
        'process.stdout.write(JSON.stringify({ok:true,messageId:"stub"}));'
    [System.IO.File]::WriteAllText((Join-Path $scriptsDir 'rsm-dashboard-append.mjs'), $body, [System.Text.UTF8Encoding]::new($false))
    $script:fakeRoot = $fakeRoot

    # Faux `claude` en tete de PATH : s il est appele, il ecrit un marqueur.
    $script:binDir = Join-Path $script:tmp 'bin'
    New-Item -ItemType Directory -Path $script:binDir -Force | Out-Null
    $script:marker = Join-Path $script:tmp 'agent-spawned.txt'
    $fakeClaude = "@echo off`r`necho spawned> `"$($script:marker)`"`r`nexit /b 0`r`n"
    [System.IO.File]::WriteAllText((Join-Path $script:binDir 'claude.cmd'), $fakeClaude, [System.Text.UTF8Encoding]::new($false))
    $script:prevPath = $env:PATH
    $env:PATH = "$($script:binDir);$($script:prevPath)"

    $script:cliLog = Join-Path $script:tmp 'cli-argv.log'
    $env:EMB_ALERT_CLI_LOG = $script:cliLog
    $script:fixedNow = [datetime]::new(2026, 10, 27, 12, 0, 0, [System.DateTimeKind]::Utc)
}

AfterAll {
    $env:PATH = $script:prevPath
    Remove-Item Env:\EMB_ALERT_CLI_LOG -ErrorAction SilentlyContinue
    if (Test-Path $script:tmp) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe "Helper d alerte embeddings -- post deterministe par CLI" {
    It "Doit poster via le CLI sur la surface fleet, pas sur machine-<id>" {
        if (Test-Path $script:cliLog) { Remove-Item $script:cliLog -Force }
        $ok = Send-DashboardAlert -Tag 'CRITICAL' -Message 'Embeddings endpoint down' -FailureKind 'http' `
            -MachineName 'myia-ai-01' -RsmRoot $script:fakeRoot -NowUtc $script:fixedNow
        $ok | Should -BeTrue
        $argv = (Get-Content $script:cliLog | Select-Object -Last 1) | ConvertFrom-Json
        ($argv -join ' ') | Should -Match '--dashboard workspace:roo-extensions'
        ($argv -join ' ') | Should -Match '--author-workspace monitoring'
    }

    It "Le contenu parti doit etre [TAG]-prefixe (contrat validateTaggedContent)" {
        $argv = (Get-Content $script:cliLog | Select-Object -Last 1) | ConvertFrom-Json
        $content = $argv[[array]::IndexOf($argv, '--content') + 1]
        $content | Should -Match '^\[CRITICAL\] '
    }

    It "Le tag WARN doit produire un contenu [WARN]" {
        $null = Send-DashboardAlert -Tag 'WARN' -Message 'degraded latency' -FailureKind 'degraded' `
            -MachineName 'myia-ai-01' -RsmRoot $script:fakeRoot -NowUtc $script:fixedNow
        $argv = (Get-Content $script:cliLog | Select-Object -Last 1) | ConvertFrom-Json
        $argv[[array]::IndexOf($argv, '--content') + 1] | Should -Match '^\[WARN\] '
    }

    It "Le post doit PORTER la clef d idempotence (sinon chaque tir reposte et l agent revient)" {
        # Sans ce controle, supprimer `--message-id` de l appel CLI laisserait la
        # suite verte : la fonction de clef serait testee, mais jamais branchee.
        # Ce serait exactement le multiplicateur d origine, deplace d un cran.
        $null = Send-DashboardAlert -Tag 'CRITICAL' -Message 'idempotence check' -FailureKind 'http' `
            -MachineName 'myia-ai-01' -RsmRoot $script:fakeRoot -NowUtc $script:fixedNow
        $argv = (Get-Content $script:cliLog | Select-Object -Last 1) | ConvertFrom-Json
        ($argv -join ' ') | Should -Match '--message-id'
        $argv[[array]::IndexOf($argv, '--message-id') + 1] | Should -Be 'myia-ai-01:embeddings-alert:http:20261027'
    }
}

Describe "Helper d alerte embeddings -- clef d idempotence" {
    It "Deux tirs du meme jour et du meme kind portent le MEME messageId" {
        $a = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'http' -NowUtc $script:fixedNow
        $b = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'http' -NowUtc $script:fixedNow.AddMinutes(29)
        $a | Should -Be $b
        $a | Should -Be 'myia-ai-01:embeddings-alert:http:20261027'
    }

    It "Un kind different porte un messageId different (information neuve)" {
        $http = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'http' -NowUtc $script:fixedNow
        $tcp = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'unknown' -NowUtc $script:fixedNow
        $tcp | Should -Not -Be $http
    }

    It "Le jour UTC suivant porte un messageId different" {
        $d1 = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'http' -NowUtc $script:fixedNow
        $d2 = Get-EmbeddingsAlertMessageId -MachineName 'myia-ai-01' -FailureKind 'http' -NowUtc $script:fixedNow.AddDays(1)
        $d2 | Should -Not -Be $d1
    }

    It "Le nom de machine est normalise en minuscules (identite de claim)" {
        (Get-EmbeddingsAlertMessageId -MachineName 'MYIA-AI-01' -FailureKind 'http' -NowUtc $script:fixedNow) |
            Should -Match '^myia-ai-01:'
    }
}

Describe "Helper d alerte embeddings -- aucun agent n est spawné" {
    It "Un faux claude en tete de PATH ne doit jamais etre appele" {
        if (Test-Path $script:marker) { Remove-Item $script:marker -Force }
        $null = Send-DashboardAlert -Tag 'CRITICAL' -Message 'still down' -FailureKind 'http' `
            -MachineName 'myia-ai-01' -RsmRoot $script:fakeRoot -NowUtc $script:fixedNow
        $ok = Send-DashboardAlert -Tag 'WARN' -Message 'degraded' -FailureKind 'degraded' `
            -MachineName 'myia-ai-01' -RsmRoot $script:fakeRoot -NowUtc $script:fixedNow
        $ok | Should -BeTrue
        Test-Path $script:marker | Should -BeFalse
    }

    It "Le detourage des commentaires doit mordre dans les DEUX sens" {
        # Sans ce controle, l assertion suivante pourrait etre verte pour la
        # mauvaise raison (motif introuvable meme dans du vrai code).
        $proseOnly = @'
# commentaire : un claude -p ici
<#
bloc : claude -p la aussi
#>
Write-Host 'ok'
'@
        (Get-EmbAlertCodeOnly -Text $proseOnly) | Should -Not -Match 'claude\s+-p'
        (Get-EmbAlertCodeOnly -Text '& claude -p "prompt"') | Should -Match 'claude\s+-p'
    }

    It "Le helper ne doit contenir aucun appel a claude (la prose citee ne compte pas)" {
        $helperText = Get-Content (Join-Path $projectRoot 'scripts/monitoring/embeddings-alert.ps1') -Raw
        $helperCode = Get-EmbAlertCodeOnly -Text $helperText
        $helperCode | Should -Not -Match 'claude\s+-p'
        $helperCode | Should -Not -Match 'Get-Command claude'
        $helperCode | Should -Not -Match 'Start-Process[^\r\n]*claude'
    }
}

Describe "Helper d alerte embeddings -- le trou doit etre visible, pas silencieux" {
    It "Un CLI absent rend $false sans lever d exception" {
        $absent = Join-Path $script:tmp 'rsm-absent'
        $result = Send-DashboardAlert -Tag 'WARN' -Message 'x' -FailureKind 'degraded' `
            -MachineName 'myia-ai-01' -RsmRoot $absent -NowUtc $script:fixedNow 6>$null
        $result | Should -BeFalse
    }
}
