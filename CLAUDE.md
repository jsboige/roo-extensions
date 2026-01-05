# Roo Extensions - Workspace Context

**Repository:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
**System:** RooSync v2.3 Multi-Agent Coordination

---

## 🎯 Overview

This is a multi-agent system coordinating **Roo Code agents** (technical work) and **Claude Code agents** (coordination & documentation) across 5 machines.

**Machines:** myia-ai-01, myia-po-2023, myia-po-2024, myia-po-2026, myia-web-01

---

## 📚 Quick Access (Start Here)

**For ANY Claude Code agent starting work:**

1. **Run initialization script** (first time on machine):
   ```powershell
   .\.claude\scripts\init-claude-code.ps1
   ```
2. Read [`.claude/INDEX.md`](.claude/INDEX.md) - Complete documentation map
3. Read [`.claude/CLAUDE_CODE_GUIDE.md`](.claude/CLAUDE_CODE_GUIDE.md) - Agent guide (Bootstrap + SDDD)
4. Read [`.claude/MCP_ANALYSIS.md`](.claude/MCP_ANALYSIS.md) - MCP capabilities mapping

**For workspace knowledge:**
- [`docs/knowledge/WORKSPACE_KNOWLEDGE.md`](docs/knowledge/WORKSPACE_KNOWLEDGE.md) - Full workspace context (6500+ files)

---

## 🔧 Git Submodules

This repository contains 7 submodules:

### Core Submodules
- **`roo-code`** - Roo Code agent (v3.18.1+)
  - Fork: https://github.com/jsboige/Roo-Code
  - Purpose: Technical agents (scripts, tests, build)

- **`mcps/internal`** - Internal MCP servers (6 servers)
  - Repo: https://github.com/jsboige/jsboige-mcp-servers
  - **Roo Config:** `%APPDATA%\Code\User\globalStorage\rooveterinaryinc.roo-cline\settings\mcp_settings.json`
  - **Claude Code Config:** `.mcp.json` (generated from `.mcp.json.template` - see [MCP_SETUP.md](.claude/MCP_SETUP.md))
  - **Servers:**
    - `roo-state-manager` - Roo state + conversation history (50+ tools, Qdrant semantic search)
    - `github-projects-mcp` - GitHub Projects API integration
    - `jinavigator-server` - Web pages to Markdown via Jina API
    - `jupyter-papermill-mcp-server` - Jupyter Papermill integration
    - `quickfiles-server` - Multi-file operations
    - `jupyter-mcp-server` - (legacy, should be archived - use papermill version)

### Forked Submodules
- **`mcps/forked/modelcontextprotocol-servers`** - Official MCP servers
  - Fork: https://github.com/jsboige/modelcontextprotocol-servers
  - Contains: Reference implementations, everything MCP

### External MCP Submodules
**Git Submodules (5):**
- **`mcps/external/win-cli/server`** - Windows CLI MCP (https://github.com/jsboige/win-cli-mcp-server)
- **`mcps/external/mcp-server-ftp`** - FTP server MCP
- **`mcps/external/markitdown/source`** - Microsoft Markitdown (v0.1.4)
- **`mcps/external/playwright/source`** - Browser automation (v0.0.54)
- **`mcps/external/Office-PowerPoint-MCP-Server`** - PowerPoint MCP (Python)

**Local MCPs (7 non-submodule):**
- **`mcps/external/filesystem`** - File system operations (read, write, edit files)
- **`mcps/external/git`** - Git operations (init, clone, commit, push, pull, branches)
- **`mcps/external/github`** - GitHub API (repos, issues, PRs, search)
- **`mcps/external/searxng`** - Web search via SearXNG
- **`mcps/external/docker`** - Docker container operations
- **`mcps/external/jupyter`** - Jupyter notebook integration
- **`mcps/external/markitdown`** - Document conversion (Markdown)

**TODO:** Audit all 13 internal + 12 external MCPs for Claude Code compatibility (collaborative task)

---

## 🤖 Your Role as Claude Code Agent

**✅ DO:**
- Documentation consolidation and cleanup
- Multi-agent coordination via GitHub Issues
- Analysis and reporting
- Use native Claude Code tools: Read, Grep, Bash, Git

**❌ DON'T:**
- Modify Roo agent technical code (scripts, tests, build)
- Assume MCPs are available without testing
- Use tools you haven't verified exist

**Key constraint:** You don't have access to your own conversation history. Use GitHub Issues as "external memory".

---

## 🔄 Local Communication (INTERCOM)

**What:** Local communication between Claude Code and Roo agents in the same VS Code instance.

**File:** `.claude/local/INTERCOM-{MACHINE_NAME}.md`

**Purpose:**
- Coordinate tasks between Claude Code and Roo on the same machine
- Quick, real-time communication (vs. RooSync for inter-machine)
- Simple file-based protocol (VS Code notifications trigger reads)

**Documentation:** [`.claude/INTERCOM_PROTOCOL.md`](.claude/INTERCOM_PROTOCOL.md)

**Example:**
```
.claude/local/INTERCOM-myia-ai-01.md  # Communication on myia-ai-01
```

**Workflow:**
1. **Starting work:** Check for messages from the other agent
2. **Sending message:** Open file → Add message → Save (triggers notification)
3. **File format:** Simple Markdown with timestamped messages

**Quick Start:**
```markdown
## [2026-01-05 16:00:00] claude-code → roo [TASK]
Please run the test suite for module X.

---
```

**Message Types:** `INFO`, `TASK`, `DONE`, `WARN`, `ERROR`, `ASK`, `REPLY`

**Distinction:**
- **INTERCOM** = Same machine, Claude Code ↔ Roo
- **RooSync** = Different machines, inter-machine coordination

---

## 🔄 RooSync Coordination

**⚠️ IMPORTANT:** MCP configuration status for Claude Code agents:

**✅ VERIFIED & WORKING (myia-ai-01 - 2026-01-05):**
- `github-projects-mcp` - GitHub Projects API (57 tools)
  - Configuration: `~/.claude.json` (global user config)
  - Setup instructions: [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md)
  - **Status:** ✅ Tested and working on myia-ai-01 (2026-01-05)
  - **Verified tools:** list_projects, get_project, get_project_items
  - **Project accessible:** "RooSync Multi-Agent Tasks" (Project #67, 60 items, 1 completed)
  - **Project URL:** https://github.com/users/jsboige/projects/67

- `roo-state-manager` - RooSync state management + messaging (57 tools)
  - Configuration: `~/.claude.json` with `.env` injection
  - **Status:** ✅ Deployed on myia-ai-01 (2026-01-05)
  - **Commit:** `64412d47` - Fix .env injection in init script
  - **Environment:** 10 variables injected from `mcps/internal/servers/roo-state-manager/.env`
  - **Capabilities:**
    - Read RooSync messages: `get_recent_messages()`
    - Access conversation history
    - Qdrant semantic search
    - Inter-machine coordination

**❓ NOT TESTED ON OTHER MACHINES:**
- Both MCPs need deployment on:
  - myia-po-2023
  - myia-po-2024
  - myia-po-2026
  - myia-web-01

**Action Required for Other Machines:**
1. Run init script: `.\.claude\scripts\init-claude-code.ps1`
2. Restart Claude Code completely
3. Test MCPs with: "List the available GitHub projects" or "Read recent RooSync messages"
4. Create bootstrap issue: `[CLAUDE-MACHINE] MCP Test Results`

**IMPORTANT:** MCPs are loaded at VS Code startup. Always start a NEW conversation after deployment to access the tools.

---

## 📖 Documentation Structure

```
.claude/
├── INDEX.md                  # Start here - Documentation map
├── CLAUDE_CODE_GUIDE.md      # Agent guide (Bootstrap + Phases 0-3)
├── MCP_ANALYSIS.md           # MCP capabilities & portability
├── MCP_SETUP.md              # MCP configuration instructions
├── README.md                 # Workspace entry point
└── QUICKSTART.md             # Quick start guide

docs/
├── knowledge/WORKSPACE_KNOWLEDGE.md  # Full workspace context
├── roosync/                          # RooSync documentation
│   ├── PROTOCOLE_SDDD.md
│   ├── GUIDE-TECHNIQUE-v2.3.md
│   └── GESTION_MULTI_AGENT.md
└── suivi/RooSync/                    # Multi-agent tracking
    ├── PHASE1_DIAGNOSTIC_ET_STABILISATION.md
    └── RAPPORT_SYNTHESE_MULTI_AGENT_*.md
```

---

## 🚀 First Steps

When you start a new task:

1. **Verify available tools:** Check what tools Claude Code actually has access to
2. **Read documentation:** [`.claude/INDEX.md`](.claude/INDEX.md) and recent reports
3. **Use native tools:** Read code source, check git status (Read, Grep, Bash, Git)
4. **DO NOT assume MCPs work:** Test before relying on them
5. **Document reality:** What's verified to work, not what should work

---

## 🎯 Current Context (2026-01-05)

**Phase:** Multi-agent coordination startup
**Issues:**
- Dual architecture v2.1/v2.3 causing instability
- 58 tasks planned across 4 phases (Phase 1: 12 tasks, 1 completed)
- 6500+ documentation files need consolidation
- MCP configuration needs alignment between Roo and Claude Code

**Your mission:** Complete Roo agents by handling documentation, coordination, and cleanup.

**⚠️ CRITICAL CONSTRAINTS:**
- **DO NOT assume MCPs are available** - verify first
- **Use native Claude Code tools** - Read, Grep, Bash, Git
- **DO NOT invent workflows** - test what actually works
- **Document reality** - what's verified, not assumptions

**Coordination tasks:**
- ✅ Test which MCPs actually work with Claude Code (GitHub MCP verified on myia-ai-01)
- 🔄 Document verified capabilities on all machines
- 📋 Create clear task partition plan across all 5 machines
- 🎯 Focus on your machine (myia-ai-01) as baseline master coordinator

**MCP Status (2026-01-05):**
- ✅ **GitHub Projects MCP** - VERIFIED working on myia-ai-01
  - 60 tasks visible in "RooSync Multi-Agent Tasks" project
  - Can list projects, get details, read items
  - Ready for multi-agent coordination via GitHub

---

## 🤝 Multi-Agent Task Distribution

### Machine Assignments

**5 Machines in RooSync System:**

| Machine | Role | Status |
|---------|------|--------|
| **myia-ai-01** | Baseline Master / Coordinator | ⭐ Primary coordinator |
| **myia-po-2023** | Agent (flexible assignment) | 📋 Ready to start |
| **myia-po-2024** | Agent (flexible assignment) | 🔧 Ready to start |
| **myia-po-2026** | Agent (flexible assignment) | 🔍 Ready to start |
| **myia-web-01** | Agent (flexible assignment) | ✅ Ready to start |

**All machines have equal capabilities** - no rigid specialization. Tasks are distributed dynamically based on:
- Current workload
- Agent availability
- Machine performance
- Task priority

### Coordination Protocol

**myia-ai-01 Responsibilities:**
- Create GitHub issues for major task categories
- Maintain overall task tracking
- Coordinate work distribution (not doing all work)
- Rebalance load when needed
- Consolidate and integrate results

**All Agents Responsibilities:**
- Pick available tasks from GitHub issues
- Self-assign tasks via GitHub issue comments
- Report progress daily
- Coordinate with other agents via comments
- Ask for help when blocked

**Daily Communication:**
1. Each agent posts daily update: `[CLAUDE-MACHINE] Daily Report - DATE`
2. Check for new tasks in issues labeled `claude-code` and `help-wanted`
3. Comment on tasks you're working on to avoid duplication
4. Report blockers early so others can help

**Work Distribution:**
- Check the [GitHub Project board](https://github.com/jsboige/roo-extensions/projects) for available tasks
- Look for issues with label `claude-code` that are unassigned
- Self-assign by commenting: "I'm working on this"
- If you finish your tasks, help others with their workload

### Getting Started (For Other Machines)

**When you start Claude Code on another machine:**

1. **Pull latest changes** from git repository
2. **Read this file** (CLAUDE.md) completely
3. **Identify your machine** (check `$env:COMPUTERNAME` or `hostname`)
4. **Configure MCP** following [`.claude/MCP_SETUP.md`](.claude/MCP_SETUP.md):
   - Verify `.claude/.mcp.json` exists
   - Restart Claude Code
   - Test MCP tools availability
5. **Read coordination documentation:**
   - `.claude/INDEX.md` - Documentation map
   - `.claude/CLAUDE_CODE_GUIDE.md` - Agent guide
   - `.claude/MCP_ANALYSIS.md` - MCP analysis
6. **Create bootstrap GitHub issue:** `[CLAUDE-MACHINE] Bootstrap Complete - MCP Configured`
7. **Browse available tasks** and self-assign work
8. **Report progress** daily via GitHub issues

**Important:**
- ✅ DO pick any available task that needs doing
- ✅ DO coordinate via GitHub issue comments
- ✅ DO help others if you have capacity
- ✅ DO ask for help if you're blocked
- ❌ DON'T wait for assigned tasks - be proactive
- ❌ DON'T work on tasks someone else claimed (check comments)

### Task Categories

All agents can work on any of these categories:

**Documentation Tasks:**
- Duplicate detection and consolidation
- Documentation updates
- Index creation and maintenance
- Quality checks

**Technical Tasks:**
- MCP testing and validation
- Technical documentation validation
- Build script testing
- Code analysis

**Coordination Tasks:**
- GitHub issue creation and management
- Progress tracking
- Status reporting
- Blocker resolution

---

---

**Last Updated:** 2026-01-05
**For questions:** See [`.claude/INDEX.md`](.claude/INDEX.md) or create GitHub issue
