#!/usr/bin/env pwsh
# ARCHIVED — cluster 3 build-MCP consolidation #3323 (2026-09-17)
#
# This script ran `npm run build` over a hardcoded server list:
#   jupyter-mcp-server, jinavigator-server, roo-state-manager
#
# STATUS (verified firsthand, decision user 2026-09-13 relayed by ai-01):
#   - ZERO-CALLER: no skill/rule/workflow/live doc invokes it. Only mentions
#     are docs/roosync/archive/ (archived doc) and inventory fixtures (data).
#   - STALE SUBSET: listed 3 of the 6 canonical servers in
#     mcps/internal/servers/, missing jupyter-papermill-mcp-server,
#     open-terminal-mcp and sk-agent — so "compile ALL MCPs" compiled half
#     the fleet. (github-projects-mcp/quickfiles-server were already removed
#     from the submodule canon by #1093 and are NOT part of that count.)
#   - NOT archived on the "retired MCPs" motive: that motive was measured
#     false (po-2024, 2026-09-16) — jinavigator-server and jupyter-mcp-server
#     still exist in the canon.
#
# The build path is covered by scripts/claude/ensure-build-fresh.ps1
# (freshness guard) and scripts/mcp/validate-before-push.ps1 (full build +
# test gate before push).
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/compile-all-mcps.ps1

Write-Host "[ARCHIVED] compile-all-mcps.ps1 — zero-caller + stale 3/6 server subset (#3323 cluster 3)." -ForegroundColor Yellow
Write-Host "[ARCHIVED] Do not run. Use ensure-build-fresh.ps1 / validate-before-push.ps1 for builds." -ForegroundColor Yellow
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md (#3323)." -ForegroundColor Yellow
exit 0
