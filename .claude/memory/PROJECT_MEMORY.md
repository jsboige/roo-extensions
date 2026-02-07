# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 5 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (registry.ts):** 50 (31 inline + 19 roosyncTools)
- **RooSync tools (roosyncTools):** 19 entries in index.ts
- **Claude wrapper (mcp-wrapper.cjs):** 18 tools exposed
- **Gap:** roosyncTools has `roosync_heartbeat_service` not in wrapper
- **Deprecated tools kept:** ~10 (backward compat in CallTool, will be removed in CLEANUP-3)
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

## Current State (2026-02-07)

**All 11 consolidations are DONE.** No more CONS tasks open.

| Metric | Value |
|--------|-------|
| Total tools (ListTools) | 50 |
| RooSync tools (roosyncTools) | 19 |
| Claude wrapper tools | 18 |
| Tests passing | 1829 |
| Test files | 160 |
| Submodule commit | 4cb1f65 (CONS-5 wiring) |
| Parent commit | 4b48ccb |

### Next Phase: Validation & Cleanup
- **#400** - Multi-machine validation (tool count check)
- **#409-411** - Manual testing of consolidated tools
- **#412-413** - Documentation updates (PROJECT_MEMORY, Dashboard)
- **CLEANUP-3** (future) - Remove deprecated legacy tools from ListTools

### VibeSync Issues (long-term)
- **#401** - Specialized Claude agents
- **#402** - Multi-level memory management
- **#403** - Scheduled Claude Code execution
- **#404** - Git worktrees + PR workflow
- **#405** - Hierarchical CLAUDE.md
- **#406** - Port MCP tools to Claude wrapper

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
