<#
.SYNOPSIS
    Pester tests for Resolve-WorkspacePath function in dashboard-listener.ps1

.DESCRIPTION
    Tests the 6-level workspace path resolution order:
      1. WorkspacePathsFile entry (explicit override)
      2. DASHBOARD_WATCHER_WORKSPACE_PATHS env var (JSON map)
      3. Self-match (ws name == leaf of $RepoRoot)
      4. ~/.claude.json projects keys (basename match)
      5. Auto-detect: scan common parent roots
      6. Not found → return $null

.NOTES
    Issue #2048 Subtask B
    Requires Pester 5+ and PowerShell 7+
#>

Describe 'Resolve-WorkspacePath' {
    BeforeAll {
        # --- Script-level state ---
        $script:_wsPathCache = @{}
        $script:_wsPathFileMap = $null
        $script:_wsPathEnvMap = $null
        $script:_wsPathClaudeJsonMap = $null
        $script:TestWorkspacePathsFile = ''
        $script:TestMcpConfig = ''
        $script:TestRepoRoot = ''

        # --- Temp directories ---
        $script:TestRoot = Join-Path $env:TEMP "dashboard-listener-tests-$(Get-Random)"
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'locks') -Force | Out-Null

        $script:MockDevDir = Join-Path $script:TestRoot 'dev'
        New-Item -ItemType Directory -Path (Join-Path $script:MockDevDir 'roo-extensions') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'explicit-dir') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'my-workspace') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'My-Workspace-Repo') -Force | Out-Null

        # workspace-paths.json
        $script:WorkspacePathsFile = Join-Path $script:TestRoot 'workspace-paths.json'
        $pathsMap = @{
            'explicit-workspace' = Join-Path $script:TestRoot 'explicit-dir'
            'roo-extensions'     = Join-Path $script:TestRoot 'explicit-dir'
        } | ConvertTo-Json
        [System.IO.File]::WriteAllText($script:WorkspacePathsFile, $pathsMap, [System.Text.UTF8Encoding]::new($false))

        # mock .claude.json
        $script:MockClaudeJson = Join-Path $script:TestRoot 'mock-claude.json'
        $claudeJson = @{
            projects = @{
                (Join-Path $script:MockDevDir 'roo-extensions') = @{}
            }
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($script:MockClaudeJson, $claudeJson, [System.Text.UTF8Encoding]::new($false))

        # --- Functions under test (from dashboard-listener.ps1) ---
        function Write-Log($level, $msg) { }

        function Get-WorkspacePathMaps {
            if ($null -eq $script:_wsPathFileMap) {
                $script:_wsPathFileMap = @{}
                if (-not [string]::IsNullOrEmpty($script:TestWorkspacePathsFile) -and (Test-Path $script:TestWorkspacePathsFile)) {
                    try {
                        $raw = [System.IO.File]::ReadAllText($script:TestWorkspacePathsFile, [System.Text.UTF8Encoding]::new($false))
                        $obj = $raw | ConvertFrom-Json
                        foreach ($prop in $obj.PSObject.Properties) {
                            $script:_wsPathFileMap[$prop.Name] = [string]$prop.Value
                        }
                    } catch { }
                }
            }
            if ($null -eq $script:_wsPathEnvMap) {
                $script:_wsPathEnvMap = @{}
                $envJsonVal = $env:DASHBOARD_WATCHER_WORKSPACE_PATHS
                if (-not [string]::IsNullOrEmpty($envJsonVal)) {
                    try {
                        $obj = $envJsonVal | ConvertFrom-Json
                        foreach ($prop in $obj.PSObject.Properties) {
                            $script:_wsPathEnvMap[$prop.Name] = [string]$prop.Value
                        }
                    } catch { }
                }
            }
            return @{ file = $script:_wsPathFileMap; env = $script:_wsPathEnvMap }
        }

        function Get-ClaudeJsonProjectsMap {
            if ($null -ne $script:_wsPathClaudeJsonMap) {
                return $script:_wsPathClaudeJsonMap
            }
            $script:_wsPathClaudeJsonMap = @{}
            if ([string]::IsNullOrEmpty($script:TestMcpConfig) -or -not (Test-Path $script:TestMcpConfig)) {
                return $script:_wsPathClaudeJsonMap
            }
            try {
                $raw = [System.IO.File]::ReadAllText($script:TestMcpConfig, [System.Text.UTF8Encoding]::new($false))
                $obj = $raw | ConvertFrom-Json -AsHashtable
                if ($null -ne $obj -and $obj.ContainsKey('projects') -and $null -ne $obj['projects']) {
                    foreach ($absPath in $obj['projects'].Keys) {
                        if ([string]::IsNullOrEmpty($absPath)) { continue }
                        $leaf = Split-Path $absPath -Leaf
                        if ([string]::IsNullOrEmpty($leaf)) { continue }
                        $key = $leaf.ToLowerInvariant()
                        if (-not $script:_wsPathClaudeJsonMap.ContainsKey($key)) {
                            $script:_wsPathClaudeJsonMap[$key] = $absPath
                        }
                    }
                }
            } catch { }
            return $script:_wsPathClaudeJsonMap
        }

        function Resolve-WorkspacePath($ws) {
            if ($script:_wsPathCache.ContainsKey($ws)) {
                return $script:_wsPathCache[$ws]
            }
            $maps = Get-WorkspacePathMaps

            # 1. Explicit override file
            if ($maps.file.ContainsKey($ws)) {
                $p = $maps.file[$ws]
                if (Test-Path $p -PathType Container) {
                    $script:_wsPathCache[$ws] = $p
                    return $p
                }
            }
            # 2. Env var map
            if ($maps.env.ContainsKey($ws)) {
                $p = $maps.env[$ws]
                if (Test-Path $p -PathType Container) {
                    $script:_wsPathCache[$ws] = $p
                    return $p
                }
            }
            # 3. Self-match
            if (-not [string]::IsNullOrEmpty($script:TestRepoRoot)) {
                $selfName = Split-Path $script:TestRepoRoot -Leaf
                if ($ws -ieq $selfName) {
                    $script:_wsPathCache[$ws] = $script:TestRepoRoot
                    return $script:TestRepoRoot
                }
            }
            # 4. ~/.claude.json projects
            $cjMap = Get-ClaudeJsonProjectsMap
            $key = $ws.ToLowerInvariant()
            if ($cjMap.ContainsKey($key)) {
                $p = $cjMap[$key]
                if (Test-Path $p -PathType Container) {
                    $script:_wsPathCache[$ws] = $p
                    return $p
                }
            }
            # 5. Auto-detect
            $candidateRoots = @()
            if (-not [string]::IsNullOrEmpty($script:TestRepoRoot)) {
                $candidateRoots += (Split-Path $script:TestRepoRoot -Parent)
            }
            $candidateRoots += @("D:\dev", "D:\", "C:\dev", "C:\")
            foreach ($root in $candidateRoots) {
                if ([string]::IsNullOrEmpty($root)) { continue }
                $candidate = Join-Path $root $ws
                if (Test-Path $candidate -PathType Container) {
                    $script:_wsPathCache[$ws] = $candidate
                    return $candidate
                }
            }
            # 6. Not found
            $script:_wsPathCache[$ws] = $null
            return $null
        }
    }

    BeforeEach {
        $script:_wsPathCache = @{}
        $script:_wsPathFileMap = $null
        $script:_wsPathEnvMap = $null
        $script:_wsPathClaudeJsonMap = $null
        $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = $null
        $script:TestWorkspacePathsFile = ''
        $script:TestMcpConfig = ''
        $script:TestRepoRoot = ''
    }

    AfterAll {
        if (Test-Path $script:TestRoot) {
            Remove-Item $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = $null
    }

    # =================================================================
    # Level 1: WorkspacePathsFile
    # =================================================================

    Context 'Level 1: WorkspacePathsFile (explicit override)' {
        BeforeEach {
            $script:TestWorkspacePathsFile = $script:WorkspacePathsFile
        }

        It 'Returns mapped path when workspace-paths.json has a valid entry' {
            Resolve-WorkspacePath 'explicit-workspace' | Should -BeExactly (Join-Path $script:TestRoot 'explicit-dir')
        }

        It 'Falls through when mapped path does not exist on disk' {
            $badPathsFile = Join-Path $script:TestRoot 'bad-paths.json'
            $badMap = @{ 'ghost-workspace' = Join-Path $script:TestRoot 'does-not-exist' } | ConvertTo-Json
            [System.IO.File]::WriteAllText($badPathsFile, $badMap, [System.Text.UTF8Encoding]::new($false))
            $script:_wsPathFileMap = $null
            $script:TestWorkspacePathsFile = $badPathsFile
            Resolve-WorkspacePath 'ghost-workspace' | Should -BeNullOrEmpty
        }
    }

    # =================================================================
    # Level 2: Env var
    # =================================================================

    Context 'Level 2: DASHBOARD_WATCHER_WORKSPACE_PATHS env var' {
        It 'Returns path from env var JSON map' {
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = @{ 'env-workspace' = Join-Path $script:TestRoot 'explicit-dir' } | ConvertTo-Json
            Resolve-WorkspacePath 'env-workspace' | Should -BeExactly (Join-Path $script:TestRoot 'explicit-dir')
        }

        It 'Ignores malformed JSON in env var gracefully' {
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = '{invalid json'
            Resolve-WorkspacePath 'any-workspace' | Should -BeNullOrEmpty
        }

        It 'Env var takes precedence over self-match' {
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = @{ 'my-workspace' = Join-Path $script:TestRoot 'explicit-dir' } | ConvertTo-Json
            $script:TestRepoRoot = Join-Path $script:TestRoot 'my-workspace'
            Resolve-WorkspacePath 'my-workspace' | Should -BeExactly (Join-Path $script:TestRoot 'explicit-dir')
        }
    }

    # =================================================================
    # Level 3: Self-match
    # =================================================================

    Context 'Level 3: Self-match (workspace name == RepoRoot leaf)' {
        It 'Returns RepoRoot when workspace name matches leaf' {
            $script:TestRepoRoot = Join-Path $script:TestRoot 'my-workspace'
            Resolve-WorkspacePath 'my-workspace' | Should -BeExactly (Join-Path $script:TestRoot 'my-workspace')
        }

        It 'Self-match is case-insensitive' {
            $script:TestRepoRoot = Join-Path $script:TestRoot 'My-Workspace-Repo'
            Resolve-WorkspacePath 'my-workspace-repo' | Should -BeExactly (Join-Path $script:TestRoot 'My-Workspace-Repo')
        }
    }

    # =================================================================
    # Level 4: ~/.claude.json projects
    # =================================================================

    Context 'Level 4: ~/.claude.json projects' {
        BeforeEach {
            $script:TestMcpConfig = $script:MockClaudeJson
        }

        It 'Returns path from .claude.json when basename matches' {
            Resolve-WorkspacePath 'roo-extensions' | Should -BeExactly (Join-Path $script:MockDevDir 'roo-extensions')
        }

        It 'Match is case-insensitive' {
            Resolve-WorkspacePath 'Roo-Extensions' | Should -BeExactly (Join-Path $script:MockDevDir 'roo-extensions')
        }

        It 'Falls through when .claude.json path does not exist on disk' {
            $badClaudeJson = Join-Path $script:TestRoot 'bad-claude.json'
            $badContent = @{ projects = @{ 'C:\nonexistent\workspace' = @{} } } | ConvertTo-Json -Depth 5
            [System.IO.File]::WriteAllText($badClaudeJson, $badContent, [System.Text.UTF8Encoding]::new($false))
            $script:_wsPathClaudeJsonMap = $null
            $script:TestMcpConfig = $badClaudeJson
            Resolve-WorkspacePath 'workspace' | Should -BeNullOrEmpty
        }
    }

    # =================================================================
    # Level 5: Auto-detect
    # =================================================================

    Context 'Level 5: Auto-detect (scan common roots)' {
        It 'Finds workspace in parent of RepoRoot' {
            $script:TestRepoRoot = Join-Path $script:MockDevDir 'some-other-dir'
            Resolve-WorkspacePath 'roo-extensions' | Should -BeExactly (Join-Path $script:MockDevDir 'roo-extensions')
        }
    }

    # =================================================================
    # Level 6: Not found
    # =================================================================

    Context 'Level 6: Not found' {
        It 'Returns $null when workspace cannot be resolved' {
            $script:TestRepoRoot = $script:TestRoot
            Resolve-WorkspacePath 'totally-nonexistent-xyz-abc' | Should -BeNullOrEmpty
        }
    }

    # =================================================================
    # Priority order
    # =================================================================

    Context 'Resolution priority order' {
        It 'Level 1 (file) takes precedence over all other levels' {
            $script:TestWorkspacePathsFile = $script:WorkspacePathsFile
            $script:TestMcpConfig = $script:MockClaudeJson
            $script:TestRepoRoot = Join-Path $script:MockDevDir 'roo-extensions'
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = @{ 'roo-extensions' = Join-Path $script:MockDevDir 'roo-extensions' } | ConvertTo-Json
            # File maps 'roo-extensions' → explicit-dir (exists) → should win
            Resolve-WorkspacePath 'roo-extensions' | Should -BeExactly (Join-Path $script:TestRoot 'explicit-dir')
        }

        It 'Level 2 (env) takes precedence over 3/4/5 when file is empty' {
            $script:TestMcpConfig = $script:MockClaudeJson
            $script:TestRepoRoot = Join-Path $script:MockDevDir 'roo-extensions'
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = @{ 'roo-extensions' = Join-Path $script:TestRoot 'explicit-dir' } | ConvertTo-Json
            Resolve-WorkspacePath 'roo-extensions' | Should -BeExactly (Join-Path $script:TestRoot 'explicit-dir')
        }

        It 'Level 3 (self) takes precedence over 4/5 when file and env are empty' {
            $script:TestMcpConfig = $script:MockClaudeJson
            $selfMatchDir = Join-Path $script:TestRoot 'roo-extensions'
            New-Item -ItemType Directory -Path $selfMatchDir -Force | Out-Null
            $script:TestRepoRoot = $selfMatchDir
            Resolve-WorkspacePath 'roo-extensions' | Should -BeExactly $selfMatchDir
        }
    }

    # =================================================================
    # Caching
    # =================================================================

    Context 'Caching behavior' {
        It 'Returns same result on repeated calls' {
            $script:TestWorkspacePathsFile = $script:WorkspacePathsFile
            $result1 = Resolve-WorkspacePath 'explicit-workspace'
            $result2 = Resolve-WorkspacePath 'explicit-workspace'
            $result1 | Should -Be $result2
        }
    }
}
