<#
.SYNOPSIS
    Behavioural test: ensure-build-fresh.ps1 must not rebuild when only MTIMES moved.

.DESCRIPTION
    The restart treadmill this guards against (measured ai-01, 2026-09-11: ~3 operator restarts
    per day for corrections that did not exist) is a five-step loop in which no step requires a
    real source change:

      1. a git checkout / branch switch / stash / same-sha `submodule update` rewrites src mtimes
      2. the mtime comparison in ensure-build-fresh.ps1 reads STALE
      3. `npm run build` (clean + tsc) rewrites build/index.js unconditionally
      4. every live RSM host now predates that mtime -> ARM guard
      5. operator restarts VS Code; the next git operation returns to step 1

    Test-BuildMatchesSource breaks the loop at step 2 by asking a CONTENT question that mtime
    cannot answer, using the stamp `postbuild` already writes.

    This is a BEHAVIOURAL test, not a source contract: it EXTRACTS the function from the script
    itself and evaluates it against throwaway git repositories, so it cannot drift from what the
    script really executes. It uses only git and portable path handling -- no Get-CimInstance, no
    Windows paths -- so it runs under the Linux pwsh of the `unit-pester` CI job.

.NOTES
    Amends #2822 (STALE-TRAP) and #3489 (ARM guard). Requires Pester 5+.
#>

Describe 'ensure-build-fresh content key -- mtime is not evidence of a source change' {

    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\ensure-build-fresh.ps1'
        $lines = (Get-Content $scriptPath -Raw) -split "`r?`n"

        # Extract the REAL function body from the script under test. A copy pasted into this file
        # could diverge from what ships; this cannot.
        $start = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^function Test-BuildMatchesSource\s*\{') { $start = $i; break }
        }
        if ($start -lt 0) { throw 'Test-BuildMatchesSource not found in ensure-build-fresh.ps1' }
        $end = -1
        for ($i = $start + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\}\s*$') { $end = $i; break }
        }
        if ($end -lt 0) { throw 'closing brace of Test-BuildMatchesSource not found' }
        . ([scriptblock]::Create(($lines[$start..$end] -join "`n")))

        function New-Fixture {
            # Builds parent repo + nested "submodule" repo + a stamped build.
            # -Unpopulated skips the nested git init, reproducing the case where `git -C` walks up
            # to the PARENT instead of failing.
            param([switch]$Unpopulated)

            $root = Join-Path ([System.IO.Path]::GetTempPath()) ('ebf-' + [guid]::NewGuid().ToString('N'))
            $sub  = Join-Path $root  'mcps/internal'
            $mcp  = Join-Path $sub   'servers/roo-state-manager'
            New-Item -ItemType Directory -Path (Join-Path $mcp 'src')   -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $mcp 'build') -Force | Out-Null

            & git -C $root init --quiet 2>$null
            & git -C $root config user.email 'test@example.invalid' 2>$null
            & git -C $root config user.name  'test' 2>$null
            Set-Content -LiteralPath (Join-Path $root 'README.md') -Value 'parent' -NoNewline
            & git -C $root add -A 2>$null
            & git -C $root commit -q -m parent 2>$null

            Set-Content -LiteralPath (Join-Path $mcp 'src/tool.ts')     -Value 'export const x = 1;' -NoNewline
            Set-Content -LiteralPath (Join-Path $mcp 'build/index.js')  -Value 'export const x = 1;' -NoNewline

            # When unpopulated, stamp the PARENT's HEAD. Without the toplevel guard the function
            # would then compare the parent's HEAD to itself, find src/ merely UNTRACKED (so
            # `diff --quiet` stays silent), and wrongly return $true. This makes the case
            # discriminating instead of merely red.
            $sha = (& git -C $root rev-parse HEAD 2>$null).Trim()
            if (-not $Unpopulated) {
                & git -C $sub init --quiet 2>$null
                & git -C $sub config user.email 'test@example.invalid' 2>$null
                & git -C $sub config user.name  'test' 2>$null
                & git -C $sub add -A 2>$null
                & git -C $sub commit -q -m submod 2>$null
                $sha = (& git -C $sub rev-parse HEAD 2>$null).Trim()
            }

            $stamp = [ordered]@{ sha = $sha; shortSha = $(if ($sha) { $sha.Substring(0,8) } else { $null }); dirty = $false; builtAt = '2026-01-01T00:00:00.000Z'; version = '1.0.0' }
            Set-Content -LiteralPath (Join-Path $mcp 'build/build-info.json') -Value ($stamp | ConvertTo-Json)

            [pscustomobject]@{ Root = $root; Sub = $sub; Mcp = $mcp; Build = (Join-Path $mcp 'build'); Sha = $sha }
        }

        function Invoke-Guard {
            param($Fixture)
            Test-BuildMatchesSource -BuildPath $Fixture.Build -McpServerPath $Fixture.Mcp -RepoRoot $Fixture.Root
        }
    }

    It 'accepts a build whose source mtime was rewritten without any content change (the fix)' {
        # NEGATIVE CONTROL for the whole file: without this case, a function that always returned
        # $false would satisfy every refusal test below and look perfectly guarded.
        $f = New-Fixture
        # Reproduce what a checkout does: rewrite the mtime, leave the bytes alone.
        (Get-Item (Join-Path $f.Mcp 'src/tool.ts')).LastWriteTimeUtc = (Get-Date).ToUniversalTime()
        Invoke-Guard $f | Should -BeTrue
    }

    It 'refuses when the stamped sha does not match the submodule HEAD (real source move)' {
        $f = New-Fixture
        $info = Get-Content -Raw (Join-Path $f.Build 'build-info.json') | ConvertFrom-Json
        $info.sha = ('0' * 40)
        Set-Content -LiteralPath (Join-Path $f.Build 'build-info.json') -Value ($info | ConvertTo-Json)
        Invoke-Guard $f | Should -BeFalse
    }

    It 'refuses when src/ carries an uncommitted content change' {
        $f = New-Fixture
        Set-Content -LiteralPath (Join-Path $f.Mcp 'src/tool.ts') -Value 'export const x = 2;' -NoNewline
        Invoke-Guard $f | Should -BeFalse
    }

    It 'refuses when build-info.json is absent' {
        $f = New-Fixture
        Remove-Item -LiteralPath (Join-Path $f.Build 'build-info.json') -Force
        Invoke-Guard $f | Should -BeFalse
    }

    It 'refuses a stamp marked dirty' {
        $f = New-Fixture
        $info = Get-Content -Raw (Join-Path $f.Build 'build-info.json') | ConvertFrom-Json
        $info.dirty = $true
        Set-Content -LiteralPath (Join-Path $f.Build 'build-info.json') -Value ($info | ConvertTo-Json)
        Invoke-Guard $f | Should -BeFalse
    }

    It 'refuses when git -C walks up to the PARENT repo (unpopulated submodule)' {
        # The mechanism, not one of its consequences: -C answered for the wrong repository.
        $f = New-Fixture -Unpopulated
        # Premise: -C really did answer for the parent. Without this the test could go green on a
        # git that simply failed, which is a different world from the one the guard protects.
        $subTop    = (& git -C $f.Mcp  rev-parse --show-toplevel 2>$null).Trim()
        $parentTop = (& git -C $f.Root rev-parse --show-toplevel 2>$null).Trim()
        $subTop | Should -Be $parentTop
        Invoke-Guard $f | Should -BeFalse
    }
}
