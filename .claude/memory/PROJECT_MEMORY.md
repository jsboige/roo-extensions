# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 6 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (ListTools):** 36 (was 39 before #457 consolidation)
- **Claude wrapper (mcp-wrapper.cjs):** 36 tools (v4 pass-through, no filtering since 2026-02-10)
- **Tests:** 3294 passed, 0 failed (202 files, 2026-02-17)
- **MCP Servers:** roo-state-manager (TypeScript) + sk-agent (Python/FastMCP)

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
6. Build: `npm run build` (output in `build/`, NOT `dist/`)
7. Test: `npx vitest run` (NEVER `npm test`)
8. Update `alwaysAllow` in Roo mcp_settings.json (use `sync_always_allow` subAction)
9. Restart VS Code (MCPs load at startup only)

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
| CONS-X #457 | Conversation Browser | 3 tools | 1 tool | myia-po-2023 | Done |

## Current State (2026-02-13 02:30)

**CONS-X #457 completed.** conversation_browser consolidates 3→1 tool. G1+G5+CONS-X done.
**#453 Phase 1 done:** Embedding model/dims/batch/baseURL configurable via env vars.

| Metric | Value |
|--------|-------|
| Total tools (ListTools) | ~35 (16 inline + 19 roosyncTools) |
| RooSync tools (roosyncTools) | 19 |
| Claude wrapper tools | 39 (pass-through, no filtering) |
| Tests passing | 3281/3295 (14 skipped) |
| Test files | 202/203 (1 skipped) |
| GitHub Project #67 | 161+ items, ~164 Done |
| Skills | 5 (validate, git-sync, github-status, sync-tour, debrief) |
| Scheduler | 3h interval, 6 machines staggered, **Step 1b** added (#456) |
| Heartbeat | **Auto-start enabled** (6/6 config, #455 done) - Runtime: 1/6 online, 3/6 not registered, 2/6 offline (#460) |
| Machine Registry | 6 machines (case-sensitive duplicate fixed 2026-02-12) |
| MCP Servers | roo-state-manager (TS) + sk-agent (Python) + markitdown + playwright |

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
- **Pointer mismatch fix (2026-02-13)**: If parent points to commit not on remote (e.g., "not our ref c04314c2"), do `cd mcps/internal && git checkout main && git pull` then `git add mcps/internal` to update pointer

### INTERCOM is gitignored

- `.claude/local/` is in .gitignore
- Don't try to `git add` INTERCOM files

### GitHub GraphQL pagination (2026-02-13)
- API limit: 100 items max per query (NOT 200)
- Error: "Requesting 200 records on the connection exceeds the `first` limit of 100"
- Fix: Use `first: 100` in GraphQL queries
- For >100 items: use cursor pagination with `nextPageCursor`

### JSON BOM (UTF-8 Byte Order Mark)

- Some JSON files on GDrive have UTF-8 BOM (0xFEFF)
- Node.js `JSON.parse()` fails with "Unexpected token"
- **Fix**: Strip BOM before parsing: `if (data.charCodeAt(0) === 0xFEFF) data = data.substring(1);`
- Affected: `.machine-registry.json`, possibly others

### PowerShell ConvertFrom-Json case-insensitive keys

- PowerShell treats JSON keys as case-insensitive
- `{"MyIA-Web1": {...}, "myia-web1": {...}}` triggers "duplicate keys" error
- **Fix**: Use text manipulation (regex) or Node.js for case-sensitive JSON
- Example: `fix-machine-registry-duplicate.js` (Node.js) vs `.ps1` (text regex)

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

### Agent/skill/command maintenance (2026-02-12)
- **SDDD** = Semantic Documentation Driven Development (NOT "Semantic-Driven Development Documentation")
- **Project #70** deleted - ALL references purged from agents/skills/commands
- **mcp__github-projects-mcp__*** fully deprecated - replaced by `gh` CLI everywhere
- **Legacy RooSync tool names** cleaned → CONS-1 consolidated names only (roosync_send/read/manage)
- **Project agent overrides**: Only needed when genuinely project-specific. Global + `rules/` is often sufficient.
- **Machine count**: Always 6 (ai-01, po-2023, po-2024, po-2025, po-2026, web1). po-2025 was frequently missing.
- **Deprecation ripple**: When deprecating something, grep ALL `.claude/` files for references. Easy to miss.
- **Orphaned scripts**: Always grep references before assuming scripts are needed.

### Scheduler cache bug
- Roo Scheduler extension caches schedules.json at VS Code startup
- Deploy config then restart VS Code IMMEDIATELY before next tick
- `.\roo-config\scheduler\scripts\install\deploy-scheduler.ps1 -Action deploy`

### Embeddings migration (2026-02-11)
- Qwen3-4B AWQ self-hosted on myia-ai-01 (RTX 4090)
- Endpoint: `https://embeddings.myia.io/v1`
- 2560 dims, ~287 req/s, zero cost, +15% quality over OpenAI
- Risk: previous overrun cost 200EUR - always rate-limit (#453)

## Active Issues (2026-02-13)

| # | Title | Priority | Status |
|---|-------|----------|--------|
| #443 | Consolidation finale 39→18 (G1+G5+CONS-X done) | HIGH | In Progress |
| #452 | MCP outil exploitation index semantique | MEDIUM | Todo |
| #453 | Qdrant task indexation | MEDIUM | Todo |
| #456 | Scheduler feedback loop (Phase 3 Step 1b done) | MEDIUM | In Progress |
| #458 | E2E validation post-CONS-#443 | HIGH | Todo |
| #459 | Scheduler deployment remaining machines | HIGH | In Progress |
| #460 | Dashboard + heartbeat automation (1/5 fixed, procedures created) | HIGH | Todo |
| #461 | Worktree integration | MEDIUM | Todo |
| #462 | Autonomy roadmap | MEDIUM | Todo |
| #463 | Cross-workspace template | LOW | Todo |
| #464 | Dev Containers + Ralph Wiggum | MEDIUM | Todo |
| #465 | sk-agent MCP proxy LLM multi-modeles | MEDIUM | In Progress |

**Closed recently:** #455, #466, #451, #433, #457 (5 issues)

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
- **Global user**: `~/.claude/CLAUDE.md` (cross-project preferences, local only)
- **Git template**: `.claude/configs/user-global-claude.md` (propagatable via git)
- **Propagation**: `Copy-Item .claude/configs/user-global-claude.md $env:USERPROFILE\.claude\CLAUDE.md`
- **Scripts**: `scripts/memory/extract-shared-memory.ps1` (private->shared), `merge-memory.ps1` (shared->private)
- **Skill**: `redistribute-memory` - audit and redistribute info across all memory/rules levels
- **Rule**: ALWAYS consolidate before session ends to preserve experience

### Claude Code Configuration Hierarchy
| Level | File | Scope | In Git? |
|-------|------|-------|---------|
| Global user | `~/.claude/CLAUDE.md` | All projects on this machine | No (deploy from template) |
| Global settings | `~/.claude/settings.json` | Permissions, model, MCPs | No |
| Project instructions | `CLAUDE.md` (repo root) | This project | Yes |
| Project auto-memory | `~/.claude/projects/<hash>/memory/MEMORY.md` | Per-machine private | No |
| Shared memory | `.claude/memory/PROJECT_MEMORY.md` | All machines | Yes |
| Rules | `.claude/rules/*.md` | Project-specific rules | Yes |

### Qdrant Semantic Indexation Infrastructure
- **Qdrant**: `http://localhost:6333` (local on myia-ai-01)
- **Embeddings**: `https://embeddings.myia.io/v1/embeddings` (Qwen3-4B AWQ)
- **Collection naming**: `ws-<sha256(workspace).substring(0,16)>`
- **Payload structure**: `filePath`, `codeChunk`, `startLine`, `endLine`
- **Workflow**: Scan -> Chunk -> Embed -> Upload -> Watch
- **Issues**: #452 (workspace search tool), #453 (task re-indexation)

### MCP Safe Update Pattern (NEW - 2026-02-12)
- **`sync_always_allow`**: Programmatically update `alwaysAllow` array for any MCP server
- **`update_server_field`**: MERGE individual fields (vs `update_server` which REPLACES entire config)
- **Issue**: #466 - Per-machine deployment checklist
