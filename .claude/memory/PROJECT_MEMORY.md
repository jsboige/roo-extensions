# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 6 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (ListTools):** 36 (was 39 before #457 consolidation)
- **Claude wrapper (mcp-wrapper.cjs):** 36 tools (v4 pass-through, no filtering)
- **Tests:** 3305 passed, 0 failed (2026-02-18)
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

### RooSync vs INTERCOM protocol (CRITICAL)
- **RooSync** = EXCLUSIVELY Claude Code inter-machine communication
- **INTERCOM** = Local Roo <-> Claude Code on same machine
- **Roo NEVER uses RooSync tools**
- Enforced in workflow files + rules `.roo/rules/03-mcp-usage.md`

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

## Current State (2026-02-18)

**Phase**: MONTEE EN CHARGE (Cycle 9)
**Tests**: 3305 PASS, 0 FAILED | **Tools**: 36 | **GitHub #67**: ~161/179 Done (90%)

### sk-agent MCP (v2.0)
- **Location**: `mcps/internal/servers/sk-agent/`
- **Tools**: `call_agent`, `run_conversation`, `list_agents`, `list_conversations`, `list_tools`, `end_conversation`
- **Agents**: 11 | **Conversations**: 4 | **Tests**: 109 unit + 35 functional
- **4 Models**: Cloud reasoning (Opus/Sonnet), Cloud vision, Local reasoning (GLM-5), Local vision
- **Fix #482**: Write-Host polluted stdout. Use `[Console]::Error.WriteLine()` only.

### EMBEDDING Config (required in .env for codebase_search)
```
EMBEDDING_MODEL=qwen3-4b-awq-embedding
EMBEDDING_DIMENSIONS=2560
EMBEDDING_API_BASE_URL=https://embeddings.myia.io/v1
EMBEDDING_API_KEY=365f36ffbff3f43de53299625590381aa48eaf3cf8cc3b6162b59559cb35a9d500e6f1
QDRANT_URL=https://qdrant.myia.io
QDRANT_API_KEY=4f89edd5-90f7-4ee0-ac25-9185e9835c44
```
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
