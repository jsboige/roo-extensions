#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Get-WorkspacePathMaps from dashboard-listener.ps1 (#2048 Subtask C).

.DESCRIPTION
    Tests the workspace path map resolution from file and env var sources.
    Uses brace-counting extraction from source (no inline duplication).
    Validates parsing, error handling (malformed JSON), caching, and partial failure.

.NOTES
    CI: Pester requires PowerShell — run locally on Windows.
    Run: pwsh -Command "Invoke-Pester -Path tests/Pester/dashboard-listener.Get-WorkspacePathMaps.tests.ps1 -Output Detailed"
    Requires Pester 5+.
#>

Describe "Get-WorkspacePathMaps" {
    BeforeAll {
        # Brace-counting extraction of Get-WorkspacePathMaps from source.
        # Avoids inline duplication so any source change is automatically reflected.
        $scriptDir = Split-Path $PSCommandPath -Parent
        $script:repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
        $script:listenerPath = Join-Path $script:repoRoot 'scripts\dashboard-scheduler\dashboard-listener.ps1'

        $lines = Get-Content $script:listenerPath
        $startIdx = -1
        $braceCount = 0
        $fnLines = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'function Get-WorkspacePathMaps') { $startIdx = $i }
            if ($startIdx -ge 0) {
                $fnLines += $lines[$i]
                $braceCount += ($lines[$i] -replace '[^{]', '').Length
                $braceCount -= ($lines[$i] -replace '[^}]', '').Length
                if ($braceCount -eq 0 -and $fnLines.Count -gt 1) { break }
            }
        }
        $script:fnBody = $fnLines -join "`r`n"

        # Write-Log spy for asserting on WARN calls
        $script:logMessages = [System.Collections.Generic.List[string]]::new()

        # Single-quoted templates — no PowerShell interpolation
        $script:logSpy = 'function Write-Log($level, $msg) { $script:logMessages.Add("[$level] $msg") }'
        $script:noOpSpy = 'function Write-Log($level, $msg) { }'

        # Temp dir for test fixtures
        $script:testDir = Join-Path $env:TEMP "dashboard-listener-tests-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        # Helper: invoke Get-WorkspacePathMaps with extracted function body + injected state
        function Invoke-GetWorkspacePathMaps {
            param(
                [string]$FilePath = '',
                [string]$EnvJson = ''
            )
            $script:logMessages.Clear()
            $envExpr = if ($EnvJson) { "'" + $EnvJson.Replace("'", "''") + "'" } else { '$null' }
            $fpExpr = "'" + $FilePath.Replace("'", "''") + "'"

            $nl = [char]10
            $code = $script:logSpy + $nl +
                    ('$WorkspacePathsFile = ' + $fpExpr) + $nl +
                    '$script:_wsPathFileMap = $null' + $nl +
                    '$script:_wsPathEnvMap = $null' + $nl +
                    ('$env:DASHBOARD_WATCHER_WORKSPACE_PATHS = ' + $envExpr) + $nl +
                    $script:fnBody + $nl +
                    'Get-WorkspacePathMaps'

            & ([ScriptBlock]::Create($code))
        }
    }

    AfterAll {
        if (Test-Path $script:testDir) {
            Remove-Item $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        Remove-Item Env:\DASHBOARD_WATCHER_WORKSPACE_PATHS -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Remove-Item Env:\DASHBOARD_WATCHER_WORKSPACE_PATHS -ErrorAction SilentlyContinue
    }

    Context "File map - valid JSON" {
        BeforeAll {
            $script:jsonFile = Join-Path $script:testDir "workspace-paths.json"
            $json = '{"roo-extensions": "C:/dev/roo-extensions", "nanoclaw": "D:/nanoclaw"}'
            [System.IO.File]::WriteAllText($script:jsonFile, $json, [System.Text.UTF8Encoding]::new($false))
        }

        It "Parses valid JSON file into file map" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:jsonFile
            $result.file["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
            $result.file["nanoclaw"] | Should -Be "D:/nanoclaw"
        }

        It "Returns empty env map when env var not set" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:jsonFile
            $result.env.Count | Should -Be 0
        }

        It "Does not log any warnings" {
            Invoke-GetWorkspacePathMaps -FilePath $script:jsonFile | Out-Null
            $script:logMessages.Count | Should -Be 0
        }
    }

    Context "File map - missing file" {
        It "Returns empty file map when file does not exist" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            $result = Invoke-GetWorkspacePathMaps -FilePath $missingFile
            $result.file.Count | Should -Be 0
        }

        It "Does not log any warnings" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            Invoke-GetWorkspacePathMaps -FilePath $missingFile | Out-Null
            $script:logMessages.Count | Should -Be 0
        }
    }

    Context "File map - malformed JSON" {
        BeforeAll {
            $script:badFile = Join-Path $script:testDir "bad.json"
            [System.IO.File]::WriteAllText($script:badFile, "{invalid json!!!", [System.Text.UTF8Encoding]::new($false))
        }

        It "Returns empty file map for malformed JSON" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:badFile
            $result.file.Count | Should -Be 0
        }

        It "Logs a WARN message about parse failure" {
            Invoke-GetWorkspacePathMaps -FilePath $script:badFile | Out-Null
            $script:logMessages.Count | Should -BeGreaterOrEqual 1
            $script:logMessages[0] | Should -Match "WARN.*Failed to parse"
        }
    }

    Context "Env var - valid JSON only" {
        It "Parses valid env var JSON into env map" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            $result = Invoke-GetWorkspacePathMaps -FilePath $missingFile -EnvJson '{"roo-extensions": "C:/dev/roo-extensions"}'
            $result.env["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
        }

        It "Returns empty file map when file missing" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            $result = Invoke-GetWorkspacePathMaps -FilePath $missingFile -EnvJson '{"roo-extensions": "C:/dev/roo-extensions"}'
            $result.file.Count | Should -Be 0
        }
    }

    Context "Env var - malformed JSON" {
        It "Returns empty env map for malformed JSON" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            $result = Invoke-GetWorkspacePathMaps -FilePath $missingFile -EnvJson '{{not valid}}'
            $result.env.Count | Should -Be 0
        }

        It "Logs a WARN about env var parse failure" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            Invoke-GetWorkspacePathMaps -FilePath $missingFile -EnvJson '{{not valid}}' | Out-Null
            $script:logMessages.Count | Should -BeGreaterOrEqual 1
            $script:logMessages[0] | Should -Match "WARN.*DASHBOARD_WATCHER_WORKSPACE_PATHS"
        }
    }

    Context "File + env var combined" {
        BeforeAll {
            $script:bothFile = Join-Path $script:testDir "both.json"
            $json = '{"roo-extensions": "C:/dev/roo-extensions"}'
            [System.IO.File]::WriteAllText($script:bothFile, $json, [System.Text.UTF8Encoding]::new($false))
        }

        It "Populates both file and env maps" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:bothFile -EnvJson '{"nanoclaw": "D:/nanoclaw"}'
            $result.file["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
            $result.env["nanoclaw"] | Should -Be "D:/nanoclaw"
        }

        It "File and env maps are independent" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:bothFile -EnvJson '{"nanoclaw": "D:/nanoclaw"}'
            $result.file.ContainsKey("nanoclaw") | Should -BeFalse
            $result.env.ContainsKey("roo-extensions") | Should -BeFalse
        }
    }

    Context "Partial failure - file valid + env malformed" {
        BeforeAll {
            $script:partialFile = Join-Path $script:testDir "partial.json"
            [System.IO.File]::WriteAllText($script:partialFile, '{"roo-extensions": "C:/dev/roo-extensions"}', [System.Text.UTF8Encoding]::new($false))
        }

        It "File map populated, env map empty when env is malformed" {
            $result = Invoke-GetWorkspacePathMaps -FilePath $script:partialFile -EnvJson '{{bad}}'
            $result.file["roo-extensions"] | Should -Be "C:/dev/roo-extensions"
            $result.env.Count | Should -Be 0
        }

        It "Logs only env-related WARN" {
            Invoke-GetWorkspacePathMaps -FilePath $script:partialFile -EnvJson '{{bad}}' | Out-Null
            $script:logMessages.Count | Should -BeGreaterOrEqual 1
            $script:logMessages[0] | Should -Match "WARN.*DASHBOARD_WATCHER_WORKSPACE_PATHS"
        }
    }

    Context "Empty env var" {
        It "Returns empty env map for empty string" {
            $missingFile = Join-Path $script:testDir "nonexistent.json"
            $result = Invoke-GetWorkspacePathMaps -FilePath $missingFile -EnvJson ''
            $result.env.Count | Should -Be 0
        }
    }

    Context "Caching behavior" {
        It "Returns same result on second call (cache hit)" {
            $cacheFile = Join-Path $script:testDir "cache-test.json"
            $json = '{"ws1": "C:/ws1"}'
            [System.IO.File]::WriteAllText($cacheFile, $json, [System.Text.UTF8Encoding]::new($false))

            $fpExpr = "'" + $cacheFile.Replace("'", "''") + "'"
            $nl = [char]10
            $code = $script:noOpSpy + $nl +
                    ('$WorkspacePathsFile = ' + $fpExpr) + $nl +
                    '$script:_wsPathFileMap = $null' + $nl +
                    '$script:_wsPathEnvMap = $null' + $nl +
                    $script:fnBody + $nl +
                    '$r1 = Get-WorkspacePathMaps' + $nl +
                    '$r2 = Get-WorkspacePathMaps' + $nl +
                    '@($r1, $r2)'

            $result = & ([ScriptBlock]::Create($code))
            $result[1].file["ws1"] | Should -Be $result[0].file["ws1"]
        }

        It "Cache survives file modification (stale read)" {
            $cacheFile = Join-Path $script:testDir "cache-stale.json"
            $json = '{"ws1": "C:/ws1"}'
            [System.IO.File]::WriteAllText($cacheFile, $json, [System.Text.UTF8Encoding]::new($false))

            $fpExpr = "'" + $cacheFile.Replace("'", "''") + "'"
            $nl = [char]10
            # Use single-quoted string for the WriteAllText call to avoid escape hell
            $writeUpdated = '[System.IO.File]::WriteAllText($WorkspacePathsFile, ''{"ws1": "C:/ws1-UPDATED"}'', [System.Text.UTF8Encoding]::new($false))'
            $code = $script:noOpSpy + $nl +
                    ('$WorkspacePathsFile = ' + $fpExpr) + $nl +
                    '$script:_wsPathFileMap = $null' + $nl +
                    '$script:_wsPathEnvMap = $null' + $nl +
                    $script:fnBody + $nl +
                    '$r1 = Get-WorkspacePathMaps' + $nl +
                    $writeUpdated + $nl +
                    '$r2 = Get-WorkspacePathMaps' + $nl +
                    '@($r1, $r2)'

            $result = & ([ScriptBlock]::Create($code))
            $result[1].file["ws1"] | Should -Be "C:/ws1"
        }

        It "Cache is cleared when script variables reset" {
            $cacheFile = Join-Path $script:testDir "cache-reset.json"
            $json = '{"ws1": "C:/ws1"}'
            [System.IO.File]::WriteAllText($cacheFile, $json, [System.Text.UTF8Encoding]::new($false))

            $fpExpr = "'" + $cacheFile.Replace("'", "''") + "'"
            $nl = [char]10

            # First call
            $code1 = $script:noOpSpy + $nl +
                     ('$WorkspacePathsFile = ' + $fpExpr) + $nl +
                     '$script:_wsPathFileMap = $null' + $nl +
                     '$script:_wsPathEnvMap = $null' + $nl +
                     $script:fnBody + $nl +
                     'Get-WorkspacePathMaps'

            $first = & ([ScriptBlock]::Create($code1))
            $first.file["ws1"] | Should -Be "C:/ws1"

            # Modify file
            $newJson = '{"ws1": "C:/ws1-NEW"}'
            [System.IO.File]::WriteAllText($cacheFile, $newJson, [System.Text.UTF8Encoding]::new($false))

            # Second call with fresh cache
            $code2 = $script:noOpSpy + $nl +
                     ('$WorkspacePathsFile = ' + $fpExpr) + $nl +
                     '$script:_wsPathFileMap = $null' + $nl +
                     '$script:_wsPathEnvMap = $null' + $nl +
                     $script:fnBody + $nl +
                     'Get-WorkspacePathMaps'

            $second = & ([ScriptBlock]::Create($code2))
            $second.file["ws1"] | Should -Be "C:/ws1-NEW"
        }
    }
}
