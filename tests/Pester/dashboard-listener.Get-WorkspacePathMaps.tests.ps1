#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-WorkspacePathMaps from dashboard-listener.ps1 (#2048 Subtask C).

.DESCRIPTION
    Tests the workspace path map resolution from file and env var sources.
    Validates parsing, error handling (malformed JSON), caching, and precedence.

.NOTES
    CI: Pester requires PowerShell — run locally on Windows.
    Run: pwsh -Command "Invoke-Pester -Path tests/Pester/dashboard-listener.Get-WorkspacePathMaps.tests.ps1 -Output Detailed"
    Requires Pester 5+.
#>

Describe "Get-WorkspacePathMaps" {
    BeforeAll {
        $script:logMessages = [System.Collections.Generic.List[string]]::new()
        function Write-Log($level, $msg) {
            $script:logMessages.Add("[$level] $msg")
        }

        $script:_wsPathFileMap = $null
        $script:_wsPathEnvMap = $null

        $script:testDir = Join-Path $env:TEMP "dashboard-listener-tests-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        function Get-WorkspacePathMaps {
            if ($null -eq $script:_wsPathFileMap) {
                $script:_wsPathFileMap = @{}
                if (Test-Path $WorkspacePathsFile) {
                    try {
                        $raw = [System.IO.File]::ReadAllText($WorkspacePathsFile, [System.Text.UTF8Encoding]::new($false))
                        $obj = $raw | ConvertFrom-Json
                        foreach ($prop in $obj.PSObject.Properties) {
                            $script:_wsPathFileMap[$prop.Name] = [string]$prop.Value
                        }
                    } catch {
                        Write-Log "WARN" "Failed to parse $WorkspacePathsFile : $_"
                    }
                }
            }
            if ($null -eq $script:_wsPathEnvMap) {
                $script:_wsPathEnvMap = @{}
                $envJson = $env:DASHBOARD_WATCHER_WORKSPACE_PATHS
                if (-not [string]::IsNullOrEmpty($envJson)) {
                    try {
                        $obj = $envJson | ConvertFrom-Json
                        foreach ($prop in $obj.PSObject.Properties) {
                            $script:_wsPathEnvMap[$prop.Name] = [string]$prop.Value
                        }
                    } catch {
                        Write-Log "WARN" "Failed to parse DASHBOARD_WATCHER_WORKSPACE_PATHS env var: $_"
                    }
                }
            }
            return @{ file = $script:_wsPathFileMap; env = $script:_wsPathEnvMap }
        }
    }

    AfterAll {
        if (Test-Path $script:testDir) {
            Remove-Item $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item Env:\DASHBOARD_WATCHER_WORKSPACE_PATHS -ErrorAction SilentlyContinue
    }

    BeforeEach {
        $script:_wsPathFileMap = $null
        $script:_wsPathEnvMap = $null
        $script:logMessages.Clear()
        Remove-Item Env:\DASHBOARD_WATCHER_WORKSPACE_PATHS -ErrorAction SilentlyContinue
    }

    Context "File map — valid JSON" {
        BeforeEach {
            $jsonFile = Join-Path $script:testDir "workspace-paths.json"
            $json = '{"roo-extensions": "C:/dev/roo-extensions", "nanoclaw": "D:/nanoclaw"}'
            [System.IO.File]::WriteAllText($jsonFile, $json, [System.Text.UTF8Encoding]::new($false))
            $script:WorkspacePathsFile = $jsonFile
        }

        It "Parses valid JSON file into file map" {
            $result = Get-WorkspacePathMaps
            $result.file["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
            $result.file["nanoclaw"] | Should -Be "D:/nanoclaw"
        }

        It "Returns empty env map when env var not set" {
            $result = Get-WorkspacePathMaps
            $result.env.Count | Should -Be 0
        }

        It "Does not log any warnings" {
            Get-WorkspacePathMaps | Out-Null
            $script:logMessages.Count | Should -Be 0
        }
    }

    Context "File map — missing file" {
        BeforeEach {
            $script:WorkspacePathsFile = Join-Path $script:testDir "nonexistent.json"
        }

        It "Returns empty file map when file does not exist" {
            $result = Get-WorkspacePathMaps
            $result.file.Count | Should -Be 0
        }

        It "Does not log any warnings" {
            Get-WorkspacePathMaps | Out-Null
            $script:logMessages.Count | Should -Be 0
        }
    }

    Context "File map — malformed JSON" {
        BeforeEach {
            $jsonFile = Join-Path $script:testDir "bad.json"
            [System.IO.File]::WriteAllText($jsonFile, "{invalid json!!!", [System.Text.UTF8Encoding]::new($false))
            $script:WorkspacePathsFile = $jsonFile
        }

        It "Returns empty file map for malformed JSON" {
            $result = Get-WorkspacePathMaps
            $result.file.Count | Should -Be 0
        }

        It "Logs a WARN message about parse failure" {
            Get-WorkspacePathMaps | Out-Null
            $script:logMessages.Count | Should -BeGreaterOrEqual 1
            $script:logMessages[0] | Should -Match "WARN.*Failed to parse"
        }
    }

    Context "Env var — valid JSON only" {
        BeforeEach {
            $script:WorkspacePathsFile = Join-Path $script:testDir "nonexistent.json"
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = '{"roo-extensions": "C:/dev/roo-extensions"}'
        }

        It "Parses valid env var JSON into env map" {
            $result = Get-WorkspacePathMaps
            $result.env["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
        }

        It "Returns empty file map when file missing" {
            $result = Get-WorkspacePathMaps
            $result.file.Count | Should -Be 0
        }
    }

    Context "Env var — malformed JSON" {
        BeforeEach {
            $script:WorkspacePathsFile = Join-Path $script:testDir "nonexistent.json"
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = '{{not valid}}'
        }

        It "Returns empty env map for malformed JSON" {
            $result = Get-WorkspacePathMaps
            $result.env.Count | Should -Be 0
        }

        It "Logs a WARN about env var parse failure" {
            Get-WorkspacePathMaps | Out-Null
            $script:logMessages.Count | Should -BeGreaterOrEqual 1
            $script:logMessages[0] | Should -Match "WARN.*DASHBOARD_WATCHER_WORKSPACE_PATHS"
        }
    }

    Context "File + env var combined" {
        BeforeEach {
            $jsonFile = Join-Path $script:testDir "both.json"
            $json = '{"roo-extensions": "C:/dev/roo-extensions"}'
            [System.IO.File]::WriteAllText($jsonFile, $json, [System.Text.UTF8Encoding]::new($false))
            $script:WorkspacePathsFile = $jsonFile
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = '{"nanoclaw": "D:/nanoclaw"}'
        }

        It "Populates both file and env maps" {
            $result = Get-WorkspacePathMaps
            $result.file["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
            $result.env["nanoclaw"] | Should -Be "D:/nanoclaw"
        }

        It "File and env maps are independent" {
            $result = Get-WorkspacePathMaps
            $result.file.ContainsKey("nanoclaw") | Should -BeFalse
            $result.env.ContainsKey("roo-extensions") | Should -BeFalse
        }
    }

    Context "Empty env var" {
        BeforeEach {
            $script:WorkspacePathsFile = Join-Path $script:testDir "nonexistent.json"
            $env:DASHBOARD_WATCHER_WORKSPACE_PATHS = ""
        }

        It "Returns empty env map for empty string" {
            $result = Get-WorkspacePathMaps
            $result.env.Count | Should -Be 0
        }
    }

    Context "Caching behavior" {
        BeforeEach {
            $jsonFile = Join-Path $script:testDir "cache-test.json"
            $json = '{"ws1": "C:/ws1"}'
            [System.IO.File]::WriteAllText($jsonFile, $json, [System.Text.UTF8Encoding]::new($false))
            $script:WorkspacePathsFile = $jsonFile
        }

        It "Returns same result on second call (cache hit)" {
            $first = Get-WorkspacePathMaps
            $second = Get-WorkspacePathMaps
            $second.file["ws1"] | Should -Be $first.file["ws1"]
        }

        It "Cache survives file modification (stale read)" {
            $first = Get-WorkspacePathMaps
            $newJson = '{"ws1": "C:/ws1-UPDATED"}'
            [System.IO.File]::WriteAllText($script:WorkspacePathsFile, $newJson, [System.Text.UTF8Encoding]::new($false))
            $second = Get-WorkspacePathMaps
            $second.file["ws1"] | Should -Be "C:/ws1"
        }

        It "Cache is cleared when script variables reset" {
            $first = Get-WorkspacePathMaps
            $script:_wsPathFileMap = $null
            $script:_wsPathEnvMap = $null
            $newJson = '{"ws1": "C:/ws1-NEW"}'
            [System.IO.File]::WriteAllText($script:WorkspacePathsFile, $newJson, [System.Text.UTF8Encoding]::new($false))
            $second = Get-WorkspacePathMaps
            $second.file["ws1"] | Should -Be "C:/ws1-NEW"
        }
    }
}
