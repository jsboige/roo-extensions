# mcp-process-census.ps1 — per-server MCP process census (#4149 F1 instrument)
#
# The BEFORE/AFTER proof organ for the launcher flattening, using the method of
# the coordinator's 28/10 census (Win32_Process + working set, grouped per MCP
# server). Run BEFORE the deploy, then AFTER the next session restart, and
# compare the per-session columns.
#
# What it counts, per server tag:
#   - processes: every cmd/node/python whose command line matches the tag
#     (the npx chain is cmd -> npx-node -> cmd .bin-shim -> server-node — the
#     flattening is what collapses it)
#   - ws_mb_total / ws_mb_avg: working set summed / averaged over those processes
#   - per_session_procs: processes divided by the number of live claude.exe
#     hosts (the multiplier the issue is about)
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File mcp-process-census.ps1 [-JsonPath <file>]
# Read-only. No elevation. Windows only (Win32_Process).
#
# First-match-wins classification — rule ORDER matters:
#   rsm-wrapper before rsm-server (a wrapper command line also contains the
#   roo-state-manager path of the child it spawned).

param(
    [string]$JsonPath = ""   # optional: also write the census as JSON
)

$ErrorActionPreference = "Stop"

$Rules = @(
    @{ Tag = 'rsm-wrapper'; Pattern = 'mcp-wrapper\.cjs' },
    @{ Tag = 'rsm-server';  Pattern = 'roo-state-manager[\\/]build' },
    @{ Tag = 'playwright';  Pattern = 'playwright[\\/]mcp|playwright-mcp|@playwright' },
    @{ Tag = 'searxng';     Pattern = 'mcp-searxng' },
    @{ Tag = 'sk-agent';    Pattern = 'sk_agent' },
    @{ Tag = 'papermill';   Pattern = 'papermill' }
)

$Candidates = Get-CimInstance Win32_Process -Filter "Name='node.exe' OR Name='cmd.exe' OR Name='python.exe'"
$Rows = @()
foreach ($P in $Candidates) {
    if (-not $P.CommandLine) { continue }
    foreach ($R in $Rules) {
        if ($P.CommandLine -match $R.Pattern) {
            $Proc = Get-Process -Id $P.ProcessId -ErrorAction SilentlyContinue
            $Rows += [pscustomobject]@{
                Tag   = $R.Tag
                PID   = $P.ProcessId
                Name  = $P.Name
                WS_MB = if ($Proc) { [math]::Round($Proc.WorkingSet64 / 1MB, 1) } else { 0 }
            }
            break
        }
    }
}

$Sessions = @(Get-Process claude -ErrorAction SilentlyContinue).Count

$Servers = $Rows | Group-Object Tag | ForEach-Object {
    [pscustomobject]@{
        server             = $_.Name
        processes          = $_.Count
        ws_mb_total        = [math]::Round(($_.Group | Measure-Object WS_MB -Sum).Sum, 1)
        ws_mb_avg          = [math]::Round(($_.Group | Measure-Object WS_MB -Average).Average, 1)
        per_session_procs  = if ($Sessions -gt 0) { [math]::Round($_.Count / $Sessions, 2) } else { $null }
    }
} | Sort-Object server

$Totals = [pscustomobject]@{
    machine    = $env:COMPUTERNAME
    timestamp  = [DateTimeOffset]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    sessions   = $Sessions
    servers    = $Servers
    total_procs = ($Servers | Measure-Object processes -Sum).Sum
    total_ws_mb = [math]::Round((($Servers | Measure-Object ws_mb_total -Sum).Sum), 1)
}

Write-Host "MCP process census — $($Totals.machine) $($Totals.timestamp)" -ForegroundColor Cyan
Write-Host "claude.exe hosts (sessions): $Sessions`n" -ForegroundColor Cyan
$Table = $Servers | Format-Table -AutoSize | Out-String -Width 120
Write-Host $Table
Write-Host ("TOTAL: {0} processes, {1} MB working set" -f $Totals.total_procs, $Totals.total_ws_mb) -ForegroundColor Cyan

if ($JsonPath) {
    $Totals | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
    Write-Host "[JSON] Written to $JsonPath" -ForegroundColor Green
}
