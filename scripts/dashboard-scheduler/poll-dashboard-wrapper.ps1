$ErrorActionPreference = 'Continue'
$logDir = 'D:\roo-extensions\outputs\scheduling\logs'
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $logDir "dashboard-watcher-$ts.log"
"=== Dashboard-Watcher started: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append
& 'D:\roo-extensions\scripts\dashboard-scheduler\poll-dashboard.ps1' `
    -AllowedTags 'ASK,TASK,BLOCKED' `
    -Workspaces 'nanoclaw,roo-extensions' `
    -Stub:$false 2>&1 | Tee-Object -FilePath $logFile -Append
$exitCode = $LASTEXITCODE
"=== Dashboard-Watcher exit code ${exitCode}: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append
exit $exitCode