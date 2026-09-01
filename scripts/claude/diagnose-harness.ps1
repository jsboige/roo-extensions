#!/usr/bin/env pwsh
# Thin wrapper — delegates to analyze-harness-tokens.ps1
#
# CONSOLIDATION (#3323, 2026-08-31):
# - This script previously duplicated the token-footprint analysis of
#   scripts/claude/analyze-harness-tokens.ps1 (both targeting Issue #1026).
# - analyze-harness-tokens.ps1 is the canonical version (more comprehensive:
#   handles code blocks, MCP schema files, optimization suggestions).
# - This file is preserved as a thin wrapper for backwards compatibility
#   (Issue #1026 references both scripts). Original archived to
#   scripts/_archive/harness-tokens-{date}/.

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$target = Join-Path $scriptDir "analyze-harness-tokens.ps1"

if (-not (Test-Path $target)) {
    Write-Host "[ERROR] analyze-harness-tokens.ps1 not found at: $target" -ForegroundColor Red
    exit 1
}

Write-Host "[diagnose-harness.ps1] Thin wrapper → analyze-harness-tokens.ps1 (consolidation #3323)" -ForegroundColor DarkGray
Write-Host ""
& $target @args
exit $LASTEXITCODE