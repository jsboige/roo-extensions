#!/usr/bin/env pwsh
# Pester 5+ tests for dashboard-listener.ps1
# Issue #2048: Subtask B — Resolve-WorkspacePath coverage
# Machine: myia-po-2024

Describe 'Resolve-WorkspacePath' {

BeforeAll {
    $scriptFilePath = Join-Path $PSScriptRoot '../../scripts/dashboard-scheduler/dashboard-listener.ps1'
    $resolvedPath = (Resolve-Path $scriptFilePath).Path

    # Parse the source script with PowerShell AST and extract function definitions.
    # We cannot dot-source the script (it calls `exit` and creates FileSystemWatcher side effects).
    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath,
        [ref]$tokens,
        [ref]$parseErrors
    )

    $funcDefs = $ast.FindAll(
        { param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $true
    )

    # Extract function BODIES (not full definitions) from AST.
    # Key insight: Set-Item function:\Name with the full "function Name { ... }" text
    # creates a wrapper that defines a nested function and returns $null.
    # We must pass only the body statements (without the function wrapper).
    # Also: parameters defined in the function signature (not param() block) must be
    # re-added as param() at the top of the extracted body.
    $needed = @('Resolve-WorkspacePath', 'Get-WorkspacePathMaps', 'Get-ClaudeJsonProjectsMap', 'Write-Log')
    foreach ($fd in $funcDefs) {
        if ($fd.Name -in $needed) {
            # Body text includes outer { } — strip them
            $bodyText = $fd.Body.Extent.Text
            $inner = $bodyText.Substring(1, $bodyText.Length - 2)

            # Reconstruct param() block from function signature parameters
            if ($fd.Parameters -and $fd.Parameters.Count -gt 0) {
                $paramNames = $fd.Parameters | ForEach-Object { '$' + $_.Name.VariablePath.UserPath }
                $paramBlock = 'param(' + ($paramNames -join ', ') + ')'
                $inner = $paramBlock + "`n" + $inner
            }

            # Replace scope prefixes so variables resolve from global scope
            $inner = $inner -replace '\$script:', '$$global:'
            $inner = $inner -replace '\$WorkspacePathsFile\b', '$$global:WorkspacePathsFile'
            $inner = $inner -replace '\$McpConfig\b', '$$global:McpConfig'
            $inner = $inner -replace '\$RepoRoot\b', '$$global:RepoRoot'
            Set-Item -Path "function:\$($fd.Name)" -Value ([ScriptBlock]::Create($inner))
        }
    }

    # Variables referenced by the extracted functions (no scope prefix in source).
    # Must be $global: because extracted functions (via Set-Item) are session-scoped
    # and resolve unqualified variables through the scope chain ending at global scope.
    $global:WorkspacePathsFile = Join-Path $TestDrive 'workspace-paths.json'
    $global:McpConfig = Join-Path $TestDrive 'claude.json'
    $global:RepoRoot = Join-Path $TestDrive 'repo'
    New-Item -ItemType Directory -Path $global:RepoRoot -Force | Out-Null

    # Initialize global cache variables (replaced from $script: → $global:)
    $global:_wsPathCache = @{}
    $global:_wsPathFileMap = $null
    $global:_wsPathEnvMap = $null
    $global:_wsPathClaudeJsonMap = $null
}

BeforeEach {
    # Reset caches and test files between tests
    $global:_wsPathCache = @{}
    $global:_wsPathFileMap = $null
    $global:_wsPathEnvMap = $null
    $global:_wsPathClaudeJsonMap = $null
    if (Test-Path $global:WorkspacePathsFile) { Remove-Item $global:WorkspacePathsFile -Force }
    if (Test-Path $global:McpConfig) { Remove-Item $global:McpConfig -Force }
    Remove-Item Env:\DASHBOARD_WATCHER_WORKSPACE_PATHS -ErrorAction SilentlyContinue
    # Clean up auto-detect artifacts: remove all subdirs of TestDrive except RepoRoot
    Get-ChildItem $TestDrive -Directory | Where-Object { $_.Name -ne 'repo' } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

AfterAll {
    # Clean up global variables
    Remove-Variable _wsPathCache, _wsPathFileMap, _wsPathEnvMap, _wsPathClaudeJsonMap, WorkspacePathsFile, McpConfig, RepoRoot -Scope Global -ErrorAction SilentlyContinue
}

    Context 'Level 1: Explicit file map' {
        It 'Returns mapped path when entry exists and path is valid directory' {
            $targetDir = Join-Path $TestDrive 'my-ws'
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            @{ 'my-ws' = $targetDir } | ConvertTo-Json | Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'my-ws'
            $result | Should -BeExactly $targetDir
        }

        It 'Falls through when mapped path does not exist as directory' {
            @{ 'my-ws' = 'C:\nonexistent\path\12345' } | ConvertTo-Json |
                Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'my-ws'
            $result | Should -BeNullOrEmpty
        }

        It 'Handles workspace names with hyphens and dots' {
            $targetDir = Join-Path $TestDrive 'my-app.v2'
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            @{ 'my-app.v2' = $targetDir } | ConvertTo-Json |
                Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'my-app.v2'
            $result | Should -BeExactly $targetDir
        }
    }

    Context 'Level 2: Env var map' {
        It 'Returns mapped path from DASHBOARD_WATCHER_WORKSPACE_PATHS env var' {
            $targetDir = Join-Path $TestDrive 'env-ws'
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = ConvertTo-Json @{ 'env-ws' = $targetDir }

            $result = Resolve-WorkspacePath 'env-ws'
            $result | Should -BeExactly $targetDir
        }

        It 'Falls through when env-mapped path does not exist' {
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = ConvertTo-Json @{ 'env-ws' = 'C:\no\such\dir' }

            $result = Resolve-WorkspacePath 'env-ws'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Level 3: Self-match (workspace name == RepoRoot leaf)' {
        It 'Returns RepoRoot when workspace name matches RepoRoot leaf' {
            # RepoRoot = TestDrive:\repo, leaf = 'repo'
            $result = Resolve-WorkspacePath 'repo'
            $result | Should -BeExactly $RepoRoot
        }

        It 'Does not match when workspace name differs from RepoRoot leaf' {
            $result = Resolve-WorkspacePath 'other-workspace'
            $result | Should -BeNullOrEmpty
        }

        It 'Self-match is case-insensitive' {
            $result = Resolve-WorkspacePath 'REPO'
            $result | Should -BeExactly $RepoRoot
        }
    }

    Context 'Level 4: Claude.json projects' {
        It 'Returns path from .claude.json projects registry' {
            $wsDir = Join-Path $TestDrive 'my-claude-project'
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

            $claudeJson = @{ projects = @{ $wsDir = @{} } } | ConvertTo-Json -Depth 5
            Set-Content $McpConfig $claudeJson -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'my-claude-project'
            $result | Should -BeExactly $wsDir
        }

        It 'Falls through when project path does not exist on disk' {
            $claudeJson = @{ projects = @{ 'C:\nonexistent\deleted-project' = @{} } } |
                ConvertTo-Json -Depth 5
            Set-Content $McpConfig $claudeJson -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'deleted-project'
            $result | Should -BeNullOrEmpty
        }

        It 'Match is case-insensitive on basename' {
            $wsDir = Join-Path $TestDrive 'MyProject'
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

            $claudeJson = @{ projects = @{ $wsDir = @{} } } | ConvertTo-Json -Depth 5
            Set-Content $McpConfig $claudeJson -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'myproject'
            $result | Should -BeExactly $wsDir
        }
    }

    Context 'Level 5: Auto-detect' {
        It 'Finds workspace under parent of RepoRoot' {
            $wsDir = Join-Path (Split-Path $RepoRoot -Parent) 'auto-ws'
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

            $result = Resolve-WorkspacePath 'auto-ws'
            $result | Should -BeExactly $wsDir
        }
    }

    Context 'Level 6: Not found' {
        It 'Returns null when no resolution level matches' {
            $result = Resolve-WorkspacePath 'completely-unknown-workspace-xyz'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Caching behavior' {
        It 'Returns cached result on second call without re-reading maps' {
            $targetDir = Join-Path $TestDrive 'cached-ws'
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            @{ 'cached-ws' = $targetDir } | ConvertTo-Json |
                Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM

            $result1 = Resolve-WorkspacePath 'cached-ws'
            $result1 | Should -BeExactly $targetDir

            # Remove file map — second call should use cache, not re-read
            Remove-Item $WorkspacePathsFile -Force

            $result2 = Resolve-WorkspacePath 'cached-ws'
            $result2 | Should -BeExactly $targetDir
        }

        It 'Caches not-found result (subsequent calls return null without re-scanning)' {
            $result1 = Resolve-WorkspacePath 'unknown-ws'
            $result1 | Should -BeNullOrEmpty

            # Create a dir that would match auto-detect
            $wsDir = Join-Path (Split-Path $RepoRoot -Parent) 'unknown-ws'
            New-Item -ItemType Directory -Path $wsDir -Force | Out-Null

            # Second call should still return null (cached not-found)
            $result2 = Resolve-WorkspacePath 'unknown-ws'
            $result2 | Should -BeNullOrEmpty
        }

        It 'Cache is reset between tests (BeforeEach resets state)' {
            $result = Resolve-WorkspacePath 'cached-ws'
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Priority: higher level wins over lower' {
        It 'File map wins over env map (level 1 > level 2)' {
            $fileDir = Join-Path $TestDrive 'file-wins'
            $envDir = Join-Path $TestDrive 'env-loses'
            New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            New-Item -ItemType Directory -Path $envDir -Force | Out-Null

            @{ 'ws-priority' = $fileDir } | ConvertTo-Json |
                Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = ConvertTo-Json @{ 'ws-priority' = $envDir }

            $result = Resolve-WorkspacePath 'ws-priority'
            $result | Should -BeExactly $fileDir
        }

        It 'File map wins over self-match (level 1 > level 3)' {
            # RepoRoot leaf = 'repo' — self-match would return RepoRoot
            # But file map should take priority
            $otherDir = Join-Path $TestDrive 'other-location'
            New-Item -ItemType Directory -Path $otherDir -Force | Out-Null
            @{ 'repo' = $otherDir } | ConvertTo-Json |
                Set-Content $WorkspacePathsFile -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'repo'
            $result | Should -BeExactly $otherDir
        }

        It 'Self-match wins over auto-detect (level 3 > level 5)' {
            # Self-match returns RepoRoot (leaf = 'repo')
            # Auto-detect would also find 'repo' under parent of RepoRoot (same path)
            # but self-match runs first
            $result = Resolve-WorkspacePath 'repo'
            $result | Should -BeExactly $RepoRoot
        }
    }

    Context 'Error handling' {
        It 'Handles malformed JSON in workspace-paths.json gracefully' {
            Set-Content $WorkspacePathsFile '{invalid json!!!' -Encoding UTF8NoBOM

            { Resolve-WorkspacePath 'any-ws' } | Should -Not -Throw
        }

        It 'Handles malformed DASHBOARD_WATCHER_WORKSPACE_PATHS gracefully' {
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = '{not valid json'

            { Resolve-WorkspacePath 'any-ws' } | Should -Not -Throw
        }

        It 'Handles missing claude.json gracefully' {
            # McpConfig points to non-existent file (default state from BeforeEach)
            $result = Resolve-WorkspacePath 'some-workspace'
            $result | Should -BeNullOrEmpty
        }

        It 'Handles claude.json without projects section' {
            Set-Content $McpConfig '{"apiProvider":"anthropic"}' -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'any-ws'
            $result | Should -BeNullOrEmpty
        }

        It 'Handles empty workspace-paths.json' {
            Set-Content $WorkspacePathsFile '{}' -Encoding UTF8NoBOM

            $result = Resolve-WorkspacePath 'any-ws'
            $result | Should -BeNullOrEmpty
        }
    }
}
