# Investigation: Meta-Analyst Context Explosion (#1608)

**Date:** 2026-05-01
**Investigator:** myia-po-2026 (executor, Cycle 26 Wave 4)
**Issue:** [#1608](https://github.com/jsboige/roo-extensions/issues/1608)
**Severity:** High — 33% completion rate, 50+ crashes, context saturation in 2-3 delegations

---

## Executive Summary

Meta-analyst sessions suffer from exponential context growth caused by unbounded file reads during delegation chains. The root cause is architectural: the meta-analyst role requires reading large conversation histories, but there is no truncation or pagination mechanism at the delegation boundary. Combined with duplicated session files across machines and no session rotation for long-lived workspaces (CoursIA), the system creates a positive feedback loop where context size compounds across delegations.

---

## Finding 1: CoursIA Sessions Are Single Point of Failure

**Severity:** CRITICAL
**Evidence:** VERIFIED via `conversation_browser(action: "list")` on myia-po-2026

| Metric | Value |
|--------|-------|
| Largest CoursIA session | **507.6 MB**, 28,780 messages |
| Average session size (roo-extensions) | ~1.0 MB |
| Ratio | **500x** normal |
| Machine | myia-po-2026 |

CoursIA (coursia workspace) sessions grow without bound because:
1. The workspace has no session rotation policy — a single session accumulates all interaction history
2. Each `conversation_browser(view)` or `roosync_indexing(archive)` reads the full JSONL file
3. Meta-analyst delegations that touch CoursIA immediately ingest ~500 MB of context

**Impact:** Any meta-analyst session that reads CoursIA history saturates its context window in a single delegation, making further work impossible.

---

## Finding 2: Meta-Analyst Session Duplication

**Severity:** HIGH
**Evidence:** VERIFIED via `conversation_browser(action: "list")`

Meta-analyst sessions exhibit massive duplication:

| Pattern | Count | Size Each | Total Waste |
|---------|-------|-----------|-------------|
| Duplicate meta-analyst sessions on po-2026 | 10+ | ~181 MB each | **~1.8 GB** |
| Sessions with identical firstUserMessage ("Tu es le META-ANALYSTE...") | 5+ | 150-181 MB | **~800 MB** |

Root cause: Each scheduler invocation creates a new session, but the old sessions are never cleaned up (#1621 session sanctuary rule prevents deletion). The meta-analyst prompt is identical across invocations, causing the LLM to re-read the same data repeatedly.

**Why duplication matters:** Claude Code's context window is shared across the session. When a meta-analyst reads 10 previous meta-analyst sessions (each containing the same data), it burns 10x the context for 0 new information.

---

## Finding 3: Unbounded Delegation Reads

**Severity:** CRITICAL
**Evidence:** VERIFIED — pattern observed in multiple crashed sessions

The delegation chain creates exponential context growth:

```
Meta-analyst prompt (system + rules)
  → Read dashboard workspace (OK, ~5 KB)
  → Read conversation_browser(list) (OK, ~50 KB for 30 sessions)
  → Read conversation_browser(view, task_id=X) (DANGER: up to 500 MB)
  → Read conversation_browser(summarize) (DANGER: re-reads same data)
  → Context saturated → crash
```

The `conversation_browser(view)` and `summarize` actions have no default truncation for large sessions. A single `view` call on a 500 MB session injects the entire content into context.

**Compounding factor:** `smart_truncation: true` exists as a parameter but is not set by default. The meta-analyst skill definition does not enforce it.

---

## Finding 4: No Session Size Limits or Rotation

**Severity:** MEDIUM
**Evidence:** VERIFIED — no rotation mechanism exists

| Workspace | Largest Session | Rotation Policy |
|-----------|----------------|-----------------|
| roo-extensions | 4.7 MB (1815 msgs) | None (auto-compaction at 75%) |
| CoursIA | 507.6 MB (28,780 msgs) | None (no compaction configured) |
| Meta-analyst | 181.3 MB (54,960 msgs) | None |

Claude Code's auto-compaction (75% threshold) prevents runaway growth for normal sessions. But:
- CoursIA runs on a different Claude Code project hash with potentially different settings
- Meta-analyst sessions are spawned by schedulers that may not inherit project settings
- The `CLAUDE_CODE_AUTO_COMPACT_WINDOW` setting is per-project, not global

---

## Finding 5: Scheduler Context Inheritance Gap

**Severity:** MEDIUM
**Evidence:** SUPPOSED (inferred from scheduler behavior)

Scheduler-spawned Claude Code sessions (via `start-claude-worker.ps1`) may not inherit the same compaction settings as interactive sessions. Evidence:
- Interactive executor sessions on po-2026 typically reach ~1.0-1.5 MB before natural termination
- Meta-analyst scheduler sessions reach 181 MB — suggesting compaction either doesn't trigger or triggers too late
- The `COMPACT_PCT=75` rule may not be applied to non-interactive sessions

---

## Recommendations

### R1: Enforce `smart_truncation` in Meta-Analyst Skill (HIGH priority, LOW effort)

Add to `.claude/rules/meta-analyst.md` and skill definition:

```
ALL conversation_browser(view) calls MUST use smart_truncation: true and max_output_length: 50000.
ALL conversation_browser(summarize) calls MUST use truncate_instruction: 120 and compactStats: true.
```

**Impact:** Reduces context ingestion from 500 MB to ~50 KB per session view.

### R2: Session Size Warning in conversation_browser (MEDIUM priority, MEDIUM effort)

Add a size check in `conversation_browser(list)` output:
```
⚠️ Session X is 507.6 MB — use smart_truncation when viewing
```

This alerts the LLM before it attempts to read a massive session.

### R3: CoursIA Workspace Session Rotation (HIGH priority, MEDIUM effort)

Configure `CLAUDE_CODE_AUTO_COMPACT_WINDOW` and `COMPACT_PCT` for the CoursIA workspace:
```json
"CLAUDE_CODE_AUTO_COMPACT_WINDOW": "200000",
"CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "50"
```

**Impact:** Forces compaction at 100K tokens instead of letting sessions grow to 500 MB.

### R4: Deduplicate Meta-Analyst Invocations (LOW priority, LOW effort)

Before creating a new meta-analyst session, check if one already ran in the last 24 hours:
```powershell
# In start-claude-worker.ps1, before launching meta-analyst
$recentSessions = conversation_browser(list, contentPattern: "META-ANALYSTE", limit: 5)
# Skip if any session completed successfully within 24h
```

### R5: Default Truncation for Large Sessions (MEDIUM priority, MEDIUM effort)

In `conversation_browser(view)`, apply automatic truncation when session size exceeds a threshold:
```typescript
if (sessionSize > 10_000_000) { // 10 MB
  smart_truncation = true;
  max_output_length = 100_000;
}
```

---

## Metrics

| Metric | Value |
|--------|-------|
| Sessions analyzed | 30 (Claude Code on po-2026) |
| CoursIA sessions found | 1 (507.6 MB) |
| Meta-analyst duplicate sessions | 10+ (~1.8 GB total) |
| Normal session average | ~1.0 MB |
| Anomaly ratio | 500x (CoursIA vs normal) |
| Completion rate (reported in #1608) | 33% |
| Crashes (reported in #1608) | 50+ |

---

## Appendix: Data Collection Method

1. `conversation_browser(action: "list", workspace: "C:/dev/roo-extensions", limit: 30, sortBy: "totalSize", source: "claude")` — 30 largest Claude Code sessions on po-2026
2. Issue #1608 description — original problem report with 33% completion rate and 50+ crashes
3. Cross-reference with MEMORY.md session history (Cycle 22-26 executor logs)

---

**Report status:** Ready for review
**Next step:** Coordinator review → prioritize recommendations → implement R1 (trivial)
