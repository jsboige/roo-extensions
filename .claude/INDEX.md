# Claude Code Workspace - Documentation Index

**Last Updated:** 2026-01-18
**Workspace:** roo-extensions (RooSync Multi-Agent System)

---

## 📚 Quick Navigation

### Start Here
- **[CLAUDE.md](../CLAUDE.md)** - ⭐ Main guide for Claude Code agents (READ THIS FIRST)
- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide

### For Claude Code Agents
- **[CLAUDE_CODE_GUIDE.md](CLAUDE_CODE_GUIDE.md)** - Complete agent guide (Bootstrap + SDDD Phases)
- **[INTERCOM_PROTOCOL.md](INTERCOM_PROTOCOL.md)** - Local communication protocol (Claude Code ↔ Roo)
- **[../CLAUDE.md § Feedback](../CLAUDE.md#4-processus-de-feedback-et-amélioration-continue)** - Workflow improvement process (collective feedback via RooSync)

### Configuration & Deployment
- **[MCP_SETUP.md](MCP_SETUP.md)** - ✅ MCP configuration guide (UPDATED with wrapper solution)
- **[MULTI_MACHINE_DEPLOYMENT.md](MULTI_MACHINE_DEPLOYMENT.md)** - Multi-machine RooSync deployment

### Workspace Knowledge
- **[../docs/knowledge/WORKSPACE_KNOWLEDGE.md](../docs/knowledge/WORKSPACE_KNOWLEDGE.md)** - Complete workspace context (6500+ files)

### Agents & Skills (NEW - 2026-01-18)
- **[agents/](agents/)** - 11 specialized subagents (Opus model)
  - `roosync-hub` / `roosync-reporter` - RooSync coordination
  - `dispatch-manager` / `task-planner` - Multi-agent planning
  - `github-tracker` - GitHub Project #67 tracking
  - `git-sync` - Conservative pull/merge
  - `test-runner` - Build + unit tests
  - `intercom-handler` - Local Roo ↔ Claude communication
  - `code-explorer` - Codebase exploration
  - `task-worker` - Autonomous task execution
  - `roosync-coordinator` - Inter-machine messaging
- **[skills/](skills/)** - Auto-invoked skills
  - `sync-tour` - 8-phase sync tour (INTERCOM → Messages → Git → Tests → GitHub → Planning → Responses)
- **[commands/](commands/)** - Slash commands
  - `/coordinate` - Coordination session (myia-ai-01)
  - `/executor` - Execution session (other machines)
  - `/sync-tour` - Full sync tour
  - `/switch-provider` - Switch LLM provider

---

## ✅ MCP Status (2026-01-18)

### VERIFIED & WORKING (myia-ai-01)

**github-projects-mcp** (57 tools)
- Status: ✅ Fully operational
- Projects:
  - #67 "RooSync Multi-Agent Tasks" (69/77 items Done = 89.6%)
  - #70 "RooSync Multi-Agent Coordination" (10/11 Done = 90.9%)
- URL: https://github.com/users/jsboige/projects/67

**roo-state-manager** (17 RooSync tools)
- Status: ✅ DEPLOYED & FUNCTIONAL
- Version: wrapper v2.5.0 (2026-01-18)
- Recent Fix: Bug #322 - Inventory → collect config mapping (commit 7ce45751)
- Tools include:
  - 6 messaging tools (send_message, read_inbox, reply_message, etc.)
  - 5 config tools (collect_config, publish_config, apply_config, etc.)
  - 3 status tools (get_status, compare_config, list_diffs)
  - 3 decision tools (get_decision_details, etc.)
- Capabilities:
  - Inter-machine messaging via RooSync
  - Configuration sync across 5 machines
  - Machine inventory collection

### PENDING (Other Machines)
- myia-po-2023
- myia-po-2024
- myia-po-2026
- myia-web1

**Action Required:** Run `.\.claude\scripts\init-claude-code.ps1`

See [MCP_SETUP.md](MCP_SETUP.md) for details.

---

## 🗂️ RooSync Documentation

### Main Guides
- **[../docs/roosync/PROTOCOLE_SDDD.md](../docs/roosync/PROTOCOLE_SDDD.md)** - SDDD Protocol v2.2.0
- **[../docs/roosync/GUIDE-TECHNIQUE-v2.3.md](../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)** - RooSync v2.3 Technical Guide
- **[../docs/roosync/GESTION_MULTI_AGENT.md](../docs/roosync/GESTION_MULTI_AGENT.md)** - Multi-agent management

### Operational Docs
- **[../docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md](../docs/roosync/GUIDE-OPERATIONNEL-UNIFIE-v2.1.md)** - Unified operational guide
- **[../docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md](../docs/roosync/GUIDE-DEVELOPPEUR-v2.1.md)** - Developer guide

---

## 📊 Tracking & Reports

### Claude Code Tracking
- **[../docs/suivi/Claude-Code/RESUME_WORK.md](../docs/suivi/Claude-Code/RESUME_WORK.md)** - Transition guide
- **[../docs/suivi/Claude-Code/START_NEW_CONVERSATION.txt](../docs/suivi/Claude-Code/START_NEW_CONVERSATION.txt)** - Message template

### RooSync Phase 1
- **[../docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md](../docs/suivi/RooSync/PHASE1_DIAGNOSTIC_ET_STABILISATION.md)** - Phase 1 status

### Action Plans
- **[../docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](../docs/suivi/RooSync/PLAN_ACTION_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)** - 58 planned tasks

### Synthesis Reports
- **[../docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md](../docs/suivi/RooSync/RAPPORT_SYNTHESE_MULTI_AGENT_myia-ai-01_2025-12-31_v2.md)** - Multi-agent synthesis

---

## 🛠️ Available MCP Tools

### Internal MCPs (6 servers)

**RooSync (roo-state-manager) - 6 tools (via wrapper):**
- `roosync_send_message` - Send message
- `roosync_read_inbox` - Read inbox
- `roosync_reply_message` - Reply to message
- `roosync_get_message` - Get message details
- `roosync_mark_message_read` - Mark as read
- `roosync_archive_message` - Archive message

**Note:** The wrapper filters 57+ tools down to these 6 RooSync messaging tools for stability.

**GitHub Projects (github-projects-mcp):**
- `list_projects` - List projects
- `get_project_items` - Get project items
- `create_project` - Create project
- `update_project_item_field` - Update item

**Other Internal MCPs:**
- `jinavigator-server` - Web → Markdown (Jina API)
- `jupyter-papermill-mcp-server` - Jupyter Papermill
- `quickfiles-server` - Multi-file operations

### External MCPs (12 servers)

**Basic Operations:**
- `filesystem` - File operations (read, write, edit)
- `git` - Git operations (commit, push, pull, branches)
- `github` - GitHub API (repos, issues, PRs)

**External Services:**
- `searxng` - Web search
- `docker` - Docker containers
- `jupyter` - Jupyter notebooks
- `markitdown` - Document conversion

**Git Submodules:**
- `win-cli/server` - Windows CLI
- `mcp-server-ftp` - FTP server
- `markitdown/source` - Microsoft Markitdown (v0.1.4)
- `playwright/source` - Browser automation (v0.0.54)
- `Office-PowerPoint-MCP-Server` - PowerPoint (Python)

---

## 🎯 SDDD Protocol for Claude Code

### Triple Grounding

**1. Semantic Grounding**
- Tools: `search_tasks_by_content` (Roo MCP) + Grep/Glob
- Semantic search via Qdrant
- Textual search complement
- Read relevant documents

**2. Conversational Grounding**
- Tools: `view_conversation_tree`, `get_conversation_synthesis` (Roo MCP)
- Conversation tree
- LLM synthesis
- Read recent reports

**3. Technical Grounding**
- Tools: Read, Grep, Bash, Git
- Read source code
- Git status check
- Feasibility validation

### GitHub Traceability

**CRITICAL REQUIREMENT:** Create a GitHub issue for any significant task.

**Format:**
```
Title: [CLAUDE-myia-XX-XX] TASK_TITLE
Labels: claude-code, phase-X, priority-X
```

---

## 📋 Repository Structure

### Documentation
```
docs/
├── roosync/                     # RooSync documentation
│   ├── PROTOCOLE_SDDD.md
│   ├── GUIDE-TECHNIQUE-v2.3.md
│   └── GESTION_MULTI_AGENT.md
├── suivi/RooSync/               # Multi-agent tracking
│   ├── PHASE1_DIAGNOSTIC_ET_STABILISATION.md
│   ├── PLAN_ACTION_MULTI_AGENT_*.md
│   └── RAPPORT_SYNTHESE_MULTI_AGENT_*.md
└── ...
```

### Source Code
```
mcps/
├── internal/                    # Internal MCPs
│   └── servers/
│       ├── roo-state-manager/   # RooSync + Roo tools (with wrapper)
│       └── github-projects-mcp/ # GitHub Projects
└── external/                    # External MCPs
    └── ...
```

---

## 🚀 Current Status (2026-01-18)

### Recent Accomplishments
- ✅ Bug #322 RESOLVED - Inventory → collect config mapping (commit 7ce45751)
- ✅ Git conflicts resolved - Get-MachineInventory.ps1 + mcps/internal submodule
- ✅ Tests: 1311/1319 PASS (99.4%)
- ✅ Project #67: 89.6% Done (69/77 items)
- ✅ Project #70: 90.9% Done (10/11 items)
- ✅ Agent architecture deployed - 11 subagents + 1 skill
- ✅ Improved workflows: coordinate.md, executor.md, sync-tour skill (8 phases)

### Problems Solved
- ✅ Bug #322 - paths.rooExtensions not available in inventory
- ✅ Git merge conflicts - HEAD vs incoming branch resolution
- ✅ Submodule sync issues - mcps/internal at correct commit
- Solution: Find-RooExtensionsRoot function in Get-MachineInventory.ps1

### Immediate Goals (24-48h)
- 🔄 Git pull on 4 machines (myia-web1, myia-po-2023, myia-po-2024, myia-po-2026)
- 🔄 Restart VS Code to reload MCPs after pull
- 🔄 Validate workflow: collect_config → compare_config → apply_config
- 🎯 Close remaining issues: #320 (E2E tests), #323 (Deploy myia-po-2023), #327 (Workflow publish)

---

## 🤝 Multi-Agent Contribution

### Coordination in Progress

**Phase 0: Bootstrap** (Immediate)
- Start Claude Code agents on 5 machines
- Validate MCP access

**Phase 1: Observation** (Days 1-2)
- Complete RooSync system analysis
- Documentation mapping
- Technical diagnostics

**Phase 2: Cleanup** (Days 3-7)
- Documentation consolidation
- Repository cleanup
- Validation with Roo agents

**Phase 3: Coordination** (Days 8-14)
- SDDD protocol deployment
- Communication rituals
- Coordination tools

**Phase 4: Extension** (Weeks 3-4)
- Replicable model
- Deployment documentation
- Testing on additional workspaces

### How to Participate

1. Read [CLAUDE.md](../CLAUDE.md) completely
2. Follow the adapted SDDD protocol
3. Create GitHub issues for traceability
4. Communicate via RooSync

---

## 📞 Support & Resources

### Documentation
- **RooSync:** `../docs/roosync/`
- **Coordination:** See [CLAUDE.md](../CLAUDE.md)

### Issues & Questions
- **GitHub:** [jsboige/roo-extensions](https://github.com/jsboige/roo-extensions)
- **RooSync:** Via `roosync_send_message`

---

## 📝 Meta-Documentation

### .claude/ Files

**Auto-loaded at startup:**
- `README.md` - Short entry point with links
- `INDEX.md` - This table of contents
- `QUICKSTART.md` - Quick start guide

**Scripts and configs:**
- `scripts/` - PowerShell scripts
- `local/` - INTERCOM communication logs

---

**Version:** 2.0.0
**Last Updated:** 2026-01-18
**Maintainer:** jsboige

---

**Built with Claude Code 🤖**
