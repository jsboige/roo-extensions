# Web1 Jupyter-MCP Fix Instructions

**Issue:** #527 - Config-sync automation blocked by web1 jupyter-mcp enablement
**Date:** 2026-02-28
**Priority:** CRITICAL
**Machine:** myia-web1

---

## Problem

Web1 has jupyter-mcp **ENABLED** which violates the 2GB RAM constraint and crashes the scheduler. The jupyter-mcp server loads 152 tools which is too heavy for web1's limited resources.

**Current Status:**
- Directives sent: 2026-02-27 18:31 UTC (msg-20260227T173118-6xmq4o)
- Follow-up sent: 2026-02-27 21:32 UTC (msg-20260227T203210-k8nz2o)
- **Awaiting:** web1 confirmation and fix application

---

## Solution

### Method 1: Using roosync_mcp_management MCP Tool (RECOMMENDED)

**Step 1: Read current MCP settings**

```typescript
roosync_mcp_management(
  action: "manage",
  subAction: "read"
)
```

This will show the current MCP configuration including jupyter-mcp status.

**Step 2: Disable jupyter-mcp**

```typescript
roosync_mcp_management(
  action: "manage",
  subAction: "update_server_field",
  serverName: "jupyter",
  fieldName: "disabled",
  fieldValue: true
)
```

**Step 3: Verify the fix**

```typescript
roosync_mcp_management(
  action: "manage",
  subAction: "read"
)
```

Confirm that `jupyter.disabled` is now `true`.

**Step 4: Restart VS Code**

Close and reopen VS Code to apply the MCP configuration changes.

---

### Method 2: Manual Edit (Alternative)

**File location:**
```
%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json
```

**Change to make:**

Find the `"jupyter"` section and ensure:
```json
"jupyter": {
  "disabled": true,
  "autoStart": false,
  ...
}
```

**Important:** Set BOTH `disabled: true` AND `autoStart: false`.

---

### Method 3: PowerShell Script (Quickest)

Run this command in PowerShell on web1:

```powershell
# Read current settings
$settingsPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json

# Disable jupyter-mcp
$settings.mcpServers.jupyter.disabled = $true
$settings.mcpServers.jupyter.autoStart = $false

# Save settings
$settings | ConvertTo-Json -Depth 100 | Set-Content $settingsPath -Encoding UTF8

Write-Host "✅ jupyter-mcp disabled successfully" -ForegroundColor Green
Write-Host "⚠️  Restart VS Code to apply changes" -ForegroundColor Yellow
```

---

## Verification

After applying the fix, run the config-sync pipeline to verify:

```typescript
// 1. Collect current config
roosync_config(
  action: "collect",
  targets: ["mcp"],
  machineId: "myia-web1"
)

// 2. Publish new version
roosync_config(
  action: "publish",
  version: "2.7.1",
  description: "Fix jupyter-mcp enablement on web1",
  targets: ["mcp"],
  machineId: "myia-web1"
)

// 3. Compare across machines
roosync_compare_config(
  granularity: "mcp"
)
```

**Expected result:**
- No CRITICAL diffs for jupyter-mcp
- web1 config shows `jupyter.disabled: true`

---

## After Fix

Once web1 confirms the fix:

1. **Re-run config-sync** to verify compliance
2. **Update issue #527** with confirmation
3. **Begin 7-day verification period** for baseline establishment
4. **Close issue** after successful verification

---

## Reference

- **Issue:** https://github.com/jsboige/roo-extensions/issues/527
- **Tool docs:** `.claude/rules/tool-availability.md` (line 47: jupyter MUST be disabled)
- **Constraints:** `.claude/rules/myia-web1-constraints.md` (2GB RAM limitation)

---

**Created:** 2026-02-28 by Claude Code (myia-po-2023)
**Purpose:** Unblock config-sync automation by fixing web1 jupyter-mcp blocker
