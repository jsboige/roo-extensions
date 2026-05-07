# Pester 3.4.0 tests for Get-WorkspacePathMaps (#2048 Subtask C)
# Run: Invoke-Pester -Script .\tests\Pester\dashboard-listener.Get-WorkspacePathMaps.tests.ps1

function Invoke-GetWorkspacePathMapsTest {
    param(
        [string]$FnBody,
        [string]$FilePath = '',
        [string]$EnvJson = ''
    )
    $envExpr = if ($EnvJson) { "'" + $EnvJson.Replace("'", "''") + "'" } else { '$null' }
    $fpExpr = "'" + $FilePath.Replace("'", "''") + "'"

    $code = "function Write-Log([string]`$level, [string]`$msg) { }`n" +
            "`$WorkspacePathsFile = $fpExpr`n" +
            "`$script:_wsPathFileMap = `$null`n" +
            "`$script:_wsPathEnvMap = `$null`n" +
            "`$env:DASHBOARD_WATCHER_WORKSPACE_PATHS = $envExpr`n" +
            "$FnBody`n" +
            "Get-WorkspacePathMaps"

    & ([ScriptBlock]::Create($code))
}

Describe 'Get-WorkspacePathMaps' {

    BeforeAll {
        $scriptDir = Split-Path $PSCommandPath -Parent
        $script:repoRoot = Split-Path (Split-Path $scriptDir -Parent) -Parent
        $script:listenerPath = Join-Path $script:repoRoot 'scripts\dashboard-scheduler\dashboard-listener.ps1'

        # Extract function using brace counting (regex fails on nested braces)
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

        $script:testTemp = Join-Path $env:TEMP "pester-wsmaps-$(Get-Random)"
        New-Item -ItemType Directory -Path $script:testTemp -Force | Out-Null
    }

    AfterAll {
        if (Test-Path $script:testTemp) {
            Remove-Item $script:testTemp -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'File map: valid JSON file' {
        BeforeAll {
            $script:jsonFile = Join-Path $script:testTemp 'valid-paths.json'
            [System.IO.File]::WriteAllText($script:jsonFile, '{"roo-extensions": "D:/roo-extensions", "CoursIA": "D:/CoursIA"}', [System.Text.UTF8Encoding]::new($false))
        }

        It 'Returns file map with correct entries' {
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $script:jsonFile
            $result.file['roo-extensions'] | Should Be 'D:/roo-extensions'
            $result.file['CoursIA'] | Should Be 'D:/CoursIA'
        }

        It 'Returns empty env map when env var not set' {
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $script:jsonFile
            $result.env.Count | Should Be 0
        }
    }

    Context 'File map: missing file' {
        It 'Returns empty file map without error' {
            $missingFile = Join-Path $script:testTemp 'nonexistent.json'
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $missingFile
            $result.file.Count | Should Be 0
        }
    }

    Context 'File map: malformed JSON' {
        BeforeAll {
            $script:badFile = Join-Path $script:testTemp 'bad-paths.json'
            [System.IO.File]::WriteAllText($script:badFile, '{not valid json!!!', [System.Text.UTF8Encoding]::new($false))
        }

        It 'Returns empty file map (catches parse error)' {
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $script:badFile
            $result.file.Count | Should Be 0
        }
    }

    Context 'File map: empty JSON object' {
        BeforeAll {
            $script:emptyFile = Join-Path $script:testTemp 'empty-paths.json'
            [System.IO.File]::WriteAllText($script:emptyFile, '{}', [System.Text.UTF8Encoding]::new($false))
        }

        It 'Returns file map with zero entries' {
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $script:emptyFile
            $result.file.Count | Should Be 0
        }
    }

    Context 'Env var: valid JSON' {
        It 'Returns env map with correct entries' {
            $missingFile = Join-Path $script:testTemp 'nonexistent.json'
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $missingFile -EnvJson '{"test-ws": "C:/test-workspace"}'
            $result.env['test-ws'] | Should Be 'C:/test-workspace'
        }
    }

    Context 'Env var: invalid JSON' {
        It 'Returns empty env map (catches parse error)' {
            $missingFile = Join-Path $script:testTemp 'nonexistent.json'
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $missingFile -EnvJson 'not-valid-json'
            $result.env.Count | Should Be 0
        }
    }

    Context 'Both file and env var populated' {
        BeforeAll {
            $script:dualFile = Join-Path $script:testTemp 'dual-paths.json'
            [System.IO.File]::WriteAllText($script:dualFile, '{"ws-file": "D:/file-path"}', [System.Text.UTF8Encoding]::new($false))
        }

        It 'Returns both maps with their respective entries' {
            $result = Invoke-GetWorkspacePathMapsTest -FnBody $script:fnBody -FilePath $script:dualFile -EnvJson '{"ws-env": "D:/env-path"}'
            $result.file['ws-file'] | Should Be 'D:/file-path'
            $result.env['ws-env'] | Should Be 'D:/env-path'
        }
    }

    Context 'Cache behavior' {
        It 'Returns cached result on second call without re-reading file' {
            $cacheFile = Join-Path $script:testTemp 'cache-test.json'
            [System.IO.File]::WriteAllText($cacheFile, '{"cached-ws": "D:/cached"}', [System.Text.UTF8Encoding]::new($false))

            $fpExpr = "'" + $cacheFile.Replace("'", "''") + "'"
            $code = "function Write-Log([string]`$level, [string]`$msg) { }`n" +
                    "`$WorkspacePathsFile = $fpExpr`n" +
                    "`$script:_wsPathFileMap = `$null`n" +
                    "`$script:_wsPathEnvMap = `$null`n" +
                    "$($script:fnBody)`n" +
                    "`$r1 = Get-WorkspacePathMaps`n" +
                    "Remove-Item $fpExpr -Force -ErrorAction SilentlyContinue`n" +
                    "`$r2 = Get-WorkspacePathMaps`n" +
                    "@(`$r1, `$r2)"

            $result = & ([ScriptBlock]::Create($code))

            $result[0].file['cached-ws'] | Should Be 'D:/cached'
            $result[1].file['cached-ws'] | Should Be 'D:/cached'
        }
    }
}
