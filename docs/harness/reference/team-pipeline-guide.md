# Team Pipeline Stages — Reference Guide

**Issue:** #1853
**ADR:** [005-team-pipeline-stages.md](../adr/005-team-pipeline-stages.md)
**Source:** oh-my-claudecode Team mode extraction

---

## Overview

5-stage structured pipeline for complex tasks (>50 LOC or >3 files):

```
team-plan → team-prd → team-exec → team-verify → team-fix (loop)
```

## Stage Definitions

| Stage | Purpose | Required? | Dashboard tag |
|-------|---------|-----------|---------------|
| **team-plan** | Decompose into subtasks | Yes, for >50 LOC/>3 files | `[CLAIMED]` + plan |
| **team-prd** | Clarify requirements | Only if ambiguous | `[ASK]` questions |
| **team-exec** | Implement | Yes | `[PROGRESS]` updates |
| **team-verify** | Build + tests | **Always before [DONE]** | `[VERIFY]` report |
| **team-fix** | Fix verify failures | Loop until pass | `[PROGRESS]` fixes |

## Stage Transitions

```markdown
## [CLAIMED] #NNN — task description
**Team Stage:** team-plan

## [PROGRESS] team-exec — Implementation started
**Previous Stage:** team-plan (team-prd skipped, requirements clear)

## [PROGRESS] team-verify — Running build + tests
**Previous Stage:** team-exec

## [DONE] Verification passed
**team-verify:** build PASSED tests PASSED (74/74)
```

## Dashboard Integration

Report stages via `teamStage` field in `roosync_dashboard`:

```typescript
// In dashboard-schemas.ts
teamStage: 'team-plan' | 'team-prd' | 'team-exec' | 'team-verify' | 'team-fix' | 'done'
teamStageData: {
  previousStage?: TeamStage,
  nextStage?: TeamStage,
  verificationResult?: {
    buildPassed?: boolean,
    testsPassed?: boolean,
    issuesFound?: string[]
  }
}
```

## Verification Gate

**NEVER** mark a task as [DONE] without:
1. Running `npm run build` (or relevant build)
2. Running `npx vitest run` (NEVER `npm test`)
3. Posting verification results

If verification fails:
1. Transition to `team-fix`
2. Fix only the failed items
3. Re-run verification
4. Loop max 3 times; 3 failures → `[BLOCKED]` on dashboard

## Simple Task Bypass

If scope < 3 files AND < 50 LOC AND clear requirements: skip PLAN/PRD.
Go directly: EXEC → VERIFY → DONE.

## Files Involved

| File | Role |
|------|------|
| `dashboard-schemas.ts` | TeamStage enum + schemas |
| `dashboard.ts` | teamStage/teamStageData params |
| `.claude/agents/executor/task-worker.md` | Stage enforcement |
| `.claude/commands/team.md` | `/team` slash command |
| `CLAUDE.md` | Team Pipeline section |

## Commands

- `/team <issue-number>` — Execute issue through full pipeline
- `/executor` — Executor sessions use pipeline for complex tasks
