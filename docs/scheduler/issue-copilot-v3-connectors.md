## Context

We currently run two agentic systems in VS Code:

- Roo Scheduler (extension-based, 3h cadence)
- Claude Code workers/coordinator/meta-audit (Windows Task Scheduler)

We now want GitHub Copilot to join as a 3rd lane while preserving a single task/control plane.

`roo-state-manager` already provides unified task visibility and coordination semantics, and should remain the source of truth.

## Problem

Without a shared connector contract, adding Copilot risks:

- duplicate claim logic
- fragmented task status and handoff
- inconsistent scheduler behavior across Roo/Claude/Copilot

## Proposal (V3 Connectors)

Define and implement Connector V3 for all three lanes:

- identity: machine + agent + workspace
- inbox: unified read model
- claim: anti-duplicate lock protocol
- execution mode: interactive | scheduled | both
- status: started | blocked | done (+ evidence)
- handoff: structured transfer payload

## Copilot Integration Scope

### Phase A (immediate)
- Configure Copilot MCP with `roo-state-manager`
- Validate interactive read/write through unified tools

### Phase B (transition scheduler)
- Add `Copilot-Dispatcher` Windows scheduled task (3h)
- Dispatcher bridge for cadence and traceability
- Escalation policy with budget profiles (`low|balanced|throughput`)
- Thresholds: blocked escalation at 2 consecutive runs, idle review at 4 consecutive runs

### Phase C (target)
- Upgrade to full headless Copilot scheduled worker once runtime stability is validated

## Deliverables

- [ ] V3 connector spec (Roo/Claude/Copilot)
- [ ] Copilot MCP bootstrap script (`scripts/copilot/configure-copilot-mcp.ps1`)
- [ ] Copilot dispatcher scheduler scripts (`scripts/scheduling/setup-copilot-dispatcher.ps1`, `scripts/scheduling/start-copilot-dispatcher.ps1`)
- [ ] Escalation calibration table (profiles, thresholds, routing targets)
- [ ] Validation checklist for 6 machines
- [ ] Rollback strategy

## Acceptance Criteria

- [ ] Copilot can access `roo-state-manager` MCP in local environment
- [ ] Claim protocol is identical across Roo/Claude/Copilot
- [ ] No duplicate processing for scheduled issues over 72h pilot
- [ ] Project #67 fields remain consistent for all 3 lanes
- [ ] Escalation behavior matches configured profile for 3 consecutive simulated runs

## Labels

`needs-approval`, `harness-change`, `scheduler`, `mcp`, `copilot`
