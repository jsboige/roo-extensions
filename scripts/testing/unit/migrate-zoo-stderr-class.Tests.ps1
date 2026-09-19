<#
.SYNOPSIS
    Drift-guard for the #3731 stderr class, lot 2 family `migrate-zoo-globalstate-settings`
    in scripts/zoo-scheduler/migrate-zoo-globalstate-settings.ps1 (2 `2>&1` sites under the
    file-global EAP=Stop at line 79).

    A PS-level `2>&1` on a native mints ErrorRecords from stderr; under EAP=Stop the first
    one terminates the script on a call that succeeded. The sites now merge stderr at the
    cmd.exe layer (`2>&1` inside `& cmd /c "..."`): no ErrorRecord ever exists, under any
    EAP, $LASTEXITCODE propagates, and the merged stderr stays in the variable for the
    throw messages below each call.
#>

Describe 'migrate-zoo stderr class, lot 2 family (#3731)' {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\zoo-scheduler\migrate-zoo-globalstate-settings.ps1'
        $script:src = Get-Content $scriptPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$errors)
        $script:parseErrors = @($errors).Count
    }

    It 'parses cleanly' {
        $script:parseErrors | Should -Be 0
    }

    It 'reads python sqlite3 version via cmd-layer stderr merge' {
        $script:src | Should -Match 'cmd /c "python -c ""import sqlite3; print\(sqlite3\.sqlite_version\)"" 2>&1"'
        # The bare PS-level redirect on that call is gone.
        $script:src | Should -Not -Match '& python -c "import sqlite3; print\(sqlite3\.sqlite_version\)" 2>&1'
        # The guard that reports the failure survives.
        $script:src | Should -Match 'Python sqlite3 stdlib not available'
    }

    It 'invokes the vscdb helper via cmd with the piped spec and exit-code guard intact' {
        $script:src | Should -Match '\$output = \$spec \| & cmd /c "python \$helper \$Database 2>&1"'
        $script:src | Should -Not -Match '\$spec \| & python \$helper \$Database 2>&1'
        # The downstream throw that carries $output survives.
        $script:src | Should -Match 'SQLite helper error \(\$Op\): \$output'
    }
}
