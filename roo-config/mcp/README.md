# MCP Configuration Management

This directory contains centralized configuration for MCP server management across all 6 machines in the RooSync ecosystem.

## Files

### `reference-alwaysallow.json`

**Purpose:** Source of truth for MCP tool auto-approval configuration

**Description:**
Lists all MCP tools that should be auto-approved by Roo Code without requiring manual prompts. This file is the reference used by deployment scripts to keep all machines synchronized.

**Structure:**
```json
{
  "mcpServers": {
    "SERVER_NAME": {
      "alwaysAllow": ["tool1", "tool2", "..."]
    }
  }
}
```

**Maintenance:**
- Updated whenever new MCPs are added or tools change
- Deployed via `Sync-AlwaysAllow.ps1` script
- Validated automatically by deployment checks

**Current Tools (8 MCPs, 104 total tools):**

| MCP Server | Tools | Status |
|------------|-------|--------|
| jinavigator | 4 | Active |
| searxng | 2 | Active |
| win-cli | 9 | **CRITICAL** |
| markitdown | 1 | Active |
| playwright | 15 | Active |
| roo-state-manager | 36 | Active |
| jupyter | 22 | DISABLED on execution machines |
| desktop-commander | 26 | Deprecated (for backward compat) |

## Scripts

### `Sync-AlwaysAllow.ps1`

**Location:** `../scripts/Sync-AlwaysAllow.ps1`

**Purpose:** Synchronize alwaysAllow configuration from reference file to local Roo settings

**Usage:**
```powershell
# Preview changes
.\roo-config\scripts\Sync-AlwaysAllow.ps1 -DryRun

# Apply changes
.\roo-config\scripts\Sync-AlwaysAllow.ps1 -Force

# Merge mode (add missing without removing extras)
.\roo-config\scripts\Sync-AlwaysAllow.ps1
```

**Options:**
- `-DryRun` - Show what would change without modifying files
- `-Force` - Overwrite all alwaysAllow entries to match reference exactly
- `-Backup` - Create backup before modifying (default: true)
- `-ReferenceFile` - Specify custom reference file path (default: reference-alwaysallow.json)

## Deployment

See `docs/deployment/DEPLOY-ALWAYSALLOW.md` for complete deployment guide.

**Quick Deploy (all machines):**

1. On each machine, run:
   ```powershell
   cd D:\dev\roo-extensions
   .\roo-config\scripts\Sync-AlwaysAllow.ps1 -Force
   ```

2. Restart VS Code to reload Roo with updated settings

3. Verify next scheduler cycle completes without approval prompts

## Machine-Specific Configuration

### Critical Machines

**myia-web1 (2GB RAM):**
- Uses local GDrive path: `C:\Drive\.shortcut-targets-by-id\...\.shared-state`
- Win-cli MUST use fork 0.2.0 (not npm 0.2.1)
- Jupyter MUST be disabled (RAM constraint)

**All machines:**
- Win-cli must point to: `mcps/external/win-cli/server/dist/index.js` (fork 0.2.0)
- Never use: `npx @anthropic/win-cli` (broken in npm 0.2.1)

## Troubleshooting

### Tools Not Being Auto-Approved

1. **Check if sync was applied:**
   ```powershell
   $settings = Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" | ConvertFrom-Json
   $settings.mcpServers."win-cli".alwaysAllow.Count
   ```

2. **Restart VS Code:**
   - Close all instances: `Get-Process code | Stop-Process -Force`
   - Reopen VS Code

3. **Check reference file:**
   ```powershell
   (Get-Content .\roo-config\mcp\reference-alwaysallow.json | ConvertFrom-Json).mcpServers | Get-Member
   ```

### Script Errors

- **"Reference file not found"** → Run from repository root
- **"Permission denied"** → Close VS Code, run as Administrator
- **"Invalid JSON"** → Reference file may be corrupted, restore from git: `git checkout roo-config/mcp/reference-alwaysallow.json`

## Adding New MCPs

When adding a new MCP server:

1. **Get tool list:** Run MCP server, list available tools
2. **Add to reference file:** Add entry under `mcpServers` with all tools
3. **Commit:** `git add roo-config/mcp/reference-alwaysallow.json && git commit -m "feat(mcp): Add NEW_SERVER to reference-alwaysallow"`
4. **Deploy:** Run `Sync-AlwaysAllow.ps1` on each machine
5. **Verify:** Confirm next scheduler cycle doesn't prompt for approvals

## Removing MCPs

When removing an MCP:

1. **Remove from reference file:** Delete the server entry
2. **Commit:** `git add roo-config/mcp/reference-alwaysallow.json && git commit -m "refactor(mcp): Remove DEPRECATED_SERVER from reference-alwaysallow"`
3. **Deploy:** Run `Sync-AlwaysAllow.ps1` with `-Force` on each machine
4. **Note:** Deprecated MCPs kept in reference for backward compatibility only

## References

- **Deployment Guide:** `docs/deployment/DEPLOY-ALWAYSALLOW.md`
- **Tool Availability Rules:** `.claude/rules/tool-availability.md`
- **Issue #496:** Auto-approbation complète des outils Roo
- **Related Issues:** #473 (partial fix), #488 (bash fallback), #502 (condensation)

---

**Last Updated:** 2026-03-01
**Maintained By:** Coordinador (myia-ai-01)
