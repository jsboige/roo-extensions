<#
.SYNOPSIS
    Scheduled launcher for detect-approval-stalls.py with its dashboard signal (#4243 item 3).

.DESCRIPTION
    The detector takes its bearer from MCP_PROXY_BEARER. A scheduled task must not carry
    the token in its arguments (readable in the task definition), so this launcher reads
    MCP_PROXY_BEARER and MCP_PROXY_BASE_URL from the bot .env at run time -- same source
    and same parser as mcp-chain-watchdog.ps1 -- sets them in its own process environment
    only, and runs the detector. The token is never printed or logged.

    The window defaults suit a periodic tick, not an incident scan: with -ActiveHours 6 a
    frozen tail ages out after about three 2-hour ticks, so a closed window is not
    re-announced for a week (the detector default, 168 h, would post one WARN note per
    tick for it). A DEAD session no longer needs the window at all: since the #4243
    detector facet it is classified once and never re-announced (state file under
    ~/.roo-state-manager/detect-approval-stalls). For forensics, run the detector
    directly.

    One line per run is appended to <repo>\outputs\stall-detector\stall-detector.log,
    followed by the detector output (its command excerpts are already redacted).
    The exit code is the detector's: 0 clean, 1 error, 2 waiting stalls.

.PARAMETER DryRun
    Run the detector without --dashboard; the log line says whether a bearer was found.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File scripts\diagnostic\run-approval-stall-detector.ps1 -DryRun
#>
param(
    [string]$BotEnvFile = 'D:\nanoclaw\.env',
    [double]$ActiveHours = 6,
    [double]$MinMinutes = 15,
    [ValidateSet('workspace', 'machine', 'global')]
    [string]$DashboardType = 'workspace',
    [string]$DashboardWorkspace = 'roo-extensions',
    [double]$DashboardTimeout = 60,
    [string]$LogDir = '',
    [string]$Python = 'python',
    [switch]$DryRun
)

# Continue, not Stop: under Windows PowerShell 5.1 a native command's stderr becomes
# ErrorRecords, and Stop would turn the detector's own warnings into a crash.
$ErrorActionPreference = 'Continue'

$detector = Join-Path $PSScriptRoot 'detect-approval-stalls.py'
if (-not $LogDir) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $LogDir = Join-Path $repoRoot 'outputs\stall-detector'
}

function Read-EnvValue {
    param([string]$Path, [string]$Key)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$") {
            return $matches[1].Trim('"').Trim("'")
        }
    }
    return $null
}

$bearer = Read-EnvValue -Path $BotEnvFile -Key 'MCP_PROXY_BEARER'
$baseUrl = Read-EnvValue -Path $BotEnvFile -Key 'MCP_PROXY_BASE_URL'

$argList = @($detector, '--active-hours', "$ActiveHours", '--min-minutes', "$MinMinutes")
if ($DryRun) {
    $signal = 'dry-run (bearer found: no)'
    if ($bearer) { $signal = 'dry-run (bearer found: yes)' }
} elseif ($bearer) {
    $env:MCP_PROXY_BEARER = $bearer
    if ($baseUrl) { $env:MCP_PROXY_BASE_URL = $baseUrl }
    $argList += @('--dashboard', '--dashboard-type', $DashboardType, '--dashboard-workspace', $DashboardWorkspace,
                  '--dashboard-timeout', "$DashboardTimeout")
    $signal = "on ($DashboardType)"
} else {
    $signal = "off (no MCP_PROXY_BEARER in $BotEnvFile)"
}

# Command excerpts may hold non-ASCII text: force UTF-8 on both sides of the pipe.
$env:PYTHONIOENCODING = 'utf-8'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$rc = 1
$output = @()
try {
    $output = @(& $Python @argList 2>&1 | ForEach-Object { "$_" })
    $rc = $LASTEXITCODE
} catch {
    $output = @("launcher error: $($_.Exception.Message)")
}

$stamp = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$lines = @("$stamp rc=$rc signal=$signal") + @($output | ForEach-Object { "    $_" })
try {
    if (-not (Test-Path -LiteralPath $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    $logFile = Join-Path $LogDir 'stall-detector.log'
    [System.IO.File]::AppendAllText($logFile, (($lines -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
} catch {
    Write-Output "log write failed: $($_.Exception.Message)"
}
$lines | ForEach-Object { Write-Output $_ }
exit $rc
