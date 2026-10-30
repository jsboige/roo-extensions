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

    function Reset-ExtensionDirs {
        # The extension-dir leg of the probes, in BOTH shapes they build it: the PS
        # probe joins the LITERAL ".vscode\extensions" (one directory on Linux),
        # the JS probe path.join's two components (real nesting there). Removing
        # the exact paths covers both without touching anything else.
        $shapes = @(
            (Join-Path $script:FakeHome '.vscode\extensions'),
            ([System.IO.Path]::Combine($script:FakeHome, '.vscode', 'extensions'))
        )
        foreach ($p in $shapes) {
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
        }
    }

    function New-ExtensionDirFixture {
        # An "installed but never activated" extension: a directory under
        # <extRoot>/<marketplace-id>-<version> and NO globalStorage -- the exact
        # seat shape the folder leg of the probes exists for. The caller passes the
        # extRoot in the shape of the engine under test (PS vs JS path building).
        param([string]$ExtRoot, [string]$ExtensionId)
        $dir = Join-Path $ExtRoot "$ExtensionId-3.86.0"
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Set-Content -Path (Join-Path $dir 'package.json') -Value '{"name":"fixture"}' -NoNewline
        return $dir
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

    function Get-FullTreeSnapshot {
        # Files AND directories under a root (ai-01 CHANGES on #4432): the dry-run
        # proof must catch a stray directory even when no file ever lands in it,
        # and a stray file even at a location no explicit assert names.
        param([string]$Root)
        $files = @{}
        $dirs = @()
        if ($Root -and (Test-Path -LiteralPath $Root)) {
            Get-ChildItem -LiteralPath $Root -Recurse -File | ForEach-Object {
                $files[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            }
            $dirs = @(Get-ChildItem -LiteralPath $Root -Recurse -Directory | ForEach-Object { $_.FullName })
        }
        return @{ Files = $files; Dirs = $dirs }
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
            # Documented behavior: regeneration goes to a PID-keyed temp file under
            # the SYSTEM temp dir (deleted after reading, never under APPDATA) —
            # this test asserts the APPDATA side, which is the contract.
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
            # the extension dir under the redirected HOME -- reset too, the folder
            # fixtures below install through it and must not leak into the next test).
            Reset-ExtensionTrees
            Reset-ExtensionDirs
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

        It 'auto-detects Zoo installed only via its extension dir (no globalStorage yet)' {
            # Surviving-mutant guard (ai-01, 2026-10-10 afternoon queue): no test
            # exercised the extension-dir leg of Test-ExtensionInstalled -- a mutant
            # deleting that probe stayed green because every fixture installed via
            # globalStorage. An installed-but-never-activated extension has none.
            New-ExtensionDirFixture -ExtRoot (Join-Path $script:FakeHome '.vscode\extensions') -ExtensionId 'zoocodeorganization.zoo-code' | Out-Null

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+ZooCode \(auto-detected\)'
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'auto falls back to Roo installed only via its extension dir' {
            New-ExtensionDirFixture -ExtRoot (Join-Path $script:FakeHome '.vscode\extensions') -ExtensionId 'rooveterinaryinc.roo-cline' | Out-Null

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+RooCode \(auto-detected\)'
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'refuses with exit 2 when neither extension is installed (no ghost globalStorage)' {
            # ai-01 afternoon queue item 3: the Roo fallback used to CREATE the Roo
            # globalStorage on an empty host -- a directory nothing reads, and one
            # that answers "installed" to every later probe. Trees and extension
            # dirs are empty (BeforeEach reset), so Auto has nothing to resolve.
            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 2 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'neither Roo Code nor Zoo Code is installed'
            (Test-Path -LiteralPath $script:RooStorageDir) | Should -BeFalse -Because 'a refused deploy must not leave a ghost Roo globalStorage'
            (Test-Path -LiteralPath $script:ZooStorageDir) | Should -BeFalse
        }

        It 'refuses BEFORE regenerating: the tracked yaml is not rewritten by a refused deploy' {
            # ai-01 review note (optional, 2026-10-10): the refusal used to run AFTER
            # generation, so a REAL deploy on an empty host rewrote the tracked
            # simple-complex.yaml before exiting 2. Resolution now happens first.
            # Sentinel: what the old order would overwrite comes back byte-identical.
            $trackedYaml = Join-Path $script:Sandbox (Join-Path 'roo-config' (Join-Path 'modes' (Join-Path 'generated' 'simple-complex.yaml')))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $trackedYaml) | Out-Null
            'sentinel-not-a-real-yaml' | Set-Content -LiteralPath $trackedYaml -NoNewline

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes)

            $r.ExitCode | Should -Be 2 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'neither Roo Code nor Zoo Code is installed'
            (Get-Content -LiteralPath $trackedYaml -Raw) | Should -Be 'sentinel-not-a-real-yaml' -Because 'the refusal fired after regeneration and rewrote the tracked yaml'
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
            # ROOT-level reset on the JS side too (see Reset-ExtensionTrees), plus the
            # JS-shaped extension dirs (the PS Context above installs folder fixtures
            # -- same physical path as the JS shape on Windows).
            foreach ($d in @($jsRooStorageDir, $jsZooStorageDir)) {
                if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
            }
            Reset-ExtensionDirs
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

        It 'auto picks Zoo installed only via its extension dir' {
            # Surviving-mutant guard (ai-01, 2026-10-10 afternoon queue): the JS
            # extension-dir leg (readdirSync under ~/.vscode/extensions) was never
            # exercised -- the JS-shaped root differs from the PS one on Linux, so
            # the fixture must be built with .Combine like the JS path.join does.
            New-ExtensionDirFixture -ExtRoot ([System.IO.Path]::Combine($script:FakeHome, '.vscode', 'extensions')) -ExtensionId 'zoocodeorganization.zoo-code' | Out-Null
            $out = Join-Path $script:Sandbox 'js-out-zoofolder.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            (Test-Path -LiteralPath (Join-Path $jsZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'honours an explicit roo target while Zoo is installed' {
            # Surviving-mutant guard (ai-01): a mutant making resolveExtensionId
            # ignore the requested target (always auto) stayed green -- no test
            # pinned the explicit override on the JS side.
            New-McpFixtureAt -SettingsDir $jsZooSettingsDir -McpPath (Join-Path $jsZooSettingsDir 'mcp_settings.json')
            $out = Join-Path $script:Sandbox 'js-out-explicitroo.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global',
                                        '--target-extension', 'roo')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            (Test-Path -LiteralPath (Join-Path $jsRooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $jsZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'refuses with exit 2 when neither extension is installed' {
            # ai-01 afternoon queue item 3, JS side: no ghost Roo globalStorage on an
            # empty host. The --output file is written during generation (before the
            # deploy step) and is not part of the refusal.
            $out = Join-Path $script:Sandbox 'js-out-none.yaml'

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out, '--deploy-global')

            $r.ExitCode | Should -Be 2 -Because "generate-modes output was: $($r.Output)"
            $r.Output | Should -Match 'neither Roo Code nor Zoo Code is installed'
            (Test-Path -LiteralPath $jsRooStorageDir) | Should -BeFalse -Because 'a refused deploy must not leave a ghost Roo globalStorage'
            (Test-Path -LiteralPath $jsZooStorageDir) | Should -BeFalse
        }
    }

    Context 'generate-modes.js --dry-run behavioural proof (#4334)' {

        # ai-01 CHANGES on #4432: the six static cases in
        # generate-modes-deploy-global.Tests.ps1 only inspect the SOURCE TEXT --
        # a future extra write can pass that regex suite. These three tests
        # invoke the REAL node CLI and assert the FILESYSTEM:
        #   1. with --dry-run: zero files AND zero directories, anywhere;
        #   2. without the flag: the same invocation writes every target
        #      (positive control -- it proves the assertions can SEE a write);
        #   3. a mutation witness: removing one guard IS detected.
        #
        # Targets are explicit and disposable: --output and --global-path both
        # point INSIDE the sandbox, and the script's ROOT (the .roomodes parent)
        # is the sandbox copy itself -- no real globalStorage, no real .roomodes.
        # --global-path short-circuits the extension resolution, so no extension
        # fixture is needed and no host globalStorage is ever probed.
        #
        # UNRESOLVED LIMITATION (NanoClaw review on #4432, NAMED, NOT FIXED HERE):
        # an unknown flag is still silently ignored by parseArgs. --dry-run is now
        # parsed, but the wider class "any unrecognised flag is dropped without
        # error" stays open -- coordinator decision, deliberately not expanded here.

        BeforeEach {
            # Fresh disposable targets per test. The parents are deliberately ABSENT,
            # so a directory creation is observable (the old defect created one).
            $drRoot = Join-Path $script:Sandbox 'dryrun-targets'
            if (Test-Path -LiteralPath $drRoot) { Remove-Item -LiteralPath $drRoot -Recurse -Force }
            $out = Join-Path $drRoot (Join-Path 'out' 'modes.yaml')
            $globalTarget = Join-Path $drRoot (Join-Path 'global' 'custom_modes.yaml')
        }

        It 'with --dry-run writes ZERO files and ZERO directories (full-sandbox diff)' {
            $before = Get-FullTreeSnapshot -Root $script:Sandbox
            # The sandbox may already carry a .roomodes (the local-deploy Context
            # above wrote one): the contract is "UNCHANGED", not "absent".
            $roomodes = Join-Path $script:Sandbox '.roomodes'
            $roomodesHashBefore = if (Test-Path -LiteralPath $roomodes) { (Get-FileHash -LiteralPath $roomodes -Algorithm SHA256).Hash } else { $null }

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out,
                                        '--deploy', '--deploy-global', '--global-path', $globalTarget,
                                        '--dry-run')

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            $r.Output | Should -Match 'DRY RUN -- nothing was written'
            # Explicit targets: file absent AND parent directory absent.
            (Test-Path -LiteralPath $out) | Should -BeFalse -Because 'dry-run wrote the output file'
            (Test-Path -LiteralPath (Split-Path -Parent $out)) | Should -BeFalse -Because 'dry-run created the output directory'
            (Test-Path -LiteralPath $globalTarget) | Should -BeFalse -Because 'dry-run wrote the global target'
            (Test-Path -LiteralPath (Split-Path -Parent $globalTarget)) | Should -BeFalse -Because 'dry-run created the global target directory'
            if ($roomodesHashBefore) {
                (Get-FileHash -LiteralPath $roomodes -Algorithm SHA256).Hash | Should -Be $roomodesHashBefore -Because 'dry-run rewrote .roomodes'
            } else {
                (Test-Path -LiteralPath $roomodes) | Should -BeFalse -Because 'dry-run deployed .roomodes'
            }
            # The airtight half: NOTHING appeared anywhere in the sandbox -- a write
            # at a location no explicit assert names still fails here.
            $after = Get-FullTreeSnapshot -Root $script:Sandbox
            @($after.Files.Keys | Sort-Object) | Should -Be @($before.Files.Keys | Sort-Object) -Because 'dry-run added or removed a file in the sandbox'
            @($after.Dirs | Sort-Object) | Should -Be @($before.Dirs | Sort-Object) -Because 'dry-run created or removed a directory in the sandbox'
            foreach ($path in $before.Files.Keys) {
                $after.Files[$path] | Should -Be $before.Files[$path] -Because "dry-run modified an existing file: $path"
            }
        }

        It 'same invocation WITHOUT the flag is the positive control: every target IS written' {
            # The sandbox may already carry a .roomodes (the local-deploy Context
            # above wrote a JSON one): the contract is "rewritten by THIS deploy",
            # so the hash MUST change -- an absent write would leave it identical.
            $roomodes = Join-Path $script:Sandbox '.roomodes'
            $roomodesHashBefore = if (Test-Path -LiteralPath $roomodes) { (Get-FileHash -LiteralPath $roomodes -Algorithm SHA256).Hash } else { $null }

            $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $out,
                                        '--deploy', '--deploy-global', '--global-path', $globalTarget)

            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            $r.Output | Should -Match 'Deployed to global:'
            # Output file + the directory that had to be created for it.
            (Test-Path -LiteralPath $out) | Should -BeTrue
            (Test-Path -LiteralPath (Split-Path -Parent $out)) | Should -BeTrue
            ([regex]::Matches((Get-Content -LiteralPath $out -Raw), '(?m)^\s*- slug:')).Count | Should -Be $script:ExpectedModeCount
            # .roomodes at the SANDBOX root (disposable copy), with full mode parity.
            (Test-Path -LiteralPath $roomodes) | Should -BeTrue
            (Get-FileHash -LiteralPath $roomodes -Algorithm SHA256).Hash | Should -Not -Be $roomodesHashBefore -Because 'the .roomodes deploy did not happen'
            ([regex]::Matches((Get-Content -LiteralPath $roomodes -Raw), '(?m)^\s*- slug:')).Count | Should -Be $script:ExpectedModeCount
            # Global target + its directory, with full mode parity.
            (Test-Path -LiteralPath $globalTarget) | Should -BeTrue
            (Test-Path -LiteralPath (Split-Path -Parent $globalTarget)) | Should -BeTrue
            ([regex]::Matches((Get-Content -LiteralPath $globalTarget -Raw), '(?m)^\s*- slug:')).Count | Should -Be $script:ExpectedModeCount
        }

        It 'mutation witness: an unguarded write IS detected by the behavioural layer' {
            # ai-01 CHANGES: prove the layer can FAIL. The sandbox copy of the
            # script loses its writeFileSync dry-run guard, and the SAME dry-run
            # invocation runs against it: the output file must APPEAR -- that
            # appearance IS the detection (the zero-assertion of the first test
            # would go red on this mutant).
            $scriptPath = Join-Path $script:Sandbox (Join-Path 'roo-config' (Join-Path 'scripts' 'generate-modes.js'))
            $originalBytes = [System.IO.File]::ReadAllBytes($scriptPath)
            $original = [System.Text.Encoding]::UTF8.GetString($originalBytes)
            $mutated = $original -replace 'if \(!args\.dryRun\) \{\s*fs\.writeFileSync\(args\.output', "if (true) {`n    fs.writeFileSync(args.output"
            $mutated | Should -Not -Be $original -Because 'the mutation did not apply -- the witness would pass without detecting anything'
            # The output target lives in the sandbox ROOT (its parent exists): the
            # mkdir guard is still intact, so the unguarded write cannot die on
            # ENOENT -- it must land, visibly.
            $witnessOut = Join-Path $script:Sandbox 'mutant-witness-out.yaml'
            try {
                [System.IO.File]::WriteAllText($scriptPath, $mutated, (New-Object System.Text.UTF8Encoding($false)))
                $r = Invoke-GenerateModes @('--format', 'yaml', '--output', $witnessOut, '--dry-run')
            } finally {
                # Byte-exact restore (the sandbox is disposable, but the next test
                # in this run must see the pristine script).
                [System.IO.File]::WriteAllBytes($scriptPath, $originalBytes)
            }
            $r.ExitCode | Should -Be 0 -Because "generate-modes output was: $($r.Output)"
            (Test-Path -LiteralPath $witnessOut) | Should -BeTrue -Because 'the unguarded write did not happen -- the behavioural layer would be blind to it'
            # And the log still claims nothing was written: that is the original defect.
            $r.Output | Should -Match 'DRY RUN -- nothing was written'
        }
    }

    Context 'global deploy DryRun (writes nothing)' {

        BeforeEach {
            Reset-ExtensionTrees
            Reset-ExtensionDirs
        }

        It 'DryRun creates no directory and writes no destination file' {
            # ai-01 afternoon queue item 2: the New-Item used to run BEFORE the
            # $DryRun test -- a DryRun left an empty settings/ behind (measured on
            # ai-01's seat). Fixture: the storage ROOT only (the probe answers Zoo),
            # settings/ deliberately absent so creation is observable.
            New-Item -ItemType Directory -Force -Path $script:ZooStorageDir | Out-Null

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes, '-DryRun')

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'DRY RUN'
            $r.Output | Should -Match 'Target:\s+ZooCode \(auto-detected\)'
            (Test-Path -LiteralPath $script:ZooSettingsDir) | Should -BeFalse -Because 'DryRun must not create the settings dir'
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }

        It 'DryRun leaves the tracked generated yaml untouched (writes to a temp path)' {
            # ai-01 afternoon queue item 2: regeneration used to target the TRACKED
            # simple-complex.yaml -- on a checkout where it is stale vs the generator
            # (measured +114/-27) every DryRun rewrote it. Sentinel: the file the
            # buggy path would overwrite must come back byte-identical.
            New-Item -ItemType Directory -Force -Path $script:ZooStorageDir | Out-Null
            $trackedYaml = Join-Path $script:Sandbox (Join-Path 'roo-config' (Join-Path 'modes' (Join-Path 'generated' 'simple-complex.yaml')))
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $trackedYaml) | Out-Null
            'sentinel-not-a-real-yaml' | Set-Content -LiteralPath $trackedYaml -NoNewline

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes, '-DryRun')

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'YAML generated:'
            (Get-Content -LiteralPath $trackedYaml -Raw) | Should -Be 'sentinel-not-a-real-yaml' -Because 'DryRun regenerated into the tracked file instead of a temp path'
        }

        It 'DryRun deletes its PID-keyed temp yaml after reading it' {
            # ai-01 review note (optional, 2026-10-10): no test guarded the
            # Remove-Item of the temp file -- a mutant deleting that line stayed
            # green. Count pattern files before/after: the child shares our TEMP.
            New-Item -ItemType Directory -Force -Path $script:ZooStorageDir | Out-Null
            $tempRoot = [System.IO.Path]::GetTempPath()
            $strays = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'deploy-modes-dryrun-*.yaml' -ErrorAction SilentlyContinue)

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes, '-DryRun')

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'YAML generated:'
            $after = @(Get-ChildItem -LiteralPath $tempRoot -Filter 'deploy-modes-dryrun-*.yaml' -ErrorAction SilentlyContinue)
            $after.Count | Should -Be $strays.Count -Because 'the DryRun temp yaml was not deleted after reading'
        }
    }
}
