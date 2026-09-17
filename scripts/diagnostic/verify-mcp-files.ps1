#!/usr/bin/env pwsh
# ARCHIVED — one-shot verifier #3323 (2026-08-31)
#
# This script checked 5 hardcoded MCP file paths:
#   1. C:/dev/roo-extensions/mcps/internal/servers/jupyter-mcp-server/dist/index.js
#   2. C:/dev/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js
#   3. C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager/build/index.js
#   4. C:/dev/roo-extensions/mcps/internal/servers/jinavigator-server/dist/index.js
#   5. C:/dev/roo-extensions/mcps/internal/servers/quickfiles-server/build/index.js
#
# STATUS (corrected 2026-09-17 — the original "4 retired MCPs" claim was
# measured FALSE for two of them, see po-2024 comment on #3323):
#   - github-projects-mcp, quickfiles-server: runtime-retired, removed from
#     the submodule canon by #1093 (.claude/rules/tool-availability.md).
#   - jupyter-mcp-server, jinavigator-server: STILL PRESENT in
#     mcps/internal/servers/ — the earlier "retired" labels were wrong.
#   - roo-state-manager: still valid.
# All 5 paths hardcode "C:/dev/roo-extensions", incorrect for other hosts.
# The archive motive stands on the hardcoded paths + runtime-retired pair.
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/verify-mcp-files.ps1

Write-Host "[ARCHIVED] verify-mcp-files.ps1 — hardcoded host-specific paths + 2 runtime-retired MCPs (#3323)." -ForegroundColor Yellow
Write-Host "[ARCHIVED] Do not run. Use scripts/mcp/cleanup-mcp-zombies.ps1 for live MCP health." -ForegroundColor Yellow
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md (#3323)." -ForegroundColor Yellow
exit 0