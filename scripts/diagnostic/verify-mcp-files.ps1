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
# STATUS: 4 of 5 paths reference RETIRED MCPs that no longer exist:
#   - jupyter-mcp-server (replaced by jupyter-papermill integration, retired)
#   - github-projects-mcp (retired per .claude/rules/tool-availability.md)
#   - jinavigator-server (not present in current fleet)
#   - quickfiles-server (retired per .claude/rules/tool-availability.md)
#
# Only path #3 (roo-state-manager) is still valid, and use of hardcoded
# "C:/dev/roo-extensions" path is incorrect for non-po-2023 machines.
#
# Original archived at:
#   scripts/_archive/cleanup-3323-2026-08-31/verify-mcp-files.ps1

Write-Host "[ARCHIVED] verify-mcp-files.ps1 — references 4 retired MCPs + 1 wrong hardcoded path." -ForegroundColor Yellow
Write-Host "[ARCHIVED] Do not run. Use scripts/mcp/cleanup-mcp-zombies.ps1 for live MCP health." -ForegroundColor Yellow
Write-Host "[ARCHIVED] See scripts/_archive/cleanup-3323-2026-08-31/README.md (#3323)." -ForegroundColor Yellow
exit 0