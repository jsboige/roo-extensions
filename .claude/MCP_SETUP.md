# MCP Configuration for Claude Code Agents

**Date:** 2026-01-09 (Updated)
**Purpose:** Configure github-projects-mcp and roo-state-manager for Claude Code multi-agent coordination
**Status:** ✅ **VERIFIED WORKING on myia-ai-01**

---

## 🎯 Objective

Enable Claude Code agents on all 5 machines to use GitHub Projects API for task tracking and coordination.

---

## 🚀 Quick Start (New Machine)

**Run the initialization script:**

```powershell
cd d:\Dev\roo-extensions  # or your workspace path

# Default: Global installation (recommended)
.\.claude\scripts\init-claude-code.ps1

# Also install to project (rare)
.\.claude\scripts\init-claude-code.ps1 -Project

# Project only, no global
.\.claude\scripts\init-claude-code.ps1 -ProjectOnly

# Specific MCPs only
.\.claude\scripts\init-claude-code.ps1 -McpServers github-projects-mcp
```

This script will:

1. Install MCPs to `~/.claude.json` (global, available in all projects) - **default**
2. Optionally create `.mcp.json` for project-level config (with `-Project`)
3. Create `.claude/local/` directory
4. Create INTERCOM file for your machine
5. Verify MCP server build status
6. Check .env file exists

Then restart Claude Code to activate MCP.

### Project vs Global Installation

| Scope | File | Available In | Default |
|-------|------|--------------|---------|
| **Global** | `~/.claude.json` | All projects | ✅ Yes |
| **Project** | `.mcp.json` | This project only | ❌ Use `-Project` |

**Default behavior:** Global installation. MCPs like `github-projects-mcp` are available in all your Claude Code projects.

---

## ✅ Current Status

### Verified Working (myia-ai-01)

**Machine:** myia-ai-01
**Date:** 2026-01-09
**Status:** ✅ **FULLY OPERATIONAL**

#### github-projects-mcp (57 tools)

**Tested tools:**
- ✅ `list_projects` - Lists all GitHub projects
- ✅ `get_project` - Retrieves project details
- ✅ `get_project_items` - Lists all items (60 items found)

**Accessible project:**
- **Name:** "RooSync Multi-Agent Tasks"
- **ID:** PVT_kwHOADA1Xc4BLw3w
- **URL:** https://github.com/users/jsboige/projects/67
- **Items:** 60 total (1 completed, 59 in progress)

#### roo-state-manager (6 RooSync messaging tools)

**Configuration:** `~/.claude.json` with wrapper [mcp-wrapper.cjs](../mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs)

**Status:** ✅ **DEPLOYED & FUNCTIONAL** (2026-01-09)

**Solution: Smart Wrapper**
- Problem: roo-state-manager has 57+ tools and generates verbose logs that crash Claude Code
- Solution: Wrapper filters to 6 RooSync messaging tools and manages logs
- File: [mcp-wrapper.cjs](../mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs)

**Available Tools (after filtering):**
- ✅ `roosync_send_message` - Send message to another machine
- ✅ `roosync_read_inbox` - Read RooSync inbox
- ✅ `roosync_reply_message` - Reply to a message
- ✅ `roosync_get_message` - Get message details
- ✅ `roosync_mark_message_read` - Mark as read
- ✅ `roosync_archive_message` - Archive a message

**Capabilities:**
- Inter-machine messaging via RooSync
- 65 messages in inbox (4 unread)
- Multi-agent coordination

**Troubleshooting roo-state-manager:**

If Claude Code crashes on startup:
1. Check if wrapper is being used in `~/.claude.json`
2. Look for `mcp-wrapper.cjs` in the args
3. Test wrapper directly: `node mcp-wrapper.cjs` from roo-state-manager directory
4. Check for errors in stderr

### myia-po-2024 ✅ OPERATIONAL

**Date:** 2026-01-10
**Status:** ✅ **FULLY OPERATIONAL**

- ✅ github-projects-mcp (57 tools)
- ✅ roo-state-manager via wrapper (6 RooSync tools)
- ✅ INTERCOM configured

### Pending Configuration

These machines need MCP configuration (run init script):
- ❌ myia-po-2023
- ❌ myia-po-2026
- ❌ myia-web-01

---

## 📋 Prerequisites

1. **GitHub Token** - Already configured in Roo settings
2. **github-projects-mcp** - Already built and available in `mcps/internal/servers/github-projects-mcp/`
3. **Node.js** - Required to run the MCP server

---

## 🔧 Configuration System

### Template-Based Configuration

**Problem:** `.mcp.json` contains absolute paths that vary per machine (e.g., `d:/Dev/roo-extensions` vs `d:/roo-extensions`).

**Solution:** Template file with placeholder + initialization script.

| File | Purpose | Versioned |
|------|---------|-----------|
| `.mcp.json.template` | Template with `{{WORKSPACE_ROOT}}` placeholder | ✅ Yes |
| `.mcp.json` | Machine-specific config (generated) | ❌ No (gitignored) |
| `.claude/scripts/init-claude-code.ps1` | Initialization script | ✅ Yes |

### Manual Configuration (if needed)

If you prefer manual setup:

1. Copy template:
   ```powershell
   Copy-Item .mcp.json.template .mcp.json
   ```

2. Replace `{{WORKSPACE_ROOT}}` with your actual path:
   ```powershell
   (Get-Content .mcp.json) -replace '\{\{WORKSPACE_ROOT\}\}', 'd:/Dev/roo-extensions' | Set-Content .mcp.json
   ```

**⚠️ IMPORTANT:** The `.mcp.json` file must be at the **project root**, NOT in `.claude/` directory.
This is due to a known bug: [GitHub Issue #5037](https://github.com/anthropics/claude-code/issues/5037)

### Step 3: Restart Claude Code

After the configuration is in place:

1. **Close Claude Code** completely
2. **Reopen Claude Code**
3. **Start a new conversation**

The MCP server should automatically start in stdio mode

### Step 4: Verify MCP is Available

In your first Claude Code conversation, test the MCP:

```
Can you list the available GitHub projects?
```

If the MCP is working, you should see:
- Project: "RooSync Multi-Agent Tasks"
- ID: PVT_kwHOADA1Xc4BLw3w
- 60 items (1 completed, 59 in progress)

---

## 🛠️ Available MCP Tools

Once configured, the following tools should be available:

**Project Management:**
- ✅ `list_projects` - List all GitHub projects
- ✅ `get_project` - Get project details
- `create_project` - Create a new project

**Item Management:**
- ✅ `get_project_items` - List items in a project
- `add_item_to_project` - Add an item to a project
- `update_project_item_field` - Update item fields
- `delete_project_item` - Delete an item

**Issue Management:**
- `convert_draft_to_issue` - Convert draft to GitHub issue
- `list_repository_issues` - List repository issues
- `get_repository_issue` - Get issue details
- `delete_repository_issues` - Delete issues

**Field Management:**
- `create_project_field` - Create custom field
- `update_project_field` - Update field definition
- `delete_project_field` - Delete field

**Archive:**
- `archive_project` - Archive a project
- `unarchive_project` - Unarchive a project
- `archive_project_item` - Archive item
- `unarchive_project_item` - Unarchive item

---

## ✅ Deployment Checklist

**Use this checklist BEFORE deploying MCPs to avoid configuration errors.**

Based on analysis of past fix commits (Task 2.24), these are the common pitfalls:

### Pre-Deployment Checks

```powershell
# 1. Verify ports are available (MCP uses 3001-3002)
netstat -an | findstr ":300"

# 2. Check existing MCP config
if (Test-Path ~/.claude.json) { Get-Content ~/.claude.json | ConvertFrom-Json | Select-Object -ExpandProperty mcpServers }

# 3. Verify .env file exists for roo-state-manager
Test-Path "mcps/internal/servers/roo-state-manager/.env"

# 4. Test wrapper directly (should show version without crash)
node mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs
# Expected: "Roo State Manager Server started - v1.0.14"
```

### Deployment Steps

- [ ] Run `git pull` to get latest config
- [ ] Run `.\.claude\scripts\init-claude-code.ps1`
- [ ] Verify output shows [OK] for each step
- [ ] **Restart VS Code completely** (not just reload)
- [ ] Test MCP: "List the available GitHub projects"
- [ ] Test RooSync: Use `roosync_read_inbox`

### Post-Deployment Verification

- [ ] `github-projects-mcp` shows 57 tools
- [ ] `roo-state-manager` shows 6 RooSync tools
- [ ] Can access project #67 (Roo tasks)
- [ ] Can send/receive RooSync messages

### Common Issues (from Task 2.24 Analysis)

| Issue | Cause | Solution |
|-------|-------|----------|
| Port conflict | Another service on 3001/3002 | Change port or stop conflicting service |
| .env not loaded | Manual config missing env vars | Use init script (auto-injects .env) |
| Too many tools | Using build/index.js directly | Use mcp-wrapper.cjs instead |
| Crash on startup | Verbose logs from roo-state-manager | Wrapper filters logs automatically |

---

## 🔍 Troubleshooting

### MCP not starting

**Check if MCP process is running:**
```powershell
Get-Process node | Where-Object { $_.Path -like '*github-projects-mcp*' }
```

**Check .env file:**
```powershell
Test-Path "d:\roo-extensions\.env"
```

### MCP tools not available

**Verify the configuration:**
```powershell
# Check .mcp.json exists (at project root!)
Test-Path "d:\roo-extensions\.mcp.json"

# Verify content
Get-Content "d:\roo-extensions\.mcp.json"
```

**⚠️ CRITICAL:** Ensure `.mcp.json` is at the **project root**, NOT in `.claude/` directory.
Claude Code has a known bug where it doesn't read `.claude/.mcp.json` properly.

### Permission errors

**Verify .env file exists with GitHub tokens:**
```powershell
# Check .env exists
Test-Path "d:\roo-extensions\.env"
```

The `.env` file should contain `GITHUB_ACCOUNTS_JSON` with your GitHub tokens (format: JSON array of accounts with owner and token fields).

- Token should have `repo`, `project` scopes
- Check token at: https://github.com/settings/tokens
- .env file is already gitignored for security

### Build errors

**Rebuild the MCP server:**
```powershell
cd d:/roo-extensions/mcps/internal/servers/github-projects-mcp
npm install
npm run build
```

### roo-state-manager crashes Claude Code

**Problem:** roo-state-manager generates too many logs and has 57+ tools, causing Claude Code to crash on startup.

**Solution:** The wrapper [mcp-wrapper.cjs](../mcps/internal/servers/roo-state-manager/mcp-wrapper.cjs) solves this by:
1. Filtering tools from 57+ down to 6 RooSync messaging tools
2. Managing verbose logs (passes startup logs, filters after initialization)
3. Keeping only JSON-RPC messages on stdout

**To verify the wrapper is being used:**
```powershell
# Check ~/.claude.json contains the wrapper
Get-Content ~/.claude.json | Select-String "mcp-wrapper.cjs"
```

**To test the wrapper directly:**
```powershell
cd d:/roo-extensions/mcps/internal/servers/roo-state-manager
node mcp-wrapper.cjs
# Should see: "Roo State Manager Server started - v1.0.14"
```

**To enable debug logs (for troubleshooting):**
```powershell
# Set environment variable before testing
$env:ROO_DEBUG_LOGS = "1"
node mcp-wrapper.cjs
# Will show: "Filtered tools: XX -> 6"
```

**Common issues:**
- **Crash on startup:** Wrapper not being used - check `~/.claude.json` args
- **No tools available:** Check stderr for errors, verify .env variables
- **Timeout:** Server might be loading skeletons - wait 30 seconds

---

## 📊 Next Steps After Configuration

Once MCP is verified working on your machine:

1. **Test basic operations:**
   - List projects (should see "RooSync Multi-Agent Tasks")
   - Get project items (should see 60 items)
   - Verify you can read item details
2. **Create bootstrap GitHub issue:** `[CLAUDE-MACHINE] Bootstrap Complete - MCP Configured`
3. **Self-assign your first task** from the project board
4. **Report your results** in GitHub issue: `[CLAUDE-MACHINE] MCP Test Results`

---

## 🤝 Coordination

**All machines should:**
1. Configure MCP using these instructions
2. Test availability
3. Report results in daily GitHub issues
4. Use the MCP for task tracking once verified

**myia-ai-01 (VERIFIED ✅):**
- ✅ GitHub Projects MCP working
- ✅ Can access "RooSync Multi-Agent Tasks" project
- ✅ Ready to coordinate with other agents

**Other machines (PENDING):**
- myia-po-2023 - Needs configuration
- myia-po-2024 - Needs configuration
- myia-po-2026 - Needs configuration
- myia-web-01 - Needs configuration

---

## 📚 Resources

- [Claude Code MCP Complete Guide](https://hrefgo.com/zh/blog/claude-code-mcp-complete-guide)
- [Claude Code MCP Extension Guide](https://feisky.xyz/posts/2025-06-18-claude-code-mcp/)
- [GitHub MCP Server Source](d:/roo-extensions/mcps/internal/servers/github-projects-mcp/)

---

**Last Updated:** 2026-01-09
**For questions:** Create GitHub issue or contact myia-ai-01 coordinator
