# worker-gh-rest.Tests.ps1 — Pester 5 : câblage REST du worker (#4150 lot 8)
#
# Ce que ces tests prouvent : les 5 jambes converties du worker
# (start-claude-worker.ps1) passent bien par les modules REST — pas seulement
# le code PINNÉ l'affirme, le COMPORTEMENT le montre. Les fonctions sont
# extraites du worker par AST (le script de 5 700 lignes n'est jamais exécuté),
# les modules réels (gh-issues.ps1, gh-pull-requests.ps1) sont dot-sourcés, et
# `gh` est un shim PATH routé par URL — même harness que gh-issues-rest.
#
#   * Test-IssueAlreadyProcessed — fenêtre -Last 5, fail-safe Ok=false = $false ;
#   * Test-GitHubIssueLock — fenêtre -Last 3, unknown-age = locked ;
#   * Test-UserApproval — tous les bodies, TaskId sans issue = zéro appel gh ;
#   * Test-GitHubDecision — détail + commentaires, reprise sur CLOSED ;
#   * Request-StaleReview — reviewRequests+headRefOid en UN appel module,
#     skip si reviewers en attente, jamais de sous-commande GraphQL (sentinelle
#     du log : tout est `gh api`).
#
# Portabilité : les DEUX hôtes (powershell.exe 5.1 sièges, pwsh/ubuntu CI job
# `unit-pester`) — slashes `/`, [IO.Path]::GetTempPath(), shim gh.cmd sous
# Windows / script sh exécutable ailleurs.
#
# Exécution : powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/worker-gh-rest.Tests.ps1

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot/../../.." rev-parse --show-toplevel).Trim()
    $script:WorkerPath = Join-Path $script:RepoRoot 'scripts/scheduling/start-claude-worker.ps1'
    $script:TmpRoot = [System.IO.Path]::GetTempPath()
    # PAS « IsWindows » : variable AUTOMATIQUE read-only en pwsh 7 (CI).
    $script:HostIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT')

    # ---- Extraction AST : les fonctions converties, sans exécuter le worker ----
    $errors = $null
    $tokens = $null
    $script:Ast = [System.Management.Automation.Language.Parser]::ParseFile($script:WorkerPath, [ref]$tokens, [ref]$errors)
    $script:ParseErrors = @($errors)

    foreach ($name in @('ConvertTo-UtcDateTime', 'Test-IssueAlreadyProcessed', 'Test-GitHubIssueLock',
                        'Test-UserApproval', 'Test-GitHubDecision', 'Get-StaleReviewers', 'Request-StaleReview')) {
        $fn = $script:Ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $name
        }, $true) | Select-Object -First 1
        if ($fn) { Invoke-Expression $fn.Extent.Text }
        else { throw "fonction $name introuvable dans start-claude-worker.ps1" }
    }

    # Write-Log : stub (les fonctions extraites journalisent — pas le test).
    function Write-Log { param($Message, $Level) }

    # ---- Modules réels : c est le câblage qu on teste, pas les modules ----
    . (Join-Path $script:RepoRoot 'scripts/common/gh-issues.ps1')
    . (Join-Path $script:RepoRoot 'scripts/common/gh-pull-requests.ps1')

    # ---- Shim gh routé par URL (copie du harness gh-issues-rest.Tests.ps1) ----
    function New-WorkerGhShim {
        param(
            [Parameter(Mandatory)][string]$Dir,
            [string]$ListJson = '',
            [string]$DetailJson = '',
            [string]$CommentsJson = ''
        )
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $log = Join-Path $Dir 'calls.log'
        if ($script:HostIsWindows) {
            # Routage par URL : Request-StaleReview appelle aussi `user` et
            # `commits/<sha>` (lot 8) — chaque jambe a SON fichier de réponse.
            $cmd = @(
                '@echo off',
                'if /I not "%~1"=="api" goto graphql',
                'set "URL=%~2"',
                ('>>"{0}" echo api "%URL%"' -f $log),
                'echo "%URL%" | findstr /I /C:"/comments" >nul',
                'if not errorlevel 1 goto comments',
                'echo "%URL%" | findstr /I /C:"/issues?" >nul',
                'if not errorlevel 1 goto list',
                'echo "%URL%" | findstr /I /C:"/commits/" >nul',
                'if not errorlevel 1 goto commits',
                'if /I "%URL%"=="user" goto user',
                'goto detail',
                ':comments',
                ('type "{0}"' -f (Join-Path $Dir 'comments.json')),
                'exit /b 0',
                ':list',
                ('type "{0}"' -f (Join-Path $Dir 'list.json')),
                'exit /b 0',
                ':commits',
                ('type "{0}"' -f (Join-Path $Dir 'commit.json')),
                'exit /b 0',
                ':user',
                ('type "{0}"' -f (Join-Path $Dir 'user.json')),
                'exit /b 0',
                ':detail',
                ('type "{0}"' -f (Join-Path $Dir 'detail.json')),
                'exit /b 0',
                ':graphql',
                ('>>"{0}" echo %~1' -f $log),
                'echo GraphQL: API rate limit exceeded for user ID 999. 1>&2',
                'exit /b 1'
            )
            [System.IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
        }
        else {
            # `?` cité dans le case POSIX (glob sinon — review #4641 point a).
            # user / commits routés comme sous Windows : sinon les 2 jambes de
            # Request-StaleReview recevaient detail.json (JSON brut au lieu
            # d'une date / d'un login) — mesuré CI unit-pester : Expected 4, got 1.
            $cmd = @(
                '#!/bin/sh',
                ('LOG=''{0}''' -f ($log -replace '\\', '/')),
                ('DIR=''{0}''' -f ($Dir -replace '\\', '/')),
                'if [ "$1" = "api" ]; then',
                '  printf ''%s\n'' "api $2" >> "$LOG"',
                '  case "$2" in',
                '    */comments*) cat "$DIR/comments.json"; exit 0 ;;',
                '    */commits/*) cat "$DIR/commit.json"; exit 0 ;;',
                '    user) cat "$DIR/user.json"; exit 0 ;;',
                '    */issues/*) cat "$DIR/detail.json"; exit 0 ;;',
                '    */issues"?"*) cat "$DIR/list.json"; exit 0 ;;',
                '    *) cat "$DIR/detail.json"; exit 0 ;;',
                '  esac',
                'else',
                '  printf ''%s\n'' "$1" >> "$LOG"',
                '  echo ''GraphQL: API rate limit exceeded for user ID 999.'' 1>&2',
                '  exit 1',
                'fi'
            )
            $ghPath = Join-Path $Dir 'gh'
            [System.IO.File]::WriteAllText($ghPath, ($cmd -join "`n") + "`n", [System.Text.Encoding]::ASCII)
            & chmod +x $ghPath
        }
        # Réponses par défaut des jambes Request-StaleReview (lot 8) : une date
        # ISO pour commits/<sha> (jq du worker : .commit.committer.date), un
        # login pour user. Un test peut les écraser via les paramètres.
        $pairs = @(@{ f = 'list.json'; c = $ListJson }, @{ f = 'detail.json'; c = $DetailJson }, @{ f = 'comments.json'; c = $CommentsJson },
                   @{ f = 'commit.json'; c = ('{"commit":{"committer":{"date":"2026-11-10T00:00:00Z"}}}' + "`n") },
                   @{ f = 'user.json'; c = ('{"login":"tester"}' + "`n") })
        foreach ($pair in $pairs) {
            [System.IO.File]::WriteAllText((Join-Path $Dir $pair.f), $pair.c, [System.Text.Encoding]::ASCII)
        }
        return [pscustomobject]@{ Dir = $Dir; Log = $log }
    }

    function Invoke-WithShim {
        param([string]$ShimDir, [scriptblock]$Body)
        $saved = $env:PATH
        try {
            $env:PATH = "$ShimDir$([IO.Path]::PathSeparator)$env:PATH"
            & $Body
        }
        finally { $env:PATH = $saved }
    }

    function Get-CallLog {
        param([string]$Log)
        if (-not (Test-Path $Log)) { return @() }
        return @(Get-Content -Path $Log | Where-Object { $_ })
    }

    # Fixture commentaire — createdAt runtime-relatif (les gardes vivent sur
    # l âge réel : < 6h CLAIMED, < 24h BLOCKED, < 30min LOCK).
    # -Compress OBLIGATOIRE : le ConvertTo-Json de PS 5.1 WRAPPE les chaînes
    # >80 caractères sur plusieurs lignes (mesuré : le body CLAIMED de 52+ chars
    # arrivait en deux lignes, cassant le contrat une-ligne-par-objet du module).
    function New-CommentJson {
        param([string[]]$Bodies, [object[]]$AgesUtc)
        $lines = for ($i = 0; $i -lt $Bodies.Count; $i++) {
            $ts = ((Get-Date).ToUniversalTime().Add([timespan]$AgesUtc[$i])).ToString('yyyy-MM-ddTHH:mm:ssZ')
            '{"author": {"login": "someone"}, "body": ' + ($Bodies[$i] | ConvertTo-Json -Compress) + ', "createdAt": "' + $ts + '"}'
        }
        ($lines -join "`n") + "`n"
    }
}

Describe 'Worker REST wiring — préambule' {
    It 'start-claude-worker.ps1 parse sans erreur (5 700+ lignes, PS 5.1 et pwsh)' {
        $script:ParseErrors.Count | Should -Be 0
    }
}

Describe 'Test-IssueAlreadyProcessed (lot 8 : Get-IssueComments + fenêtre -Last 5)' {
    # PIÈGE Pester 6 : « <...> » dans un NOM de test est un template -TestCases
    # (Pester.psm1:1272 l évalue via ScriptBlock::Create — «< 6h ->» y devient
    # une sous-expression «$ ...» -> CommandNotFoundException «$», AVANT le corps
    # du test, donc incatchable). Aucun chevron ouvrant dans les noms ici.

    It 'CLAIMED by claude de moins de 6h -> $true (skip, ne pas re-traiter)' {
        $json = New-CommentJson @('[CLAIMED] by claude on myia-po-2028:roo-extensions') @([timespan]::FromHours(-2))
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -CommentsJson $json
        try {
            $r = Invoke-WithShim $shim.Dir { Test-IssueAlreadyProcessed -IssueNumber 3560 }
            $r | Should -BeTrue
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'BLOCKED de moins de 24h -> $true ; CLAIMED de plus de 6h sans marqueur -> $false' {
        $blocked = New-CommentJson @('[BLOCKED] awaiting user input') @([timespan]::FromHours(-3))
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -CommentsJson $blocked
        try {
            Invoke-WithShim $shim.Dir { Test-IssueAlreadyProcessed -IssueNumber 1 } | Should -BeTrue
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }

        $stale = New-CommentJson @('[CLAIMED] by claude on myia-po-2028:roo-extensions') @([timespan]::FromHours(-10))
        $dir2 = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim2 = New-WorkerGhShim -Dir $dir2 -CommentsJson $stale
        try {
            Invoke-WithShim $shim2.Dir { Test-IssueAlreadyProcessed -IssueNumber 2 } | Should -BeFalse
        }
        finally { Remove-Item -Recurse -Force $dir2 -ErrorAction SilentlyContinue }
    }

    It 'la fenêtre est bien -Last 5 : un marqueur PLUS VIEUX que la fenêtre n est PAS vu' {
        # L API commentaires rend l ordre chronologique (plus vieux en premier) ;
        # -Last 5 = les 5 PLUS RÉCENTS. Le CLAIMED en PREMIÈRE position (le plus
        # vieux des 6) tombe hors fenêtre : l ancien jq [-5:] ne le voyait pas,
        # le Select-Object -Last 5 non plus.
        $bodies = @('[CLAIMED] by claude on myia-po-2028:roo-extensions', 'plain 1', 'plain 2', 'plain 3', 'plain 4', 'plain 5')
        $ages = @([timespan]::FromHours(-2),
                  [timespan]::FromHours(-1), [timespan]::FromHours(-1.1), [timespan]::FromHours(-1.2),
                  [timespan]::FromHours(-1.3), [timespan]::FromHours(-1.4))
        $json = New-CommentJson $bodies $ages
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -CommentsJson $json
        try {
            Invoke-WithShim $shim.Dir { Test-IssueAlreadyProcessed -IssueNumber 3 } | Should -BeFalse
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-GitHubIssueLock (lot 8 : fenêtre -Last 3, âge < 30 min)' {
    It 'CLAIMED 10 min -> verrou ; CLAIMED 40 min -> libre ; timestamp illisible -> verrou' {
        $locked = New-CommentJson @('[CLAIMED] by claude on myia-po-2028:roo-extensions') @([timespan]::FromMinutes(-10))
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -CommentsJson $locked
        try {
            Invoke-WithShim $shim.Dir { Test-GitHubIssueLock -IssueNumber 100 } | Should -BeTrue
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }

        $expired = New-CommentJson @('[CLAIMED] by claude on myia-po-2028:roo-extensions') @([timespan]::FromMinutes(-40))
        $dir2 = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim2 = New-WorkerGhShim -Dir $dir2 -CommentsJson $expired
        try {
            Invoke-WithShim $shim2.Dir { Test-GitHubIssueLock -IssueNumber 101 } | Should -BeFalse
        }
        finally { Remove-Item -Recurse -Force $dir2 -ErrorAction SilentlyContinue }

        # Timestamp illisible : âge inconnu => LOCK (fail-safe anti-course #2958).
        $illisible = '{"author": {"login": "someone"}, "body": "[CLAIMED] by claude", "createdAt": "not-a-date"}' + "`n"
        $dir3 = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim3 = New-WorkerGhShim -Dir $dir3 -CommentsJson $illisible
        try {
            Invoke-WithShim $shim3.Dir { Test-GitHubIssueLock -IssueNumber 102 } | Should -BeTrue
        }
        finally { Remove-Item -Recurse -Force $dir3 -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-UserApproval (lot 8 : tous les bodies via module)' {
    It 'un body d approbation -> $true ; rien -> $false ; TaskId sans issue -> ZÉRO appel gh' {
        $ok = New-CommentJson @('looks good, [OK] to proceed') @([timespan]::FromHours(-1))
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -CommentsJson $ok
        try {
            Invoke-WithShim $shim.Dir { Test-UserApproval -TaskId 'issue-3560' -WaitState @{} } | Should -BeTrue

            $plain = New-CommentJson @('plain status update') @([timespan]::FromHours(-1))
            [System.IO.File]::WriteAllText((Join-Path $dir 'comments.json'), $plain, [System.Text.Encoding]::ASCII)
            Invoke-WithShim $shim.Dir { Test-UserApproval -TaskId 'issue-3560' -WaitState @{} } | Should -BeFalse

            # TaskId sans numéro -> return $false SANS toucher gh : le log n a pas grandi.
            $before = @(Get-CallLog $shim.Log).Count
            Invoke-WithShim $shim.Dir { Test-UserApproval -TaskId 'adhoc-task' -WaitState @{} } | Should -BeFalse
            @(Get-CallLog $shim.Log).Count | Should -Be $before
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Test-GitHubDecision (lot 8 : Get-IssueDetail + Get-IssueComments)' {
    It 'issue CLOSED -> reprise candidate ($true) — l appel détail est bien REST (issues/N)' {
        $detail = '{"number": 500, "title": "T", "body": "", "state": "closed", "url": "https://github.com/jsboige/roo-extensions/issues/500", "updatedAt": "2026-11-10T10:00:00Z", "labels": [], "assignees": [], "is_pr": false}' + "`n"
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -DetailJson $detail -CommentsJson ''
        try {
            $wait = @{ waitFor = '#500'; timestamp = '2026-11-10T00:00:00Z' }
            $r = Invoke-WithShim $shim.Dir { Test-GitHubDecision -TaskId '#500' -WaitState $wait }
            $r | Should -BeTrue
            (Get-CallLog $shim.Log) -match '/issues/500' | Should -Not -BeNullOrEmpty
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'commentaire d approbation PLUS RÉCENT que le timestamp -> $true ; plus vieux -> $false' {
        $detail = '{"number": 501, "title": "T", "body": "", "state": "open", "url": "https://github.com/jsboige/roo-extensions/issues/501", "updatedAt": "2026-11-10T10:00:00Z", "labels": [], "assignees": [], "is_pr": false}' + "`n"
        $recent = New-CommentJson @('lgtm, proceed') @([timespan]::FromHours(-1))
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -DetailJson $detail -CommentsJson $recent
        try {
            # Timestamp de sauvegarde plus vieux que le commentaire -> visible.
            $waitOld = @{ waitFor = '#501'; timestamp = ((Get-Date).ToUniversalTime().AddHours(-2)).ToString('yyyy-MM-ddTHH:mm:ssZ') }
            Invoke-WithShim $shim.Dir { Test-GitHubDecision -TaskId '#501' -WaitState $waitOld } | Should -BeTrue

            # Timestamp plus récent -> le commentaire est ignoré, pas de reprise.
            $waitNew = @{ waitFor = '#501'; timestamp = ((Get-Date).ToUniversalTime().AddMinutes(-30)).ToString('yyyy-MM-ddTHH:mm:ssZ') }
            Invoke-WithShim $shim.Dir { Test-GitHubDecision -TaskId '#501' -WaitState $waitNew } | Should -BeFalse
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Request-StaleReview (lot 8 : reviewRequests + headRefOid en UN appel module)' {
    It 'reviewers EN ATTENTE -> skip : UN seul appel api, aucun POST' {
        $detail = '{"reviewers":["alice"],"head_sha":"87460acbff0000000000000000000000000000000"}' + "`n"
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -DetailJson $detail
        try {
            Invoke-WithShim $shim.Dir { Request-StaleReview -PrUrl 'https://github.com/jsboige/roo-extensions/pull/4641' }
            $log = @(Get-CallLog $shim.Log)
            # Un seul appel : le pulls/N du module. Le skip arrive AVANT commits/
            # reviews/user — c est la fusion des deux anciennes jambes gh pr view.
            $log.Count | Should -Be 1
            $log[0] | Should -Match '/pulls/4641'
            @($log | Where-Object { $_ -match '-X' }).Count | Should -Be 0
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'aucun reviewer -> la chaîne continue en REST pur (commits, reviews, user) et la sentinelle tient : tout est gh api' {
        $detail = '{"reviewers":[],"head_sha":"87460acbff0000000000000000000000000000000"}' + "`n"
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -DetailJson $detail
        try {
            Invoke-WithShim $shim.Dir { Request-StaleReview -PrUrl 'https://github.com/jsboige/roo-extensions/pull/4641' }
            $log = @(Get-CallLog $shim.Log)
            # pulls/N (module) + commits/<sha> + pulls/N/reviews + user = 4 appels.
            $log.Count | Should -Be 4
            @($log | Where-Object { $_ -notmatch '^api ' }).Count | Should -Be 0
            @($log | Where-Object { $_ -match 'commits/87460acb' }).Count | Should -Be 1
            @($log | Where-Object { $_ -match '/pulls/4641/reviews' }).Count | Should -Be 1
            @($log | Where-Object { $_ -match 'user' }).Count | Should -Be 1
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'URL de PR non reconnue -> return immédiat, ZÉRO appel gh' {
        $dir = Join-Path $script:TmpRoot ('worker-gh-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-WorkerGhShim -Dir $dir -DetailJson '{}'
        try {
            Invoke-WithShim $shim.Dir { Request-StaleReview -PrUrl 'https://example.test/not-a-pr' }
            @(Get-CallLog $shim.Log).Count | Should -Be 0
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}
