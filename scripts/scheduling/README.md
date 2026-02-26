# Claude Code Scheduling

**Version:** 2.0 (Phase 2 - Production)
**Date:** 2026-02-26
**Issues:** #414 (Phase 1), #525 (Phase 2)
**Status:** OPERATIONAL on myia-ai-01

---

## Overview

Automated Claude Code worker that picks up GitHub issues and executes them via Windows Task Scheduler. Features:

- **Auto-detect tasks** from GitHub (`roo-schedulable` label) or RooSync inbox
- **Escalade Haiku → Sonnet/Opus** via agent signal (STATUS: escalate)
- **Sub-agent delegation** (Haiku can spawn Sonnet sub-agents)
- **Wait state** persistence for tasks requiring user approval
- **Graceful idle** (clean exit when no work, -NoFallback)
- **DryRun** mode for safe testing
- **Detailed logs** in `.claude/logs/worker-*.log`

---

## Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `start-claude-worker.ps1` | Main worker with escalation + sub-agents | Manual or via Task Scheduler |
| `setup-scheduler.ps1` | Install/remove/list/test Windows Task Scheduler | Setup and management |
| `sync-tour-scheduled.ps1` | Sync-tour wrapper (legacy Phase 1) | Manual |
| `test-escalation.ps1` | 33 unit tests (escalation, wait state, idle) | Validation |
| `test-integration.ps1` | 3 integration tests (live Claude calls) | Validation |

---

## Quick Start

### 1. List current Task Scheduler status

```powershell
.\setup-scheduler.ps1 -Action list
```

### 2. Test worker (DryRun - no side effects)

```powershell
.\setup-scheduler.ps1 -Action test
```

### 3. Install Task Scheduler (production)

```powershell
# Default: 3h interval, Haiku, 1 iteration, clean exit if no work
.\setup-scheduler.ps1 -Action install

# Conservative 6h interval
.\setup-scheduler.ps1 -Action install -IntervalHours 6

# More iterations per run
.\setup-scheduler.ps1 -Action install -MaxIterations 3

# Preview without installing
.\setup-scheduler.ps1 -Action install -DryRun
```

### 4. Remove Task Scheduler

```powershell
.\setup-scheduler.ps1 -Action remove
```

---

## Worker Parameters

```powershell
.\start-claude-worker.ps1
    [-Mode <string>]         # Claude mode (sync-simple, code-simple, etc.)
    [-Model <string>]        # Model override (haiku, sonnet, opus)
    [-TaskId <string>]       # Specific RooSync task ID
    [-Prompt <string>]       # Direct prompt injection (for testing)
    [-MaxIterations <int>]   # Max Ralph Wiggum iterations (default: from mode config)
    [-NoFallback]            # Clean exit if no work (no maintenance fallback)
    [-UseWorktree]           # Create git worktree for isolation
    [-DryRun]                # Show commands without executing
```

### Examples

```powershell
# Auto-detect next task (RooSync then GitHub)
.\start-claude-worker.ps1 -Mode code-simple -Model haiku -MaxIterations 1

# Specific task
.\start-claude-worker.ps1 -TaskId "msg-xyz" -Mode code-simple

# Test with direct prompt
.\start-claude-worker.ps1 -Prompt "Run tests and report" -Mode code-simple -Model haiku

# Scheduled mode (no fallback maintenance)
.\start-claude-worker.ps1 -Mode code-simple -Model haiku -MaxIterations 1 -NoFallback
```

---

## Task Detection Pipeline

```
1. Check RooSync inbox → prioritized messages
2. Check GitHub issues (label: roo-schedulable) → oldest unclaimed
3. If -NoFallback → clean exit (WORKER IDLE)
4. Else → fallback maintenance (build + tests)
```

### GitHub Issue Selection

- Issues must have label `roo-schedulable`
- Issues with `Agent: Roo` (explicitly, without Both/Any) are skipped
- Already-assigned issues are skipped
- Issues locked by recent "Claimed by" comment (<5min) are skipped
- Worker claims the issue before execution

---

## Escalation

The worker uses "Ralph Wiggum" iteration loop. The agent signals its status:

```
=== AGENT STATUS ===
STATUS: success|failure|escalate|wait|continue
REASON: description
ESCALATE_TO: sonnet|opus  (optional, for escalate)
WAIT_FOR: description     (optional, for wait)
RESUME_WHEN: condition    (optional, for wait)
===================
```

### Escalation Flow

```
Haiku (code-simple) → Agent signals ESCALATE
  → Worker switches to code-complex (Sonnet)
  → Retries same prompt with more powerful model
  → If escalated model also fails → report failure
```

### Wait State

Agent signals STATUS: wait → Worker saves state to `.claude/scheduler/wait-states/{taskId}.json` → Next run can check and resume.

---

## Logs

```
.claude/logs/
├── worker-20260226-032958.log    # Timestamped worker logs
└── ...
```

```powershell
# Recent logs
Get-ChildItem .claude/logs/worker-*.log | Sort LastWriteTime -Desc | Select -First 5

# Last 50 lines of latest
Get-Content (Get-ChildItem .claude/logs/worker-*.log | Sort LastWriteTime -Desc | Select -First 1).FullName -Tail 50
```

---

## Tests

### Unit Tests (33 tests)

```powershell
powershell -ExecutionPolicy Bypass -File .\test-escalation.ps1
```

Tests: mode config loading, escalation mapping, escalation model bug fix, wait state save/load, NoFallback parameter, escalation code path.

### Integration Tests (3 tests, requires Claude API)

```powershell
powershell -ExecutionPolicy Bypass -File .\test-integration.ps1
```

Tests: real escalation (Haiku→Sonnet), sub-agent delegation, wait state signal.

---

## Current Deployment

| Machine | Task Name | Interval | Model | Status |
|---------|-----------|----------|-------|--------|
| myia-ai-01 | Claude-Worker | 3h | Haiku | OPERATIONAL |
| Others | - | - | - | Planned (#534) |

**Configuration:** code-simple, MaxIterations=1, NoFallback, Timeout=15min

---

## Cost Estimation

| Config | Cost/run | Cost/day (8 runs) | Cost/month |
|--------|----------|-------------------|------------|
| Haiku MaxIter=1 | ~$0.005 | ~$0.04 | ~$1.20 |
| Haiku MaxIter=3 | ~$0.015 | ~$0.12 | ~$3.60 |
| With escalation to Sonnet | ~$0.05 | ~$0.10 | ~$3.00 |

---

## References

- **#414** : Phase 1 - Base implementation (po-2026)
- **#525** : Phase 2 - Capabilities validation + Task Scheduler (ai-01)
- **#534** : Phase 3 - Multi-machine deployment (planned)
- [docs/architecture/scheduler-claude-code.md](../../docs/architecture/scheduler-claude-code.md) : Architecture design

---

**Authors:** Claude Code (myia-po-2026 Phase 1, myia-ai-01 Phase 2)
**Version:** 2.0 (Production)
