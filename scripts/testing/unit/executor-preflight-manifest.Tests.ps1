<#
.SYNOPSIS
    Guards the fleet-manifest drift check wired into the executor pre-flight (#4336).

.DESCRIPTION
    Two halves, deliberately kept apart:

    - TEXT contracts on scripts/claude/executor-preflight.ps1: the verifier is
      invoked with the workspace flag, a finding (exit 2) and an instrument
      error are branched separately, and the block never changes the
      pre-flight's own exit (WARN-never-block, same posture as #3169/#4340).
      Both executor entry points (skill + command) must instruct the cycle to
      relay the WARN — local pre-flight output dies with the log.

    - BEHAVIOUR: the verifier is actually EXECUTED against fixtures. #4365
      taught the fleet that a text-only suite can be 10/10 green while both
      defects are still there, so the connector exclusion is proven by running
      the script: a disable naming a claude.ai connector is a workspace choice,
      and the SAME disable with no registry entry is still a residue (control).
#>

Describe 'Executor pre-flight fleet-manifest check (#4336)' {
    BeforeAll {
        $preflightPath = Join-Path $PSScriptRoot '..\..\..\scripts\claude\executor-preflight.ps1'
        $preflight = Get-Content $preflightPath -Raw
        $verifierPath = Join-Path $PSScriptRoot '..\..\..\scripts\diagnostic\verify-fleet-manifest.py'
        $skillPath = Join-Path $PSScriptRoot '..\..\..\.claude\skills\executor\SKILL.md'
        $commandPath = Join-Path $PSScriptRoot '..\..\..\.claude\commands\executor.md'
        $skill = Get-Content $skillPath -Raw
        $command = Get-Content $commandPath -Raw

        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($preflightPath, [ref]$null, [ref]$errors)

        function New-ManifestFixture {
            param([string]$Root)
            $manifest = @{
                fleet_common = @{ required = @('roo-state-manager'); allowed = @(); retired = @() }
                machines     = @{ 'myia-test' = @{ roles = @('executor') } }
            }
            $path = Join-Path $Root 'manifest.json'
            [System.IO.File]::WriteAllText(
                $path,
                ($manifest | ConvertTo-Json -Depth 6),
                (New-Object System.Text.UTF8Encoding($false)))
            return $path
        }

        # The workspace key must be a path that EXISTS, otherwise the fixture
        # would also raise GHOST_DISABLE_PATH and blur what is being asserted.
        function New-ConfigFixture {
            param([string]$Name, [string]$Workspace, [bool]$WithRegistry)
            $cfg = @{
                mcpServers = @{ 'roo-state-manager' = @{} }
                projects   = @{ $Workspace = @{ disabledMcpServers = @('Some Connector') } }
            }
            if ($WithRegistry) { $cfg['claudeAiMcpEverConnected'] = @('Some Connector') }
            $path = Join-Path $TestDrive $Name
            [System.IO.File]::WriteAllText(
                $path,
                ($cfg | ConvertTo-Json -Depth 6),
                (New-Object System.Text.UTF8Encoding($false)))
            return $path
        }

        function Invoke-Verifier {
            param([string]$ConfigPath, [string]$ManifestPath, [string]$Workspace, [switch]$Strict)
            $argList = @($verifierPath, '--config', $ConfigPath, '--manifest', $ManifestPath,
                         '--machine', 'myia-test', '--workspace', $Workspace)
            if ($Strict) { $argList += '--strict' }
            $out = & python @argList 2>&1 | Out-String
            return [pscustomobject]@{ Output = $out; Exit = $LASTEXITCODE }
        }

        $fixtureRoot = $TestDrive
        $manifestPath = New-ManifestFixture -Root $fixtureRoot
    }

    Context 'text contracts on the pre-flight' {
        It 'parses executor-preflight.ps1 under PowerShell' {
            $errors.Count | Should -Be 0
        }

        It 'invokes the verifier with the workspace flag' {
            $preflight | Should -Match ([regex]::Escape('scripts/diagnostic/verify-fleet-manifest.py'))
            $preflight | Should -Match ([regex]::Escape('--workspace'))
            $preflight | Should -Match ([regex]::Escape('"$RepoRoot"'))
        }

        It 'branches on the finding contract (exit 2) and instrument error separately' {
            $preflight | Should -Match '\$manifestExit -eq 2'
            $preflight | Should -Match '\$manifestExit -ne 0'
            $preflight | Should -Match '\[executor-preflight\]\[MANIFEST-DRIFT\]'
        }

        It 'warns without blocking — the pre-flight keeps its own exit' {
            $block = [regex]::Match($preflight, '(?s)\$manifestCheck = .*?exit 0')
            $block.Success | Should -BeTrue
            $block.Value | Should -Match 'Write-Warning'
            $block.Value | Should -Not -Match 'exit [1-9]'
        }

        It 'routes the MANIFEST-DRIFT warning to a dashboard relay in both executor entry points' {
            $skill | Should -Match '\[MANIFEST-DRIFT\]'
            $command | Should -Match '\[MANIFEST-DRIFT\]'
            $skill | Should -Match 'tag `WARN`'
            $command | Should -Match '\[WARN\]'
        }
    }

    Context 'behaviour — the verifier is executed' {
        It 'keeps its own selftest green' {
            & python $verifierPath --selftest | Out-Null
            $LASTEXITCODE | Should -Be 0
        }

        It 'does NOT flag a claude.ai connector disable as residue' {
            $cfgPath = New-ConfigFixture -Name 'connector.json' -Workspace $fixtureRoot -WithRegistry $true
            $r = Invoke-Verifier -ConfigPath $cfgPath -ManifestPath $manifestPath -Workspace $fixtureRoot
            $r.Exit | Should -Be 0
            $r.Output | Should -Not -Match 'DISABLE_OF_UNINSTALLED'
        }

        It 'still flags the SAME disable when no connector registry entry exists (control)' {
            $cfgPath = New-ConfigFixture -Name 'residue.json' -Workspace $fixtureRoot -WithRegistry $false
            $r = Invoke-Verifier -ConfigPath $cfgPath -ManifestPath $manifestPath -Workspace $fixtureRoot
            $r.Output | Should -Match 'DISABLE_OF_UNINSTALLED'
            # warn-only: the exit stays clean unless --strict is asked for
            $r.Exit | Should -Be 0
        }

        It 'promotes that residue to a finding under --strict' {
            $cfgPath = New-ConfigFixture -Name 'residue-strict.json' -Workspace $fixtureRoot -WithRegistry $false
            $r = Invoke-Verifier -ConfigPath $cfgPath -ManifestPath $manifestPath -Workspace $fixtureRoot -Strict
            $r.Exit | Should -Be 2
        }
    }
}
