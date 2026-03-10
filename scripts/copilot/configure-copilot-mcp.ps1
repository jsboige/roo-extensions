<#
.SYNOPSIS
    Configure GitHub Copilot MCP config to include roo-state-manager.

.DESCRIPTION
    Creates or updates %APPDATA%\Code\User\mcp.json with an entry for
    roo-state-manager using the local wrapper in this repository.

    This script is idempotent and preserves existing server entries.
    Uses the official VS Code MCP configuration location.

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

$userMcpConfigPath = Join-Path $env:APPDATA "Code\User\mcp.json"
$wrapperPath = Join-Path $RepoRoot "mcps\internal\servers\roo-state-manager\mcp-wrapper.cjs"

if (-not (Test-Path $wrapperPath)) {
    throw "roo-state-manager wrapper not found: $wrapperPath"
}

# Read existing config or initialize empty
$config = @{}
if (Test-Path $userMcpConfigPath) {
    $raw = Get-Content -Path $userMcpConfigPath -Raw
    if ($raw.Trim().Length -gt 0) {
        $config = $raw | ConvertFrom-Json -AsHashtable
    }
}

# Ensure servers object exists
if (-not $config.ContainsKey("servers")) {
    $config["servers"] = @{}
}

# Create/update server definition  
$server = @{
    type = "stdio"
    command = "node"
    args = @($wrapperPath)
}

if ($SharedPath -and $SharedPath.Trim().Length -gt 0) {
    $server["env"] = @{ ROOSYNC_SHARED_PATH = $SharedPath }
}

# Upsert roo-state-manager into servers map (preserves others)
$config["servers"]["roo-state-manager"] = $server

# Convert to JSON and display/write
$json = $config | ConvertTo-Json -Depth 20

if ($DryRun) {
    Write-Host "[DRY-RUN] Would write: $userMcpConfigPath" -ForegroundColor Yellow
    Write-Host $json
    return
}

# Write with UTF-8 no-BOM encoding (critical for VS Code)
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($userMcpConfigPath, $json, $utf8NoBom)

Write-Host "[OK] VS Code MCP config updated: $userMcpConfigPath" -ForegroundColor Green
Write-Host "[OK] Upserted server: roo-state-manager -> $wrapperPath" -ForegroundColor Green
