#!/usr/bin/env pwsh
# Thin wrapper — delegates to scripts/mcp/cleanup-mcp-zombies.ps1 -Mode ParentChain
#
# CONSOLIDATION (#3323, 2026-08-31):
# - This script previously implemented the WMI parent-chain orphan cleanup (#1281).
# - Logic absorbed into scripts/mcp/cleanup-mcp-zombies.ps1 as `-Mode ParentChain`.
# - This file is preserved as a thin wrapper for backwards compatibility
#   (Issue #1281 references this filename).
# - Original archived to scripts/_archive/cleanup-3323-2026-08-31/cleanup-mcp-orphans.ps1.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Get-Item "$scriptDir\..\..").FullName
$target = Join-Path $repoRoot "scripts\mcp\cleanup-mcp-zombies.ps1"

if (-not (Test-Path $target)) {
    Write-Host "[ERROR] cleanup-mcp-zombies.ps1 not found at: $target" -ForegroundColor Red
    exit 1
}

# Forward args + add -Mode ParentChain (only if not specified)
$forwardArgs = @('-Mode', 'ParentChain') + $args
& $target @forwardArgs
exit $LASTEXITCODE