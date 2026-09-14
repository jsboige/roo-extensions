#Requires -Version 5.1
<#
    Pester tests for the alwaysAllow sync scripts resolved against the ACTIVE
    Roo/Zoo extension (#3639).

    What this file locks, one block per acceptance criterion:

      1. reference-alwaysallow.json vs the served catalogue -- the reference must
         carry every tool the server advertises and no name it has dropped;
      2. Roo seat active  -> the Roo target is the one written;
      3. Zoo seat active  -> the Zoo target is written and the inactive Roo shell
         (the empty globalStorage a migrated host leaves behind) stays untouched;
         a hardcoded-Roo target fails this block, so it cannot pass vacuously;
      4. a CURRENT tool missing from the live allowlist is added;
      5. a HISTORICAL name absent from the catalogue is removed;
      6. active seat undeterminable -> explicit refusal (exit 2), nothing written;
      7. -DryRun is non-destructive and lists the exact delta;
      8. post-write verification re-reads the ACTIVE file, and its primitive can
         actually go red (a verifier that never fails verifies nothing).

    The end-to-end blocks drive the REAL scripts as subprocesses with $env:APPDATA
    redirected to a temp sandbox: the production path helper is asked for the seat
    paths (never a hand-built string), so the assertion is about the same
    expression the scripts use, not a copy of it that could drift.

    Executed in CI by the `unit-pester` job (.github/workflows/ci.yml, #3216) on
    ubuntu-latest. That job checks out WITHOUT submodules, so the one block that
    needs the submodule source (the catalogue cross-check) skips itself there and
    says so -- same contract as path-guards.Tests.ps1. The other blocks are
    fixture-based and run everywhere.

    This file is deliberately ASCII-only: Windows PowerShell 5.1 mis-decodes
    non-ASCII prose on a host whose active code page is not 65001 unless the file
    carries a BOM (#2368), and a pure-ASCII file cannot hit that.

.NOTES
    Issue #3639.
#>

# Discovery-time data. This MUST be at file scope: Pester reads it while
# discovering, before any BeforeAll runs.
#
# Only the data a -ForEach/-Skip needs at DISCOVERY lives here. Everything the
# test BODIES read is re-declared in the Describe-scoped BeforeAll below: Pester
# runs each container in its own script scope (Invoke-InNewScriptScope), so a
# file-scope `$script:x` is NOT what `$script:x` resolves to inside an It -- it
# silently binds $null there. That cost one red run on this very file; the split
# between this block and the BeforeAll is deliberate, not redundant.
$script:SyncScripts = @(
    @{
        Label          = 'scripts/mcp/sync-alwaysallow.ps1'
        Rel            = 'scripts/mcp/sync-alwaysallow.ps1'
        RefFlag        = '-ReferencePath'
        WriteVar       = 'SettingsPath'
        SeatPattern    = 'Extension active: ZooCode'
        RemovalFlags   = @()
        # Both scripts expose -DryRun as a bare switch (#3639 aligned the [bool]
        # copy on this shape: a [bool] parameter cannot be reached from the
        # command line at all, so the documented `-DryRun` never worked).
        DryRunArgs     = @('-DryRun')
        DryAddPattern  = '\+ Ajoutes:'
        DryKeepPattern = '- Retires:'
    }
    @{
        Label          = 'roo-config/scripts/Sync-AlwaysAllow.ps1'
        Rel            = 'roo-config/scripts/Sync-AlwaysAllow.ps1'
        RefFlag        = '-ReferenceFile'
        WriteVar       = 'activeMcpSettingsPath'
        SeatPattern    = 'Active extension: ZooCode'
        # This copy merges by default; -Force is what makes it drop extras.
        RemovalFlags   = @('-Force')
        DryRunArgs     = @('-DryRun')
        DryAddPattern  = 'Add \('
        DryKeepPattern = 'Keep \('
    }
)

Describe 'alwaysAllow sync against the active extension (#3639)' {

    BeforeAll {
        $script:projectRoot = (Resolve-Path -Path "$PSScriptRoot/../../..").Path
        $script:referencePath = Join-Path $script:projectRoot 'roo-config/mcp/reference-alwaysallow.json'
        $script:CatalogueSourcePath = Join-Path $script:projectRoot 'mcps/internal/servers/roo-state-manager/src/tools/tool-definitions.ts'

        # The 17-tool roo-state-manager catalogue served by ListTools at the time
        # of #3639, mirrored from allToolDefinitions and cross-checked against
        # that source by the block that skips without submodules.
        $script:Catalogue17 = @(
            'conversation_browser', 'roosync_search', 'roosync_indexing', 'codebase_search',
            'read_vscode_logs', 'claudish_traffic', 'export_data', 'roosync_compare_config',
            'roosync_baseline', 'roosync_config', 'roosync_harmonization', 'roosync_inventory',
            'roosync_mcp_management', 'roosync_storage_management', 'roosync_diagnose',
            'roosync_messages', 'roosync_dashboard'
        )

        # Names the v1.3.0 reference carried that the catalogue no longer advertises.
        $script:HistoricalNames = @(
            'roosync_send', 'roosync_read', 'roosync_manage', 'roosync_attachments',
            'roosync_decision', 'roosync_decision_info', 'roosync_list_diffs', 'roosync_init',
            'roosync_get_status', 'roosync_refresh_dashboard', 'roosync_update_dashboard',
            'roosync_machines', 'roosync_cleanup_messages', 'roosync_claim',
            'analyze_roosync_problems', 'get_mcp_best_practices', 'export_config',
            'get_raw_conversation', 'view_task_details', 'task_export'
        )

        # The two tools ai-01's live Zoo config was missing (15/17 verified in #3639).
        $script:MissingOnAi01 = @('claudish_traffic', 'roosync_harmonization')

        # The interpreter running this test (pwsh on CI, either engine locally).
        $script:interpreter = (Get-Process -Id $PID).Path

        $script:origAppData = $env:APPDATA

        # Same modules the scripts dot-source: the seat paths and the delta
        # arithmetic are the production ones, not a re-implementation.
        . (Join-Path $script:projectRoot 'scripts/common/extension-paths.ps1')
        . (Join-Path $script:projectRoot 'scripts/common/alwaysallow-sync.ps1')

        function New-Sandbox {
            <# A throwaway APPDATA root: the scripts see a host with no globalStorage. #>
            $root = Join-Path ([System.IO.Path]::GetTempPath()) ("aa3639-" + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            return $root
        }

        function Get-SeatPath {
            <# The production expression, evaluated against the sandbox APPDATA. #>
            param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Seat)
            $prev = $env:APPDATA
            $env:APPDATA = $Root
            try {
                return Get-McpSettingsPath -Extension $Seat
            } finally {
                $env:APPDATA = $prev
            }
        }

        function Write-LiveSettings {
            param(
                [Parameter(Mandatory)][string]$Path,
                [Parameter(Mandatory)][string[]]$Tools
            )
            $dir = Split-Path -Parent $Path
            if (-not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
            $json = @{
                mcpServers = @{ 'roo-state-manager' = @{ alwaysAllow = @($Tools) } }
            } | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
        }

        function Get-PersistedTools {
            param([Parameter(Mandatory)][string]$Path)
            $parsed = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
            return @($parsed.mcpServers.'roo-state-manager'.alwaysAllow | Where-Object { $_ -ne $null })
        }

        function Invoke-Sync {
            param(
                [Parameter(Mandatory)][string]$Rel,
                [Parameter(Mandatory)][string]$RefFlag,
                [Parameter(Mandatory)][string]$Root,
                [string[]]$ExtraArgs = @()
            )
            $cliArgs = @('-NoProfile', '-File', (Join-Path $script:projectRoot $Rel), $RefFlag, $script:referencePath) + $ExtraArgs
            $prev = $env:APPDATA
            $env:APPDATA = $Root
            try {
                $captured = & $script:interpreter @cliArgs 2>&1 | Out-String
                return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $captured }
            } finally {
                $env:APPDATA = $prev
            }
        }
    }

    AfterAll {
        $env:APPDATA = $script:origAppData
    }

    # ---------------------------------------------------------------- reference

    Context 'reference-alwaysallow.json vs the served catalogue' {

        BeforeAll {
            $script:ref = Get-Content -LiteralPath $script:referencePath -Raw | ConvertFrom-Json
            $script:refTools = @($script:ref.mcpServers.'roo-state-manager'.alwaysAllow | Where-Object { $_ -ne $null })
        }

        It 'lists exactly the advertised tools -- none missing, none extra' {
            $delta = Get-AlwaysAllowDelta -ReferenceTools $script:Catalogue17 -CurrentTools $script:refTools
            $delta.Added   | Should -BeNullOrEmpty -Because 'every advertised tool must be auto-approved'
            $delta.Removed | Should -BeNullOrEmpty -Because 'the reference must not keep names the server dropped'
        }

        It 'carries the recomputed count (33 historical -> 17 current)' {
            $script:refTools.Count | Should -Be 17
            $script:ref.version     | Should -Be '1.4.0'
            $script:ref.issue       | Should -Match '#3639'
        }

        It 'keeps no name that left the catalogue' {
            foreach ($stale in $script:HistoricalNames) {
                $script:refTools | Should -Not -Contain $stale -Because "$stale is not served any more, whitelisting it hides the gap"
            }
        }

        # The skip condition is written out in full ON PURPOSE: it is evaluated at
        # DISCOVERY, and a `$script:` variable declared inside this file's
        # BeforeAll does not exist yet at that point (see the file header note).
        It 'matches allToolDefinitions in the submodule source' -Skip:(-not (Test-Path (Join-Path (Resolve-Path -Path "$PSScriptRoot/../../..").Path 'mcps/internal/servers/roo-state-manager/src/tools/tool-definitions.ts'))) {
            # Skipped on a checkout without submodules (the ubuntu CI job). Run
            # locally/on Windows to catch a catalogue change on the server side;
            # the three tests above still run everywhere and catch a reference edit.
            $lines = Get-Content -LiteralPath $script:CatalogueSourcePath
            $startLine = ($lines | Select-String -SimpleMatch 'export const allToolDefinitions = [' | Select-Object -First 1).LineNumber
            $startLine | Should -Not -BeNullOrEmpty

            $definitions = @()
            for ($i = $startLine; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match '^\];') { break }
                # Live entries only: the commented ones start with '//'.
                if ($lines[$i] -match '^\s*([A-Za-z][A-Za-z0-9]*Definition)\s*,?\s*$') {
                    $definitions += $Matches[1]
                }
            }

            $served = @($definitions | ForEach-Object {
                $base = $_ -replace 'Definition$', ''
                (($base -creplace '([a-z0-9])([A-Z])', '$1_$2')).ToLower()
            })

            $served.Count | Should -Be 17
            $delta = Get-AlwaysAllowDelta -ReferenceTools $served -CurrentTools $script:refTools
            $delta.Added   | Should -BeNullOrEmpty -Because 'the submodule serves a tool the reference omits'
            $delta.Removed | Should -BeNullOrEmpty -Because 'the reference lists a tool the submodule does not serve'
        }
    }

    # -------------------------------------------------------------- static guard

    Context 'no write path is hardcoded on Roo (<Label>)' -ForEach $script:SyncScripts {

        BeforeAll {
            $script:source = Get-Content -LiteralPath (Join-Path $script:projectRoot $Rel) -Raw
        }

        It 'binds the write target to the active-extension resolution' {
            $script:source | Should -Match 'Get-ActiveMcpSettingsPath'
            $script:source | Should -Match "\[System\.IO\.File\]::WriteAllText\(\s*\`$$WriteVar"
        }

        It 'never ASSIGNS a hardcoded Roo settings path' {
            # The literal may still appear inside the refusal diagnostic; what must
            # not appear is a binding that a write could then use.
            $script:source | Should -Not -Match '\$\w+\s*=\s*Get-McpSettingsPath\s+-Extension\s+RooCode'
        }
    }

    # ------------------------------------------------------------------ Roo seat

    Context 'Roo seat active (<Label>)' -ForEach $script:SyncScripts {

        It 'writes the Roo target and creates nothing for Zoo' {
            $root = New-Sandbox
            try {
                $rooPath = Get-SeatPath -Root $root -Seat RooCode
                $zooPath = Get-SeatPath -Root $root -Seat ZooCode
                Write-LiveSettings -Path $rooPath -Tools @('conversation_browser')

                $result = Invoke-Sync -Rel $Rel -RefFlag $RefFlag -Root $root
                $result.ExitCode | Should -Be 0
                Get-PersistedTools -Path $rooPath | Should -Contain 'roosync_harmonization'
                Test-Path -LiteralPath $zooPath | Should -BeFalse -Because 'Zoo is not installed here; nothing may be created for it'
                $result.Output | Should -Match 'POST-WRITE VERIFICATION OK'
                $result.Output | Should -Not -Match 'VERIFICATION FAILED'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }
    }

    # ------------------------------------------------------------------ Zoo seat

    Context 'Zoo seat active (<Label>) -- the migrated host of #3639' -ForEach $script:SyncScripts {

        It 'writes the Zoo target and leaves the inactive Roo shell untouched' {
            $root = New-Sandbox
            try {
                $rooPath = Get-SeatPath -Root $root -Seat RooCode
                $zooPath = Get-SeatPath -Root $root -Seat ZooCode

                # The migrated shape: roo-cline globalStorage survives as an empty
                # shell (no settings/mcp_settings.json) while Zoo carries the live
                # config. A sentinel makes "untouched" observable.
                $rooSentinel = Join-Path (Split-Path -Parent (Split-Path -Parent $rooPath)) 'state.vscdb'
                New-Item -ItemType Directory -Path (Split-Path -Parent $rooSentinel) -Force | Out-Null
                [System.IO.File]::WriteAllText($rooSentinel, 'roo-shell-sentinel', [System.Text.UTF8Encoding]::new($false))

                # ai-01's verified live state: 15 of 17 tools present.
                $liveTools = @($script:Catalogue17 | Where-Object { $script:MissingOnAi01 -notcontains $_ })
                Write-LiveSettings -Path $zooPath -Tools $liveTools

                $result = Invoke-Sync -Rel $Rel -RefFlag $RefFlag -Root $root
                $result.ExitCode | Should -Be 0

                $persisted = Get-PersistedTools -Path $zooPath
                foreach ($tool in $script:MissingOnAi01) {
                    $persisted | Should -Contain $tool -Because "$tool is served by the live catalogue and was missing"
                }
                $result.Output | Should -Match $SeatPattern -Because 'the run must report the seat it resolved'

                # The inactive copy: no settings file conjured into it, sentinel intact.
                Test-Path -LiteralPath $rooPath | Should -BeFalse -Because 'the sync succeeded against the inactive Roo copy the old code wrote to'
                (Get-Content -LiteralPath $rooSentinel -Raw) | Should -Match 'roo-shell-sentinel'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }

        It 'drops a historical name from the live allowlist' {
            $root = New-Sandbox
            try {
                $zooPath = Get-SeatPath -Root $root -Seat ZooCode
                Write-LiveSettings -Path $zooPath -Tools (@($script:MissingOnAi01) + @('roosync_send', 'roosync_read'))

                $result = Invoke-Sync -Rel $Rel -RefFlag $RefFlag -Root $root -ExtraArgs $RemovalFlags
                $result.ExitCode | Should -Be 0

                $persisted = Get-PersistedTools -Path $zooPath
                $persisted | Should -Not -Contain 'roosync_send'
                $persisted | Should -Not -Contain 'roosync_read'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }
    }

    # ---------------------------------------------------------------- refusal

    Context 'active seat undeterminable (<Label>)' -ForEach $script:SyncScripts {

        It 'refuses explicitly, exits 2, and writes nothing' {
            $root = New-Sandbox
            try {
                $rooPath = Get-SeatPath -Root $root -Seat RooCode
                $zooPath = Get-SeatPath -Root $root -Seat ZooCode

                $result = Invoke-Sync -Rel $Rel -RefFlag $RefFlag -Root $root

                $result.ExitCode | Should -Be 2 -Because 'guessing a seat would configure an extension that is not installed'
                $result.Output   | Should -Match 'REFUSED'
                Test-Path -LiteralPath $rooPath | Should -BeFalse
                Test-Path -LiteralPath $zooPath | Should -BeFalse
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }
    }

    # ---------------------------------------------------------------- dry run

    Context 'dry run (<Label>)' -ForEach $script:SyncScripts {

        It 'lists the exact delta and leaves the file byte-identical' {
            $root = New-Sandbox
            try {
                $zooPath = Get-SeatPath -Root $root -Seat ZooCode
                # Both directions present at once: a current tool missing (added)
                # and a historical name the catalogue dropped (removed/kept).
                $liveTools = @($script:Catalogue17 | Where-Object { $script:MissingOnAi01 -notcontains $_ }) + @('roosync_send')
                Write-LiveSettings -Path $zooPath -Tools $liveTools
                $before = Get-Content -LiteralPath $zooPath -Raw

                $result = Invoke-Sync -Rel $Rel -RefFlag $RefFlag -Root $root -ExtraArgs $DryRunArgs
                $result.ExitCode | Should -Be 0

                foreach ($tool in $script:MissingOnAi01) {
                    $result.Output | Should -Match $tool -Because 'the dry run must name what it would add'
                }
                $result.Output | Should -Match 'roosync_send' -Because 'the dry run must name the historical entry it would drop'
                $result.Output | Should -Match $DryAddPattern
                $result.Output | Should -Match $DryKeepPattern

                (Get-Content -LiteralPath $zooPath -Raw) | Should -Be $before -Because 'a dry run must not touch the file'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }
    }

    # ------------------------------------------------------- verification primitive

    Context 'Test-AlwaysAllowApplied' {

        It 'is Ok when the file on disk holds exactly the expected tools' {
            $root = New-Sandbox
            try {
                $path = Join-Path $root 'settings.json'
                Write-LiveSettings -Path $path -Tools @('a', 'b')
                $r = Test-AlwaysAllowApplied -SettingsPath $path -Expected @{ 'roo-state-manager' = @('a', 'b') }
                $r.Ok | Should -BeTrue
                $r.Checked | Should -Be 1
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }

        It 'goes red when a demanded tool is missing on disk' {
            # Positive control for the verifier itself: it must be able to fail,
            # otherwise "POST-WRITE VERIFICATION OK" means nothing.
            $root = New-Sandbox
            try {
                $path = Join-Path $root 'settings.json'
                Write-LiveSettings -Path $path -Tools @('a')
                $r = Test-AlwaysAllowApplied -SettingsPath $path -Expected @{ 'roo-state-manager' = @('a', 'b') }
                $r.Ok | Should -BeFalse
                ($r.Mismatches -join ' ') | Should -Match 'b'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }

        It 'goes red when the file is absent' {
            $root = New-Sandbox
            try {
                $r = Test-AlwaysAllowApplied -SettingsPath (Join-Path $root 'nope.json') -Expected @{ 'x' = @('a') }
                $r.Ok | Should -BeFalse
                ($r.Mismatches -join ' ') | Should -Match 'absent'
            } finally {
                Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
            }
        }
    }
}
