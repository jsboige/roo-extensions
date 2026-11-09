# gh-pull-requests-rest.Tests.ps1 — Pester 5 : contrat REST + sentinelle GraphQL
#
# Ce que ces tests prouvent (#4150 lot 2, doctrine #4604) :
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
}
