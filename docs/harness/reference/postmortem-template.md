# Postmortem Template — Multi-Agent Incident Analysis

**Version:** 2.0.1
**Issue:** #1244 Phase 2 (cross-machine browsing now operational)
**MAJ:** 2026-08-12

---

## Purpose

Structured template for postmortems of multi-agent incidents where agent reports diverged from real-world outcomes. Derives from the CoursIA slides migration failure (2026-04-08).

**v2.0.0 change:** Cross-machine browsing via `conversation_browser` is operational. The previous "Tool Limitations" section listed it as unsupported — that is no longer accurate.

**v2.0.1 correction:** v2.0.0 also claimed the cold-start timeout was *fixed*. That claim was a
po-2023 measurement relayed as a property of the tool, and it does not hold everywhere — see
[Cold-start performance](#tool-capabilities-verified-2026-08-12) below.

## Template

Copy the sections below into a new issue or doc. Fill each section with evidence.

```markdown
# Postmortem: [Incident Title]

**Date:** YYYY-MM-DD
**Workspace:** [workspace name]
**Machines involved:** [list]
**Severity:** [HIGH/CRITICAL] — [1 sentence why]
**Reporter:** [who flagged it]

## 1. Executive Summary

[2-3 sentences: what happened, what the agents reported, what the reality was.]

## 2. Timeline

| Time (UTC) | Machine | Agent | Event | Source |
|------------|---------|-------|-------|--------|
| HH:MM | machine | Claude/Roo | What happened | task_id / dashboard |

Start from the first relevant action. Include:
- Task creation and assignment
- Agent status reports ([DONE], [CLAIMED])
- User interventions (BLOCAGE/CORRECTION/STOP)
- Point of divergence (report vs reality)
- User discovery of the gap

## 3. Root Cause Analysis

### 3.1 Technical Cause
[What went wrong technically — code, config, tooling, environment]

### 3.2 Process Cause
[What went wrong in the harness — wrong signals, missing validation, premature [DONE]]

### 3.3 Assessment Failure
[Where the agent(s) self-assessed incorrectly — claimed success when deliverable was broken]
- Agent said: "[quote from dashboard/trace]"
- Reality: "[what actually happened]"

## 4. Evidence Trail

### Traces consulted
- conversation_browser task_ids: [list]
- Dashboard workspace messages: [date range]
- roosync_search queries: [list]
- Git commits: [SHAs]

### Key findings
- [Finding 1 with trace reference]
- [Finding 2 with trace reference]

## 5. Recommendations

| # | Recommendation | Type | Priority | Issue |
|---|---------------|------|----------|-------|
| 1 | [Concrete action] | rule/tool/process | P1/P2/P3 | #[issue] |

Types:
- **rule**: Change to .claude/rules/ or .roo/rules/
- **tool**: Code change in roo-state-manager or other MCP
- **process**: Workflow change (dispatch, review, validation)

## 6. Lessons Learned

- [Lesson 1]
- [Lesson 2]

## 7. Action Items

- [ ] [Action 1] — assigned to [machine/person], deadline [date]
- [ ] [Action 2] — assigned to [machine/person], deadline [date]
```

---

## Investigation Workflow

### Step 1: Identify the incident

Sources:
- User report (BLOCAGE/CORRECTION in traces)
- Dashboard [FRICTION] or [ERROR] messages
- `roosync_search(has_errors: true)` for error patterns
- `roosync_search(role: "user", exclude_tool_results: true)` for user interventions

### Step 2: Gather traces (cross-machine — verified operational as of 2026-08-12)

`conversation_browser` loads cross-machine archives from `ROOSYNC_SHARED_PATH/task-archive/<machineId>/`
on first call. That first call may be slow enough to hit the 30s tool ceiling — see
[Cold-start performance](#tool-capabilities-verified-2026-08-12). If it errors out, call again:
the cache is warm and the second call returns in ~100ms.

```bash
# List recent tasks on a specific workspace — across ALL machines
conversation_browser(
    action: "list",
    workspace: "CoursIA",                  # any workspace basename
    workspacePathMatch: "substring",       # tolerant cross-machine path matching
    includeArchives: true,                 # REQUIRED to include cross-machine GDrive archives
    source: "all",                         # roo + claude
    sortBy: "lastActivity", sortOrder: "desc",
    limit: 20
)

# Filter by machine + date window (incident timeline)
conversation_browser(
    action: "list",
    machineId: "myia-po-2025",             # cross-machine filter
    startDate: "2026-04-07", endDate: "2026-04-09",
    includeArchives: true,
    limit: 30
)

# Search by content across the entire fleet (no workspace filter)
conversation_browser(
    action: "list",
    contentPattern: "slidev",              # searched in archive sequences (Tier 3) + local
    includeArchives: true,
    source: "all",
    limit: 20
)

# View a specific task's traces (works for any machine's archive)
conversation_browser(
    action: "view",
    task_id: "TASK_ID_FROM_LIST",
    detail_level: "summary",
    smart_truncation: true,
    max_output_length: 50000
)
```

For semantic concept search:
```bash
# Semantic search (requires embeddings API — may be degraded if vLLM is down)
roosync_search(action: "semantic", search_query: "slides migration slidev marp", workspace: "*")

# Text fallback (always available)
roosync_search(action: "text", search_query: "deck slidev PROPRE", workspace: "*")
```

### Step 3: Map the divergence point

Using traces, identify:
1. **Last accurate report**: The last agent message that matched reality
2. **First inaccurate report**: The first agent message that claimed success incorrectly
3. **Validation gap**: What check was missing between agent claim and reality

### Step 4: Write the postmortem

Use the template above. Focus on:
- **Evidence over opinion**: Link to specific task_ids, timestamps, dashboard messages
- **Systemic over individual**: What harness change would prevent recurrence
- **Actionable over theoretical**: Concrete recommendations, not vague suggestions

### Step 5: Extract harness improvements

Each recommendation must have:
- An owner (machine or person)
- A priority (P1/P2/P3)
- A concrete deliverable (rule change, code fix, process doc)

---

## Tool Capabilities (verified 2026-08-12)

| Capability | Status | Notes |
|------------|--------|-------|
| Cross-machine conversation browsing | ✅ Operational | `includeArchives: true` + `workspace`/`machineId`/date filters |
| Content-pattern search (cross-machine) | ✅ Operational | `contentPattern: "..."` searches Tier 1/2/3 sequences in-memory |
| Date-window filter | ✅ Operational | `startDate`/`endDate` on `lastActivity` |
| Machine filter | ✅ Operational | `machineId: "myia-po-XXXX"` isolates one machine's archives |
| View archive detail | ✅ Operational | `view(task_id)` reads from any machine's archive |
| Semantic search | ⚠️ Degraded | Requires embeddings API; falls back to text when vLLM is down |
| Dashboard message history | ✅ Operational | `roosync_dashboard(action: "read_archive")` |
| User intervention detection | ✅ Operational | `roosync_search(role: "user", exclude_tool_results: true)` |

**Cold-start performance — machine-dependent, do not treat as a tool property.**

The first call after an MCP server start populates the Tier 3 cache. How long that takes depends on
the machine's DriveFS state, not on the tool alone. Two measurements on 2026-08-12, same build
(submodule `4c1a480f`, #975 live in both):

| machine | first call, `includeArchives: true` | second call |
|---------|-------------------------------------|-------------|
| myia-po-2023 | ~5s for ~11k archives | ~26ms |
| myia-ai-01 | **TIMEOUT at 30s** (error returned to caller) | 134ms |

On ai-01 the first call still primes the cache — it just fails to return before the ceiling, so the
caller sees an error and the retry succeeds. `includeArchives: false` returns in ~73ms there, which
isolates the cost to Tier 3.

Do not plan a postmortem around a single fast cold call. **Budget for a retry**, and if you are
writing performance figures into this file, say which machine produced them.

Subsequent calls return in <100ms (30-minute cache TTL) on both machines.

---

## Anti-patterns to avoid

1. **No evidence, no claim**: Every statement in the postmortem must link to a trace
2. **No blame, only systems**: Focus on what harness change prevents recurrence, not who made the mistake
3. **No close without action**: Each postmortem must produce at least 1 actionable recommendation
4. **No complacency markers**: If agents reported success but the user says it failed, the postmortem must explain WHY agents assessed incorrectly — this is the core finding

---

## CoursIA reference postmortems

For examples of completed postmortems using this template, see the comments on issue [#1244](https://github.com/jsboige/roo-extensions/issues/1244):
- **po-2024 (2026-05-12)** — Full postmortem with timeline, root causes, recommendations
- **web1 (2026-05-18)** — Harness failure analysis + 5 harness recommendations
- **po-2023 (2026-08-12)** — Cold-start timeout fix; tooling capability now operational
