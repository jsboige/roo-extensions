# MCP Configuration for Claude Code Agents

**Date:** 2026-01-05
**Purpose:** Configure github-projects-mcp for Claude Code multi-agent coordination

---

## 🎯 Objective

Enable Claude Code agents on all 5 machines to use GitHub Projects API for task tracking and coordination.

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

The configuration file is already created at `.claude/.mcp.json` in the workspace.

**For each machine**, after pulling from git:

1. Verify the file exists:
   ```powershell
   Test-Path "d:\roo-extensions\.claude\.mcp.json"
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

If the MCP is working, you should see a list of projects.

---

## 🛠️ Available MCP Tools

Once configured, the following tools should be available:

**Project Management:**
- `list_projects` - List all GitHub projects
- `get_project` - Get project details
- `create_project` - Create a new project

**Item Management:**
- `get_project_items` - List items in a project
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
# Check .mcp.json exists
Test-Path "d:\roo-extensions\.claude\.mcp.json"

# Verify content
Get-Content "d:\roo-extensions\.claude\.mcp.json"
```

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

1. **Create a test GitHub Project** for Claude Code coordination
2. **Test basic operations:**
   - List projects
   - Create a draft issue
   - Convert to issue
3. **Report your results** in GitHub issue: `[CLAUDE-MACHINE] MCP Test Results`

---

## 🤝 Coordination

**All machines should:**
1. Configure MCP using these instructions
2. Test availability
3. Report results in daily GitHub issues
4. Use the MCP for task tracking once verified

**myia-ai-01** will:
1. Create dedicated GitHub Project for Claude Code tasks
2. Set up labels and fields
3. Document project structure
4. Coordinate with other agents

---

## 📚 Resources

- [Claude Code MCP Complete Guide](https://hrefgo.com/zh/blog/claude-code-mcp-complete-guide)
- [Claude Code MCP Extension Guide](https://feisky.xyz/posts/2025-06-18-claude-code-mcp/)
- [GitHub MCP Server Source](d:/roo-extensions/mcps/internal/servers/github-projects-mcp/)

---

**Last Updated:** 2026-01-05
**For questions:** Create GitHub issue or contact myia-ai-01 coordinator
