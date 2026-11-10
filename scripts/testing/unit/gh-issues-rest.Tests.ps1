# gh-issues-rest.Tests.ps1 — Pester 5 : contrat REST + sentinelle GraphQL (#4150 lot 7)
#
# Ce que ces tests prouvent (même grille que gh-pull-requests-rest.Tests.ps1,
# lots 2-5, doctrine #4604) :
#   1. la parité de forme avec `gh --json` : champs minuscules (number, title,
#      updatedAt), state MAJUSCULE (gh émet OPEN/CLOSES ; REST open/closed),
#      labels [{name}] et assignees [{login}] — OBJETS, pas scalaires (le reaper
#      coordinator lit `$_.assignees | % { $_.login }`) ;
#   2. l'exclusion des PRs : GET /issues renvoie aussi les PRs (is_pr dans la
#      fixture post-jq) — `gh issue list` n'en a jamais rendu ;
#   3. la SENTINELLE : un shim `gh` qui ÉCHOUE sur tout ce qui n'est pas
#      `gh api` ne gêne pas la lecture, et le log n'enregistre QUE des appels
#      api — si une jambe GraphQL subsistait, elle échouerait et rougirait ;
#   4. échec ≠ absence : `gh api` exit 1 rend Ok = $false avec le motif, pas
#      un tableau vide silencieux ;
#   5. #3731 : sous EAP=Stop en 5.1, le stderr d'un natif redirigé est
#      TERMINANT — le catch du helper contient la panne (Ok défini) ;
#   6. la négation de label côté client (-ExcludeLabels) et le paramètre
#      serveur `labels=` asserté dans le log d'URL ;
#   7. Get-IssueDetail refuse un numéro de PR (parité `gh issue view`) et
#      traite une sortie vide en échec, pas en « issue introuvable silencieuse ».
#
# Portabilité : les DEUX hôtes (powershell.exe 5.1 sièges, pwsh/ubuntu CI job
# `unit-pester`) — slashes `/`, [IO.Path]::GetTempPath(), shim gh.cmd sous
# Windows / script sh exécutable ailleurs. Fixtures en forme POST-JQ (le shim
# ne filtre pas : il rejoue ce que `gh api --jq` aurait émis, une ligne JSON
# par objet — mesuré lot 2).
#
# Exécution : powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/gh-issues-rest.Tests.ps1

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot/../../.." rev-parse --show-toplevel).Trim()
    $script:Helper = Join-Path $script:RepoRoot 'scripts/common/gh-issues.ps1'
    $script:TmpRoot = [System.IO.Path]::GetTempPath()
    # PAS « IsWindows » : variable AUTOMATIQUE read-only en pwsh 7 (CI).
    $script:HostIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT')

    # Shim gh ROUTÉ sur l'URL : /comments, /issues? (liste), /issues/{n} (détail).
    # Fixtures FICHIERS rejoués par type/cat (jamais echo : les parenthèses des
    # noms casseraient cmd). Tout ce qui n'est pas `gh api` simule un 403 GraphQL.
    function New-GhIssuesShim {
        param(
            [Parameter(Mandatory)][string]$Dir,
            [string]$ListJson = '',
            [string]$DetailJson = '',
            [string]$CommentsJson = '',
            [switch]$FailList,
            [switch]$NoisyStderr
        )
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $log = Join-Path $Dir 'calls.log'
        foreach ($pair in @(
            @{ f = 'list.json'; c = $ListJson }, @{ f = 'detail.json'; c = $DetailJson },
            @{ f = 'comments.json'; c = $CommentsJson }
        )) {
            [System.IO.File]::WriteAllText((Join-Path $Dir $pair.f), $pair.c, [System.Text.Encoding]::ASCII)
        }
        if ($FailList) { New-Item -ItemType File -Path (Join-Path $Dir 'fail-list.flag') -Force | Out-Null }
        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'if /I not "%~1"=="api" goto graphql',
                'set "URL=%~2"',
                ('>>"{0}" echo api "%URL%"' -f $log),
                'echo "%URL%" | findstr /I /C:"/comments" >nul',
                'if not errorlevel 1 goto comments',
                'echo "%URL%" | findstr /I /C:"/issues?" >nul',
                'if not errorlevel 1 goto list',
                'goto detail',
                ':comments',
                ('type "{0}"' -f (Join-Path $Dir 'comments.json')),
                'exit /b 0',
                ':list',
                ('if exist "{0}" exit /b 1' -f (Join-Path $Dir 'fail-list.flag')),
                ('type "{0}"' -f (Join-Path $Dir 'list.json')),
                'exit /b 0',
                ':detail',
                ('type "{0}"' -f (Join-Path $Dir 'detail.json')),
                'exit /b 0',
                ':graphql',
                ('>>"{0}" echo %~1' -f $log),
                'echo GraphQL: API rate limit exceeded for user ID 999. 1>&2',
                'exit /b 1'
            )
            if ($NoisyStderr) { $cmd = $cmd[0..2] + 'echo warning: deprecation notice 1>&2' + $cmd[3..($cmd.Count - 1)] }
            [System.IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
        }
        else {
            $cmd = @(
                '#!/bin/sh',
                ('LOG=''{0}''' -f ($log -replace '\\', '/')),
                ('DIR=''{0}''' -f ($Dir -replace '\\', '/')),
                'if [ "$1" = "api" ]; then',
                '  printf ''%s\n'' "api $2" >> "$LOG"',
                '  case "$2" in',
                '    */comments*) cat "$DIR/comments.json"; exit 0 ;;',
                '    */issues?*) if [ -f "$DIR/fail-list.flag" ]; then exit 1; fi; cat "$DIR/list.json"; exit 0 ;;',
                '    *) cat "$DIR/detail.json"; exit 0 ;;',
                '  esac',
                'else',
                '  printf ''%s\n'' "$1" >> "$LOG"',
                '  echo ''GraphQL: API rate limit exceeded for user ID 999.'' 1>&2',
                '  exit 1',
                'fi'
            )
            if ($NoisyStderr) { $cmd = $cmd[0..2] + '  echo ''warning: deprecation notice'' 1>&2' + $cmd[3..($cmd.Count - 1)] }
            $ghPath = Join-Path $Dir 'gh'
            [System.IO.File]::WriteAllText($ghPath, ($cmd -join "`n") + "`n", [System.Text.Encoding]::ASCII)
            & chmod +x $ghPath
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

    . $script:Helper

    # Fixtures en forme post-jq : ce que `gh api --jq $IssueSummaryJq` émettrait.
    # 101/102 copilot-target (102 porte AUSSI frozen), 103 sans label, 900 = PR
    # (is_pr — une PR est une issue côté REST, jamais rendue par gh issue list).
    $script:ListFixture = (@(
        '{"number": 101, "title": "Bug one", "body": "b101", "state": "open", "url": "https://github.com/jsboige/roo-extensions/issues/101", "updatedAt": "2026-11-09T10:00:00Z", "labels": [{"name": "copilot-target"}], "assignees": [{"login": "jsboige"}], "is_pr": false}',
        '{"number": 102, "title": "Bug two", "body": "b102", "state": "closed", "url": "https://github.com/jsboige/roo-extensions/issues/102", "updatedAt": "2026-11-09T11:00:00Z", "labels": [{"name": "copilot-target"}, {"name": "frozen"}], "assignees": [], "is_pr": false}',
        '{"number": 103, "title": "Bug three", "body": "b103", "state": "open", "url": "https://github.com/jsboige/roo-extensions/issues/103", "updatedAt": "2026-11-09T12:00:00Z", "labels": [], "assignees": [], "is_pr": false}',
        '{"number": 900, "title": "PR hidden", "body": "b900", "state": "open", "url": "https://github.com/jsboige/roo-extensions/pull/900", "updatedAt": "2026-11-09T13:00:00Z", "labels": [], "assignees": [], "is_pr": true}'
    ) -join "`n") + "`n"

    $script:DetailFixture = '{"number": 101, "title": "Bug one", "body": "b101", "state": "open", "url": "https://github.com/jsboige/roo-extensions/issues/101", "updatedAt": "2026-11-09T10:00:00Z", "labels": [{"name": "bug"}], "assignees": [{"login": "jsboige"}], "is_pr": false}' + "`n"

    # Fixture « réponse du serveur À la requête labels=copilot-target » (le shim
    # ne filtre pas : il rejoue ce que le serveur aurait rendu POUR cette
    # requête) — 103 sans label n'y vit pas, 102 porte frozen en plus.
    $script:ListLabeledFixture = (@(
        '{"number": 101, "title": "Bug one", "body": "b101", "state": "open", "url": "https://github.com/jsboige/roo-extensions/issues/101", "updatedAt": "2026-11-09T10:00:00Z", "labels": [{"name": "copilot-target"}], "assignees": [], "is_pr": false}',
        '{"number": 102, "title": "Bug two", "body": "b102", "state": "closed", "url": "https://github.com/jsboige/roo-extensions/issues/102", "updatedAt": "2026-11-09T11:00:00Z", "labels": [{"name": "copilot-target"}, {"name": "frozen"}], "assignees": [], "is_pr": false}',
        '{"number": 900, "title": "PR hidden", "body": "b900", "state": "open", "url": "https://github.com/jsboige/roo-extensions/pull/900", "updatedAt": "2026-11-09T13:00:00Z", "labels": [], "assignees": [], "is_pr": true}'
    ) -join "`n") + "`n"

    $script:DetailPrFixture = '{"number": 901, "title": "A pull request", "body": "", "state": "open", "url": "https://github.com/jsboige/roo-extensions/pull/901", "updatedAt": "2026-11-09T10:00:00Z", "labels": [], "assignees": [], "is_pr": true}' + "`n"

    $script:CommentsFixture = (@(
        '{"author": {"login": "worker-a"}, "body": "[CLAIMED] myia-po-2028 takes it", "createdAt": "2026-11-10T10:00:00Z"}',
        '{"author": {"login": "worker-b"}, "body": "plain comment", "createdAt": "2026-11-10T11:00:00Z"}'
    ) -join "`n") + "`n"
}

Describe 'Get-IssueSummary (REST, #4150 lot 7)' {
    It 'rend la forme gh : champs minuscules, state MAJUSCULE, labels/assignees objets — et EXCLUT les PRs' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions -State open }
            $r.Ok | Should -BeTrue
            @($r.Items).Count | Should -Be 3
            ($r.Items | Where-Object { $_.number -eq 900 }) | Should -BeNullOrEmpty
            $i = $r.Items | Where-Object { $_.number -eq 102 }
            $i.state | Should -Be 'CLOSED'
            $i.title | Should -Be 'Bug two'
            $i.updatedAt | Should -Be '2026-11-09T11:00:00Z'
            @($i.labels).Count | Should -Be 2
            $i.labels[0].name | Should -Be 'copilot-target'
            $a = $r.Items | Where-Object { $_.number -eq 101 }
            $a.assignees[0].login | Should -Be 'jsboige'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'sentinelle GraphQL : le log ne contient QUE des appels api, jamais une sous-commande gh' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture
        try {
            $null = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions -State open }
            $log = Get-CallLog $shim.Log
            @($log).Count | Should -BeGreaterThan 0
            @($log | Where-Object { $_ -notmatch '^api ' }).Count | Should -Be 0
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'passe le filtre labels côté SERVEUR (labels= dans l URL loguée)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture
        try {
            $null = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions -Labels @('copilot-target') }
            (Get-CallLog $shim.Log) -match 'labels=copilot-target' | Should -Not -BeNullOrEmpty
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'ExcludeLabels filtre côté CLIENT (-label:x de --search)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListLabeledFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions -Labels @('copilot-target') -ExcludeLabels @('frozen') }
            $r.Ok | Should -BeTrue
            @($r.Items).Count | Should -Be 1
            $r.Items[0].number | Should -Be 101
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'MaxCount tronque aux plus récentes (ordre created desc conservé)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions -MaxCount 2 }
            @($r.Items).Count | Should -Be 2
            $r.Items[0].number | Should -Be 101
            $r.Items[1].number | Should -Be 102
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'échec gh api = Ok false avec motif, PAS un tableau vide (échec != absence)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture -FailList
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions }
            $r.Ok | Should -BeFalse
            $r.Error | Should -Match 'exit 1'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It '#3731 : stderr bruité sous EAP=Stop 5.1 ne tue pas le helper (Ok défini)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -ListJson $script:ListFixture -NoisyStderr
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueSummary -Repo jsboige/roo-extensions }
            $r.Ok | Should -BeTrue
            @($r.Items).Count | Should -Be 3
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Get-IssueDetail (REST, #4150 lot 7)' {
    It 'rend le détail dans la même forme que la liste' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -DetailJson $script:DetailFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueDetail -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeTrue
            $r.Item.number | Should -Be 101
            $r.Item.state | Should -Be 'OPEN'
            $r.Item.url | Should -Be 'https://github.com/jsboige/roo-extensions/issues/101'
            $r.Item.labels[0].name | Should -Be 'bug'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'refuse un numéro de PR (parité gh issue view), Ok false explicite' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -DetailJson $script:DetailPrFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueDetail -Repo jsboige/roo-extensions -Number 901 }
            $r.Ok | Should -BeFalse
            $r.Error | Should -Match 'pull request'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'sortie vide = échec explicite, pas « issue introuvable » silencieuse' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -DetailJson ''
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueDetail -Repo jsboige/roo-extensions -Number 424242 }
            $r.Ok | Should -BeFalse
            $r.Error | Should -Match 'sortie vide'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

Describe 'Get-IssueComments (REST, #4150 lot 7)' {
    It 'rend les commentaires en casse gh : author.login, body, createdAt' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -CommentsJson $script:CommentsFixture
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueComments -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeTrue
            @($r.Items).Count | Should -Be 2
            $r.Items[0].author.login | Should -Be 'worker-a'
            $r.Items[0].body | Should -Match '\[CLAIMED\]'
            $r.Items[0].createdAt | Should -Be '2026-11-10T10:00:00Z'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'zéro commentaire = Ok true, Items vide (pas une erreur)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        $shim = New-GhIssuesShim -Dir $dir -CommentsJson ''
        try {
            $r = Invoke-WithShim $shim.Dir { Get-IssueComments -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeTrue
            @($r.Items).Count | Should -Be 0
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }

    It 'échec gh api = Ok false avec motif (le claim check du vibe-worker reste fail-closed)' {
        $dir = Join-Path $script:TmpRoot ('gh-issues-shim-' + [guid]::NewGuid().ToString('N'))
        # Pas de flag FailComments : on force l échec via une liste en erreur et
        # l URL de commentaires routée vers detail (Dir sans comments.json la
        # route comments sert un fichier vide -> Ok true ; l échec se prouve
        # plutôt par exit non-nul simulé par le shim GraphQL sur sous-commande).
        # Plus direct : shim dont SEULE la route comments échoue.
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $log = Join-Path $dir 'calls.log'
        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'if /I not "%~1"=="api" goto graphql',
                ('>>"{0}" echo api %~2' -f $log),
                'exit /b 1',
                ':graphql',
                'exit /b 1'
            )
            [System.IO.File]::WriteAllText((Join-Path $dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
        }
        else {
            $cmd = @('#!/bin/sh', 'exit 1')
            $ghPath = Join-Path $dir 'gh'
            [System.IO.File]::WriteAllText($ghPath, ($cmd -join "`n") + "`n", [System.Text.Encoding]::ASCII)
            & chmod +x $ghPath
        }
        try {
            $r = Invoke-WithShim $dir { Get-IssueComments -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeFalse
            $r.Error | Should -Match 'exit 1'
        }
        finally { Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}
