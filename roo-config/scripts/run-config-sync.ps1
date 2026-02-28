# Run Config-Sync Pipeline
# This script runs the config-sync pipeline to push configuration changes to machines
#
# Usage:
#   .\run-config-sync.ps1 -Version "2.7.1" -Description "Fix jupyter-mcp enablement on web1"
#   .\run-config-sync.ps1 -Version "2.7.1" -Description "Fix" -DryRun

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Description,

    [string[]]$Targets = @("mcp"),

    [switch]$DryRun,

    [string]$MachineId = $env:ROOSYNC_MACHINE_ID
)

$ErrorActionPreference = "Stop"

# Determine paths
$rooExtensionsPath = "D:\Dev\roo-extensions"
$mcpServerPath = Join-Path $rooExtensionsPath "mcps\internal\servers\roo-state-manager"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Config-Sync Pipeline" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Version: $Version"
Write-Host "Description: $Description"
Write-Host "Targets: $($Targets -join ', ')"
Write-Host "MachineId: $MachineId"
Write-Host "DryRun: $DryRun"
Write-Host ""

# Step 1: Collect configuration
Write-Host "[Step 1/3] Collecting configuration..." -ForegroundColor Yellow

$collectArgs = @{
    action = "collect"
    targets = $Targets
    dryRun = $DryRun
}

if ($MachineId) {
    $collectArgs.machineId = $MachineId
}

Write-Host "  Collecting: $($Targets -join ', ')"
# Note: This requires MCP tool invocation which can only be done through VS Code Roo Code extension
# The actual invocation would be:
# roosync_config(action: "collect", targets: ["mcp"])

Write-Host "  [!] MCP tools require VS Code with Roo Code extension" -ForegroundColor Red
Write-Host "  [!] Run this pipeline through Roo Code in VS Code" -ForegroundColor Red

# Step 2: Publish configuration
Write-Host ""
Write-Host "[Step 2/3] Publishing configuration..." -ForegroundColor Yellow

$publishArgs = @{
    action = "publish"
    version = $Version
    description = $Description
    targets = $Targets
    dryRun = $DryRun
}

if ($MachineId) {
    $publishArgs.machineId = $MachineId
}

Write-Host "  Version: $Version"
Write-Host "  Description: $Description"
# Note: This requires MCP tool invocation
# roosync_config(action: "publish", version: "2.7.1", description: "...", targets: ["mcp"])

Write-Host "  [!] MCP tools require VS Code with Roo Code extension" -ForegroundColor Red

# Step 3: Compare configuration
Write-Host ""
Write-Host "[Step 3/3] Comparing configuration..." -ForegroundColor Yellow

Write-Host "  Comparing MCP settings across machines"
# Note: This requires MCP tool invocation
# roosync_compare_config(granularity: "mcp")

Write-Host "  [!] MCP tools require VS Code with Roo Code extension" -ForegroundColor Red

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "To run this pipeline:" -ForegroundColor Cyan
Write-Host "1. Open VS Code with Roo Code extension" -ForegroundColor White
Write-Host "2. Start a Roo Code session" -ForegroundColor White
Write-Host "3. Ask Roo to run:" -ForegroundColor White
Write-Host "   - roosync_config(action: 'collect', targets: ['mcp'])" -ForegroundColor Gray
Write-Host "   - roosync_config(action: 'publish', version: '$Version', description: '$Description')" -ForegroundColor Gray
Write-Host "   - roosync_compare_config(granularity: 'mcp')" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
