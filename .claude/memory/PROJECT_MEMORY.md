# Project Memory - roo-extensions

Shared knowledge base for all Claude Code agents across 6 machines.
Updated via git commits. Each agent should read this at session start.

## Architecture

### MCP Tool System
- **Total tools (ListTools):** 15 — verified 2026-05-19 via mcp-tools.myia.io E2E + build/.tools-cache.json + roosync_indexing
- **Historical:** 39 (pre-CONS) → 34 (post CONS-1→#675, 2026-03) → 15 (current, post all CONS rounds)
- **Claude wrapper (mcp-wrapper.cjs v4.1):** pass-through + persisted cache in `build/.tools-cache.json` (NOT %TEMP%, Windows Disk Cleanup safe)
- **Tests:** 7933 passed, 26 skipped (2026-03-20)
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

### Adding a Parameter to an Existing Tool — 3 Surfaces (+ derived paths)
*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-01). Complement of the checklist above: that one covers new tools, this one the most common edit after.*

Adding a param to a roo-state-manager tool is **never a one-file edit**:

1. **Zod schema** (`*ArgsSchema` / tool args interface) — the obvious surface.
2. **Static wire schema** in `src/tools/tool-definitions.ts` — the drift-guard (#3254) requires **exact key parity** with the zod schema. A zod field without its wire key = red CI.
3. **Unit-test mocks with EXACT arity** — `toHaveBeenCalledWith` rejects a 7-arg call when the test expects 6, even if the 7th is `undefined`; and a mock object missing a method the code now calls = `TypeError` on **all** tests of the file, not just the new param's.

**Plus propagation:** if the param changes a read path (e.g. a `deep` flag), every **derived** path must receive it too (e.g. `getFilteredCount` — otherwise derived counts come from the full pool while the listing serves the slice: visible inconsistency).

**Why:** targeted tests green ≠ suite green — a first full-suite pass caught 12 regressions (11 mock-layer + 1 drift-guard) after 4 targeted tests passed. Always run the full CI suite (`npx vitest run --config vitest.config.ci.ts`) before concluding.

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

### Comment/code divergence — grep the named mechanism before push

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-02).*

When a comment (code, PR body, issue) names a precise mechanism — cmdlet, condition, convention — **grep the code for that mechanism before pushing**. Review-by-effects sees nothing: these defects are only readable at the named condition/call site, not in behavior.

- **Before push:** if a comment references a mechanism, `grep` the exact name in the emitted diff.
- **In PR review:** read the code's comments AND verify the named condition actually exists — a read of the *condition*, not of the effects.
- **Why:** three occurrences in one day (2026-08-21): #3208 (backup guard claimed in a comment, absent from code), #1023 ("Condensation stamp" claimed guarded by `!backfill` — it wasn't), #3209 (comment said "killable by `Stop-Job`" while the code only did `Remove-Job -Force`). The third was caught an hour *after* a review had explicitly cited this exact defect class — the class is easy to name and easy to miss.

### Validate the measurement harness before concluding a fix failed

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-02).*

When a measurement contradicts a fix you have just verified in the code, **suspect the instrument before the fix**. A buggy harness produces credible-looking numbers that are simply wrong.

- **Absolute paths, always**, when spawning a process from a test or ad-hoc measurement — `cwd` changes relative-path resolution; the process dies at 0.1 s on `MODULE_NOT_FOUND` while the harness reports "cold start 76 s" or "timeout".
- **Never swallow stderr** in a disposable harness — a silent `p.stderr.on('data',()=>{})` turns an instant crash into a phantom latency.
- **Aberrant timing (too slow AND too fast)** = first verify the measured process is actually alive.
- **Separate the server's first-call cost** (lazy load, paid once by whichever tool runs first) from the cost of the tool being measured — otherwise the tool inherits a latency that isn't its. Measure a different tool first to isolate.

**Why:** #3292 re-measurement (2026-09-01): a harness spawned the server with a changed `cwd`; the relative path died at startup, stderr was discarded, and the run reported "76.7 s cold start / 200 s timeout" for a server that actually answers in 0.4–0.6 s — numbers that nearly went out as "fix #1052 doesn't work". Same fault class as concluding from a threshold without having the value: acting on an unvalidated instrument.

### Cite fresh measurement artifacts from the tree being changed

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-02).*

When citing coverage stats (or any regenerated measurement artifact) as a pre-work baseline in `[CLAIMED]` or pre-work analysis, read the **worktree's** artifact — never the parent checkout's. The parent's copy is refreshed only when a full run happens there, so it can describe a state several cycles old, especially after a submodule pointer bump.

- **Run the measurement from inside the worktree**, so the emitted JSON describes the code you are about to change.
- **Pass the worktree's artifact path** to any analyzer script — never a parent-tree path picked by convenience.
- **Cite those fresh numbers** as the baseline; a stale one silently misstates both the starting point and the credit for the work delivered.
- A mismatch discovered after the fact must be corrected in the [DONE] — acceptable only when the delivered work matches the post-PR fresh state.

**Why:** Sprint C3 coverage work: a [CLAIMED] cited "11 cold branches / 89.7%" read from the parent repo's `coverage-final.json` (stale, pre-#751 merge — the post-work state of a *previous* cycle). The worktree's fresh run showed the real baseline: 18 cold branches / 67.95%. Complement of the harness rule above: there the instrument was wrong; here the instrument was right but pointed at a stale artifact of the wrong tree.

### Reach the errors>0 log branch by throwing per-extractor, not per-iteration

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-04, 5th of the series).*

In `MessageExtractionCoordinator.extractFromMessages()` (roo-state-manager submodule), the `logExtractionSummary(result)` call sits **inside** the outer `try`, and the global `catch` appends to `result.errors` *after* the summary has been bypassed. So an exception thrown at **iteration level** (e.g. a throwing `Symbol.iterator`) jumps straight to the global catch — the summary call never runs, and the `Error details:` log (which only fires when `result.errors.length > 0` at summary time) is unreachable that way.

To cover the `errors > 0` branch of the summary log, throw **inside a per-extractor `extract()`** instead:

```ts
const extractors = (coordinator as any).extractors as any[];
extractors[0].extract = () => { throw new Error('synthetic'); };
// pass a message shape that makes the extractor's canHandle return true
coordinator.extractFromMessages(messages, { enableDebug: true });
// → per-extractor try/catch populates result.errors WITHOUT escaping
//   the outer try → summary runs with errors > 0 → "Error details" logs
```

- **Mechanism, not lines:** verified intact 2026-09-04 (`src/utils/message-extraction-coordinator.ts` — summary call in `try`, global catch bypasses it). Exact line numbers drift; grep `logExtractionSummary` to relocate.
- **General form:** when a summary/report call lives inside the same `try` as the loop it reports on, only errors swallowed *below* the loop's handler reach it — design the throw at the same depth the production code recovers.

**Why:** Sprint C3 (web1 c.30): a coverage test aimed a throw at the iteration level, saw the test pass, and assumed the `errors > 0` summary branch was covered — it was not; the global catch had bypassed the summary entirely. Fleet-relevant for any machine writing vitest coverage on the submodule (po-2023/24/25, ai-01, web1); zero machine-specific content.

### extractFromMessages() re-reads debug flags from options — env vars alone stay silent

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-04, 6th of the series).*

In `MessageExtractionCoordinator` (roo-state-manager submodule), the constructor sets `this.debugEnabled` from `process.env.ROO_DEBUG_INSTRUCTIONS === '1'`, and the head of `extractFromMessages()` has a diagnostic block that sets it again from the same env var — **but a few lines later the unconditional assignment `this.debugEnabled = options.enableDebug || false;` flattens both back**. Setting the env var in a test therefore produces a constructor-time `true` that is dead before any message is processed.

To assert on debug log lines, pass the option:

```ts
coordinator.extractFromMessages(messages, { enableDebug: true });
```

Without `enableDebug: true`, every gated branch stays silent: the per-message trace, the extractor-matched log, the no-extractor-matched log, `logExtractionSummary` (including its `errors > 0` "Error details" block — see the lesson above), and `logError`. A test asserting on those lines passes vacuously: the guard `if (!this.debugEnabled) return;` short-circuits before them.

- **Mechanism, not lines:** verified intact 2026-09-04 (`src/utils/message-extraction-coordinator.ts` — unconditional `options.enableDebug || false` assignment inside `extractFromMessages`). Exact line numbers drift; grep `enableDebug` to relocate.
- **General form:** when a method re-derives a flag from its `options` argument mid-body, constructor state and env vars are not state — pass the option, don't rely on ambient setup.

**Why:** Sprint C3 (web1 c.30): coverage tests stubbed `ROO_DEBUG_INSTRUCTIONS='1'`, saw green, and believed the debug branches were covered — the mid-body reset had zeroed the flag and the asserted branches never ran. Fleet-relevant for any machine writing vitest coverage on the submodule (po-2023/24/25, ai-01, web1); zero machine-specific content.

### A constructor-ordering branch can be unreachable by design — skip with evidence, don't reorder

*Promoted T5→T6 (#2368 ACTION-B, web1 2026-09-05, 7th of the series).*

In `MessageExtractionCoordinator` (roo-state-manager submodule), the constructor calls `this.initializeExtractors()` **before** assigning `this.debugEnabled` from the env var — so the `if (this.debugEnabled)` log inside `initializeExtractors()` is always evaluated against the class-field default `false`. The truthy arm is **unreachable by design**: no test input can reach it, because the flag is set only after the guarded code has already run.

For coverage work, the correct response is **skip-with-evidence, not source mutation**:

```ts
// unreachable-by-design: initializeExtractors() runs in the constructor BEFORE
// this.debugEnabled is assigned from the env var — this log always sees false.
it.todo('extractor-init debug log — unreachable by constructor ordering');
```

- **Mechanism, not lines:** verified intact 2026-09-05 (`src/utils/message-extraction-coordinator.ts` — constructor: `initializeExtractors()` then `debugEnabled = env`; the guarded log lives inside `initializeExtractors`). Exact line numbers drift; grep `initializeExtractors` to relocate.
- **Companion of the options-reset lesson above:** that one kills debug flags set *before* the call (env vars flattened by `options.enableDebug || false`); this one kills them set *after* the call — together, only `{ enableDebug: true }` at call sites exercises debug branches.
- **Do not "fix" by reordering the source:** a coverage gap caused by construction order is a design fact, not a bug — reordering production code so a test can reach a log line is churn (surgical-changes rule).

**Why:** Sprint C3 (web1 c.30): the truthy arm was unreachable from any test seam without editing the source; the temptation to reorder production code for a coverage line was rejected and the gap documented instead. Fleet-relevant for any machine writing vitest coverage on the submodule; zero machine-specific content.

## Known Bugs / Gotchas

## Known Bugs / Gotchas

### Critical (recurring)
- **npm test blocks**: ALWAYS use `npx vitest run` not `npm test`
- **MCP tools load at startup only**: Code changes need VS Code restart
- **Submodule workflow**: Commit inside first, push, then `git add mcps/internal` in parent
- **JSON BOM**: Some GDrive files have BOM. Strip before parsing: `data.charCodeAt(0) === 0xFEFF`
- **PowerShell 5.1 Join-Path**: Only 2 args. Use string interpolation for deeper paths.
- **Case-sensitive machineId**: Always `.toLowerCase()` (commit bd8e5b94)
- **Scheduler cache**: Deploy config then restart VS Code IMMEDIATELY before next tick
- **MCP_TIMEOUT variable**: Set to `300000` (300s) on all machines for sk-agent (semantic_kernel slow load). Windows: `setx MCP_TIMEOUT "300000"`

## Current State (2026-03-20)

**Phase**: MAINTENANCE (Issues #556, #473 Active)
**Tests**: 7933 PASS, 26 skipped | **Tools**: 15 (post all CONS) | **GitHub #67**: Progression continue

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
- ✅ Documentation updated in `docs/harness/reference/scheduler-densification.md`

**Archived:** `.claude/memory/archive/issue-545-escalation-observation-plan.md`

### Memory Files Archived (Cycle 49)
- ✅ `.claude/memory/archive/issue-545-escalation-observation-plan.md` (Plan obsolète, issue fermée)
- ✅ `.claude/memory/archive/SONNET_4.6_RELEASE.md` (Info ponctuelle)

### Active Issues
| Issue | Title | Scope | Status |
|-------|-------|-------|--------|
| #556 | Memory Redistribution & Rules Audit | All machines | In Progress |
| #473 | Auto-approbations alwaysAllow | All machines | In Progress |
| #679 | Qdrant Indexer Null-Safety | All machines | Fixed (4 crash paths) |

### sk-agent MCP (v2.0)
- **Location**: `mcps/internal/servers/sk-agent/`
- **Tools**: `call_agent`, `run_conversation`, `list_agents`, `list_conversations`, `list_tools`, `end_conversation`
- **Agents**: 16 (core 7 + roles 3 + specialized 3 + audit 3) | **Conversations**: 6 | **Tests**: 109 unit + 35 functional
- **3 Models**: Qwen3.5 (262K ctx), GLM-4.7-Flash (131K ctx), OWUI (vision)
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
| #545 | Roo Complex Mode Graduation | All machines | **CLOSED** ✅ |
| #555 | GLM-5 Condensation Parameters | All machines | **CLOSED** ✅ |
| #556 | Memory Redistribution & Rules Audit | All machines | In Progress |
| #679 | Qdrant Indexer Null-Safety | All machines | Fixed (po-2025 verified) |
| #1377 | Memory Auto-Injection (Reddit pattern) | All machines | **CLOSED** ✅ |

### Memory Auto-Injection (#1377) - IMPLEMENTED ✅

**Status:** Feature implémentée, skill `memory-inject` créé
**Pattern source:** Reddit 3-agent setup analysis (#1369)

**Fonctionnalité:**
- Auto-injection des leçons MEMORY.md au début de chaque tâche
- Détection automatique du type de tâche (mcp, test, git, build, etc.)
- Filtrage par pertinence (scoring basé sur récurrence, impact, fraîcheur)
- Intégration dans le Session Pattern (étape 1.5)

**Fichiers créés:**
- `.claude/skills/memory-inject/SKILL.md` - Skill principal
- `docs/knowledge/MEMORY-AUTO-INJECTION.md` - Documentation

**Impact attendu:**
- -50% d'erreurs récurrentes (estimation Reddit)
- < 1 seconde de surcharge par tâche
- Maintenance mensuelle faible
