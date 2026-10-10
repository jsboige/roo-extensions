<#
.SYNOPSIS
    Modes <-> MCP non-regression suite — #603 phase 4, checklist item
    "appliquer un changement de modes ne casse pas les MCPs".

.DESCRIPTION
    Executes the REAL Deploy-Modes.ps1 pipeline (local and global, including
    the generate-modes.js YAML regeneration) inside a sandboxed copy of the
    repo tree, with APPDATA redirected to a temp dir. The regression it guards:
    a modes deploy writing anywhere near mcp_settings.json (the neighbor file
    in the same settings/ directory) or any other pre-existing settings file.

    Hermeticity:
    - The sandbox mirrors the repo layout (roo-config/scripts/, scripts/common/,
      roo-config/modes/...) so $PSScriptRoot/../.. inside the copied script
      resolves INSIDE the sandbox — the temp YAML regeneration writes there,
      never into the real repo.
    - APPDATA is redirected for both the fixture placement and the deploy run;
      on Linux the redirect is what makes Get-GlobalStoragePath resolve at all
      (the suite runs on ubuntu-latest in the unit-pester CI job — hence the
      cross-platform path resolution in Deploy-Modes.ps1).
    - Fixture paths come from the PRODUCTION helpers (Get-GlobalStoragePath /
      Get-McpSettingsPath, dot-sourced in BeforeAll from the sandbox copy) —
      no duplicated path logic that could drift from what the deploy writes.

    The deploy runs in a CHILD process of the same engine as Pester: the script
    under test calls `exit` on its error paths, which would kill the suite.

    NOTE on structure: BeforeAll/AfterAll sit at FILE ROOT (BOM-SafeFileWriter
    pattern). Under Pester 6 a BeforeAll nested inside Describe loses its
    function definitions for AfterAll (measured 2026-10-10, Pester 6.1.0),
    and plain file-scope code does not survive into the run phase at all —
    root-level BeforeAll is the one scope shared by It and AfterAll.
#>

BeforeAll {
    # Save the caller's APPDATA FIRST -- before anything that can throw. AfterAll
    # restores it under a flag: were a later line here (the copy loop, the
    # ConvertFrom-Json) to raise, an ungated AfterAll would Remove-Item APPDATA on
    # the Pester process and silently strip it for every suite running after this
    # one in the same launch (review follow-up, ai-01 on #4160).
    $script:SavedAppData = $env:APPDATA
    $script:AppDataSaved = $true

    $repoRoot = (Resolve-Path -LiteralPath ([System.IO.Path]::Combine($PSScriptRoot, '..', '..', '..'))).Path
    $sandbox = (New-Item -ItemType Directory -Path ([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [guid]::NewGuid().ToString('N')))).FullName
    $script:Sandbox = $sandbox

    # --- Mirror the repo layout the script resolves via $PSScriptRoot/../.. ---
    $sep = [System.IO.Path]::DirectorySeparatorChar
    foreach ($rel in @(
        'roo-config/scripts',
        'roo-config/modes/generated',
        'roo-config/modes/templates/commons',
        'scripts/common'
    )) {
        New-Item -ItemType Directory -Force -Path (Join-Path $sandbox ($rel -replace '/', $sep)) | Out-Null
    }
    $copies = @(
        @{ From = 'roo-config/scripts/Deploy-Modes.ps1';      To = 'roo-config/scripts/Deploy-Modes.ps1' },
        @{ From = 'roo-config/scripts/generate-modes.js';     To = 'roo-config/scripts/generate-modes.js' },
        @{ From = 'roo-config/modes/modes-config.json';       To = 'roo-config/modes/modes-config.json' },
        @{ From = 'roo-config/modes/templates/commons/mode-instructions.md'; To = 'roo-config/modes/templates/commons/mode-instructions.md' },
        @{ From = 'roo-config/modes/generated/simple-complex.roomodes';     To = 'roo-config/modes/generated/simple-complex.roomodes' },
        @{ From = 'scripts/common/extension-paths.ps1';       To = 'scripts/common/extension-paths.ps1' }
    )
    foreach ($c in $copies) {
        Copy-Item (Join-Path $repoRoot ($c.From -replace '/', $sep)) (Join-Path $sandbox ($c.To -replace '/', $sep))
    }

    $script:DeployScript = Join-Path $sandbox (Join-Path 'roo-config' (Join-Path 'scripts' 'Deploy-Modes.ps1'))
    $script:SourceRoomodes = Join-Path $sandbox (Join-Path 'roo-config' (Join-Path 'modes' (Join-Path 'generated' 'simple-complex.roomodes')))
    $script:ExpectedModeCount = (Get-Content $script:SourceRoomodes -Raw | ConvertFrom-Json).customModes.Count

    # Production path helpers from the SANDBOX copy (same file the deploy
    # dot-sources): fixture paths and deploy destinations share ONE resolution.
    $extPaths = Join-Path $sandbox (Join-Path 'scripts' (Join-Path 'common' 'extension-paths.ps1'))
    $script:FakeAppData = Join-Path $sandbox 'fake-appdata'
    # Fake HOME for the extension-dir leg of Test-ExtensionInstalled (~/.vscode/extensions):
    # the real home of a Zoo seat (po-2024, ai-01, po-2025) would flip the Auto
    # resolution outside the fixtures. Deliberately left WITHOUT a .vscode child.
    $script:FakeHome = Join-Path $sandbox 'fake-home'
    New-Item -ItemType Directory -Force -Path $script:FakeHome | Out-Null
    # JS-side globalStorage base -- mirror of generate-modes.js globalStorageBase()
    # (win32: APPDATA, backslash joins; otherwise XDG_CONFIG_HOME, redirected to
    # FakeAppData). On Linux the PS helper's literal backslashes ("Code\User\...")
    # do NOT match the JS path, so the JS behaviour tests place fixtures and assert
    # on THIS base instead of the PS helpers (ai-01 review point 2).
    $script:JsGlobalStorageBase = if ($env:OS -eq 'Windows_NT') {
        Join-Path $script:FakeAppData 'Code\User\globalStorage'
    } else {
        Join-Path (Join-Path (Join-Path $script:FakeAppData 'Code') 'User') 'globalStorage'
    }
    $env:APPDATA = $script:FakeAppData
    . $extPaths
    $script:SettingsDir = Join-Path (Get-GlobalStoragePath -Extension RooCode) 'settings'
    $script:McpSettingsPath = Get-McpSettingsPath -Extension RooCode
    # #595 phase 3: both extensions' paths, from the SAME production helpers -- the
    # target-selection tests below need the Zoo side to assert on.
    $script:ZooSettingsDir = Join-Path (Get-GlobalStoragePath -Extension ZooCode) 'settings'
    $script:ZooMcpSettingsPath = Get-McpSettingsPath -Extension ZooCode
    $script:RooStorageDir = Get-GlobalStoragePath -Extension RooCode
    $script:ZooStorageDir = Get-GlobalStoragePath -Extension ZooCode

    function Reset-ExtensionTrees {
        # The probe under test reads the globalStorage ROOT (directory presence), so the
        # reset must remove the ROOT: purging only the settings/ child left an empty
        # <id>/ behind and the next test read the extension as installed (measured --
        # 'auto falls back to Roo' resolved ZooCode on a leftover empty dir).
        foreach ($d in @($script:RooStorageDir, $script:ZooStorageDir)) {
            if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
        }
    }

    function New-McpFixtureAt {
        param([string]$SettingsDir, [string]$McpPath)
        # A distinctive, hash-sensitive MCP config: the exact bytes matter.
        New-Item -ItemType Directory -Force -Path $SettingsDir | Out-Null
        @'
{
  "mcpServers": {
    "win-cli": {
      "command": "npx",
      "args": ["-y", "@simonb97/win-cli-mcp"],
      "env": { "WIN_CLI_TIMEOUT": "600" }
    }
  }
}
'@ | Set-Content -Path $McpPath -Encoding utf8 -NoNewline
    }

    function New-McpFixture {
        New-McpFixtureAt -SettingsDir $script:SettingsDir -McpPath $script:McpSettingsPath
    }

    function Get-TreeSnapshot {
        # path -> SHA256 for every file under a root; empty map when root absent.
        # (Hashtables do not unroll in the pipeline, so an empty map survives return.)
        param([string]$Root)
        $map = @{}
        if ($Root -and (Test-Path -LiteralPath $Root)) {
            Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
                $map[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
        }
        return $map
    }

    function Invoke-DeployModes {
        # Child of the SAME engine (Pester may be powershell.exe 5.1 or pwsh,
        # on Windows or Linux) — the script's `exit` paths must not kill the suite.
        # APPDATA carries the globalStorage fixtures; USERPROFILE/HOME carry the
        # extension-dir leg of Test-ExtensionInstalled — all three redirected so
        # the real seat's installed extensions cannot flip the resolution under test.
        param([string[]]$DeployArgs)
        $psExe = (Get-Process -Id $PID).Path
        $savedAppData = $env:APPDATA
        $savedHome = $env:HOME
        $savedUserProfile = $env:USERPROFILE
        try {
            $env:APPDATA = $script:FakeAppData
            $env:HOME = $script:FakeHome
            $env:USERPROFILE = $script:FakeHome
            $output = & $psExe -NoProfile -ExecutionPolicy Bypass -File $script:DeployScript @DeployArgs 2>&1
            return @{
                Output   = ($output | Out-String)
                ExitCode = $LASTEXITCODE
            }
        } finally {
            if ($null -ne $savedAppData) { $env:APPDATA = $savedAppData } else { Remove-Item env:APPDATA -ErrorAction SilentlyContinue }
            if ($null -ne $savedHome) { $env:HOME = $savedHome } else { Remove-Item env:HOME -ErrorAction SilentlyContinue }
            if ($null -ne $savedUserProfile) { $env:USERPROFILE = $savedUserProfile } else { Remove-Item env:USERPROFILE -ErrorAction SilentlyContinue }
        }
    }

    function Invoke-GenerateModes {
        # Runs the real node script (ai-01 review point 2): APPDATA *and*
        # XDG_CONFIG_HOME redirected (off Windows the JS reads XDG), plus
        # USERPROFILE/HOME so the extension-dir leg of the probe cannot see the
        # real seat's installed extensions.
        param([string[]]$GenArgs)
        $node = (Get-Command node -ErrorAction Stop).Source
        $jsScript = Join-Path $sandbox (Join-Path 'roo-config' (Join-Path 'scripts' 'generate-modes.js'))
        $saved = @{}
        foreach ($n in @('APPDATA', 'XDG_CONFIG_HOME', 'USERPROFILE', 'HOME')) {
            $saved[$n] = [Environment]::GetEnvironmentVariable($n)
        }
        try {
            $env:APPDATA = $script:FakeAppData
            $env:XDG_CONFIG_HOME = $script:FakeAppData
            $env:USERPROFILE = $script:FakeHome
            $env:HOME = $script:FakeHome
            $output = & $node $jsScript @GenArgs 2>&1
            return @{
                Output   = ($output | Out-String)
                ExitCode = $LASTEXITCODE
            }
        } finally {
            foreach ($n in @('APPDATA', 'XDG_CONFIG_HOME', 'USERPROFILE', 'HOME')) {
                if ($null -ne $saved[$n]) { Set-Item -Path "env:$n" -Value $saved[$n] }
                else { Remove-Item -Path "env:$n" -ErrorAction SilentlyContinue }
            }
        }
    }
}

AfterAll {
    # Gated on the flag set by BeforeAll's first line: restoring when nothing was
    # ever captured would Remove-Item APPDATA on the Pester process itself
    # (review follow-up, ai-01 on #4160).
    if ($script:AppDataSaved) {
        if ($null -ne $script:SavedAppData) {
            $env:APPDATA = $script:SavedAppData
        } else {
            Remove-Item env:APPDATA -ErrorAction SilentlyContinue
        }
    }
    if ($script:Sandbox -and (Test-Path -LiteralPath $script:Sandbox)) {
        Remove-Item -LiteralPath $script:Sandbox -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# NB: block/test NAMES must not contain '<...>' — Pester 6 runs them through
# its template expansion (Data-driven test placeholders), and 'modes<->MCP'
# compiled to "$($-)" → CommandNotFoundException '$-' at run phase (measured
# 2026-10-10, Pester 6.2.0, via Set-PSDebug trace).
Describe 'Deploy-Modes modes-MCP non-regression' {

    Context 'global deploy (custom_modes.yaml)' {

        BeforeEach {
            # Per-TEST reset: the sandbox is shared by the whole suite, and the
            # earlier deploys leave custom_modes.yaml behind — a later DryRun
            # would otherwise find a destination it did not write (measured).
            # Reset-ExtensionTrees (not just settings/) keeps the Auto probe on Roo
            # here: an empty Zoo globalStorage root would read as "Zoo installed".
            Reset-ExtensionTrees
            New-McpFixture
        }

        It 'updates custom_modes.yaml and leaves mcp_settings.json byte-identical' {
            $before = Get-TreeSnapshot -Root $script:SettingsDir
            $mcpHashBefore = (Get-FileHash -LiteralPath $script:McpSettingsPath -Algorithm SHA256).Hash
            $mcpServersBefore = (Get-Content $script:McpSettingsPath -Raw | ConvertFrom-Json).mcpServers.PSObject.Properties.Name

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'DEPLOYED SUCCESSFULLY'

            # The regression under guard: the MCP neighbor file must be untouched.
            (Get-FileHash -LiteralPath $script:McpSettingsPath -Algorithm SHA256).Hash | Should -Be $mcpHashBefore
            $mcpServersAfter = (Get-Content $script:McpSettingsPath -Raw | ConvertFrom-Json).mcpServers.PSObject.Properties.Name
            $mcpServersAfter | Should -Be $mcpServersBefore

            # Every file that existed before the deploy must be bit-identical after.
            $after = Get-TreeSnapshot -Root $script:SettingsDir
            foreach ($path in $before.Keys) {
                $after[$path] | Should -Be $before[$path] -Because "pre-existing file was modified by the modes deploy: $path"
            }
            # The only allowed additions: custom_modes.yaml (and its backups).
            $added = @($after.Keys | Where-Object { $_ -notin $before.Keys })
            $added.Count | Should -BeGreaterThan 0
            $added | ForEach-Object { $_ | Should -Match 'custom_modes\.yaml' }

            # The deployed artifact is real: mode count parity with the source.
            $deployed = Get-ChildItem -LiteralPath $script:SettingsDir -Filter 'custom_modes.yaml' | Select-Object -First 1
            ([regex]::Matches((Get-Content $deployed.FullName -Raw), '(?m)^\s*- slug:')).Count | Should -Be $script:ExpectedModeCount
        }

        It 'backs up a pre-existing custom_modes.yaml before overwriting; MCP untouched' {
            $sentinel = "# sentinel previous modes`n"
            [System.IO.File]::WriteAllText((Join-Path $script:SettingsDir 'custom_modes.yaml'), $sentinel)
            $mcpHashBefore = (Get-FileHash -LiteralPath $script:McpSettingsPath -Algorithm SHA256).Hash

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0
            $backups = @(Get-ChildItem -LiteralPath $script:SettingsDir -Filter 'custom_modes.yaml.backup-*')
            $backups.Count | Should -BeGreaterThan 0
            (Get-Content $backups[0].FullName -Raw) | Should -Be $sentinel
            (Get-FileHash -LiteralPath $script:McpSettingsPath -Algorithm SHA256).Hash | Should -Be $mcpHashBefore
        }

        It 'DryRun writes no destination and no backup; MCP untouched' {
            # Documented behavior: the YAML regeneration happens BEFORE the DryRun
            # exit, writing the temp file inside the sandbox REPO tree (never under
            # APPDATA) — this test asserts the APPDATA side, which is the contract.
            $before = Get-TreeSnapshot -Root $script:FakeAppData

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes, '-DryRun')

            $r.ExitCode | Should -Be 0
            $r.Output | Should -Match 'DRY RUN'
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeFalse
            @(Get-ChildItem -LiteralPath $script:SettingsDir -Filter 'custom_modes.yaml.backup-*' -ErrorAction SilentlyContinue).Count | Should -Be 0
            $after = Get-TreeSnapshot -Root $script:FakeAppData
            @($after.Keys) | Should -Be @($before.Keys)
            foreach ($path in $before.Keys) {
                $after[$path] | Should -Be $before[$path] -Because "DryRun modified a file under APPDATA: $path"
            }
        }
    }

    Context 'local deploy (.roomodes)' {

        It 'writes only .roomodes at the repo root; nothing under APPDATA changes' {
            New-McpFixture
            $beforeAppData = Get-TreeSnapshot -Root $script:FakeAppData

            $r = Invoke-DeployModes @('-DeploymentType', 'local', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'DEPLOYED SUCCESSFULLY'

            $roomodes = Join-Path $script:Sandbox '.roomodes'
            (Test-Path -LiteralPath $roomodes) | Should -BeTrue
            ((Get-Content $roomodes -Raw | ConvertFrom-Json).customModes.Count) | Should -Be $script:ExpectedModeCount

            # A local deploy must never reach the VS Code settings tree.
            $afterAppData = Get-TreeSnapshot -Root $script:FakeAppData
            @($afterAppData.Keys) | Should -Be @($beforeAppData.Keys)
            foreach ($path in $beforeAppData.Keys) {
                $afterAppData[$path] | Should -Be $beforeAppData[$path] -Because "local deploy modified a file under APPDATA: $path"
            }
        }
    }

    Context 'global deploy target selection' {

        BeforeEach {
            # Both extension trees start empty (ROOT-level reset: the probe reads the
            # globalStorage root, not the settings/ child): each test builds only what
            # it needs, because the probe under test reads exactly those trees (plus
            # the extension dir under the redirected HOME, which stays empty).
            Reset-ExtensionTrees
        }

        It 'auto-detects Zoo when only the Zoo settings file exists' {
            New-McpFixtureAt -SettingsDir $script:ZooSettingsDir -McpPath $script:ZooMcpSettingsPath
            $zooMcpHashBefore = (Get-FileHash -LiteralPath $script:ZooMcpSettingsPath -Algorithm SHA256).Hash

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+ZooCode \(auto-detected\)'

            # The regression this closes: the deploy landed in the Roo globalStorage, which a
            # Zoo-only seat never reads -- the modes silently never appeared.
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeFalse
            # The MCP neighbor file is untouched on the Zoo side too.
            (Get-FileHash -LiteralPath $script:ZooMcpSettingsPath -Algorithm SHA256).Hash | Should -Be $zooMcpHashBefore
        }

        It 'auto-detects Zoo even when the Roo settings file also exists (migrated seat)' {
            # ai-01 review point 1: Roo recreates its mcp_settings.json at every startup
            # and migrate-roo-to-zoo.ps1 COPIES it to Zoo instead of moving it -- a
            # migrated or dual host has BOTH files, and the old config-file probe
            # resolved it back to Roo, leaving the modes where nothing reads them.
            New-McpFixture
            New-McpFixtureAt -SettingsDir $script:ZooSettingsDir -McpPath $script:ZooMcpSettingsPath
            $zooMcpHashBefore = (Get-FileHash -LiteralPath $script:ZooMcpSettingsPath -Algorithm SHA256).Hash

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+ZooCode \(auto-detected\)'
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeFalse
            (Get-FileHash -LiteralPath $script:ZooMcpSettingsPath -Algorithm SHA256).Hash | Should -Be $zooMcpHashBefore
        }

        It 'auto falls back to Roo when Zoo is not installed' {
            New-McpFixture   # Roo settings only, Zoo tree entirely absent

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+RooCode \(auto-detected\)'
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'honours an explicit RooCode target while Zoo is installed' {
            # The discriminating explicit case under the Zoo-first rule: Auto would
            # answer ZooCode here (Zoo tree present); only the explicit pin lands
            # the deploy on the Roo side.
            New-McpFixture
            New-McpFixtureAt -SettingsDir $script:ZooSettingsDir -McpPath $script:ZooMcpSettingsPath

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes,
                                      '-TargetExtension', 'RooCode')

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+RooCode \(explicit\)'
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }
    }

    Context 'generate-modes.js deploy-global target selection (behaviour)' {

        # ai-01 review point 2: a static layer cannot see the resolution -- the
        # mutant that short-circuits resolveExtensionId back to Roo left the static
        # suite green. These tests run the REAL node script on fixtures.
        # Fixtures and assertions use the JS-side base ($script:JsGlobalStorageBase),
        # NOT the PS helpers: on Linux the helper's literal backslashes never match
        # the path the JS builds. Computed in BeforeEach (Pester 6 guarantees the
        # BeforeEach scope reaches the It; Context-body variables do not always).
        BeforeEach {
            $jsRooStorageDir = Join-Path $script:JsGlobalStorageBase 'rooveterinaryinc.roo-cline'
            $jsZooStorageDir = Join-Path $script:JsGlobalStorageBase 'zoocodeorganization.zoo-code'
            $jsRooSettingsDir = Join-Path $jsRooStorageDir 'settings'
            $jsZooSettingsDir = Join-Path $jsZooStorageDir 'settings'
            # ROOT-level reset on the JS side too (see Reset-ExtensionTrees).
            foreach ($d in @($jsRooStorageDir, $jsZooStorageDir)) {
                if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
            }
        }

        It 'auto picks Zoo on a Zoo-only fixture and writes the modes file there' {
            New-McpFixtureAt -SettingsDir $jsZooSettingsDir -McpPath (Join-Path $jsZooSettingsDir 'mcp_settings.json')
            $out = Join-Path $script:Sandbox 'js-out-zooonly.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            $r.Output | Should -Match 'Deployed to global:'
            $deployed = Join-Path $jsZooSettingsDir 'custom_modes.yaml'
            (Test-Path -LiteralPath $deployed) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
            # The deployed artifact is real: mode-count parity with the source roomodes.
            ([regex]::Matches((Get-Content -LiteralPath $deployed -Raw), '(?m)^\s*- slug:')).Count | Should -Be $script:ExpectedModeCount
        }

        It 'auto picks Zoo even when the Roo settings file also exists (migrated seat)' {
            New-McpFixtureAt -SettingsDir $jsRooSettingsDir -McpPath (Join-Path $jsRooSettingsDir 'mcp_settings.json')
            New-McpFixtureAt -SettingsDir $jsZooSettingsDir -McpPath (Join-Path $jsZooSettingsDir 'mcp_settings.json')
            $out = Join-Path $script:Sandbox 'js-out-both.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            (Test-Path -LiteralPath (Join-Path $jsZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'auto falls back to Roo when Zoo is absent' {
            New-McpFixtureAt -SettingsDir $jsRooSettingsDir -McpPath (Join-Path $jsRooSettingsDir 'mcp_settings.json')
            $out = Join-Path $script:Sandbox 'js-out-rooonly.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $jsZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'rejects a prototype-chain target-extension value before writing anything' {
            # ai-01 review point 4: 'constructor' passes !EXTENSION_IDS[x] through the
            # prototype chain; the guard must refuse it inside parseArgs, BEFORE the
            # --output file is written.
            $out = Join-Path $script:Sandbox 'js-out-ctor.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global',
                                        '--target-extension', 'constructor')

            $r.ExitCode | Should -Be 1
            $r.Output | Should -Match 'ERROR: --target-extension'
            (Test-Path -LiteralPath $out) | Should -BeFalse
            (Test-Path -LiteralPath (Join-Path $jsZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }
    }
}
