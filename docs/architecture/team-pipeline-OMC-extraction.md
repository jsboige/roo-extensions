# ADR: Team Pipeline — OMC Stage Extraction for RooSync

**Issue:** #1853
**EPIC:** #1864 (Cycle 26 — Harness Consolidation)
**Status:** Proposed (Phase 1 — Design)
**Author:** myia-po-2024
**Date:** 2026-04-30

---

## 1. Context

### 1.1 OMC Team Pipeline (Source Pattern)

[oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) Team mode uses a 5-stage sequential pipeline:

```
team-plan → team-prd → team-exec → team-verify → team-fix (loop)
```

| Stage | Purpose | Output |
|-------|---------|--------|
| `team-plan` | Decompose task into subtasks | Plan document with ordered subtask list |
| `team-prd` | Clarify requirements, constraints, acceptance criteria | PRD with scope boundaries |
| `team-exec` | Implement the solution | Code changes, commits |
| `team-verify` | Validate (build + tests + criteria) | Verification report |
| `team-fix` | Fix issues found in verify; loop until pass | Fixed code, re-verified |

Each stage gates the next: you cannot exec without a plan, you cannot verify without exec, etc.

### 1.2 Current RooSync Workflow

Our existing workflow has two modes:

**Coordinator mode** (`/coordinate` → `sync-tour` 9 phases):
```
Phase 0 (SDDD grounding) → Phase 1 (RooSync inbox) → Phase 1.5 (config audit)
→ Phase 1.6 (friction detection) → Phase 1.7 (Git notifications)
→ Phase 2 (Git sync) → Phase 3 (build+tests) → Phase 3.5 (GitHub checklists)
→ Phase 4 (GitHub status) → Phase 5 (GitHub updates) → Phase 6 (planning)
→ Phase 7 (RooSync replies) → Phase 8 (memory consolidation)
→ Phase 9 (Dashboard update)
```

**Executor mode** (`/executor` → 3 phases):
```
Phase 0 (pre-flight) → Phase 1 (collect+grounding) → Phase 2 (task selection)
→ Phase 3 (execute: investigate → implement → validate → commit+PR → report)
```

### 1.3 Gap Analysis

| OMC Stage | RooSync Equivalent | Gap |
|-----------|-------------------|-----|
| `team-plan` | sync-tour Phase 6 (task-planner) | Partial — planning exists but not enforced per-task |
| `team-prd` | **Missing** | No requirements clarification gate before execution |
| `team-exec` | executor Phase 3 | Covered — but no plan prerequisite |
| `team-verify` | validate skill + executor "validate" step | Covered — but can be skipped |
| `team-fix` | Manual loop | **Missing** — no auto-loop until verification passes |

**Key gaps:**
1. No PRD stage — agents jump from issue title to code
2. No enforced gating — stages can be skipped
3. No auto-fix loop — agents report [DONE] without verification passing

---

## 2. Decision

Adopt the Team pipeline stages as an **overlay** on the existing RooSync workflow, not a replacement. The pipeline activates only for **complex tasks** (threshold: >3 files or >50 LOC expected change).

### 2.1 Mapping: OMC Stages ↔ RooSync Components

```
┌──────────────────────────────────────────────────────────────┐
│                    Team Pipeline (per-task)                   │
│                                                              │
│  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌──────────┐   │
│  │ PLAN    │──▶│ PRD     │──▶│ EXEC    │──▶│ VERIFY   │   │
│  │         │   │         │   │         │   │          │   │
│  │ task-   │   │ require-│   │ executor│   │ validate │   │
│  │ planner │   │ ments   │   │ skill   │   │ skill    │   │
│  │ agent   │   │ doc     │   │         │   │          │   │
│  └─────────┘   └─────────┘   └─────────┘   └────┬─────┘   │
│       ▲                                         │          │
│       │              ┌─────────┐                │          │
│       └──────────────│ FIX     │◀───────────────┘          │
│         (re-plan)    │ loop   │   (if fails)               │
│                      └─────────┘                            │
└──────────────────────────────────────────────────────────────┘
```

### 2.2 Stage Definitions

#### Stage 1: PLAN (`team-plan`)

**Trigger:** Complex task selected (threshold exceeded).
**Tool:** `task-planner` agent (already exists).
**Output:** Plan document posted to dashboard with `[PLAN]` tag.

```markdown
## [PLAN] #{issue} — {title}

### Decomposition
1. Subtask A — {description} — ETA: {time}
2. Subtask B — {description} — ETA: {time}
3. Subtask C — {description} — ETA: {time}

### Dependencies
- B depends on A
- C depends on B

### Estimated scope
- Files: ~{N} | LOC: ~{M}
```

**Existing mapping:** sync-tour Phase 6 (task-planner), executor Phase 2 (selection).
**New:** Plan is **required** before execution for complex tasks. Posted to dashboard for coordinator review.

#### Stage 2: PRD (`team-prd`)

**Trigger:** Plan is posted. Ambiguous requirements detected.
**Tool:** New — requirements clarification via dashboard `[ASK]`.
**Output:** PRD section appended to plan.

```markdown
### Requirements (PRD)
- **Scope:** {what's included}
- **Out of scope:** {what's excluded}
- **Acceptance criteria:**
  1. {criterion 1}
  2. {criterion 2}
- **Constraints:** {technical constraints}
```

**Existing mapping:** No direct equivalent. Currently implicit in issue body.
**New:** For ambiguous tasks, agents must post `[ASK]` on dashboard and wait for coordinator/user response before proceeding. For clear tasks (detailed issue body), PRD stage is auto-satisfied.

**Skip condition:** If issue body has clear acceptance criteria AND scope is unambiguous → skip PRD, proceed to EXEC.

#### Stage 3: EXEC (`team-exec`)

**Trigger:** Plan (and optional PRD) are complete.
**Tool:** Executor skill Phase 3, or interactive Claude session.
**Output:** Code changes + commits.

**Existing mapping:** Executor Phase 3 (investigate → implement → validate → commit+PR).
**New:** Executor must reference the plan's subtask numbers in commit messages. `[PLAN-REF: #A]`.

**Constraint:** Each subtask gets its own commit when possible. Plan acts as a checklist.

#### Stage 4: VERIFY (`team-verify`)

**Trigger:** Execution complete, PR created.
**Tool:** `validate` skill (build + tests).
**Output:** Verification report posted to dashboard.

```markdown
## [VERIFY] #{issue}
- Build: ✅ / ❌
- Tests: X passed, Y failed
- Acceptance criteria: N/M satisfied
- Files changed: {count}
```

**Existing mapping:** Validate skill, executor "validate" step.
**New:** Verification is **mandatory** before `[DONE]`. Cannot skip. Acceptance criteria from PRD are checked.

#### Stage 5: FIX (`team-fix`)

**Trigger:** VERIFY reports failures.
**Tool:** Manual re-execution of failed items.
**Output:** Fixed code, re-verification.

**Existing mapping:** Implicit — agents sometimes fix and re-test.
**New:** **Auto-loop**: if VERIFY fails, automatically re-enter EXEC for failed items only (not the whole task). Loop up to 3 times. After 3 failures, post `[BLOCKED]` on dashboard with failure details.

```
VERIFY fail → FIX → VERIFY (loop max 3)
         └──────┘
```

### 2.3 Dashboard Tags for Pipeline Stages

| Stage | Dashboard tag | When used |
|-------|---------------|-----------|
| PLAN | `[PLAN]` | Task decomposition posted |
| PRD | `[PRD]` | Requirements clarification asked/provided |
| EXEC | `[EXEC]` | Implementation started |
| VERIFY | `[VERIFY]` | Verification report |
| FIX | `[FIX]` | Fix loop iteration N |
| DONE | `[DONE]` | Verification passed, task complete |
| BLOCKED | `[BLOCKED]` | 3 fix loops failed |

### 2.4 Activation Threshold

The pipeline activates for tasks meeting **any** of:
- Expected change: >3 files OR >50 LOC
- Issue complexity: multiple subtasks identified
- Ambiguity: unclear requirements in issue body

**Simple tasks** (doc-only, <50 LOC, clear scope) skip PLAN/PRD and go directly to EXEC → VERIFY → DONE (the current executor flow).

### 2.5 Compatibility with sync-tour

The Team pipeline is **per-task**, not per-session. sync-tour is **per-session** (9 phases for the whole coordination round).

```
sync-tour (session-level)            Team pipeline (task-level)
├── Phase 0: SDDD grounding          │
├── Phase 1: RooSync inbox           │
├── Phase 1.5: Config audit          │
├── Phase 2: Git sync                │
├── Phase 3: Build+tests             │
├── Phase 4: GitHub status           │
├── Phase 5: GitHub updates          │
├── Phase 6: Planning           ──── ▶ PLAN stage (for each complex task)
│   └── task-planner agent           │
├── Phase 7: RooSync replies         │
│                                     ├── PRD stage (if ambiguous)
│                                     ├── EXEC stage (implementation)
│                                     ├── VERIFY stage (validation)
│                                     └── FIX loop (if needed)
├── Phase 8: Memory consolidation     │
└── Phase 9: Dashboard update         │
```

The sync-tour's Phase 6 (task-planner) **produces** the Team pipeline PLAN for each complex task. After the sync-tour completes, each executor picks up their dispatched tasks and runs through EXEC → VERIFY → (FIX loop) → DONE.

---

## 3. Implementation Phases

### Phase 1 (Design — this document)

- [x] Map OMC stages to RooSync workflow
- [x] Define activation threshold
- [x] Define dashboard tags
- [x] Define compatibility with sync-tour
- [ ] Optional: `/team` command prototype

### Phase 2 (Implementation — follow-up issue)

- [ ] Add pipeline stage tracking to executor skill
- [ ] Create `/team` command that orchestrates all 5 stages
- [ ] Update executor skill Phase 3 to enforce PLAN prerequisite
- [ ] Add FIX loop logic (max 3 iterations)
- [ ] Update agent-claim-discipline to include pipeline stage
- [ ] Integration test: run `/team` on a sample issue

### Phase 3 (Validation)

- [ ] Run Team pipeline on 3+ real issues
- [ ] Measure: time-to-DONE with vs without pipeline
- [ ] Measure: verification pass rate on first attempt
- [ ] Gather agent friction reports

---

## 4. `/team` Command Prototype

The optional `/team` command would orchestrate the 5 stages for a single task:

```markdown
---
name: team
description: Execute a complex task through the full Team pipeline (PLAN → PRD → EXEC → VERIFY → FIX loop). Usage: /team <issue-number>
---

# Team Pipeline Command

## Usage
/team <issue-number>

## Stages

### Stage 1: PLAN
1. Read issue #N details
2. Analyze codebase to understand scope (codebase_search + Read)
3. Decompose into subtasks (max 5)
4. Post [PLAN] on dashboard
5. Wait for coordinator ACK (if coordinator active, else proceed)

### Stage 2: PRD
1. Evaluate ambiguity level
2. If ambiguous: post [PRD] with [ASK] questions on dashboard
3. Wait for response (max 15 min, then proceed with best judgment)
4. If clear: skip PRD, mark as auto-satisfied

### Stage 3: EXEC
1. Create worktree: wt/{issue-keyword}
2. For each subtask in plan:
   a. Investigate relevant code
   b. Implement changes
   c. Commit with [PLAN-REF: #subtask]
3. Push branch + create PR

### Stage 4: VERIFY
1. Run build: `cd mcps/internal/servers/roo-state-manager && npm run build`
2. Run tests: `npx vitest run`
3. Check acceptance criteria from PRD
4. Post [VERIFY] report on dashboard

### Stage 5: FIX (if needed)
1. If VERIFY fails:
   a. Fix failed items
   b. Commit fix
   c. Re-verify
   d. Repeat (max 3 loops)
2. If 3 loops fail: post [BLOCKED]
3. If VERIFY passes: post [DONE]

## Simple Task Bypass
If scope < 3 files AND < 50 LOC AND clear requirements:
- Skip PLAN and PRD
- Execute directly → VERIFY → DONE
```

---

## 5. Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Pipeline overhead for simple tasks | Activation threshold skips simple tasks |
| PRD stage blocks on coordinator silence | 15-min timeout → proceed with best judgment |
| FIX loop infinite | Hard cap at 3 iterations, then [BLOCKED] |
| Pipeline replaces sync-tour | Explicit: pipeline is per-task, sync-tour is per-session |
| Dashboard noise from stage tags | Tags are structured and grep-able; auto-condensation handles volume |

---

## 6. Alternatives Considered

1. **Full OMC adoption** — Rejected. Our harness is already mature with sync-tour + executor. Full replacement would discard proven patterns.

2. **No pipeline, just enforcement** — Add "must verify before DONE" rule without stages. Rejected because the PLAN/PRD stages add real value for complex tasks (reduces rework).

3. **Pipeline as MCP tool** — Implement stages as roo-state-manager tools. Rejected for Phase 1 — stages are workflow patterns, not data operations. Phase 2 could add a `roosync_pipeline` tracking tool if needed.

---

## 7. References

- Issue #1853 — OMC Team pipeline extraction
- Issue #1802 — oh-my-claudecode evaluation (source study)
- Issue #1864 — EPIC Cycle 26
- [oh-my-claudecode Team mode](https://github.com/Yeachan-Heo/oh-my-claudecode#team-mode-recommended)
- [sync-tour skill](../../.claude/skills/sync-tour/SKILL.md)
- [executor skill](../../.claude/skills/executor/SKILL.md)
- [validate skill](../../.claude/skills/validate/SKILL.md)
