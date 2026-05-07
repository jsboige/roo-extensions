<#
.SYNOPSIS
    Integration tests for dashboard-listener.ps1 end-to-end flow (#2048 Subtask D).

.DESCRIPTION
    Tests the full pipeline: dashboard file change → tag detection → workspace path
    resolution → spawn invocation with correct WorkingDirectory.

    Uses a mock spawn-claude.ps1 that captures its arguments to a capture file,
    then verifies the correct path was passed at each resolution level.

    Run: Invoke-Pester tests/Pester/dashboard-listener.integration.tests.ps1 -Output Detailed
#>

BeforeAll {
    $testRoot = Join-Path $env:TEMP "dashboard-listener-tests-$(Get-Random)"
    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

    # Directories
    $sharedPath = Join-Path $testRoot ".shared-state"
    $dashboardsDir = Join-Path $sharedPath "dashboards"
    $lockDir = Join-Path $testRoot "locks"
    $wsDir = Join-Path $testRoot "workspaces"
    New-Item -ItemType Directory -Path $dashboardsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
    New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

    # Create real workspace directories for path resolution
    $testWorkspaceDir = Join-Path $wsDir "test-ws"
    New-Item -ItemType Directory -Path $testWorkspaceDir -Force | Out-Null
    $repoRootSim = Join-Path $wsDir "roo-extensions"
    New-Item -ItemType Directory -Path $repoRootSim -Force | Out-Null

    # Capture file for mock spawn arguments
    $captureFile = Join-Path $testRoot "spawn-capture.txt"

    # Mock spawn script — writes all arguments to a capture file
    $mockSpawn = Join-Path $testRoot "spawn-claude.ps1"
    $mockSpawnContent = @'
param(
    [string]$Workspace,
    [string]$Since,
    [string]$McpConfig,
    [string]$WorkspacePath
)
$captureFile = $env:MOCK_SPAWN_CAPTURE
"$Workspace|$Since|$WorkspacePath" | Set-Content -Path $captureFile -Encoding UTF8
exit 0
'@
    [System.IO.File]::WriteAllText($mockSpawn, $mockSpawnContent, [System.Text.UTF8Encoding]::new($false))

    # Script under test
    $listenerScript = Join-Path $PSScriptRoot "..\..\scripts\dashboard-scheduler\dashboard-listener.ps1"
    $listenerScript = (Resolve-Path $listenerScript -ErrorAction SilentlyContinue).Path
    if (-not $listenerScript) {
        $listenerScript = Join-Path $PSScriptRoot "..\..\..\scripts\dashboard-scheduler\dashboard-listener.ps1"
        $listenerScript = (Resolve-Path $listenerScript).Path
    }

    # Helper: create a dashboard file with an actionable message
    function New-TestDashboard {
        param([string]$Workspace, [string]$Tag = "WAKE-CLAUDE", [string]$Timestamp)
        if (-not $Timestamp) {
            $Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        $content = @"
# Dashboard workspace-$Workspace

## Status
OK

## Intercom (1 messages)

### [$Timestamp] myia-ai-01|roo-extensions

## [$Tag] Test message for $Workspace
Please act on this.
"@
        $file = Join-Path $dashboardsDir "workspace-$Workspace.md"
        [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))
        return $file
    }

    # Helper: run listener in -Once -DryRun mode and capture output
    function Invoke-ListenerOnce {
        param(
            [string]$WorkspaceList,
            [string]$PathsFile = "",
            [string]$EnvPaths = "",
            [string]$McpConfigPath = "",
            [switch]$RealSpawn
        )
        if (Test-Path $captureFile) { Remove-Item $captureFile -Force -ErrorAction SilentlyContinue }

        $env:MOCK_SPAWN_CAPTURE = $captureFile
        $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = $envPaths
        $env:ROOSYNC_SHARED_PATH = $sharedPath

        $args = @(
            "-Workspaces", $WorkspaceList,
            "-SharedPath", $sharedPath,
            "-LockDir", $lockDir,
            "-SpawnScript", $mockSpawn,
            "-WorkspacePathsFile", $PathsFile,
            "-DebounceSeconds", "0",
            "-CooldownMinutes", "0",
            "-Once"
        )
        if (-not $RealSpawn) {
            $args += "-DryRun"
        }
        if (-not [string]::IsNullOrEmpty($McpConfigPath)) {
            $args += @("-McpConfig", $McpConfigPath)
        }

        $output = & pwsh -NoProfile -File $listenerScript @args 2>&1
        $outputText = $output -join "`n"

        $captured = $null
        if (Test-Path $captureFile) {
            $captured = Get-Content $captureFile -Raw -ErrorAction SilentlyContinue
        }

        # Clean env
        $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = $null

        return @{ Output = $outputText; Captured = $captured }
    }
}

AfterAll {
    if (Test-Path $testRoot) {
        Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# Test Suite: End-to-end integration (Subtask D)
# ============================================================

Describe "Dashboard Listener - Integration: workspace path resolution" {
    Context "Level 1: WorkspacePathsFile override" {
        It "Uses file map path when workspace-paths.json has an entry" {
            $ws = "test-ws"
            $pathsFile = Join-Path $testRoot "workspace-paths.json"
            $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
            [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

            $result.Output | Should -Match "resolved to.*$([regex]::Escape($testWorkspaceDir))"
        }
    }

    Context "Level 2: Environment variable map" {
        It "Uses env var path when DASHBOARD_WATCHER_WORKSPACE_PATHS is set" {
            $ws = "test-ws"
            # No paths file (or empty)
            $pathsFile = Join-Path $testRoot "workspace-paths-empty.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            $envJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json -Compress

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile -EnvPaths $envJson

            $result.Output | Should -Match "resolved to.*$([regex]::Escape($testWorkspaceDir))"
        }
    }

    Context "Level 3: Self-match (workspace name == repo leaf)" {
        It "Resolves to RepoRoot when workspace name matches repo directory leaf" {
            $ws = "roo-extensions"
            $pathsFile = Join-Path $testRoot "workspace-paths-empty.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

            # Must match the actual repo leaf name in the resolved path, not just "resolved to"
            $result.Output | Should -Match "resolved to.*roo-extensions"
        }
    }

    Context "Level 4: ~/.claude.json projects map" {
        It "Uses claude.json projects entry when workspace basename matches" {
            $ws = "test-ws-claude"
            $wsDir = Join-Path $wsDir $ws
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

            # No paths file override
            $pathsFile = Join-Path $testRoot "workspace-paths-empty.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            # Create a fake .claude.json with a projects section mapping our workspace
            $claudeJson = Join-Path $testRoot "fake-claude.json"
            $claudeContent = @{
                projects = @{
                    $wsDir = @{ allowedTools = @() }
                }
            } | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText($claudeJson, $claudeContent, [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile -McpConfigPath $claudeJson

            $result.Output | Should -Match "resolved to.*$([regex]::Escape($wsDir))"
        }

        It "Falls through when claude.json projects entry points to non-existent path" {
            $ws = "test-ws-ghost"
            $pathsFile = Join-Path $testRoot "workspace-paths-empty.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            $ghostPath = Join-Path $testRoot "path-that-does-not-exist"
            $claudeJson = Join-Path $testRoot "fake-claude-ghost.json"
            $claudeContent = @{
                projects = @{
                    $ghostPath = @{ allowedTools = @() }
                }
            } | ConvertTo-Json -Depth 3
            [System.IO.File]::WriteAllText($claudeJson, $claudeContent, [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile -McpConfigPath $claudeJson

            # Should warn about non-existent path and continue to Level 5
            $result.Output | Should -Match "non-existent path|No path resolved|No on-disk workspace path resolved"
        }
    }

    Context "Level 5: Auto-detect fallback" {
        It "Reports no path resolved when workspace has no mapping and directory does not exist" {
            $ws = "nonexistent-ws-$(Get-Random)"
            $pathsFile = Join-Path $testRoot "workspace-paths-empty.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

            $result.Output | Should -Match "No path resolved|No on-disk workspace path resolved"
        }
    }

    Context "Spawn invocation with correct WorkspacePath" {
        It "Passes resolved path to spawn script (real spawn, not dry run)" {
            $ws = "test-ws"
            $pathsFile = Join-Path $testRoot "workspace-paths-spawn.json"
            $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
            [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile -RealSpawn

            $result.Captured | Should -Not -BeNullOrEmpty
            $parts = $result.Captured.Trim() -split '\|'
            $parts[0] | Should -Be $ws
            $parts[2] | Should -Be $testWorkspaceDir
        }

        It "Does not spawn when path resolution fails" {
            $ws = "unresolvable-ws-$(Get-Random)"
            $pathsFile = Join-Path $testRoot "workspace-paths-nomatch.json"
            [System.IO.File]::WriteAllText($pathsFile, "{}", [System.Text.UTF8Encoding]::new($false))

            New-TestDashboard -Workspace $ws

            $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile -RealSpawn

            $result.Captured | Should -BeNullOrEmpty
        }
    }
}

Describe "Dashboard Listener - Integration: tag detection" {
    It "Triggers on [WAKE-CLAUDE] tag" {
        $ws = "test-ws"
        $pathsFile = Join-Path $testRoot "workspace-paths-tag1.json"
        $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
        [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

        New-TestDashboard -Workspace $ws -Tag "WAKE-CLAUDE"

        $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

        $result.Output | Should -Match "actionable|Found.*actionable"
    }

    It "Does not trigger on non-actionable tag" {
        $ws = "test-ws"
        $pathsFile = Join-Path $testRoot "workspace-paths-tag2.json"
        $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
        [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

        New-TestDashboard -Workspace $ws -Tag "INFO"

        $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

        $result.Output | Should -Not -Match "Found \d+ actionable"
    }

    It "Does not trigger on actionable tag inside code block" {
        $ws = "test-ws"
        $pathsFile = Join-Path $testRoot "workspace-paths-tag3.json"
        $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
        [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

        $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $content = @"
# Dashboard workspace-$ws

## Status
OK

## Intercom (1 messages)

### [$ts] myia-ai-01|roo-extensions

Some text before code block.

``````
## [WAKE-CLAUDE] This should be ignored
``````

More text after.
"@
        $file = Join-Path $dashboardsDir "workspace-$ws.md"
        [System.IO.File]::WriteAllText($file, $content, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-ListenerOnce -WorkspaceList $ws -PathsFile $pathsFile

        $result.Output | Should -Not -Match "Found \d+ actionable"
    }
}

Describe "Dashboard Listener - Integration: cooldown" {
    It "Skips spawn when cooldown is active" {
        $ws = "test-ws"
        $pathsFile = Join-Path $testRoot "workspace-paths-cd.json"
        $pathsJson = @{ $ws = $testWorkspaceDir } | ConvertTo-Json
        [System.IO.File]::WriteAllText($pathsFile, $pathsJson, [System.Text.UTF8Encoding]::new($false))

        # Set a recent last-run marker
        $lastrunFile = Join-Path $lockDir "listener-$ws.lastrun"
        $recentTs = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString("o")
        [System.IO.File]::WriteAllText($lastrunFile, $recentTs, [System.Text.UTF8Encoding]::new($false))

        New-TestDashboard -Workspace $ws

        # CooldownMinutes=5, last spawn was 1 minute ago → should be blocked
        $env:ROOSYNC_SHARED_PATH = $sharedPath
        $env:MOCK_SPAWN_CAPTURE = $captureFile

        $args = @(
            "-Workspaces", $ws,
            "-SharedPath", $sharedPath,
            "-LockDir", $lockDir,
            "-SpawnScript", $mockSpawn,
            "-WorkspacePathsFile", $pathsFile,
            "-DebounceSeconds", "0",
            "-CooldownMinutes", "5",
            "-Once",
            "-DryRun"
        )
        $output = & pwsh -NoProfile -File $listenerScript @args 2>&1
        $outputText = $output -join "`n"

        $outputText | Should -Match "Cooldown active"

        Remove-Item $lastrunFile -Force -ErrorAction SilentlyContinue
    }
}
