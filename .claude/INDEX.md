# Claude Code Workspace - Documentation Index

**Last Updated:** 2026-02-16
**Workspace:** roo-extensions (RooSync Multi-Agent System)

---

## 📚 Quick Navigation

### Start Here
- **[CLAUDE.md](../CLAUDE.md)** - Main guide for Claude Code agents (READ THIS FIRST)

### For Claude Code Agents
- **[CLAUDE_CODE_GUIDE.md](CLAUDE_CODE_GUIDE.md)** - Complete agent guide (Bootstrap + SDDD Phases)
- **[INTERCOM_PROTOCOL.md](INTERCOM_PROTOCOL.md)** - Local communication protocol (Claude Code ↔ Roo)
- **[../CLAUDE.md § Feedback](../CLAUDE.md#4-processus-de-feedback-et-amélioration-continue)** - Workflow improvement process (collective feedback via RooSync)

### Configuration & Deployment
- **[MCP_SETUP.md](MCP_SETUP.md)** - MCP configuration guide (with wrapper solution)

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
  - `roosync-hub` - Inter-machine messaging (coordinator)
  - `roosync-reporter` - Inter-machine messaging (executors)
- **[skills/](skills/)** - Auto-invoked skills
  - `sync-tour` - 8-phase sync tour (INTERCOM → Messages → Git → Tests → GitHub → Planning → Responses)
- **[commands/](commands/)** - Slash commands
  - `/coordinate` - Coordination session (myia-ai-01)
  - `/executor` - Execution session (other machines)
  - `/sync-tour` - Full sync tour
  - `/switch-provider` - Switch LLM provider

---

## ✅ MCP Status (2026-02-16)

### VERIFIED & WORKING (All Machines)

**GitHub CLI (gh)** - ⚠️ **Replaces github-projects-mcp (#368)**
- Status: ✅ MIGRATION COMPLETE
- Projects:
  - #67 "RooSync Multi-Agent Tasks" (https://github.com/users/jsboige/projects/67)
  - #70 "RooSync Multi-Agent Coordination"
- Commands: `gh issue`, `gh pr`, `gh api graphql`
- Note: **github-projects-mcp is DEPRECATED** - use native gh CLI

**roo-state-manager** (35 tools Claude Code / 39 Roo wrapper)
- Status: ✅ DEPLOYED & FUNCTIONAL (all machines, validated 2026-02-17)
- Version: wrapper v4 pass-through
- Recent Updates:
  - Cross-machine validation #480 completed
  - Access to: tasks, search, export, diagnostic tools
- Tool categories:
  - 3 messaging (roosync_send, roosync_read, roosync_manage)
  - 5 config (collect, publish, apply, compare, init)
  - 5 consolidated (CONS-1 to CONS-13)
  - 2 decisions (roosync_decision, roosync_decision_info)
  - 5 tasks (task_browse, view_task_details, view_conversation_tree, etc.)
  - 2 search (roosync_search, roosync_indexing)
  - 4 diagnostic (analyze_roosync_problems, diagnose, read_vscode_logs, etc.)
- Capabilities:
  - Inter-machine messaging via RooSync
  - Configuration sync across 6 machines
  - Machine inventory collection
  - Task/conversation browsing
  - Semantic search (Qdrant)

**sk-agent** (7 tools + deprecated aliases)
- Status: ✅ DEPLOYED (2026-02-17, fix #482)
- Wrapper: PowerShell `run-sk-agent.ps1` (100% silent stdout)
- Agents: 11 (analyst, vision-analyst, fast, researcher, synthesizer, critic, etc.)
- Conversations: 4 presets (deep-search, deep-think, code-review, research-debate)
- Tools: `call_agent`, `list_agents`, `list_conversations`, `run_conversation`, `list_tools`, `end_conversation`

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
- ✅ Tests: 3294/3308 PASS (99.6%) - All machines
- ✅ Wrapper v4: 39 tools exposed (2026-02-10, #407)
- ✅ #470 Phase 2 COMPLETE - Consolidation 48→4 docs (-96% lines, 2026-02-15)
- ✅ #472 COMPLETE - Validation MCP multi-machine (2026-02-15)
- ✅ #473 Phase 1 COMPLETE - Audit auto-approvals myia-po-2024 (2026-02-16)
- ✅ Agent architecture deployed - 11 subagents + 4 skills
- ✅ Improved workflows: coordinate.md, executor.md, sync-tour skill (8 phases)
- ✅ ESCALATION_MECHANISM.md - Roadmap autonomy 5 levels (2026-02-12)

### Problems Solved
- ✅ Bug #322 - paths.rooExtensions not available in inventory
- ✅ Git merge conflicts - HEAD vs incoming branch resolution
- ✅ Submodule sync issues - mcps/internal at correct commit
- Solution: Find-RooExtensionsRoot function in Get-MachineInventory.ps1

### Immediate Goals (24-48h)
- 🔄 #479 Phase 3 - Documentation racine (README.md, .claude/INDEX.md, docs/INDEX.md)
- 🔄 #480 - Validation wrapper 39 outils cross-machine (tests fonctionnels)
- 🔄 #473 Phase 2 - Normalisation auto-approvals (après audits 6 machines)
- 🎯 Scheduler Roo: Niveau 2 (complex tasks) activation GLM 5

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

**Scripts and configs:**
- `scripts/` - PowerShell scripts
- `local/` - INTERCOM communication logs

---

**Version:** 2.0.0
**Last Updated:** 2026-01-18
**Maintainer:** jsboige

---

**Built with Claude Code 🤖**
