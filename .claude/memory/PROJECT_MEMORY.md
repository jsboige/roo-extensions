# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 6 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (ListTools):** 36 (was 39 before #457 consolidation)
- **Claude wrapper (mcp-wrapper.cjs):** 36 tools (v4 pass-through, no filtering)
- **Tests:** 6946 passed, 19 skipped (2026-03-04)
- **MCP Servers:** roo-state-manager (TypeScript) + sk-agent (Python/FastMCP)

### Key Files
| File | Purpose |
|------|---------|
| `src/tools/registry.ts` | Central tool registration (ListTools + CallTool) |
| `src/tools/roosync/index.ts` | RooSync exports + roosyncTools array |
| `mcp-wrapper.cjs` | Claude Code wrapper (dedup + log suppression) |
| `src/tools/roosync/__tests__/*.test.ts` | Unit tests |

### Adding a New Tool - Checklist
1. Create `src/tools/roosync/tool-name.ts` with function + metadata export
2. Create `src/tools/roosync/__tests__/tool-name.test.ts`
3. Add export to `src/tools/roosync/index.ts`
4. Add metadata to `roosyncTools` array in index.ts
5. Add `case 'tool_name':` handler in `src/tools/registry.ts` CallTool switch
6. Build: `npm run build` (output in `build/`, NOT `dist/`)
7. Test: `npx vitest run` (NEVER `npm test`)
8. Update `alwaysAllow` in Roo mcp_settings.json (use `sync_always_allow` subAction)
9. Restart VS Code (MCPs load at startup only)

## Consolidation History (CONS) - All Done

| CONS | Description | Before | After |
|------|-------------|--------|-------|
| CONS-1 | Messaging | 6 | 3 |
| CONS-2 | Heartbeat | 7 | 2 |
| CONS-3 | Config | 3 | 1 |
| CONS-4 | Baseline | 3 | 1 |
| CONS-5 | Decisions | 5 | 2 |
| CONS-6 | Inventory/Machines | 4 | 2 |
| CONS-9 | Tasks | 4 | 2 |
| CONS-10 | Export | 6 | 2 |
| CONS-11 | Search/Indexing | 4 | 2 |
| CONS-12 | Summary | 3 | 1 |
| CONS-13 | Storage/Repair | 6 | 2 |
| #457 | Conversation Browser | 3 | 1 |

## Decisions & Patterns

### Consolidated tool pattern
- Use `action` or `mode` parameter for routing
- Keep legacy CallTool handlers for backward compatibility
- Remove legacy entries from ListTools (roosyncTools) and wrapper

### Test mock pattern
- Mock `getSharedStatePath()` to point to `__test-data__/`
- Mock `getLocalMachineId()` to return `'test-machine'`
- Use `vi.importActual()` to preserve real exports alongside mocks

### Agent hierarchy
- Claude Code = primary brain (investigation, coding, decisions)
- Roo = assistant (tests, builds, repetitive tasks)
- Always validate Roo's work before committing

### RooSync vs INTERCOM protocol
- **RooSync** = Inter-machine communication (both Roo and Claude Code can use it)
- **INTERCOM** = Local Roo <-> Claude Code on same machine
- Best practice: INTERCOM for local coordination, RooSync for cross-machine

### Agent/skill/command maintenance
- **SDDD** = Semantic Documentation Driven Development
- **Project #70** deleted - ALL references purged
- **github-projects-mcp** deprecated - replaced by `gh` CLI
- **Machine count**: Always 6 (ai-01, po-2023, po-2024, po-2025, po-2026, web1)
- **Deprecation ripple**: When deprecating, grep ALL `.claude/` files for references

## Known Bugs / Gotchas

### Critical (recurring)
- **npm test blocks**: ALWAYS use `npx vitest run` not `npm test`
- **MCP tools load at startup only**: Code changes need VS Code restart
- **Submodule workflow**: Commit inside first, push, then `git add mcps/internal` in parent
- **JSON BOM**: Some GDrive files have BOM. Strip before parsing: `data.charCodeAt(0) === 0xFEFF`
- **PowerShell 5.1 Join-Path**: Only 2 args. Use string interpolation for deeper paths.
- **Case-sensitive machineId**: Always `.toLowerCase()` (commit bd8e5b94)
- **Scheduler cache**: Deploy config then restart VS Code IMMEDIATELY before next tick

## Current State (2026-03-04)

**Phase**: MAINTENANCE CYCLE 53 (Issue #556 Active)
**Tests**: 6946 PASS, 19 skipped | **Tools**: 36 | **GitHub #67**: Progression continue

### Issue #543: Settings Harmonisation Pipeline (COMPLETE ✅)

**Status**: CLOSED - Campaign completed successfully

**Completed:**
- ✅ Phase 1 (all 6 machines): Settings extracted, baseline published
- ✅ Phase 2: Cross-machine drift comparison completed
- ✅ Phase 3: CRITICAL drifts corrected
- ✅ Scenarios A, B, C: All validated
- ✅ Harmonisation pipeline operationalized end-to-end

**Documentation:**
- `docs/suivi/issue-543-final-report.md` - Consolidated final report
- Original phase reports archived to `docs/archives/2026-03-03-issue553-phase2/`

### Issue #545: Roo Complex Mode Graduation (CLOSED ✅)

**Status:** Issue closed - Complex mode graduation validated

**Completed:**
- ✅ Phase 1: Tasks assigned and executed
- ✅ Phase 2: Escalation observed and validated
- ✅ Complex modes proven capable of real work
- ✅ Documentation updated in `.claude/rules/scheduler-densification.md`

**Archived:** `.claude/memory/archive/issue-545-escalation-observation-plan.md`

### Memory Files Archived (Cycle 49)
- ✅ `.claude/memory/archive/issue-545-escalation-observation-plan.md` (Plan obsolète, issue fermée)
- ✅ `.claude/memory/archive/SONNET_4.6_RELEASE.md` (Info ponctuelle)

### Active Issues
| Issue | Title | Scope | Status |
|-------|-------|-------|--------|
| #544 | Automated Quality Pipeline | ai-01 first | In Progress (platform bug) |
| #556 | Memory Redistribution & Rules Audit | All machines | In Progress |
| #558 | win-cli Timeout Configuration | All machines | In Progress |
| #537 | RooSync Config-Sync Phase 2 | All machines | Todo |

### sk-agent MCP (v2.0)
- **Location**: `mcps/internal/servers/sk-agent/`
- **Tools**: `call_agent`, `run_conversation`, `list_agents`, `list_conversations`, `list_tools`, `end_conversation`
- **Agents**: 16 (core 7 + roles 3 + specialized 3 + audit 3) | **Conversations**: 6 | **Tests**: 109 unit + 35 functional
- **4 Models**: Qwen3.5 (262K ctx), ZwZ-8B (131K ctx), GLM-4.7-Flash (131K ctx), OWUI (vision)
- **Fix #482**: Write-Host polluted stdout. Use `[Console]::Error.WriteLine()` only.
- **Issue #485**: Exploitation complete (Phase 1-3). MVP Strategy: 4-agent core (Intake/Executor/Reviewer/Orchestrator)
  - Proposed: log-analyzer, architecture-reviewer, intercom-manager
  - Proposed conversations: scheduler-optimization, mcp-diagnostics
  - Metric: Mediator Conflict Rate <20%
  - Expected: 35-45% cost reduction, 2.5x throughput, 40% accuracy improvement

### EMBEDDING Config (required in .env for codebase_search)
**Variables requises dans `mcps/internal/servers/roo-state-manager/.env`:**
- `EMBEDDING_MODEL` - Modèle d'embedding (ex: qwen3-4b-awq-embedding)
- `EMBEDDING_DIMENSIONS` - Dimensions des vecteurs (ex: 2560)
- `EMBEDDING_API_BASE_URL` - URL de l'API d'embedding
- `EMBEDDING_API_KEY` - Clé API pour l'embedding
- `QDRANT_URL` - URL du serveur Qdrant
- `QDRANT_API_KEY` - Clé API Qdrant

> ⚠️ Les valeurs réelles sont dans le fichier `.env` (non versionné). Ne jamais committer de clés API.
- 20 ws-* Qdrant collections populated (1-580K vectors, 2560 dims)
- Dedicated `getCodebaseEmbeddingClient()` separate from task-indexer

### Knowledge Hierarchy
| Level | File | In Git? |
|-------|------|---------|
| Global user | `~/.claude/CLAUDE.md` | No (deploy from `.claude/configs/`) |
| Project | `CLAUDE.md` (root) | Yes |
| Rules | `.claude/rules/*.md` (auto-loaded) | Yes |
| Private memory | `~/.claude/projects/<hash>/memory/MEMORY.md` | No |
| Shared memory | `.claude/memory/PROJECT_MEMORY.md` | Yes |
| Skill | `redistribute-memory` - audit all levels | Yes |

### MCP Safe Update Pattern
- **`sync_always_allow`**: Programmatically update `alwaysAllow` array
- **`update_server_field`**: MERGE fields (vs `update_server` which REPLACES all)

### Config-Sync Pipeline (Operationalized 2026-02-27)
- **Collect**: `roosync_config(action: "collect", targets: ["modes", "mcp", "roomodes", "model-configs", "rules"])` → 7 files, ~47KB
- **Publish**: `roosync_config(action: "publish", version: "1.0.0", description: "...")` → GDrive `configs/{machineId}/v{version}/`
- **Compare**: `roosync_compare_config(granularity: "mcp"|"mode"|"full")` → Diffs with severity (CRITICAL/WARNING/INFO)
- **Settings extract**: `python scripts/roo-settings/roo-settings-manager.py extract` → 78 keys from state.vscdb
- **Sprint #543**: Cross-machine harmonization campaign (all 6 machines)

### Strategic Directives
| Issue | Title | Scope | Status |
|-------|-------|-------|--------|
| #543 | Settings & Config-Sync Harmonization | All machines | **CLOSED** ✅ |
| #544 | Automated Quality Pipeline | ai-01 first | In Progress (platform bug) |
| #545 | Roo Complex Mode Graduation | All machines | **CLOSED** ✅ |
| #555 | GLM-5 Condensation Parameters | All machines | **CLOSED** ✅ |
| #556 | Memory Redistribution & Rules Audit | All machines | In Progress |
| #558 | win-cli commandTimeout | All machines | In Progress (deployment) |
