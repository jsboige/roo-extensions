# Postmortem Template — Multi-Agent Incident Analysis

**Version:** 1.0.0
**Issue:** #1244 Phase 1
**MAJ:** 2026-05-11

---

## Purpose

Structured template for postmortems of multi-agent incidents where agent reports diverged from real-world outcomes. Derives from the CoursIA slides migration failure (2026-04-08).

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
- `roosync_search(role: "user", exclude_tool_results: true, start_date: "...")` for user interventions

### Step 2: Gather traces

For each machine involved:

```bash
# List recent tasks on the workspace
conversation_browser(action: "list", workspace: "C:/dev/WORKSPACE", limit: 30)

# View specific task traces
conversation_browser(action: "view", task_id: "TASK_ID", smart_truncation: true, detail_level: "summary")
```

For cross-machine investigation:
```bash
# Search by concept across all workspaces
roosync_search(action: "semantic", search_query: "slides migration slidev marp", workspace: "*")

# Text search if semantic is degraded
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

## Tool Limitations (current)

| Capability | Status | Workaround |
|------------|--------|------------|
| Cross-machine conversation browsing | Not supported | `roosync_search(workspace: "*")` as fallback |
| Semantic search when degraded | Fallback to text | `roosync_search(action: "text")` |
| Dashboard message history | Last N messages | `roosync_dashboard(action: "read_archive")` |
| User intervention detection | Manual search | `roosync_search(role: "user", exclude_tool_results: true)` |

---

## Anti-patterns to avoid

1. **No evidence, no claim**: Every statement in the postmortem must link to a trace
2. **No blame, only systems**: Focus on what harness change prevents recurrence, not who made the mistake
3. **No close without action**: Each postmortem must produce at least 1 actionable recommendation
4. **No complacency markers**: If agents reported success but the user says it failed, the postmortem must explain WHY agents assessed incorrectly — this is the core finding
