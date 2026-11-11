# review-dedup-helper-rest.Tests.ps1 — the two helper reads after #4645
#
# review-dedup-helper reads reviews and comments through the module's paged
# REST helper: a single 100-row page truncated long discussions, and a URL
# carrying literal quotes returns 404 under pwsh on POSIX. verify-commit-
# citations must read a PR detail through the same URL rule, joining the
# pretty-printed `--jq '{...}'` object before ConvertFrom-Json.
#
# Both tests execute the REAL scripts against a URL-routed gh shim and assert
# on the argv gh actually receives, not on the source text.

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot/../../.." rev-parse --show-toplevel).Trim()
    $script:TmpRoot = [IO.Path]::GetTempPath()
    $script:HostIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT')

    function New-Line {
        param([string]$Body, [string]$Date = '2026-11-11T10:00:00Z')
        # Forme rendue par le --jq du module (shim = gh remplacé : le filtre
        # n'est pas rejoué). line/path sont émis à null pour les commentaires
        # de conversation — le script les lit sous StrictMode Latest.
        '{"author": {"login": "tester"}, "state": "COMMENTED", "body": ' +
            ($Body | ConvertTo-Json -Compress) + ', "submittedAt": "' + $Date + '", "createdAt": "' + $Date + '", "line": null, "path": null}'
    }

    function New-RoutedShim {
        param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Routes)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $log = Join-Path $Dir 'calls.log'
        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'setlocal EnableDelayedExpansion',
                'if /I not "%~1"=="api" exit /b 1',
                'set "URL=%~2"',
                ('set "LOG={0}"' -f $log),
                '>>"%LOG%" echo api !URL!',
                $Routes,
                'exit /b 1'
            )
            [IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
        } else {
            $cmd = @(
                '#!/bin/sh',
                ('LOG=''{0}''' -f ($log -replace '\\', '/')),
                'if [ "$1" != "api" ]; then exit 1; fi',
                'printf ''%s\n'' "api $2" >> "$LOG"',
                $Routes,
                'exit 1'
            )
            $path = Join-Path $Dir 'gh'
            [IO.File]::WriteAllText($path, ($cmd -join "`n") + "`n", [Text.Encoding]::ASCII)
            & chmod +x $path
        }
        return [pscustomobject]@{ Dir = $Dir; Log = $log }
    }

    function Invoke-WithShim {
        param([string]$ShimDir, [scriptblock]$Body)
        $saved = $env:PATH
        try {
            $env:PATH = "$ShimDir$([IO.Path]::PathSeparator)$env:PATH"
            & $Body
        } finally { $env:PATH = $saved }
    }

    function Write-Fixture {
        param([string]$Dir, [string]$Name, [string[]]$Lines)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $Dir $Name), (($Lines -join "`n") + "`n"), [Text.Encoding]::ASCII)
    }
}

Describe 'review-dedup-helper — REST pagination and bare URL (#4645)' {
    It 'reads both review pages and the comment page; no literal quotes reach gh' {
        $dir = Join-Path $script:TmpRoot ('dedup-shim-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        Write-Fixture -Dir $dir -Name 'reviews-1.json' -Lines @(1..100 | ForEach-Object { New-Line "review $_" })
        Write-Fixture -Dir $dir -Name 'reviews-2.json' -Lines @(New-Line 'review 101')
        Write-Fixture -Dir $dir -Name 'comments.json' -Lines @(New-Line 'a conversation note')
        if ($script:HostIsWindows) {
            $routes = @(
                'echo "!URL!" | findstr /I /C:"/pulls/" >nul',
                'if errorlevel 1 goto comments',
                'echo "!URL!" | findstr /I /C:"page=2" >nul',
                ('if not errorlevel 1 type "{0}" & exit /b 0' -f (Join-Path $dir 'reviews-2.json')),
                ('type "{0}"' -f (Join-Path $dir 'reviews-1.json')),
                'exit /b 0',
                ':comments',
                ('type "{0}"' -f (Join-Path $dir 'comments.json')),
                'exit /b 0'
            ) -join "`r`n"
        } else {
            $routes = @(
                'case "$2" in',
                ('  */pulls/*page=2*) cat "{0}"; exit 0 ;;' -f (Join-Path $dir 'reviews-2.json')),
                ('  */pulls/*) cat "{0}"; exit 0 ;;' -f (Join-Path $dir 'reviews-1.json')),
                ('  */issues/*) cat "{0}"; exit 0 ;;' -f (Join-Path $dir 'comments.json')),
                'esac'
            ) -join "`n"
        }
        $shim = New-RoutedShim -Dir $dir -Routes $routes
        try {
            $out = Invoke-WithShim $shim.Dir {
                & (Join-Path $script:RepoRoot 'scripts/helpers/review-dedup-helper.ps1') `
                    -RepoOwner jsboige -RepoName roo-extensions -PrNumber 4645 *>&1 | Out-String
            }
            $out | Should -Match 'Deduplication complete: 102 unique points'
            $calls = @(Get-Content $shim.Log)
            @($calls | Where-Object { $_.Contains('"') }) | Should -BeNullOrEmpty
            @($calls | Where-Object { $_ -match '/pulls/.*page=2' }).Count | Should -Be 1
        } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'verify-commit-citations — PR detail join and bare URL (#4645)' {
    It 'verifies a PR citation from a multiline pretty-printed object' {
        $dir = Join-Path $script:TmpRoot ('citation-shim-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        Write-Fixture -Dir $dir -Name 'pr.json' -Lines @('{', '  "state": "closed",', '  "merged": true,', '  "title": "done"', '}')
        if ($script:HostIsWindows) {
            $routes = @(
                'echo "!URL!" | findstr /I /C:"/pulls/" >nul',
                'if errorlevel 1 exit /b 1',
                ('type "{0}"' -f (Join-Path $dir 'pr.json')),
                'exit /b 0'
            ) -join "`r`n"
        } else {
            $routes = @(
                'case "$2" in',
                ('  */pulls/*) cat "{0}"; exit 0 ;;' -f (Join-Path $dir 'pr.json')),
                'esac'
            ) -join "`n"
        }
        $shim = New-RoutedShim -Dir $dir -Routes $routes
        try {
            $out = Invoke-WithShim $shim.Dir {
                & (Join-Path $script:RepoRoot 'scripts/validation/verify-commit-citations.ps1') `
                    -Text '#4644' *>&1 | Out-String
            }
            $out | Should -Match '\[PR MERGED\] done'
            $out | Should -Not -Match '\[Issue'
            $calls = @(Get-Content $shim.Log)
            @($calls | Where-Object { $_.Contains('"') }) | Should -BeNullOrEmpty
        } finally { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
}