<#
.SYNOPSIS
    Drift-guard for the #3731 stderr class, lot 3 residuals:
    scripts/review/auto-review.ps1 (9 sites) and
    scripts/mcp/test-jupyter-papermill-mcp-integration.ps1 (1 site converted,
    1 deliberately retained). Lots 1-2 were covered by #3733/#3734/#3739/#3740/#3742.

    A PS-level `2>$null`/`2>&1` on a native still lets PS 5.1 mint ErrorRecords
    from stderr; under a file-global EAP=Stop the first one terminates the script
    on a call that succeeded. The converted sites now discard/merge stderr at the
    cmd.exe layer (`2>nul`/`2>&1` inside `& cmd /c "..."`): no ErrorRecord ever
    exists, under any EAP, and $LASTEXITCODE keeps propagating.

    The lot also fixes 4 pre-existing PS 5.1 parse errors in the jupyter script
    (bare `$tool:` in strings = invalid scoped-variable reference) — the file did
    not parse at all under `powershell.exe -File`, the canonical fleet invocation.
    The parse assertions below pin that regression.

    One site is deliberately NOT converted: test-jupyter-papermill-mcp-integration
    :~254 invokes `conda run ... python -c <multi-line here-string>` — the payload
    cannot be spliced into a cmd string without breaking on embedded quotes and
    newlines. Its PS-level `2>&1` stays, wrapped in a try/catch, and the test
    below asserts the documented form so a silent re-audit does not "fix" it.
#>

Describe 'stderr class lot 3 residuals (#3731)' {
    BeforeAll {
        $root = Join-Path $PSScriptRoot '..\..\..'
        $script:files = @{
            autoreview = Join-Path $root 'scripts\review\auto-review.ps1'
            jupyter    = Join-Path $root 'scripts\mcp\test-jupyter-papermill-mcp-integration.ps1'
        }
        $script:src = @{}
        $script:parseErrors = @{}
        foreach ($k in $script:files.Keys) {
            $p = $script:files[$k]
            $script:src[$k] = Get-Content $p -Raw
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errors)
            $script:parseErrors[$k] = @($errors).Count
        }
    }

    It 'both scripts parse cleanly under the running PowerShell engine' {
        $script:parseErrors['autoreview'] | Should -Be 0
        $script:parseErrors['jupyter'] | Should -Be 0
    }

    It 'auto-review reads git metadata via cmd-layer discard' {
        $s = $script:src.autoreview
        $s | Should -Match 'cmd /c "git rev-parse HEAD 2>nul"'
        $s | Should -Match 'cmd /c "git rev-parse \$DiffRange 2>nul"'
        $s | Should -Match 'cmd /c "git log --format=""%s"" -1 HEAD 2>nul"'
        $s | Should -Match 'cmd /c "git log --format=""%an"" -1 HEAD 2>nul"'
        $s | Should -Match 'cmd /c "git diff --stat \$DiffRange HEAD 2>nul"'
        $s | Should -Match 'cmd /c "git diff \$DiffRange HEAD --no-color 2>nul"'
        $s | Should -Not -Match 'git rev-parse HEAD 2>\$null'
        $s | Should -Not -Match 'git diff --stat "\$DiffRange" HEAD 2>\$null'
        $s | Should -Not -Match 'git log --format="%s" -1 HEAD 2>\$null'
    }

    It 'auto-review merges build/test stderr at the cmd layer and drops the superseded EAP-relax' {
        $s = $script:src.autoreview
        $s | Should -Match 'cmd /c "npm\.cmd run build 2>&1" \| Select-Object -Last 10'
        $s | Should -Match 'cmd /c "npx vitest run --maxWorkers=1 2>&1" \| Select-Object -Last 20'
        $s | Should -Not -Match '& npm\.cmd run build 2>&1'
        $s | Should -Not -Match '& npx vitest run --maxWorkers=1 2>&1'
        # The scoped relax existed only to survive PS-minted ErrorRecords from these two
        # calls — with the cmd layer it is dead code and must not come back.
        $s | Should -Not -Match '\$prevPref'
    }

    It 'auto-review exit gates still read $LASTEXITCODE right after each cmd-layer call' {
        $s = $script:src.autoreview
        $s | Should -Match 'npm\.cmd run build 2>&1" \| Select-Object -Last 10\r?\n\s*\$buildOk = \(\$LASTEXITCODE -eq 0\)'
        $s | Should -Match 'npx vitest run --maxWorkers=1 2>&1" \| Select-Object -Last 20\r?\n\s*\$testOk = \(\$LASTEXITCODE -eq 0\)'
    }

    It 'jupyter script reads conda envs via cmd-layer discard' {
        $s = $script:src.jupyter
        $s | Should -Match 'cmd /c "conda info --envs 2>nul" \| Select-String \$EnvName'
        $s | Should -Not -Match 'conda info --envs 2>\$null'
    }

    It 'jupyter python -c invocation keeps its documented PS-level merge (non cmd-spliceable payload)' {
        # Deliberate exception, documented in-source: the multi-line python -c payload
        # cannot be spliced into a cmd string. This assertion pins the documented form
        # so a later sweep does not convert it blindly.
        $script:src.jupyter | Should -Match '& \$testCommand\[0\] \$testCommand\[1\.\.\(\$testCommand\.Length-1\)\] 2>&1'
    }

    It 'jupyter strings use ${tool} delimiting (PS 5.1 parse regression guard)' {
        $s = $script:src.jupyter
        $s | Should -Match '\$\{tool\}: Trouvé'
        $s | Should -Match '\$\{tool\}: Non trouvé'
        $s | Should -Match '\$\{tool\}: Test inconclus'
        $s | Should -Match '\$\{tool\}: Erreur'
        $s | Should -Not -Match '\$tool: '
    }
}
