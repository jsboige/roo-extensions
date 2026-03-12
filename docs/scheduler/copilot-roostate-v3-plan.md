# Copilot + Roo State Manager Integration (V3)

Date: 2026-03-11
Status: In progress (Phase B local stabilized on myia-po-2025)
Scope: Add GitHub Copilot as a 3rd agentic lane next to Roo Scheduler and Claude Worker

## 1. Objective

Use `roo-state-manager` as the unified control plane for 3 systems:

- Roo Scheduler (VS Code extension)
- Claude Code schedulers (Windows Task Scheduler)
- Copilot agent workflows (interactive first, then scheduled dispatcher)

Principle: do not create a second orchestration source of truth.

## 2. Why This Works

Copilot can use MCP servers in VS Code/Copilot CLI, but it does not natively expose your RooSync semantics.
`roo-state-manager` already provides these semantics:

- conversation/task visibility (`conversation_browser`, `task_browse`)
- messaging (`roosync_send`, `roosync_read`, `roosync_manage`)
- health and config tools (`roosync_inventory`, `roosync_compare_config`, etc.)

So Copilot should consume that MCP instead of inventing parallel connectors.

## 3. Connector V3 Target

Define a V3 connector model shared across Roo, Claude, Copilot:

- `identity`: machine + agent + workspace
- `inbox`: unified read model (RooSync + local markers)
- `claim`: anti-duplicate lock protocol
- `execution`: interactive | scheduled | both
- `status`: started | blocked | done with evidence
- `handoff`: structured transfer message between agents

Minimal acceptance:

1. Copilot can read/write RooSync messages through `roo-state-manager`.
2. Copilot follows the same claim protocol as Roo/Claude.
3. All 3 agents can report into Project #67 with consistent fields.

## 4. Copilot Scheduler Feasibility

### 4.1 What is feasible now

- A Windows scheduled task can run a dispatcher script regularly.
- The dispatcher can select work and route it to the right lane.
- Copilot remains available in interactive mode immediately.

### 4.2 Constraint

Copilot does not yet have a stable local, headless task runner equivalent to `claude -p` in this repository.

Implication:

- Scheduled lane for Copilot should start as a dispatcher/claimer bridge.
- Full autonomous Copilot execution should be enabled when a stable local headless entry point is validated.

## 5. Phase Plan

### Phase A - Immediate

- Configure Copilot MCP (`roo-state-manager`) via `%APPDATA%\Code\User\mcp.json`.
- Use Copilot interactively with unified task context.

Notes:

- Keep backward compatibility with historical path `~/.copilot/mcp-config.json` when present.
- Dispatcher detection order: `%APPDATA%\Code\User\mcp.json` first, then historical path.

### Phase B - Scheduler Bridge

- Add `Copilot-Dispatcher` scheduled task (3h staggered).
- It claims/queues work and emits RooSync messages for traceability.
- Apply an escalation policy aligned with Roo/Claude:
  - `low` profile: escalate to `claude-worker-haiku` after 2 consecutive blocked runs.
  - `balanced` profile: escalate to `claude-worker-sonnet` after 2 consecutive blocked runs.
  - `throughput` profile: escalate to `claude-worker-opus` after 2 consecutive blocked runs.
  - Trigger coordinator cadence review after 4 consecutive idle runs.

### Phase C - Full Copilot Scheduled Worker

- Replace dispatcher mode with execution mode when headless Copilot runtime is production-ready.
- Keep the same V3 connector contract.

## 6. Operational Rules

- Keep `roo-state-manager` as control plane.
- No direct bypass writes to ad-hoc files for coordination.
- No new protocol variant without updating all 3 lanes.
- Apply skepticism protocol before propagating environment assumptions.

## 7. Credit-Aware Calibration

Scheduler should run with explicit budget profiles:

- `low`: prioritize cost control, keep escalation conservative.
- `balanced`: default mode, Sonnet escalation only when repeated blocked state is observed.
- `throughput`: prioritize throughput and unblock speed, allows Opus escalation.

Recommended default for this machine: `balanced`, `MaxConsecutiveBlocked=2`, `MaxConsecutiveIdle=4`.

Monthly budget guard (Copilot Pro premium requests):

- Input usage manually from GitHub dashboard (current sample: 4.5%).
- Use soft cap 70% and hard cap 90% by default.
- Behavior:
  - usage < 70%: keep requested profile
  - 70% <= usage < 90%: downgrade one level
  - usage >= 90%: force `low` profile
- Purpose: keep scheduled lane alive through end-of-month without burning premium budget.

## 8. Deliverables for V3 Issue

- Connector V3 spec document
- Copilot MCP bootstrap script
- Scheduler bridge script + task installer
- Validation checklist across 6 machines
- Rollback plan

## 9. Controlled Rollout Checklist (6 Machines)

Target machines:

- myia-ai-01
- myia-po-2023
- myia-po-2024
- myia-po-2025
- myia-po-2026
- myia-web1

Per-machine checklist:

1. Confirm active GitHub identity is `jsboige` for `gh` CLI operations.
2. Apply Copilot MCP bootstrap script (`scripts/copilot/configure-copilot-mcp.ps1`).
3. Verify MCP config contains `roo-state-manager` in `%APPDATA%\Code\User\mcp.json`.
4. Install/refresh `Copilot-Dispatcher` with IssueNumber and guardrails:
   - `-BudgetProfile balanced`
   - `-IssueNumber 622`
   - `-MinEscalationIntervalMinutes 180`
   - `-MaxEscalationsPerDay 3`
5. Run one immediate validation cycle and check:
   - scheduled task state = `Ready`
   - `LastTaskResult = 0`
   - log includes `Found Copilot MCP config`
6. Confirm issue trace contains `STATUS: done` with `result: idle` or expected status.

Recommended execution command (run on each machine):

```powershell
scripts/scheduling/invoke-copilot-rollout-check.ps1 -IssueNumber 622 -BudgetProfile balanced
```

Optional flags:

- `-ValidateOnly` (no install/refresh)
- `-SkipBootstrap` (if MCP bootstrap already applied)
- `-PostIssueComment` (push summarized gate result to issue #622)

Rollout gate:

- Move to next machine only after previous machine reaches checklist step 6.
- If one machine is blocked, stop broad rollout and open a blocker comment on #622.

## 10. Rollback Plan

If regression is detected after rollout on a machine:

1. Disable Copilot scheduled lane:
   - `scripts/scheduling/setup-copilot-dispatcher.ps1 -Action remove`
2. Keep Roo and Claude schedulers unchanged (no cross-lane rollback).
3. Preserve logs under `.claude/logs/copilot-dispatcher-*.log` for forensic review.
4. Post rollback evidence and blocker summary on issue #622.
5. Resume with interactive-only Copilot lane until fix is validated.

Rollback trigger examples:

- repeated false `blocked` due to config detection mismatch
- escalation spam despite guardrails
- persistent non-zero task result after two retries
