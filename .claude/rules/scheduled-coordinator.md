# Scheduled Coordinator Protocol - ai-01 ONLY

**Version:** 1.0.0
**Created:** 2026-03-05
**Issue:** #540 (Coordinator tier)

---

## Overview

The scheduled coordinator is part of the **3-tier scheduling architecture** and runs **exclusively on myia-ai-01** at a 6-12h interval. It complements the local meta-analysts (#551) by handling **cross-machine analysis** that individual machines cannot do.

| Tier | Frequency | Machines | Role |
|------|-----------|----------|------|
| Meta-Analyst | 24h | ALL | Observe, analyze, PROPOSE (local) |
| **Coordinator** | 6-12h | **ai-01 only** | Triage, dispatch, track (global) |
| Executor | 3h | ALL | Execute assigned tasks |

---

## What the Coordinator Analyzes

### 1. RooSync Messaging Activity (`.shared-state/messages/`)

- Messages sent/received per machine (volume, frequency, subjects, tags)
- Communication patterns: who talks to whom, broadcast vs directed
- Silent machines detection (no messages sent/received in >48h)
- Message priority distribution (LOW/MEDIUM/HIGH/URGENT)
- Content quality: actionable instructions vs vague status updates
- Response times per machine

**How to collect:**
- `roosync_read(mode: "inbox", status: "all", limit: 50)` — all received messages
- Scan `.shared-state/messages/sent/` for outgoing messages from each machine
- Cross-reference with `roosync_get_status()` for system-level view

### 2. Git Commit Activity (cross-machine)

- `git log --oneline --since="48 hours ago"` — recent merged commits
- Commits per machine/author (identify active vs idle machines)
- Commit patterns: fix vs feat vs docs vs chore
- Compare commit activity with RooSync messaging (is work being done or just discussed?)

### 3. Cross-Machine Workload Balance

- GitHub Project #67 fields: issues per machine, status distribution
- Compare messaging volume with actual work output (commits, issues closed)
- Identify overloaded or idle machines

---

## Coordinator Report Format

```markdown
## Coordinator Analysis - {date}

### RooSync Traffic (last 48h)
| Machine | Sent | Received | Avg Response | Last Active |
|---------|------|----------|-------------|-------------|

### Git Activity (last 48h)
| Machine/Author | Commits | Types | Notable |
|----------------|---------|-------|---------|

### Workload Balance
| Machine | Open Issues | In Progress | Idle? |
|---------|------------|-------------|-------|

### Actions Taken
- [Dispatches, rebalances, escalations]
```

---

## GDrive Storage

```
.shared-state/coordinator/
  +-- coordinator-report-{date}.md
```

---

## Deployment

### Claude side (schtask)

**Script:** `scripts/scheduling/start-claude-coordinator.ps1`
**Setup:** `scripts/scheduling/setup-scheduler.ps1 -Action install -TaskType coordinator`
**Task name:** `Claude-Coordinator`
**Default:** 8h interval, opus model, 30min timeout

```powershell
# Install
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType coordinator

# Test (DryRun)
.\scripts\scheduling\setup-scheduler.ps1 -Action test -TaskType coordinator

# List status
.\scripts\scheduling\setup-scheduler.ps1 -Action list -TaskType coordinator

# Remove
.\scripts\scheduling\setup-scheduler.ps1 -Action remove -TaskType coordinator
```

### Roo side (scheduler extension)

**Not planned.** The coordinator tier is Claude-only (strategic analysis requires Opus-level reasoning).

### Implementation Status

**#540 Phase 1 DONE** (scripts created). Remaining:
- Register schtask on ai-01 (`setup-scheduler.ps1 -Action install -TaskType coordinator`)
- Validate first run
- Tune interval (6-12h) based on results

---

## Guard Rails

### Coordinator scheduler CAN:
- Read RooSync messages (all machines)
- Read git log (all commits)
- Query GitHub Project #67
- Dispatch tasks via RooSync
- Update issue fields (Machine, Status, Agent)
- Create coordinator reports on GDrive

### Coordinator scheduler MUST NOT:
- Modify harness files (same restriction as meta-analysts)
- Force-push or destructive git operations
- Close issues without verification (checklists must be 100%)

---

## References

- #540: Coordinator tier (this protocol)
- #551: Meta-Analyst tier (local analysis, separate protocol)
- `.claude/rules/meta-analysis.md`: Local meta-analysis protocol
- `.claude/commands/coordinate.md`: Interactive coordination command

---

**Last updated:** 2026-03-05
