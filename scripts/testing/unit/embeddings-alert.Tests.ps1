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
# #4393 ajoute le dernier Describe : OUVERTURE => 1 post, un kind different ou
# un passage de 00:00Z => 0 post, CLOTURE => 1 [RESOLVED], etat corrompu =>
# post, post refuse => etat non enregistre (sinon silence sur une panne non lue).
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

# ---------------------------------------------------------------------------
# #4393 -- UN post par INCIDENT, pas par kind ni par jour.
#
# Incident 27/10 : une panne de ~5 h sur po-2023 a produit 4 [CRITICAL] qui se
# contredisaient (le symptome mesure changeait : connexion coupee, puis 502),
# et la FIN de la panne n etait jamais postee. Ces tests pilotent la machine a
# etats avec un CLI factice : ils comptent les POSTS reellement partis, ils ne
# lisent pas la forme du code.
# ---------------------------------------------------------------------------
Describe "Etat d incident embeddings -- un post par incident (#4393)" {
    BeforeAll {
        $script:incRoot = Join-Path $script:tmp ("incident-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $script:incRoot -Force | Out-Null
        $script:incState = Join-Path $script:incRoot 'state/embeddings-incident.json'
        $script:incLog = Join-Path $script:incRoot 'cli.log'
        $script:prevIncCliLog = $env:EMB_ALERT_CLI_LOG
        $env:EMB_ALERT_CLI_LOG = $script:incLog
        $script:incMachine = 'myia-ai-01'
        # 27/10 23:10Z : un incident qui traverse 00:00Z, comme celui du 27/10.
        $script:incStart = [datetime]::new(2026, 10, 27, 23, 10, 0, [System.DateTimeKind]::Utc)

        function Get-IncPostCount {
            param([string]$Path)
            if (-not (Test-Path $Path)) { return 0 }
            return @(Get-Content $Path).Count
        }

        function Get-IncLastArgv {
            param([string]$Path)
            return ((Get-Content $Path | Select-Object -Last 1) | ConvertFrom-Json)
        }

        function Invoke-IncFail {
            param(
                [string]$Kind,
                [datetime]$At,
                [string]$StatePath = $script:incState,
                [string]$Root = $script:fakeRoot
            )
            return Send-EmbeddingsIncidentAlert -Outcome 'FAIL' -FailureKind $Kind `
                -FailureMessage "Embeddings endpoint http://dead/v1 is UNREACHABLE ($Kind)" `
                -MachineName $script:incMachine -StatePath $StatePath -RsmRoot $Root -NowUtc $At
        }

        function Invoke-IncOk {
            param([datetime]$At, [string]$StatePath = $script:incState)
            return Send-EmbeddingsIncidentAlert -Outcome 'OK' -SuccessDetail '412ms, models: bge-m3' `
                -MachineName $script:incMachine -StatePath $StatePath -RsmRoot $script:fakeRoot -NowUtc $At
        }
    }

    AfterAll {
        $env:EMB_ALERT_CLI_LOG = $script:prevIncCliLog
        Remove-Item Env:\EMBEDDINGS_ALERT_INCIDENT_STATE -ErrorAction SilentlyContinue
    }

    It "OUVERTURE : premier echec sans incident ouvert => UN post, clef d incident" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'unknown' -At $script:incStart
        $r.Action | Should -Be 'opened'
        $r.Posted | Should -BeTrue
        (Get-IncPostCount $script:incLog) | Should -Be ($before + 1)

        $argv = Get-IncLastArgv $script:incLog
        $argv[[array]::IndexOf($argv, '--message-id') + 1] |
            Should -Be 'myia-ai-01:embeddings-incident:20261027T2310'
        $argv[[array]::IndexOf($argv, '--content') + 1] | Should -Match '^\[CRITICAL\] '
        Test-Path $script:incState | Should -BeTrue
    }

    It "PENDANT : meme kind 30 min plus tard => ZERO post, compteur mis a jour" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'unknown' -At $script:incStart.AddMinutes(30)
        $r.Action | Should -Be 'suppressed'
        $r.Posted | Should -BeFalse
        (Get-IncPostCount $script:incLog) | Should -Be $before
        ((Get-Content $script:incState -Raw | ConvertFrom-Json).FailureCount) | Should -Be 2
    }

    It "PENDANT : un KIND DIFFERENT (unknown -> http) => ZERO post, kinds accumules" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'http' -At $script:incStart.AddMinutes(45)
        $r.Action | Should -Be 'suppressed'
        (Get-IncPostCount $script:incLog) | Should -Be $before
        $state = Get-Content $script:incState -Raw | ConvertFrom-Json
        @($state.Kinds) | Should -Contain 'http'
        $state.LastKind | Should -Be 'http'
    }

    It "PENDANT : passage de 00:00Z => ZERO post (la clef ne depend pas du jour)" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'http' -At $script:incStart.Date.AddDays(1).AddMinutes(5)
        $r.Action | Should -Be 'suppressed'
        (Get-IncPostCount $script:incLog) | Should -Be $before
        ((Get-Content $script:incState -Raw | ConvertFrom-Json).FailureCount) | Should -Be 4
    }

    It "CLOTURE : premier succes => UN [RESOLVED] sous sa propre clef, puis etat efface" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncOk -At $script:incStart.AddMinutes(90)
        $r.Action | Should -Be 'resolved'
        $r.Posted | Should -BeTrue
        $r.MessageId | Should -Be 'myia-ai-01:embeddings-incident:20261027T2310:resolved'
        (Get-IncPostCount $script:incLog) | Should -Be ($before + 1)

        $argv = Get-IncLastArgv $script:incLog
        $argv[[array]::IndexOf($argv, '--message-id') + 1] | Should -Be $r.MessageId
        $content = $argv[[array]::IndexOf($argv, '--content') + 1]
        $content | Should -Match '^\[RESOLVED\] '
        $content | Should -Match 'unknown -> http'
        $content | Should -Match '1 h 30 min'
        $content | Should -Match '4 failed probe'
        Test-Path $script:incState | Should -BeFalse
    }

    It "CLOTURE : un succes sans incident ouvert => aucun post" {
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncOk -At $script:incStart.AddMinutes(120)
        $r.Action | Should -Be 'none'
        $r.Posted | Should -BeFalse
        (Get-IncPostCount $script:incLog) | Should -Be $before
    }

    It "Un ETAT CORROMPU poste quand meme (jamais silencieux) et se repare" {
        $badState = Join-Path $script:incRoot 'corrupt/embeddings-incident.json'
        New-Item -ItemType Directory -Path (Split-Path $badState -Parent) -Force | Out-Null
        [System.IO.File]::WriteAllText($badState, '{ ceci n est pas du json', [System.Text.UTF8Encoding]::new($false))

        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'http' -At $script:incStart.AddMinutes(150) -StatePath $badState 6>$null
        $r.Action | Should -Be 'opened'
        $r.Posted | Should -BeTrue
        (Get-IncPostCount $script:incLog) | Should -Be ($before + 1)
        # L etat reecrit est exploitable : le tir suivant se tait.
        ((Get-Content $badState -Raw | ConvertFrom-Json).IncidentId) | Should -Be $r.MessageId
    }

    It "Un POST REFUSE ne marque pas l incident comme annonce (sinon silence sur une panne non lue)" {
        $refusedState = Join-Path $script:incRoot 'refused/embeddings-incident.json'
        $absentRoot = Join-Path $script:incRoot 'rsm-absent'
        $before = Get-IncPostCount $script:incLog
        $r = Invoke-IncFail -Kind 'http' -At $script:incStart.AddMinutes(180) -StatePath $refusedState -Root $absentRoot 6>$null
        $r.Action | Should -Be 'opened'
        $r.Posted | Should -BeFalse
        Test-Path $refusedState | Should -BeFalse
        (Get-IncPostCount $script:incLog) | Should -Be $before
    }

    It "Un CLI qui ECRIT sur stdout puis echoue ne marque pas l incident (la garde lit le code de sortie)" {
        $noisyRoot = Join-Path $script:incRoot 'rsm-noisy'
        New-Item -ItemType Directory -Path (Join-Path $noisyRoot 'scripts') -Force | Out-Null
        $noisy = 'process.stdout.write("partial output");process.exit(1);'
        [System.IO.File]::WriteAllText((Join-Path $noisyRoot 'scripts/rsm-dashboard-append.mjs'), $noisy, [System.Text.UTF8Encoding]::new($false))
        $noisyState = Join-Path $script:incRoot 'noisy/embeddings-incident.json'
        $r = Invoke-IncFail -Kind 'http' -At $script:incStart.AddMinutes(240) -StatePath $noisyState -Root $noisyRoot 6>$null
        $r.Posted | Should -BeFalse
        Test-Path $noisyState | Should -BeFalse
    }

    It "KILL-SWITCH EMBEDDINGS_ALERT_INCIDENT_STATE=0 : clef historique, aucun etat" {
        $legacyState = Join-Path $script:incRoot 'legacy/embeddings-incident.json'
        try {
            $env:EMBEDDINGS_ALERT_INCIDENT_STATE = '0'
            Test-EmbeddingsIncidentStateDisabled | Should -BeTrue
            $before = Get-IncPostCount $script:incLog
            $r = Invoke-IncFail -Kind 'http' -At $script:incStart.AddMinutes(20) -StatePath $legacyState
            $r.Action | Should -Be 'legacy'
            $r.MessageId | Should -Be 'myia-ai-01:embeddings-alert:http:20261027'
            (Get-IncPostCount $script:incLog) | Should -Be ($before + 1)
            Test-Path $legacyState | Should -BeFalse
        } finally {
            Remove-Item Env:\EMBEDDINGS_ALERT_INCIDENT_STATE -ErrorAction SilentlyContinue
        }
        Test-EmbeddingsIncidentStateDisabled | Should -BeFalse
    }
}
