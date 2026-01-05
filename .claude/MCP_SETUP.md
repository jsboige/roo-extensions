# MCP Configuration for Claude Code Agents

**Date:** 2026-01-05
**Purpose:** Configure github-projects-mcp for Claude Code multi-agent coordination
**Status:** ✅ **VERIFIED WORKING on myia-ai-01**

---

## 🎯 Objective

Enable Claude Code agents on all 5 machines to use GitHub Projects API for task tracking and coordination.

---

## ✅ Current Status

### Verified Working (myia-ai-01)

**Machine:** myia-ai-01
**Date:** 2026-01-05
**Status:** ✅ **FULLY OPERATIONAL**

**Tested tools:**
- ✅ `list_projects` - Lists all GitHub projects
- ✅ `get_project` - Retrieves project details
- ✅ `get_project_items` - Lists all items (60 items found)

**Accessible project:**
- **Name:** "RooSync Multi-Agent Tasks"
- **ID:** PVT_kwHOADA1Xc4BLw3w
- **URL:** https://github.com/users/jsboige/projects/67
- **Items:** 60 total (1 completed, 59 in progress)

### Pending Configuration

These machines need MCP configuration:
- ❌ myia-po-2023
- ❌ myia-po-2024
- ❌ myia-po-2026
- ❌ myia-web-01

---

## 📋 Prerequisites

1. **GitHub Token** - Already configured in Roo settings
2. **github-projects-mcp** - Already built and available in `mcps/internal/servers/github-projects-mcp/`
3. **Node.js** - Required to run the MCP server

---

## 🔧 Configuration Steps

### Step 1: Verify MCP Server Build

```powershell
# Check if the MCP server is built
Test-Path "d:/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js"

# If not built, build it:
cd d:/roo-extensions/mcps/internal/servers/github-projects-mcp
npm run build
```

### Step 2: Copy .mcp.json Configuration

**⚠️ IMPORTANT:** The `.mcp.json` file must be at the **project root**, NOT in `.claude/` directory.
This is due to a known bug: [GitHub Issue #5037](https://github.com/anthropics/claude-code/issues/5037)

The configuration file is at `.mcp.json` in the workspace root.

**For each machine**, after pulling from git:

1. Verify the file exists:
   ```powershell
   Test-Path "d:\roo-extensions\.mcp.json"
   ```

2. The file should contain:
   ```json
   {
     "mcpServers": {
       "github-projects-mcp": {
         "type": "stdio",
         "command": "node",
         "args": [
           "d:/roo-extensions/mcps/internal/servers/github-projects-mcp/dist/index.js"
         ],
         "cwd": "d:/roo-extensions/mcps/internal/servers/github-projects-mcp/"
       }
     }
   }
   ```

   **Note:** Using stdio transport (correct for github-projects-mcp)
   **Note:** GitHub tokens are stored in `mcps/internal/servers/github-projects-mcp/.env` (already exists, gitignored)
   **Note:** The MCP server automatically loads `.env` from its working directory

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

**Last Updated:** 2026-01-05
**For questions:** Create GitHub issue or contact myia-ai-01 coordinator
