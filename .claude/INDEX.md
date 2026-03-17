# Claude Code Workspace - Documentation Index

**Last Updated:** 2026-03-03
**Workspace:** roo-extensions (RooSync Multi-Agent System)

---

## 📚 Quick Navigation

### Start Here
- **[CLAUDE.md](../CLAUDE.md)** - Main guide for Claude Code agents (READ THIS FIRST)

### For Claude Code Agents
- **[INTERCOM_PROTOCOL.md](INTERCOM_PROTOCOL.md)** - Local communication protocol (Claude Code ↔ Roo)
- ~~CLAUDE_CODE_GUIDE.md~~ - Archivé 2026-03-03 (#553), remplacé par CLAUDE.md + rules/
- **[../CLAUDE.md § Feedback](../CLAUDE.md#4-processus-de-feedback-et-amélioration-continue)** - Workflow improvement process (collective feedback via RooSync)

### Configuration & Deployment
- **[MCP_SETUP.md](MCP_SETUP.md)** - MCP configuration guide (with wrapper solution)

### Workspace Knowledge
- **[../docs/knowledge/WORKSPACE_KNOWLEDGE.md](../docs/knowledge/WORKSPACE_KNOWLEDGE.md)** - Complete workspace context (6500+ files)

### Agents & Skills
- **[agents/](agents/)** - 16 specialized subagents
  - Common: `git-sync`, `test-runner`, `code-explorer`, `github-tracker`, `intercom-handler`
  - Coordinator: `roosync-hub`, `dispatch-manager`, `task-planner`
  - Executor: `roosync-reporter`, `task-worker`
  - Workers: `code-fixer`, `consolidation-worker`, `doc-updater`, `test-investigator`
- **[skills/](skills/)** - 6 auto-invoked skills
  - `sync-tour` - 9-phase sync tour
  - `validate` - CI local (build + tests)
  - `git-sync` - Conservative pull/merge
  - `github-status` - Project #67 status
  - `redistribute-memory` - Memory audit
  - `debrief` - Session analysis + lessons
- **[commands/](commands/)** - 4 slash commands
  - `/coordinate` - Coordination session (myia-ai-01)
  - `/executor` - Execution session (other machines)
  - `/switch-provider` - Switch LLM provider
  - `/debrief` - Session debrief

---

## ✅ MCP Status (2026-02-26)

### VERIFIED & WORKING (All Machines)

**GitHub CLI (gh)** - Replaces deprecated github-projects-mcp (#368)
- Status: ✅ OPERATIONAL
- Project: #67 "RooSync Multi-Agent Tasks" (https://github.com/users/jsboige/projects/67)
- Commands: `gh issue`, `gh pr`, `gh api graphql`
- Requires scope `project`: `gh auth refresh -s project`

**roo-state-manager** (36 tools via wrapper v4)
- Status: ✅ DEPLOYED & FUNCTIONAL (all machines, validated 2026-02-17)
- Version: wrapper v4 pass-through
- Recent Updates:
  - #457 consolidated 3 tools (39→36 in ListTools)
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

**sk-agent** (7 tools)
- Status: ✅ DEPLOYED (stdio MCP, #482 + #522)
- Agents: 13 (analyst, vision-analyst, vision-local, fast, researcher, synthesizer, critic, optimist, devils-advocate, pragmatist, mediator, etc.)
- Conversations: 4 presets (deep-search, deep-think, code-review, research-debate)
- Tools: `call_agent`, `list_agents`, `list_conversations`, `run_conversation`, `list_tools`, `end_conversation`, `list_models`
- Docker container on port 8100 behind `skagents.myia.io`

**win-cli** (9 tools - fork local 0.2.0)
- Status: ✅ CRITICAL (required since b91a841c modes fix)
- Tools: `execute_command`, `get_command_history`, `ssh_execute`, etc.
- **MUST use local fork** (npm 0.2.1 is broken)

**playwright** (22 tools) - Browser automation
**markitdown** (1 tool) - Document conversion

### RETIRED MCPs (DO NOT USE)
- ~~github-projects-mcp~~ → `gh` CLI (#368)
- ~~desktop-commander~~ → win-cli (#468)
- ~~quickfiles~~ → Native Read/Write/Edit (CONS-1)

See [MCP_SETUP.md](MCP_SETUP.md) for details.

---

## 📐 Auto-Loaded Rules (`.claude/rules/`)

| Règle | Description |
|-------|-------------|
| [agents-architecture.md](rules/agents-architecture.md) | Architecture 12 subagents, 6 skills, 4 commands |
| [bash-fallback.md](rules/bash-fallback.md) | Mitigation issue #488 - Bash silencieux |
| [condensation-thresholds.md](rules/condensation-thresholds.md) | Seuils GLM-5 (80% min) - issue #502 |
| [feedback-process.md](rules/feedback-process.md) | Workflow amélioration continue |
| [github-checklists.md](rules/github-checklists.md) | Checklists obligatoires issues |
| [github-cli.md](rules/github-cli.md) | Migration MCP → gh CLI |
| [mcp-discoverability.md](rules/mcp-discoverability.md) | Patterns découverte MCP |
| [myia-web1-constraints.md](rules/myia-web1-constraints.md) | Contraintes RAM 2GB web1 |
| [scheduler-densification.md](rules/scheduler-densification.md) | Sweet spot escalade + #545 graduation |
| [scheduler-system.md](rules/scheduler-system.md) | Référence technique scheduler |
| [sddd-conversational-grounding.md](rules/sddd-conversational-grounding.md) | Protocole triple grounding |
| [test-success-rates.md](rules/test-success-rates.md) | Tests : commandes, taux de succes, machines |
| [tool-availability.md](rules/tool-availability.md) | STOP & REPAIR protocole |
| [validation.md](rules/validation.md) | Checklist validation technique (#724) |

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

### Active MCPs (5 servers + GitHub CLI)

**roo-state-manager** (36 tools via wrapper v4 pass-through):
- Messaging: `roosync_send`, `roosync_read`, `roosync_manage`
- Config: `roosync_config`, `roosync_init`, `roosync_baseline`, `roosync_compare_config`
- Tasks: `conversation_browser`, `view_task_details`, `task_export`
- Search: `roosync_search`, `codebase_search`, `roosync_indexing`
- Diagnostic: `roosync_diagnose`, `read_vscode_logs`, `roosync_get_status`
- MCP: `roosync_mcp_management`, `manage_mcp_settings`, `get_mcp_best_practices`
- And more (36 total, see ListTools)

**sk-agent** (7 tools):
- `call_agent`, `run_conversation`, `list_agents`, `list_conversations`, `list_tools`, `list_models`, `end_conversation`

**win-cli** (9 tools - fork local 0.2.0):
- `execute_command`, `get_command_history`, `get_current_directory`, `ssh_execute`, etc.

**playwright** (22 tools): Browser automation
**markitdown** (1 tool): Document conversion

**GitHub CLI (gh)**: Native CLI for issues, PRs, Projects (replaces github-projects-mcp)

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
│       ├── roo-state-manager/   # RooSync + Roo tools (36 tools, wrapper v4)
│       └── sk-agent/            # AI agents (Python FastMCP + Semantic Kernel)
└── external/                    # External MCPs
    └── ...
```

---

## 🚀 Current Status (2026-01-18)

### Recent Accomplishments
- ✅ Bug #322 RESOLVED - Inventory → collect config mapping (commit 7ce45751)
- ✅ Git conflicts resolved - Get-MachineInventory.ps1 + mcps/internal submodule
- ✅ Tests: 3294/3308 PASS (99.6%) - All machines
- ✅ Wrapper v4: 36 tools exposed (2026-02-17, #407+#457)
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
- 🔄 #480 - Validation wrapper 36 outils cross-machine (tests fonctionnels)
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
