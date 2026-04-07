# Protected Path Migration - .claude/logs (2026-04-07)

## Context

Workspace rule confirmed by user: do not create new files under `.claude/logs`.

Objective: migrate operational artifacts to safe locations outside `.claude` while preserving scheduler compatibility.

## Safe destinations

- Scheduler runtime logs and reports: `outputs/scheduling/`
- Audit and onboarding reports: `docs/audit/`
- Script helpers and migration utilities: `scripts/audit/`

## Delta completed in this session

Updated:
- `scripts/scheduling/invoke-copilot-rollout-check.ps1`
- `scripts/scheduling/README.md`

Change:
- Rollout evidence report now writes to `outputs/scheduling/reports/`.
- Legacy dispatcher logs are still read from `.claude/logs` for backward compatibility.

## Remaining references to `.claude/logs` (scheduling scope)

- `scripts/scheduling/start-copilot-dispatcher.ps1`
- `scripts/scheduling/start-claude-worker.ps1`
- `scripts/scheduling/start-claude-coordinator.ps1`
- `scripts/scheduling/start-meta-audit.ps1`
- `scripts/scheduling/sync-tour-scheduled.ps1`
- `scripts/scheduling/setup-scheduler.ps1` (status message)
- `scripts/scheduling/README.md` (worker log sections)

## Migration strategy (non-breaking)

1. Introduce per-script configurable log root env var with safe default:
   - default: `outputs/scheduling/logs`
   - optional override for legacy compatibility during transition

2. Keep read fallback order during transition:
   - first: `outputs/scheduling/logs`
   - fallback: `.claude/logs`

3. Update docs and examples once script migration is done.

4. Validate with dry-run or scheduler test mode before any rollout.

## Next onboarding step

Implement phase 1 on `start-copilot-dispatcher.ps1` first (highest impact), then align the remaining scheduler scripts in small batches.
