# Deployment Guide: Auto-Approve All MCP Tools for Roo Scheduler

**Issue:** #496 - Auto-approbation complète des outils Roo
**Version:** 1.0.0
**Date:** 2026-03-01
**Status:** Ready for Deployment

---

## Overview

This guide provides step-by-step instructions to deploy the complete MCP tools auto-approval configuration on all 6 machines. This resolves scheduler blocking issues caused by manual tool approval prompts.

## What's Being Deployed

### Script: `Sync-AlwaysAllow.ps1`

**Location:** `roo-config/scripts/Sync-AlwaysAllow.ps1`

**Purpose:** Synchronizes the reference auto-approval configuration to Roo's MCP settings

**Features:**
- Reads from centralized reference file (`roo-config/mcp/reference-alwaysallow.json`)
- Synchronizes with local Roo settings (`%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`)
- Creates automatic backups before modifications
- Dry-run mode for preview without changes
- PowerShell 5.1+ compatible

### Reference File: `reference-alwaysallow.json`

**Location:** `roo-config/mcp/reference-alwaysallow.json`

**Contents:** Comprehensive list of all MCP tools that should be auto-approved:

| MCP Server | Tools Count | Status |
|------------|-------------|--------|
| jinavigator | 4 | Active |
| searxng | 2 | Active |
| win-cli | 9 | **CRITICAL** (required since commit b91a841c) |
| markitdown | 1 | Active |
| playwright | 15 | Active |
| roo-state-manager | 36 | Active |
| jupyter | 22 | DISABLED on execution machines |
| desktop-commander | 26 | Deprecated |

---

## Deployment Steps

### Phase 1: Prepare (Coordinador - myia-ai-01)

1. **Verify all machines have the latest code:**
   ```bash
   git pull origin main
   ```

2. **Announce deployment via RooSync:**
   ```
   TO: all
   SUBJECT: [DEPLOYMENT] Auto-approve MCP tools - Phase 1 Start
   BODY:
   Starting deployment of complete MCP tool auto-approval across all 6 machines.
   Expected downtime: 10 minutes per machine for Roo restart.
   Timeline: Sequential deployment (ai-01 → po-2023 → po-2024 → po-2025 → po-2026 → web1)
   ```

### Phase 2: Deploy on Each Machine (Sequential)

**Order:** myia-ai-01 → myia-po-2023 → myia-po-2024 → myia-po-2025 → myia-po-2026 → myia-web1

**On each machine, execute:**

#### Step 1: Navigate to repo
```powershell
cd D:\dev\roo-extensions
```

#### Step 2: Verify script exists
```powershell
Test-Path .\roo-config\scripts\Sync-AlwaysAllow.ps1
```
Expected: `True`

#### Step 3: Preview changes (dry-run)
```powershell
.\roo-config\scripts\Sync-AlwaysAllow.ps1 -DryRun
```

Review output for any unexpected changes. If everything looks good, continue to Step 4.

#### Step 4: Apply synchronization
```powershell
.\roo-config\scripts\Sync-AlwaysAllow.ps1 -Force
```

Expected output:
```
✓ Synchronization complete!
Updated N server(s):
  [server names and tool counts]
```

#### Step 5: Verify backup was created
```powershell
Get-ChildItem "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json.backup.*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
```

#### Step 6: Restart Roo in VS Code
- Close VS Code completely
- Wait 5 seconds
- Reopen VS Code
- Verify Roo extension loads without errors (check Output > Roo channel)

#### Step 7: Report to Coordinator
```
Machine: [name]
Status: COMPLETE
Backup: [filename]
Issues: [none|describe]
```

### Phase 3: Validate (All Machines in Parallel)

**Wait 30 minutes for next scheduler tick.** Then verify:

#### Check 1: Verify Roo doesn't prompt for tool approval
- Observe Roo performing tasks
- Should NOT see "Do you approve tool X?" prompts
- Confirm in Roo output: "Tool approved" or no prompts

#### Check 2: Monitor INTERCOM for errors
```
INTERCOM: `.claude/local/INTERCOM-[MACHINE_NAME].md`
```
- Look for [ERROR] or [CRITICAL] messages related to MCP tools
- Look for any "tool not found" or "approval required" messages
- No such messages = SUCCESS

#### Check 3: Verify scheduler completes a full cycle
- Wait until next scheduler tick completes
- Check `.roo/` directory for updated task traces
- Confirm no approval-related failures in task history

### Phase 4: Report & Close (Coordinador - myia-ai-01)

**Consolidate results:**
```
Status: DEPLOYED
Machines: 6/6 completed
Issues: [none|describe]
Validation: [passed|issues found]
Next: Close issue #496
```

---

## Rollback Plan (If Issues Occur)

### If Tool Approval Prompts Still Appear

**Cause 1: VS Code not restarted**
- Solution: Close and reopen VS Code completely
- Wait for Roo extension to fully load

**Cause 2: MCP settings not written correctly**
- Solution: Run script again with `-Force` flag
- Verify mcp_settings.json was updated: `Get-Content $path | ConvertFrom-Json | Select-Object -ExpandProperty mcpServers | Get-Member`

**Cause 3: Reference file missing tools**
- Solution: Contact coordinador to update reference file
- Current reference is at: `roo-config/mcp/reference-alwaysallow.json`

### Emergency Rollback

If the deployment causes critical issues:

1. **Stop Roo scheduler:**
   ```powershell
   .\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action disable
   ```

2. **Restore backup:**
   ```powershell
   $backup = Get-ChildItem "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json.backup.*" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
   Copy-Item $backup.FullName "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" -Force
   ```

3. **Restart Roo:**
   - Close VS Code
   - Reopen VS Code
   - Verify Roo loads

4. **Contact Coordinador** immediately with error details

---

## Troubleshooting

### Script Errors

#### "Reference file not found"
- Ensure `roo-config\mcp\reference-alwaysallow.json` exists in the repo
- Run `git pull` to get latest files
- Run from repository root: `D:\dev\roo-extensions`

#### "Failed to parse Roo mcp_settings.json"
- File may be corrupted
- Restore from backup (see Rollback section)
- Run script again

#### "Permission denied" when writing file
- Close VS Code (locks the file)
- Ensure user has write permissions to `%APPDATA%`
- Run PowerShell as Administrator if needed

### Verification Issues

#### Tool Approval Prompts Still Appear

1. **Verify the sync actually ran:**
   ```powershell
   $settings = Get-Content "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json" | ConvertFrom-Json
   $settings.mcpServers."win-cli".alwaysAllow.Count  # Should be 9
   ```

2. **Restart VS Code completely:**
   - Close all VS Code windows
   - Kill any hanging Roo processes: `Get-Process code | Stop-Process -Force`
   - Reopen VS Code

3. **Check Roo logs:**
   - VS Code > Output > Roo
   - Look for "MCP" or "approval" related messages
   - Copy relevant lines to GitHub issue

#### Scheduler Still Blocked

1. **Verify scheduler is running:**
   ```powershell
   Get-Process code | Select-Object ProcessName, StartTime
   ```

2. **Check next scheduled run time:**
   - Look at task history: `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks\`
   - Most recent task should show tool approvals or "approved"

3. **Contact Coordinador** with:
   - Machine name
   - Last scheduler task ID
   - Task output (from `ui_messages.json`)

---

## Validation Checklist

For each machine:

- [ ] Script runs successfully (no errors)
- [ ] Backup file created
- [ ] VS Code restarted
- [ ] Roo extension loads without errors
- [ ] No tool approval prompts during next scheduler cycle
- [ ] INTERCOM has no MCP-related errors
- [ ] Reported to coordinator

---

## Success Criteria

**Full deployment is successful when:**

1. ✅ All 6 machines have synchronized alwaysAllow configuration
2. ✅ Roo scheduler runs without manual approval prompts for 24+ hours
3. ✅ No [ERROR] or [CRITICAL] messages in any INTERCOM about tool approvals
4. ✅ All scheduler cycles complete without blocking
5. ✅ Issue #496 closed

---

## Support

**Questions or issues?**

1. Check Troubleshooting section above
2. Create comment on GitHub issue #496 with:
   - Machine name
   - Error output (if applicable)
   - INTERCOM messages (if applicable)
   - Steps you've taken

**Escalation:** If blocking issue affects all machines, contact Coordinador (myia-ai-01) via RooSync

---

## References

- **Script:** `roo-config/scripts/Sync-AlwaysAllow.ps1`
- **Reference:** `roo-config/mcp/reference-alwaysallow.json`
- **Issue:** #496 - Auto-approbation complète des outils Roo
- **Related Issues:** #473, #488, #502
- **Tool Availability Rules:** `.claude/rules/tool-availability.md`

---

**Last Updated:** 2026-03-01
**Next Review:** After first 24h of successful scheduler operation
