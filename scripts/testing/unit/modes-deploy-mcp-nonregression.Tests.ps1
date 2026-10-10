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
    $env:APPDATA = $script:FakeAppData
    . $extPaths
    $script:SettingsDir = Join-Path (Get-GlobalStoragePath -Extension RooCode) 'settings'
    $script:McpSettingsPath = Get-McpSettingsPath -Extension RooCode
    # #595 phase 3: both extensions' paths, from the SAME production helpers -- the
    # target-selection tests below need the Zoo side to assert on.
    $script:ZooSettingsDir = Join-Path (Get-GlobalStoragePath -Extension ZooCode) 'settings'
    $script:ZooMcpSettingsPath = Get-McpSettingsPath -Extension ZooCode

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
        param([string[]]$DeployArgs)
        $psExe = (Get-Process -Id $PID).Path
        $saved = $env:APPDATA
        try {
            $env:APPDATA = $script:FakeAppData
            $output = & $psExe -NoProfile -ExecutionPolicy Bypass -File $script:DeployScript @DeployArgs 2>&1
            return @{
                Output   = ($output | Out-String)
                ExitCode = $LASTEXITCODE
            }
        } finally {
            if ($null -ne $saved) { $env:APPDATA = $saved } else { Remove-Item env:APPDATA -ErrorAction SilentlyContinue }
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
            if (Test-Path -LiteralPath $script:SettingsDir) {
                Remove-Item -LiteralPath $script:SettingsDir -Recurse -Force
            }
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
            # Both extension trees start empty: each test builds only what it needs,
            # because the probe under test reads exactly those two files.
            foreach ($d in @($script:SettingsDir, $script:ZooSettingsDir)) {
                if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
            }
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

        It 'honours an explicit ZooCode target while Roo is the configured extension' {
            New-McpFixture   # Roo configured: the probe alone would answer RooCode
            New-McpFixtureAt -SettingsDir $script:ZooSettingsDir -McpPath $script:ZooMcpSettingsPath

            $r = Invoke-DeployModes @('-DeploymentType', 'global', '-Source', $script:SourceRoomodes,
                                      '-TargetExtension', 'ZooCode')

            $r.ExitCode | Should -Be 0 -Because "deploy output was: $($r.Output)"
            $r.Output | Should -Match 'Target:\s+ZooCode \(explicit\)'
            (Test-Path -LiteralPath (Join-Path $script:ZooSettingsDir 'custom_modes.yaml')) | Should -BeTrue
            (Test-Path -LiteralPath (Join-Path $script:SettingsDir 'custom_modes.yaml')) | Should -BeFalse
        }
    }
}
