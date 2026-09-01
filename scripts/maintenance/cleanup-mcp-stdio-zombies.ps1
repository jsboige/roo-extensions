#!/usr/bin/env pwsh
# Thin wrapper — delegates to scripts/mcp/cleanup-mcp-zombies.ps1 -Mode Stdio
#
# CONSOLIDATION (#3323, 2026-08-31):
# - This script previously implemented stdio npx wrapper cleanup (#2675).
# - Logic absorbed into scripts/mcp/cleanup-mcp-zombies.ps1 as `-Mode Stdio`.
# - This file is preserved as a thin wrapper for backwards compatibility
#   (Issue #2675 + install-mcp-zombie-cleanup-schtask.ps1 reference this filename).
# - Original archived to scripts/_archive/cleanup-3323-2026-08-31/cleanup-mcp-stdio-zombies.ps1.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Get-Item "$scriptDir\..\..").FullName
$target = Join-Path $repoRoot "scripts\mcp\cleanup-mcp-zombies.ps1"

if (-not (Test-Path $target)) {
    Write-Host "[ERROR] cleanup-mcp-zombies.ps1 not found at: $target" -ForegroundColor Red
    exit 1
}

# Forward args + add -Mode Stdio
$forwardArgs = @('-Mode', 'Stdio') + $args
& $target @forwardArgs
exit $LASTEXITCODE