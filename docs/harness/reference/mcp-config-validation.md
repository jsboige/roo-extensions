# MCP Config Validation - Cross-Machine Drift Detection

**Version:** 1.0.0
**Issue:** #1656
**Created:** 2026-04-24

## Overview

This script prevents config drift incidents that occurred on 2026-04-23 (issues #1634, #1656) where 3 critical bugs were caused by divergent MCP configurations across machines.

## The Problem

MCP configurations can drift from repository "sources of truth" when:
- Manual edits are made to deployed configs
- Deployment scripts are not used consistently
- Different machines have different versions of configs

This causes silent failures and hard-to-diagnose bugs across the RooSync cluster.

## The Solution

**Script:** `scripts/validation/validate-mcp-config-cross-machine.ps1`

### What It Validates

1. **win-cli config drift** - Compares deployed `win_cli_config.json` against repository reference (`mcps/external/win-cli/unrestricted-config.json`)
2. **Deprecated MCPs** - Detects presence of deprecated MCP servers (desktop-commander, github-projects-mcp, quickfiles)
3. **Missing keys** - Reports configuration keys present in reference but missing from deployed
4. **Extra keys** - Reports configuration keys present in deployed but not in reference (informational)

### Exit Codes

- `0` - Validation passed (no drift detected)
- `1` - Drift detected or validation failed

## Usage

### Basic Validation

```powershell
.\scripts\validation\validate-mcp-config-cross-machine.ps1
```

Reports any drift found.

### Detailed Output

```powershell
.\scripts\validation\validate-mcp-config-cross-machine.ps1 -Detailed
```

Shows full comparison including matching values (useful for debugging).

### Fix Mode (Experimental)

```powershell
.\scripts\validation\validate-mcp-config-cross-machine.ps1 -FixMode
```

Outputs suggested PowerShell commands to fix detected drifts.

## Deployed Config Locations

The script checks deployed configs in Roo-specific locations:

**Roo MCP Settings:**
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

**Roo win-cli Config:**
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\win_cli_config.json
```

## Reference Locations

The script compares against repository sources:

**win-cli reference:**
```
mcps/external/win-cli/unrestricted-config.json
```

**Deprecated MCP list:**
- desktop-commander
- github-projects-mcp
- quickfiles

## Integration Points

### Pre-commit Checks

Run before committing MCP-related changes:

```powershell
# From scripts/mcp/validate-before-push.ps1
& "$PSScriptRoot\..\validation\validate-mcp-config-cross-machine.ps1"
if ($LASTEXITCODE -ne 0) {
    Write-Host "DRIFT DETECTED: Fix before pushing" -ForegroundColor Red
    exit 1
}
```

### Cross-Machine Coordination

**Meta-analysts** should run this script during cycles:
- After any MCP deployment
- During config audits
- When investigating MCP-related issues

**Executor sessions** should run before starting MCP-related work.

### CI/CD Integration

Add to scheduled tasks on all machines:
```powershell
# Daily validation
schtasks /Create /TN "Validate-MCP-Config" /TR "powershell -File C:\path\to\validate-mcp-config-cross-machine.ps1" /SC DAILY
```

## Example Output

### Success (No Drift)

```
==========================================================
  MCP Config Cross-Machine Validation
  Preventing drift incidents like #1634, #1656
==========================================================

Checking: Reference win-cli config (repository)
  [OK] Valid JSON

Checking: Deployed win-cli config (Roo)
  [OK] Valid JSON

Comparing win-cli configurations...
  [OK] win_cli.security.commandTimeout: Matches (Value='600')

Checking for deprecated MCP servers...
  [OK] No deprecated MCPs found

==========================================================
VALIDATION PASSED: No drift detected!
```

### Failure (Drift Detected)

```
==========================================================
VALIDATION FAILED: Drift detected!

Action required:
  1. Review the drifts reported above
  2. Update deployed configs to match repository references
  3. Re-run this script to confirm fixes
```

## Troubleshooting

### "File not found" Warning

The deployed config files may not exist if:
- Roo is not installed on the machine
- This is a Claude Code-only machine (no Roo)

This is expected and not an error.

### Permission Errors

The script may need elevated permissions to read:
- `%APPDATA%\Code\User\globalStorage\` locations

Run as administrator if access is denied.

### JSON Parse Errors

If a deployed config file is corrupted:
1. Restore from backup (if available)
2. Re-deploy from repository sources
3. Re-run validation

## Related Documentation

- [Tool Availability](./tool-availability.md) - MCP critical tools
- [Incident History](./incident-history.md) - Drift-related incidents
- [MCP Proxy Architecture](./mcp-proxy-architecture.md) - MCP deployment architecture
- `.claude/rules/meta-analyst.md` - Config drift operational checks (#1584)

## Maintenance

**To add new deprecated MCPs:**
Edit the `$deprecatedMCPs` array in the script:
```powershell
$deprecatedMCPs = @(
    "desktop-commander",
    "github-projects-mcp",
    "quickfiles",
    "new-deprecated-mcp"  # Add here
)
```

**To allow machine-specific divergences:**
Edit the `$allowedDivergences` array:
```powershell
$allowedDivergences = @(
    "win_cli.security.allowedPaths",  # Machine-specific paths
    "win_cli.ssh.connections"         # Machine-specific connections
)
```

## Changelog

### 1.0.0 (2026-04-24)
- Initial release
- Validates win-cli config drift
- Detects deprecated MCPs
- Exit code 0 on success, 1 on failure
- Detailed and FixMode options
