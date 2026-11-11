# setup-branch-protection-rest.Tests.ps1 — functional REST read (#4150 lot 7b)
#
# `gh api --jq '.'` pretty-prints an object over MULTIPLE lines. The protection
# reader must join all of them before ConvertFrom-Json: taking just the first
# line reduces the document to `{`. This harness executes the real script
# against a URL-routed gh shim on both Windows PowerShell 5.1 and native pwsh.

BeforeAll {
    $script:RepoRoot = (git -C "$PSScriptRoot/../../.." rev-parse --show-toplevel).Trim()
    $script:TmpRoot = [IO.Path]::GetTempPath()
    $script:HostIsWindows = ($PSVersionTable.PSEdition -eq 'Desktop') -or ($PSVersionTable.Platform -eq 'Win32NT')

    function New-ProtectionGhShim {
        param([Parameter(Mandatory)][string]$Dir)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $protection = [pscustomobject]@{
            required_status_checks = [pscustomobject]@{
                strict = $true
                contexts = @('build-and-test (18)', 'build-and-test (20)')
            }
        } | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText((Join-Path $Dir 'protection.json'), $protection, [Text.Encoding]::ASCII)
        [IO.File]::WriteAllText((Join-Path $Dir 'list.json'), '', [Text.Encoding]::ASCII)

        if ($script:HostIsWindows) {
            $cmd = @(
                '@echo off',
                'setlocal EnableDelayedExpansion',
                'if /I not "%~1"=="api" exit /b 1',
                'set "URL=%~2"',
                'echo "!URL!" | findstr /I /C:"/protection" >nul',
                'if not errorlevel 1 goto protection',
                ('type "{0}"' -f (Join-Path $Dir 'list.json')),
                'exit /b 0',
                ':protection',
                ('type "{0}"' -f (Join-Path $Dir 'protection.json')),
                'exit /b 0'
            )
            [IO.File]::WriteAllText((Join-Path $Dir 'gh.cmd'), ($cmd -join "`r`n") + "`r`n", [Text.Encoding]::ASCII)
        } else {
            $cmd = @(
                '#!/bin/sh',
                ('DIR=''{0}''' -f ($Dir -replace '\\', '/')),
                'case "$2" in',
                '  */protection*) cat "$DIR/protection.json"; exit 0 ;;',
                '  *) cat "$DIR/list.json"; exit 0 ;;',
                'esac'
            )
            $path = Join-Path $Dir 'gh'
            [IO.File]::WriteAllText($path, ($cmd -join "`n") + "`n", [Text.Encoding]::ASCII)
            & chmod +x $path
        }
        return $Dir
    }

    function Invoke-ProtectionScript {
        param([Parameter(Mandatory)][string]$ShimDir)
        $saved = $env:PATH
        try {
            $env:PATH = "$ShimDir$([IO.Path]::PathSeparator)$env:PATH"
            return @(& (Join-Path $script:RepoRoot 'scripts/github/setup-branch-protection.ps1') -DryRun *>&1 | Out-String)
        } finally {
            $env:PATH = $saved
        }
    }
}

Describe 'setup-branch-protection REST protection read (#4645)' {
    It 'parses the whole multiline pretty-printed protection object' {
        $dir = New-ProtectionGhShim -Dir (Join-Path $script:TmpRoot ('protection-shim-' + [guid]::NewGuid().ToString('N')))
        try {
            $output = (Invoke-ProtectionScript -ShimDir $dir) -join "`n"
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match 'Required contexts \(2\)'
            $output | Should -Match 'build-and-test \(18\)'
            $output | Should -Match 'build-and-test \(20\)'
            $output | Should -Match 'No open PRs'
        } finally {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
