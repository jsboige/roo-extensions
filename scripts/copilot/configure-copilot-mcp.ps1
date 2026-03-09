<#
.SYNOPSIS
    Configure GitHub Copilot MCP config to include roo-state-manager.

.DESCRIPTION
    Creates or updates ~/.copilot/mcp-config.json with an entry for
    roo-state-manager using the local wrapper in this repository.

    This script is idempotent and preserves existing server entries.

.PARAMETER RepoRoot
    Absolute path to roo-extensions root.

.PARAMETER SharedPath
    Optional RooSync shared path. If provided, injected as ROOSYNC_SHARED_PATH.

.PARAMETER DryRun
    Show resulting JSON without writing.

.EXAMPLE
    .\scripts\copilot\configure-copilot-mcp.ps1 -RepoRoot "D:\dev\roo-extensions"
#>

[CmdletBinding()]
param(
    [string]$RepoRoot = "D:\dev\roo-extensions",
    [string]$SharedPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$copilotDir = Join-Path $HOME ".copilot"
$configPath = Join-Path $copilotDir "mcp-config.json"
$wrapperPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs"

if (-not (Test-Path $wrapperPath)) {
    throw "roo-state-manager wrapper not found: $wrapperPath"
}

if (-not (Test-Path $copilotDir)) {
    New-Item -ItemType Directory -Path $copilotDir | Out-Null
}

$config = @{}
if (Test-Path $configPath) {
    $raw = Get-Content -Path $configPath -Raw
    if ($raw.Trim().Length -gt 0) {
        $config = $raw | ConvertFrom-Json -AsHashtable
    }
}

if (-not $config.ContainsKey("servers")) {
    $config["servers"] = @{}
}

$server = @{
    command = "node"
    args = @($wrapperPath)
}

if ($SharedPath -and $SharedPath.Trim().Length -gt 0) {
    $server["env"] = @{ ROOSYNC_SHARED_PATH = $SharedPath }
}

$config["servers"]["roo-state-manager"] = $server

$json = $config | ConvertTo-Json -Depth 10

if ($DryRun) {
    Write-Host "[DRY-RUN] Would write: $configPath" -ForegroundColor Yellow
    Write-Host $json
    return
}

[System.IO.File]::WriteAllText($configPath, $json, [System.Text.UTF8Encoding]::new($false))
Write-Host "[OK] Copilot MCP config updated: $configPath" -ForegroundColor Green
Write-Host "[OK] Added server: roo-state-manager -> $wrapperPath" -ForegroundColor Green
