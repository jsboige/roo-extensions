# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 6 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (ListTools):** 39 (20 inline + 19 roosyncTools) after CLEANUP-3
- **RooSync tools (roosyncTools):** 19 entries in index.ts
- **Claude wrapper (mcp-wrapper.cjs):** 18 tools exposed
- **Gap:** roosyncTools has `roosync_heartbeat_service` not in wrapper
- **Deprecated tools:** 11 removed from ListTools by CLEANUP-3 (CallTool handlers kept for backward compat)
- **Tests:** 1829 passed, 0 failed (160 files, 2026-02-07)

### Key Files
| File | Purpose |
|------|---------|
| `src/tools/registry.ts` | Central tool registration (ListTools + CallTool) |
| `src/tools/roosync/index.ts` | RooSync exports + roosyncTools array |
| `mcp-wrapper.cjs` | Claude Code wrapper (whitelist filter) |
| `src/tools/roosync/*.ts` | Individual tool implementations |
| `src/tools/roosync/__tests__/*.test.ts` | Unit tests |

### Adding a New Tool - Checklist
1. Create `src/tools/roosync/tool-name.ts` with function + metadata export
2. Create `src/tools/roosync/__tests__/tool-name.test.ts`
3. Add export to `src/tools/roosync/index.ts`
4. Add metadata to `roosyncTools` array in index.ts
5. Add `case 'tool_name':` handler in `src/tools/registry.ts` CallTool switch
6. Add to `ALLOWED_TOOLS` Set in `mcp-wrapper.cjs` (if for Claude)
7. Build: `npx tsc --noEmit`
8. Test: `npx vitest run`

## Consolidation History (CONS)

| CONS | Description | Before | After | Machine | Status |
|------|-------------|--------|-------|---------|--------|
| CONS-1 | Messaging | 6 tools | 3 tools | myia-po-2024 | Done |
| CONS-2 | Heartbeat | 7 tools | 2 tools | myia-po-2024 | Done |
| CONS-3 | Config | 3 tools | 1 tool | myia-ai-01 | Done |
| CONS-4 | Baseline | 3 tools | 1 tool | myia-ai-01 | Done |
| CONS-5 | Decisions | 5 tools | 2 tools | myia-po-2024 | Done |
| CONS-6 | Inventory/Machines | 4 tools | 2 tools | myia-ai-01 | Done |
| CONS-9 | Tasks | 4 tools | 2 tools | myia-po-2024 | Done |
| CONS-10 | Export | 6 tools | 2 tools | myia-po-2024 | Done |
| CONS-11 | Search/Indexing | 4 tools | 2 tools | myia-po-2023 | Done |
| CONS-12 | Summary | 3 tools | 1 tool | myia-ai-01 | Done |
| CONS-13 | Storage/Repair | 6 tools | 2 tools | myia-po-2024 | Done |

## Current State (2026-02-12)

**CONS-#443 (finale consolidation 39→18) in progress.** G1+G5 done.

| Metric | Value |
|--------|-------|
| Total tools (ListTools) | 39 (wrapper v4 pass-through) |
| RooSync tools (roosyncTools) | 19 |
| Claude wrapper tools | 39 (pass-through, no filtering) |
| Tests passing | 3252 |
| Test files | 201 |
| GitHub Project #67 | 159 items, ~128 Done (83.7%) |
| Skills | 4 (validate, git-sync, github-status, sync-tour) |
| Scheduler | 3h interval, 6 machines staggered |
| Heartbeat | 3/6 machines (ai-01, po-2024, po-2025) |
| MCP Servers | roo-state-manager (TS) + sk-agent (Python, NEW) |

### Validation & Cleanup (myia-po-2023, 2026-02-07)

- **#400** - Multi-machine validation - count-tools.ps1 STATUS: OK
- **#409-411** - Manual testing consolidated tools (411 unit tests done: 30/30)
- **#412** - PROJECT_MEMORY.md updated
- **#413** - Dashboard regeneration (pending)
- **#419** - Automated tool count validation (DONE: count-tools.ps1 + validate-cons.ps1)

### VibeSync Issues (implemented by myia-po-2023)

- **#401** - Specialized Claude agents (done by myia-ai-01)
- **#402** - Multi-level memory management → **#420 done** (extract + merge scripts)
- **#403** - Scheduled Claude Code execution → **#416 done** (worker + scheduled sync)
- **#404** - Git worktrees + PR workflow → **#417 done** (3 scripts + doc)
- **#405** - Hierarchical CLAUDE.md → **#418 done** (5 templates + generator)
- **#406** - Port MCP tools to Claude wrapper (pending)

## Known Bugs / Gotchas

### Registry ListTools/CallTool mismatch (FIXED 2026-02-07)
- 6 consolidated tools had ListTools metadata but no CallTool handlers
- Caused "Tool not found" errors
- Fix: commit 4efbcb0

### npm test blocks in watch mode
- ALWAYS use `npx vitest run` not `npm test`
- `npm test` starts Vitest in watch mode (interactive, never exits)

### MCP tools load at VS Code startup only
- Code changes to tools need VS Code restart to take effect
- The wrapper caches the tools/list response

### Submodule workflow
- Commit in `mcps/internal` first, push
- Then `git add mcps/internal` in main repo, commit, push
- Both repos push to `origin/main`

### INTERCOM is gitignored
- `.claude/local/` is in .gitignore
- Don't try to `git add` INTERCOM files

### PowerShell 5.1 Join-Path (2 args only)

- `Join-Path $a "b" "c" "d"` FAILS on PS 5.1 (default Windows)
- Use string interpolation: `"$RepoRoot/mcps/internal/servers/roo-state-manager"`
- Always test with `powershell -ExecutionPolicy Bypass -File script.ps1`

## Decisions & Patterns

### Consolidated tool pattern
- Use `action` or `mode` parameter for routing
- Keep legacy CallTool handlers for backward compatibility
- Remove legacy entries from ListTools (roosyncTools) and wrapper
- Legacy source files stay (still imported by legacy handlers)

### Test mock pattern
- Mock `getSharedStatePath()` to point to `__test-data__/`
- Mock `getLocalMachineId()` to return `'test-machine'`
- Use `vi.importActual()` to preserve real exports alongside mocks

### Agent hierarchy
- Claude Code = primary brain (investigation, coding, decisions)
- Roo = assistant (tests, builds, repetitive tasks)
- Always validate Roo's work before committing

### RooSync vs INTERCOM protocol (CRITICAL - 2026-02-11)
- **RooSync** = EXCLUSIVELY Claude Code inter-machine communication
- **INTERCOM** = Local Roo <-> Claude Code communication (same machine)
- **Roo NEVER uses RooSync tools** (roosync_send, roosync_read, etc.)
- Enforced in workflow files + rules `.roo/rules/03-mcp-usage.md`

### Case-sensitive machineId (FIXED - 2026-02-12)
- Windows hostname returns mixed case (e.g., `MyIA-Web1`)
- Always `.toLowerCase()` on machineId (commit bd8e5b94)
- Fixed in: roosync-config.ts, message-helpers.ts, InventoryService.ts

### Scheduler cache bug
- Roo Scheduler extension caches schedules.json at VS Code startup
- Deploy config then restart VS Code IMMEDIATELY before next tick
- `.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy`

### Embeddings migration (2026-02-11)
- Qwen3-4B AWQ self-hosted on myia-ai-01 (RTX 4090)
- Endpoint: `https://embeddings.myia.io/v1`
- 2560 dims, ~287 req/s, zero cost, +15% quality over OpenAI
- Risk: previous overrun cost 200EUR - always rate-limit (#453)

## Active Issues (2026-02-12)
| # | Title | Priority |
|---|-------|----------|
| #443 | Consolidation finale 39→18 (G1+G5 done) | HIGH |
| #452 | MCP outil exploitation index semantique | MEDIUM |
| #453 | Qdrant task indexation | MEDIUM |
| #458 | E2E validation post-CONS-#443 | HIGH |
| #459 | Scheduler deployment remaining machines | HIGH |
| #460 | Dashboard + heartbeat automation | HIGH |
| #461 | Worktree integration | MEDIUM |
| #462 | Autonomy roadmap | MEDIUM |
| #463 | Cross-workspace template | LOW |
| #464 | Dev Containers + Ralph Wiggum | MEDIUM |
| #465 | sk-agent MCP proxy LLM multi-modeles | MEDIUM |

### sk-agent MCP Server (NEW - 2026-02-12)
- **Location**: `mcps/internal/servers/sk-agent/`
- **Type**: Python (FastMCP + Semantic Kernel), unlike roo-state-manager (TypeScript)
- **Tools**: `ask(prompt)`, `analyze_image(source, prompt)`, `list_tools()`
- **Purpose**: Proxy OpenAI-compatible models (vLLM, Open-WebUI) as MCP tools
- **Models**: GLM 4.7 Flash (agentic, no vision), Qwen 8B VL (vision + tools)
- **Architecture**: FastMCP stdio -> Semantic Kernel -> OpenAI API -> vLLM
- **Child MCPs**: SearXNG (web search), Playwright (browser) - configurable via JSON
- **Use cases**: Vision for Roo simple modes, Oracle (small model queries big model), local LLM proxy
- **API keys**: Private per-machine, NOT in git. Distribute via RooSync.
- **Issue**: #465

### Knowledge Consolidation Workflow (NEW - 2026-02-12)
- **sync-tour Phase 8**: Automatic consolidation at end of each sync-tour
- **Private memory**: `~/.claude/projects/.../memory/MEMORY.md` (per-machine, auto-loaded)
- **Shared memory**: `.claude/memory/PROJECT_MEMORY.md` (via git, all machines)
- **Scripts**: `scripts/memory/extract-shared-memory.ps1` (private->shared), `merge-memory.ps1` (shared->private)
- **Rule**: ALWAYS consolidate before session ends to preserve experience
