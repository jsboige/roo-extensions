<#
.SYNOPSIS
    Guards the global-rules deployment check wired into the executor pre-flight (#2368 volet 2).

.DESCRIPTION
    Two halves, same shape as the #4336 manifest suite:

    - TEXT contracts on scripts/claude/executor-preflight.ps1: the probe is invoked
      with the repo flag, a finding (exit 2) and an instrument error are branched
      separately, and the block never changes the pre-flight's own exit
      (WARN-never-block). Both executor entry points (skill + command) must
      instruct the cycle to relay the [RULES-DEPLOY] WARN.

    - BEHAVIOUR: the checker is EXECUTED against fixtures. #4365 taught the fleet
      that a text-only suite can be green while the defect stands. The three
      states that matter are proven by running it: a rule missing from the global
      dir is a finding, an identical copy is clean, and a copy re-introduced in
      .claude/rules/ is the duplicate this volet removed — it must be flagged.
#>

Describe 'Executor pre-flight global-rules check (#2368 volet 2)' {
    BeforeAll {
        $repoRoot = Join-Path $PSScriptRoot '..\..\..'
        $preflightPath = Join-Path $repoRoot 'scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw
        $checkerPath = Join-Path $repoRoot 'scripts\diagnostic\check-global-rules.py'
        $skillPath = Join-Path $repoRoot '.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $repoRoot '.claude\commands\executor.md'
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)

        # A minimal repo shape: only what the checker reads.
        function New-RulesFixture {
            param([string]$Name, [string[]]$Sources, [string[]]$Deployed, [string[]]$ProjectCopies)
            $root = Join-Path $TestDrive $Name
            $src = Join-Path $root '.claude\configs\rules'
            $proj = Join-Path $root '.claude\rules'
            $gl = Join-Path $root 'global-rules'
            New-Item -ItemType Directory -Force -Path $src, $proj, $gl | Out-Null
            foreach ($f in $Sources) {
                [System.IO.File]::WriteAllText((Join-Path $src $f), "# $f`n", (New-Object System.Text.UTF8Encoding($false)))
            }
            foreach ($f in $Deployed) {
                [System.IO.File]::WriteAllText((Join-Path $gl $f), "# $f`n", (New-Object System.Text.UTF8Encoding($false)))
            }
            foreach ($f in $ProjectCopies) {
                [System.IO.File]::WriteAllText((Join-Path $proj $f), "# $f summary`n", (New-Object System.Text.UTF8Encoding($false)))
            }
            return [pscustomobject]@{ Repo = $root; Global = $gl }
        }

        function Invoke-Checker {
            param([pscustomobject]$Fixture)
            $out = & python $checkerPath --repo $Fixture.Repo --global-dir $Fixture.Global 2>&1 | Out-String
            return [pscustomobject]@{ Output = $out; Exit = $LASTEXITCODE }
        }
    }

    Context 'text contracts on the pre-flight' {
        It 'parses executor-preflight.ps1 under PowerShell' {
            $errors.Count | Should -Be 0
        }

        It 'invokes the checker with the repo flag' {
            $preflight | Should -Match ([regex]::Escape('scripts/diagnostic/check-global-rules.py'))
            $preflight | Should -Match '\$rulesCheck'
            $preflight | Should -Match ([regex]::Escape('--repo'))
        }

        It 'branches on the finding contract (exit 2) and instrument error separately' {
            $preflight | Should -Match '\$rulesExit -eq 2'
            $preflight | Should -Match '\$rulesExit -ne 0'
            $preflight | Should -Match '\[executor-preflight\]\[RULES-DEPLOY\]'
        }

        It 'warns without blocking — the pre-flight keeps its own exit' {
            $block = [regex]::Match($preflight, '(?s)\$rulesCheck = .*?exit 0')
            $block.Success | Should -BeTrue
            $block.Value | Should -Match 'Write-Warning'
            $block.Value | Should -Not -Match 'exit [1-9]'
        }

        It 'routes the RULES-DEPLOY warning to a dashboard relay in both executor entry points' {
            $skill | Should -Match '\[RULES-DEPLOY\]'
            $command | Should -Match '\[RULES-DEPLOY\]'
            $skill | Should -Match 'tag `WARN`'
            $command | Should -Match '\[WARN\]'
        }

        It 'names the deploy command the relay must run' {
            $skill | Should -Match 'Deploy-GlobalConfig\.ps1 -Target rules'
            $command | Should -Match 'Deploy-GlobalConfig\.ps1 -Target rules'
        }
    }

    Context 'behaviour — the checker is executed' {
        It 'keeps its own selftest green' {
            & python $checkerPath --selftest | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        It 'is clean when every source rule is deployed verbatim (control)' {
            $fx = New-RulesFixture -Name 'clean' -Sources @('a.md', 'b.md') -Deployed @('a.md', 'b.md')
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 0
            $r.Output | Should -Not -Match 'MISSING'
        }

        It 'flags a rule the seat never deployed (the hole the project copies used to fill)' {
            $fx = New-RulesFixture -Name 'missing' -Sources @('a.md', 'b.md') -Deployed @('a.md')
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 2
            $r.Output | Should -Match 'MISSING\s+b\.md'
        }

        It 'flags a deployed rule whose content lags the source' {
            $fx = New-RulesFixture -Name 'stale' -Sources @('a.md') -Deployed @()
            [System.IO.File]::WriteAllText((Join-Path $fx.Global 'a.md'), "# older`n", (New-Object System.Text.UTF8Encoding($false)))
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 2
            $r.Output | Should -Match 'STALE\s+a\.md'
        }

        It 'flags a copy re-introduced in .claude/rules/ (the double load this volet removed)' {
            $fx = New-RulesFixture -Name 'dupe' -Sources @('a.md') -Deployed @('a.md') -ProjectCopies @('a.md')
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 2
            $r.Output | Should -Match 'DUPLICATE\s+a\.md'
        }

        It 'does not let a project copy mask an undeployed rule (worst case)' {
            $fx = New-RulesFixture -Name 'dupe-missing' -Sources @('a.md') -Deployed @() -ProjectCopies @('a.md')
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 2
            $r.Output | Should -Match 'DUPLICATE\s+a\.md'
            $r.Output | Should -Match 'MISSING'
        }

        It 'reports an instrument error when the source directory is absent' {
            $fx = New-RulesFixture -Name 'empty' -Sources @() -Deployed @()
            Remove-Item -Recurse -Force (Join-Path $fx.Repo '.claude\configs\rules')
            $r = Invoke-Checker -Fixture $fx
            $r.Exit | Should -Be 1
        }
    }
}
