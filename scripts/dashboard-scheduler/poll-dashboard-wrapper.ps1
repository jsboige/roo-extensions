<#
.SYNOPSIS
    Wrapper for poll-dashboard.ps1 with file logging (Task Scheduler swallows stdout).

.DESCRIPTION
    When launched via Windows Task Scheduler with -WindowStyle Hidden, stdout is lost.
    This wrapper redirects all output to timestamped log files.

    Paths and workspaces are auto-detected from $PSScriptRoot and environment variables.
    Override via parameters or env vars:
      - DASHBOARD_WATCHER_WORKSPACES: comma-separated workspace list
      - DASHBOARD_WATCHER_TAGS: comma-separated allowed tags (default: ASK,TASK,BLOCKED)
      - DASHBOARD_WATCHER_LOG_DIR: override log directory

.PARAMETER Workspaces
    Comma-separated workspace list. Default: $env:DASHBOARD_WATCHER_WORKSPACES.

.PARAMETER AllowedTags
    Comma-separated allowed tags. Default: ASK,TASK,BLOCKED.

.PARAMETER LogDir
    Override log directory. Default: <repo-root>/outputs/scheduling/logs.

.EXAMPLE
    .\poll-dashboard-wrapper.ps1
    .\poll-dashboard-wrapper.ps1 -Workspaces 'roo-extensions' -AllowedTags 'ASK,TASK,BLOCKED'
#>

param(
    [string]$Workspaces = $env:DASHBOARD_WATCHER_WORKSPACES,
    [string]$AllowedTags = $(if ($env:DASHBOARD_WATCHER_TAGS) { $env:DASHBOARD_WATCHER_TAGS } else { 'ASK,TASK,BLOCKED' }),
    [string]$LogDir = $env:DASHBOARD_WATCHER_LOG_DIR
)

$ErrorActionPreference = 'Continue'

# Resolve paths relative to script location
$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
$RepoRoot = (Split-Path (Split-Path $scriptDir -Parent) -Parent)

if ([string]::IsNullOrEmpty($LogDir)) {
    $LogDir = Join-Path $RepoRoot 'outputs\scheduling\logs'
}
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFile = Join-Path $LogDir "dashboard-watcher-$ts.log"

$pollScript = Join-Path $scriptDir 'poll-dashboard.ps1'

"=== Dashboard-Watcher started: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append
"=== Workspaces: $Workspaces | Tags: $AllowedTags ===" | Tee-Object -FilePath $logFile -Append

$pollArgs = @{
    AllowedTags = $AllowedTags
    Stub        = $false
}
if (-not [string]::IsNullOrEmpty($Workspaces)) {
    $pollArgs['Workspaces'] = $Workspaces
}

& $pollScript @pollArgs 2>&1 | Tee-Object -FilePath $logFile -Append
$exitCode = $LASTEXITCODE

"=== Dashboard-Watcher exit code ${exitCode}: $(Get-Date -Format o) ===" | Tee-Object -FilePath $logFile -Append
exit $exitCode
