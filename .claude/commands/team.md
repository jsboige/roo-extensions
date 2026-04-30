Execute task $ARGUMENTS through the Team pipeline (PLAN → PRD → EXEC → VERIFY → FIX loop).

Read the design doc at `docs/architecture/team-pipeline-OMC-extraction.md` for full stage definitions.

## Pipeline

### Stage 1: PLAN
1. Read issue #$ARGUMENTS details via `gh issue view`
2. Analyze scope: `codebase_search` + Read relevant files
3. Check anti-double-claim: `gh pr list --search "#$ARGUMENTS"` + dashboard
4. Post `[CLAIMED]` + `[PLAN]` on dashboard with subtask decomposition
5. If coordinator active: wait for ACK. Else: proceed after 2 min.

### Stage 2: PRD (skip if clear)
1. Evaluate: does the issue have clear acceptance criteria + unambiguous scope?
2. If NO: post `[PRD]` with `[ASK]` questions. Wait max 15 min.
3. If YES: auto-satisfy PRD, note in plan.

### Stage 3: EXEC
1. Create worktree: `git worktree add .claude/worktrees/wt-{keyword} -b wt/{keyword}`
2. For each subtask:
   - Investigate code (Read, Grep, codebase_search)
   - Implement changes
   - Commit with `[PLAN-REF: #N]` in message
3. Push + create PR

### Stage 4: VERIFY
1. Build: `cd mcps/internal/servers/roo-state-manager && npm run build`
2. Tests: `npx vitest run` (NEVER `npm test`)
3. Check acceptance criteria
4. Post `[VERIFY]` report

### Stage 5: FIX (if VERIFY fails)
1. Fix failed items only (not whole task)
2. Commit + re-verify
3. Loop max 3 times
4. 3 failures → `[BLOCKED]` on dashboard
5. Pass → `[DONE]` on dashboard

## Simple Task Bypass
If scope < 3 files AND < 50 LOC AND clear requirements: skip PLAN/PRD, go EXEC → VERIFY → DONE.

## Required
- MCP roo-state-manager (34 tools) must be available
- Git clean working tree
- Issue #$ARGUMENTS must exist and be OPEN
