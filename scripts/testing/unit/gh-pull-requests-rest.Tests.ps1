# gh-pull-requests-rest.Tests.ps1 — Pester 5 : contrat REST + sentinelle GraphQL
#
# Ce que ces tests prouvent (#4150 lots 2-3, doctrine #4604) :
#   1. la normalisation REST -> contrat historique : `state = closed` + `merged_at`
#      devient MERGED (c'est la forme que les 4 appelants comparaient déjà) ;
#   2. la SENTINELLE : un shim `gh` qui ÉCHOUE sur tout ce qui n'est pas `gh api`
#      (message « rate limit » GraphQL, exit 1) ne gêne pas la lecture — si une jambe
#      GraphQL subsistait, elle échouerait et le test rougirait ;
#   3. échec ≠ absence : un `gh api` en erreur rend Ok = $false (les appelants
#      conservent leur branche), pas un tableau vide ;
#   4. #3731 (review #4616 R2) : sous EAP=Stop en 5.1, le stderr d'un natif redirigé
#      est TERMINANT — le catch du helper contient la panne (Ok défini, pas de crash) ;
#   5. re-filtre `-Head` (review #4616 mineur) : le gh CLI peut manger le filtre
#      `head=` (substitution de placeholder sur le token « branch ») — la réponse est
#      re-filtrée sur ce qui a été demandé.
#   6. LOT 3 : Get-PullRequestDetail compose la forme « gh pr view --json » depuis
#      4 endpoints REST (PR, files, reviews, check-runs) — files[].path (REST:
#      filename), casse MAJUSCULE du rollup (REST: minuscule, mesuré #4620),
#      reviewDecision approximé des revues chronologiques — et tout échec d'appel
#      rend Ok = $false (un détail partiel ne doit jamais passer pour un CI green).
#
# Portabilité (review #4616 R1) : ce fichier tourne sur les DEUX hôtes — powershell.exe
# 5.1 sur les sièges Windows, pwsh/ubuntu en CI (job `unit-pester`). Conséquences :
#   - chemins en slashes `/` (les backslashs ne sont pas des séparateurs sous POSIX :
#     `git -C "$PSScriptRoot\..\..\.."` crashe le BeforeAll en CI) ;
#   - [IO.Path]::GetTempPath() (pas $env:TEMP, non défini sous Linux) ;
#   - shim gh.cmd sous Windows, script sh exécutable sous Linux.
#
# Exécution : powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/testing/run-pester-tests.ps1 -Path scripts/testing/unit/gh-pull-requests-rest.Tests.ps1

BeforeAll {
    # Slashes POSIX : git les accepte sous Windows, ils sont natifs sous Linux.
    $script:RepoRoot = (git -C "$PSScriptRoot/../../.." rev-parse --show-toplevel).Trim()
    $script:Helper = Join-Path $script:RepoRoot 'scripts/common/gh-pull-requests.ps1'
    # $env:TEMP n'existe pas sous Linux ; GetTempPath() rend /tmp là-bas.
    $script:TmpRoot = [System.IO.Path]::GetTempPath()
    # PAS « IsWindows » : variable AUTOMATIQUE read-only en pwsh 7 (CI) — l'assigner
    # lève SessionStateUnauthorizedAccessException ; inexistante en 5.1, d'où le
    # vert local / rouge CI du premier push.
    $script:HostIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT')

    # Shim gh : seul `gh api` répond ; tout le reste simule un 403 GraphQL.
    # Le log d'appels (1er argument seulement — jamais %*, qui casserait sur `|` du jq)
    # permet d'affirmer qu'aucune sous-commande GraphQL n'a été invoquée.
    function New-GhShim {
        param(
            [Parameter(Mandatory)][string]$Dir,
            [Parameter(Mandatory)][string]$Json,
            [int]$ExitCode = 0,
            # Émettre du stderr MÊME sur le chemin api (classe #3731) : sous 5.1 EAP=Stop,
            # le stderr d'un natif redirigé est terminant ; le catch du helper doit contenir.
            [switch]$NoisyStderr
        )
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $log = Join-Path $Dir 'calls.log'
        # `gh api --jq '.[] | {...}'` rend UN OBJET JSON PAR LIGNE, jamais un tableau :
        # le shim doit reproduire ce contrat, sinon il testerait une sortie que gh ne
        # produit pas (mesuré : un tableau d'une ligne était relu comme un objet unique
        # dont les champs étaient des tableaux).
        # Windows PowerShell 5.1 rend un tableau JSON comme UN SEUL objet de pipeline
        # (pas d'énumération) : on matérialise d'abord, sinon les deux PR sortent sur
        # une seule ligne et le helper les relit comme un objet unique.
        $parsed = ConvertFrom-Json -InputObject $Json
        $lines = @(foreach ($item in @($parsed)) { $item | ConvertTo-Json -Compress -Depth 5 })
        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'if /I "%~1"=="api" goto rest',
                ('>>"{0}" echo %~1' -f $log),
                'echo GraphQL: API rate limit exceeded for user ID 999. 1>&2',
                'exit /b 1',
                ':rest',
                ('>>"{0}" echo api' -f $log)
            )
            if ($NoisyStderr) { $cmd += 'echo warning: deprecation notice 1>&2' }
            $cmd += @($lines | ForEach-Object { 'echo ' + $_ })
            $cmd += @(('exit /b {0}' -f $ExitCode))
            # WriteAllText déterministe : Set-Content ajoute un CRLF final qui,
            # côté sh, rend `fi\r` != mot-clé fi (fumé sous WSL : « expecting fi »).
            [System.IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
        }
        else {
            # POSIX : script sh exécutable. Les lignes JSON n'y contiennent ni quote
            # simple ni backslash (fixtures contrôlées ci-dessous).
            $cmd = @(
                '#!/bin/sh',
                ('LOG=''{0}''' -f ($log -replace '\\', '/')),
                'if [ "$1" = "api" ]; then',
                '  printf ''%s\n'' ''api'' >> "$LOG"'
            )
            if ($NoisyStderr) { $cmd += '  echo ''warning: deprecation notice'' 1>&2' }
            $cmd += @($lines | ForEach-Object { '  printf ''%s\n'' ''' + $_ + '''' })
            $cmd += @(
                ('  exit {0}' -f $ExitCode),
                'else',
                '  printf ''%s\n'' "$1" >> "$LOG"',
                '  echo ''GraphQL: API rate limit exceeded for user ID 999.'' 1>&2',
                '  exit 1',
                'fi'
            )
            $ghPath = Join-Path $Dir 'gh'
            # LF purs, pas de CRLF final (Set-Content en ajoute un : sous dash,
            # `fi\r` n'est pas le mot-clé fi — fumé WSL, « Syntax error: expecting fi »).
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

    # Shim gh ROUTÉ (lot 3) : Get-PullRequestDetail fait 4 appels `gh api` DISTINCTS
    # (pulls/{n}, pulls/{n}/files, pulls/{n}/reviews, commits/{sha}/check-runs) — un
    # shim à réponse unique ne peut pas les servir. Celui-ci dispatch sur l'URL et
    # `type`/`cat` les FIXTURES (fichiers .json — jamais `echo`, qui casserait sur les
    # parenthèses des noms de check-runs type « build-and-test (20) »).
    # -FailRuns : la route check-runs échoue (exit 1) — pour le test fail-safe.
    # -FailAll : toutes les routes échouent — pour « échec ≠ absence ».
    # Tout ce qui n'est pas `gh api` simule un 403 GraphQL (sentinelle).
    function New-GhShimRouted {
        param(
            [Parameter(Mandatory)][string]$Dir,
            [Parameter(Mandatory)][string]$PrJson,
            [string]$FilesJson = '',
            [string]$ReviewsJson = '',
            [string]$RunsJson = '',
            [switch]$FailRuns,
            [int]$ExitCode = 0
        )
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $log = Join-Path $Dir 'calls.log'
        foreach ($pair in @(
            @{ f = 'pr.json'; c = $PrJson }, @{ f = 'files.json'; c = $FilesJson },
            @{ f = 'reviews.json'; c = $ReviewsJson }, @{ f = 'runs.json'; c = $RunsJson }
        )) {
            [System.IO.File]::WriteAllText((Join-Path $Dir $pair.f), $pair.c, [System.Text.Encoding]::ASCII)
        }
        if ($FailRuns) { New-Item -ItemType File -Path (Join-Path $Dir 'fail-runs.flag') -Force | Out-Null }
        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'if /I not "%~1"=="api" goto graphql',
                'set "URL=%~2"',
                ('>>"{0}" echo api "%URL%"' -f $log),
                'echo "%URL%" | findstr /I /C:"/files" >nul',
                'if not errorlevel 1 goto files',
                'echo "%URL%" | findstr /I /C:"/reviews" >nul',
                'if not errorlevel 1 goto reviews',
                'echo "%URL%" | findstr /I /C:"/check-runs" >nul',
                'if not errorlevel 1 goto runs',
                'goto pr',
                ':files',
                ('type "{0}"' -f (Join-Path $Dir 'files.json')),
                ('exit /b {0}' -f $ExitCode),
                ':reviews',
                ('type "{0}"' -f (Join-Path $Dir 'reviews.json')),
                ('exit /b {0}' -f $ExitCode),
                ':runs',
                ('if exist "{0}" exit /b 1' -f (Join-Path $Dir 'fail-runs.flag')),
                ('type "{0}"' -f (Join-Path $Dir 'runs.json')),
                ('exit /b {0}' -f $ExitCode),
                ':pr',
                ('type "{0}"' -f (Join-Path $Dir 'pr.json')),
                ('exit /b {0}' -f $ExitCode),
                ':graphql',
                ('>>"{0}" echo %~1' -f $log),
                'echo GraphQL: API rate limit exceeded for user ID 999. 1>&2',
                'exit /b 1'
            )
            [System.IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [System.Text.Encoding]::ASCII)
        }
        else {
            $cmd = @(
                '#!/bin/sh',
                ('LOG=''{0}''' -f ($log -replace '\\', '/')),
                ('DIR=''{0}''' -f ($Dir -replace '\\', '/')),
                ('EXIT={0}' -f $ExitCode),
                'if [ "$1" = "api" ]; then',
                '  printf ''%s\n'' "api $2" >> "$LOG"',
                '  case "$2" in',
                '    */files*) cat "$DIR/files.json"; exit $EXIT ;;',
                '    */reviews*) cat "$DIR/reviews.json"; exit $EXIT ;;',
                '    */check-runs*) if [ -f "$DIR/fail-runs.flag" ]; then exit 1; fi; cat "$DIR/runs.json"; exit $EXIT ;;',
                '    *) cat "$DIR/pr.json"; exit $EXIT ;;',
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
        return [pscustomobject]@{ Dir = $Dir; Log = $log }
    }

    function Get-CallLog {
        param([string]$Log)
        if (-not (Test-Path $Log)) { return @() }
        return @(Get-Content -Path $Log | Where-Object { $_ })
    }

    . $script:Helper
}

Describe 'Get-PullRequestSummary — normalisation REST (#4150)' {
    It 'closed + merged_at -> MERGED (le contrat des appelants est préservé)' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":42,"state":"closed","merged_at":"2026-08-05T10:00:00Z","head_ref":"wt/merged"}]'
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/merged -MaxCount 1 }

            $s.Ok | Should -BeTrue
            $s.Items.Count | Should -Be 1
            $s.Items[0].State | Should -Be 'MERGED'
            $s.Items[0].Number | Should -Be 42
            $s.Items[0].HeadRefName | Should -Be 'wt/merged'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'closed sans merged_at -> CLOSED ; open -> OPEN' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":7,"state":"closed","merged_at":null,"head_ref":"wt/abandoned"},{"number":8,"state":"open","merged_at":null,"head_ref":"wt/wip"}]'
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -State all }
            $s.Ok | Should -BeTrue
            ($s.Items | Where-Object { $_.Number -eq 7 }).State | Should -Be 'CLOSED'
            ($s.Items | Where-Object { $_.Number -eq 8 }).State | Should -Be 'OPEN'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'SENTINELLE : un gh qui refuse toute sous-commande non-api ne bloque pas la lecture' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":43,"state":"open","merged_at":null,"head_ref":"wt/open-pr"}]'
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/open-pr -MaxCount 1 }

            $s.Ok | Should -BeTrue
            $s.Items[0].State | Should -Be 'OPEN'
            # Preuve d'absence de jambe GraphQL : le shim échoue (exit 1) sur `pr list`,
            # `issue view`, `graphql` — le seul appel tracé doit être `api`.
            $calls = Get-CallLog -Log $shim.Log
            $calls.Count | Should -BeGreaterThan 0
            @($calls | Where-Object { $_ -ne 'api' }) | Should -BeNullOrEmpty
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'échec gh -> Ok = $false (fail-safe appelant), pas un tableau vide trompeur' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '{"message":"Server Error"}' -ExitCode 1
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/x -MaxCount 1 }

            $s.Ok | Should -BeFalse
            @($s.Items).Count | Should -Be 0
            $s.Error | Should -Match 'exit 1'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It '#3731 : stderr non vide sous EAP=Stop est terminant en 5.1 — le catch rend Ok, jamais un crash (review #4616 R2)' {
        # gh réussit (exit 0) MAIS écrit sur stderr. Sans le catch, le chemin 5.1
        # meurt (NativeCommandError TERMINANT sous EAP=Stop) AVANT le fail-safe
        # « KEPT » — ce que ce test pousse et vérifie.
        # Assertion par hôte, honnête sur ce qui est mesuré :
        #   - powershell.exe 5.1 (mesuré sur ce siège) : Ok = $false — la panne
        #     stderr est contenue par le catch, l'appelant garde sa branche ;
        #   - pwsh 7 (CI) : la VALEUR dépend de sémantiques stderr propres à chaque
        #     7.x, non mesurées depuis un siège sans pwsh — on n'affirme que la
        #     forme (Ok défini, pas de crash, cohérence Items).
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":9,"state":"open","merged_at":null,"head_ref":"wt/noisy"}]' -NoisyStderr
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir {
                $ErrorActionPreference = 'Stop'
                Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/noisy -MaxCount 1
            }
            ($s.Ok -is [bool]) | Should -BeTrue
            if ($PSVersionTable.PSEdition -ne 'Core') {
                $s.Ok | Should -BeFalse
            }
            elseif ($s.Ok) {
                $s.Items[0].Number | Should -Be 9
            }
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 're-filtre -Head : une réponse non filtrée (placeholder « branch » du gh CLI) ne rend PAS la PR d un tiers (review #4616 mineur)' {
        # Mesuré en review : head=jsboige:branch-foo rend des rows NON filtrés quand le
        # nom contient le token « branch ». Le shim simule exactement ça : on demande
        # wt/wanted, il rend branch-foo — le helper doit rendre ZÉRO item, pas la PR d'autrui.
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":77,"state":"open","merged_at":null,"head_ref":"branch-foo"},{"number":78,"state":"closed","merged_at":"2026-08-05T10:00:00Z","head_ref":"other/branch-x"}]'
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -Head wt/wanted -MaxCount 1 }

            $s.Ok | Should -BeTrue
            @($s.Items).Count | Should -Be 0
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Get-MergedPullRequestHeads (#4150)' {
    It 'ne retient que les mergées, une entrée par tête de branche' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":42,"state":"closed","merged_at":"2026-08-05T10:00:00Z","head_ref":"wt/a"},{"number":9,"state":"closed","merged_at":null,"head_ref":"wt/b"}]'
        try {
            $r = Invoke-WithShim -ShimDir $shim.Dir { Get-MergedPullRequestHeads -Repo jsboige/roo-extensions }

            $r.Ok | Should -BeTrue
            $r.Map.ContainsKey('wt/a') | Should -BeTrue
            $r.Map['wt/a'] | Should -Be 42
            $r.Map.ContainsKey('wt/b') | Should -BeFalse
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Aucune jambe GraphQL ne subsiste dans le lot (#4150)' {
    It 'les 4 consommateurs ne contiennent plus d appel `gh pr list` exécutable' {
        $root = $script:RepoRoot
        $targets = @(
            'scripts/claude/worktree-cleanup.ps1',
            'scripts/cleanup-orphan-branches.ps1',
            'scripts/scheduling/cleanup-orphan-branches.ps1',
            'scripts/git/triage-merged-branches.ps1'
        )
        foreach ($t in $targets) {
            $src = Get-Content (Join-Path $root $t) -Raw
            # Forme COMMANDE : commentaires de rationale admis, appel nu interdit.
            $src | Should -Not -Match '(?m)^\s*(\$[A-Za-z0-9_]+\s*=\s*)?&?\s*gh\s+pr\s+list'
        }
    }

    It 'lot 3 : review-bot / pr-review-and-merge / dashboard-listener ne contiennent plus d appel `gh pr list|view` / `gh issue view` exécutable' {
        $root = $script:RepoRoot
        $targets = @(
            'scripts/github/review-bot.ps1',
            'scripts/github/pr-review-and-merge.ps1',
            'scripts/dashboard-scheduler/dashboard-listener.ps1'
        )
        foreach ($t in $targets) {
            $src = Get-Content (Join-Path $root $t) -Raw
            # `gh pr diff` (REST-backed) et les mutations (pr review/comment/merge) restent
            # hors périmètre du recensement c.85 — seules les lectures GraphQL-burnantes.
            $src | Should -Not -Match '(?m)^\s*(\$[A-Za-z0-9_]+\s*=\s*)?&?\s*gh\s+(pr\s+(list|view)|issue\s+view)'
        }
    }
}

Describe 'Get-PullRequestDetail — composition REST (#4150 lot 3)' {
    BeforeAll {
        # Fixtures : une ligne JSON par item (contrat `gh api --jq` sans --slurp).
        # Casse REST volontairement minuscule (completed/success — mesuré sur #4620) :
        # la normalisation MAJUSCULE est précisément ce que ces tests vérifient.
        $script:PrJson = '{"number":101,"state":"open","merged":false,"title":"feat: add REST","body":"b","login":"alice","additions":10,"deletions":2,"mergeable":true,"head_ref":"wt/rest","head_sha":"abc123def","base_ref":"main","labels":["bug","approved"]}'
        $script:FilesJson = '{"path":"scripts/a.ps1","additions":5,"deletions":1}' + "`n" + '{"path":"scripts/b.ps1","additions":5,"deletions":1}'
        $script:RunsJson = '{"name":"build-and-test (20)","status":"completed","conclusion":"success"}' + "`n" + '{"name":"pending-check","status":"in_progress","conclusion":null}'
    }

    It 'rend la forme « gh pr view --json » : files[].path (REST: filename), rollup MAJUSCULE, reviewDecision composé' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson $script:PrJson -FilesJson $script:FilesJson `
            -ReviewsJson ('{"state":"CHANGES_REQUESTED"}' + "`n" + '{"state":"APPROVED"}') `
            -RunsJson $script:RunsJson
        try {
            $d = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestDetail -Repo jsboige/roo-extensions -Number 101 }

            $d.Ok | Should -BeTrue
            $d.Item.State | Should -Be 'OPEN'
            $d.Item.Title | Should -Be 'feat: add REST'
            $d.Item.Author.login | Should -Be 'alice'
            $d.Item.Mergeable | Should -BeTrue
            $d.Item.Additions | Should -Be 10
            $d.Item.HeadSha | Should -Be 'abc123def'
            # files[].path — parité gh (REST appelle le champ `filename`)
            $d.Item.Files.Count | Should -Be 2
            $d.Item.Files[0].path | Should -Be 'scripts/a.ps1'
            $d.Item.Labels -contains 'bug' | Should -BeTrue
            # reviewDecision : dernière revue significative (CHANGES_REQUESTED puis APPROVED -> APPROVED)
            $d.Item.ReviewDecision | Should -Be 'APPROVED'
            # statusCheckRollup : casse REST minuscule -> MAJUSCULE (forme gh mesurée)
            $d.Item.StatusCheckRollup.Count | Should -Be 2
            $done = @($d.Item.StatusCheckRollup | Where-Object { $_.Name -eq 'build-and-test (20)' })[0]
            $done.Status | Should -Be 'COMPLETED'
            $done.Conclusion | Should -Be 'SUCCESS'
            $pending = @($d.Item.StatusCheckRollup | Where-Object { $_.Name -eq 'pending-check' })[0]
            $pending.Status | Should -Be 'IN_PROGRESS'
            $pending.Conclusion | Should -BeNullOrEmpty
            # SENTINELLE : le shim échoue (exit 1) sur toute sous-commande non-api ;
            # la moindre jambe GraphQL ferait échouer le fetch OU laisserait une trace.
            $calls = Get-CallLog -Log $shim.Log
            $calls.Count | Should -BeGreaterThan 0
            @($calls | Where-Object { $_ -notmatch '^api ' }) | Should -BeNullOrEmpty
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'closed + merged -> MERGED (même normalisation que la liste)' {
        $prMerged = $script:PrJson -replace '"state":"open","merged":false', '"state":"closed","merged":true'
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson $prMerged -FilesJson $script:FilesJson -ReviewsJson '' -RunsJson $script:RunsJson
        try {
            $d = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestDetail -Repo jsboige/roo-extensions -Number 101 }
            $d.Ok | Should -BeTrue
            $d.Item.State | Should -Be 'MERGED'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'zéro check-run -> StatusCheckRollup vide et Ok (le chemin « pas de CI » de review-bot survit)' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson $script:PrJson -FilesJson $script:FilesJson -ReviewsJson '' -RunsJson ''
        try {
            $d = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestDetail -Repo jsboige/roo-extensions -Number 101 }
            $d.Ok | Should -BeTrue
            @($d.Item.StatusCheckRollup).Count | Should -Be 0
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'échec du fetch PR -> Ok = $false avec motif « pr: » (échec != absence)' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson $script:PrJson -ExitCode 1
        try {
            $d = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestDetail -Repo jsboige/roo-extensions -Number 101 }
            $d.Ok | Should -BeFalse
            $d.Item | Should -BeNullOrEmpty
            $d.Error | Should -Match '^pr: '
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'échec SEUL des check-runs -> Ok = $false (un détail partiel ne doit pas servir de CI green)' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson $script:PrJson -FilesJson $script:FilesJson -ReviewsJson '' -RunsJson $script:RunsJson -FailRuns
        try {
            $d = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestDetail -Repo jsboige/roo-extensions -Number 101 }
            $d.Ok | Should -BeFalse
            $d.Error | Should -Match 'check-runs'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Get-PullRequestReviewDecision — approximation chronologique (#4150 lot 3)' {
    It 'CHANGES_REQUESTED puis APPROVED -> APPROVED' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson '{}' -ReviewsJson ('{"state":"CHANGES_REQUESTED"}' + "`n" + '{"state":"APPROVED"}')
        try {
            $r = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestReviewDecision -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeTrue
            $r.Decision | Should -Be 'APPROVED'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'APPROVED puis CHANGES_REQUESTED -> CHANGES_REQUESTED (la revue bloquante reste la dernière)' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson '{}' -ReviewsJson ('{"state":"APPROVED"}' + "`n" + '{"state":"CHANGES_REQUESTED"}')
        try {
            $r = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestReviewDecision -Repo jsboige/roo-extensions -Number 101 }
            $r.Decision | Should -Be 'CHANGES_REQUESTED'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'APPROVED puis DISMISSED -> REVIEW_REQUIRED ; aucune revue -> REVIEW_REQUIRED' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson '{}' -ReviewsJson ('{"state":"APPROVED"}' + "`n" + '{"state":"DISMISSED"}')
        try {
            $r = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestReviewDecision -Repo jsboige/roo-extensions -Number 101 }
            $r.Decision | Should -Be 'REVIEW_REQUIRED'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
        $shim2 = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson '{}' -ReviewsJson ''
        try {
            $r2 = Invoke-WithShim -ShimDir $shim2.Dir { Get-PullRequestReviewDecision -Repo jsboige/roo-extensions -Number 101 }
            $r2.Ok | Should -BeTrue
            $r2.Decision | Should -Be 'REVIEW_REQUIRED'
        }
        finally { Remove-Item $shim2.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'échec du fetch revues -> Ok = $false (skip, pas de commentaire en double)' {
        $shim = New-GhShimRouted -Dir (Join-Path $script:TmpRoot ("ghshim3-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -PrJson '{}' -ReviewsJson '{}' -ExitCode 1
        try {
            $r = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestReviewDecision -Repo jsboige/roo-extensions -Number 101 }
            $r.Ok | Should -BeFalse
            $r.Error | Should -Match 'reviews'
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Get-PullRequestSummary — extensions lot 3 (title / author / labels)' {
    It 'les items portent Title, AuthorLogin et Labels (noms) pour review-bot' {
        $shim = New-GhShim -Dir (Join-Path $script:TmpRoot ("ghshim-" + [guid]::NewGuid().ToString('N').Substring(0, 8))) `
            -Json '[{"number":11,"state":"open","merged_at":null,"head_ref":"wt/x","title":"docs: test","login":"bob","labels":["bug","security"]}]'
        try {
            $s = Invoke-WithShim -ShimDir $shim.Dir { Get-PullRequestSummary -Repo jsboige/roo-extensions -State open }
            $s.Ok | Should -BeTrue
            $s.Items[0].Title | Should -Be 'docs: test'
            $s.Items[0].AuthorLogin | Should -Be 'bob'
            @($s.Items[0].Labels).Count | Should -Be 2
            $s.Items[0].Labels -contains 'security' | Should -BeTrue
        }
        finally { Remove-Item $shim.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}
