# Scheduled Coordinator Protocol - ai-01 ONLY

**Version:** 1.0.0
**Created:** 2026-03-05
**Issue:** #540 (Coordinator tier)

---

## Overview

The scheduled coordinator is part of the **3-tier scheduling architecture** and runs **exclusively on myia-ai-01** at a 6-12h interval. It complements the local meta-analysts (#551) by handling **cross-machine analysis** that individual machines cannot do.

| Tier | Frequency | Machines | Role |
|------|-----------|----------|------|
| Meta-Analyst | 72h | ALL | Observe, analyze, PROPOSE (local) |
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

### 4. Environment Health Monitoring (COORDINATOR RESPONSIBILITY)

**The coordinator is responsible for ensuring ALL machines have what they need to function correctly.** This includes configuration, credentials, services, and MCP tools.

**Sources of information:**
- **Meta-analysts** escalate environment issues found in execution traces (via `[META-CONSULT]` or `needs-approval` issues)
- **RooSync config-sync pipeline**: `roosync_compare_config`, `roosync_inventory`, `roosync_list_diffs` detect config drift
- **Executor reports**: Agents report missing tools, broken services, incomplete `.env`
- **Heartbeat status**: `roosync_heartbeat(status)` shows online/offline machines

**What to monitor:**
- `.env` completeness on each machine (EMBEDDING_*, QDRANT_*, ROOSYNC_* vars)
- MCP tool availability (34 tools for roo-state-manager, 9 for win-cli)
- Infrastructure services (embeddings.myia.io, qdrant.myia.io, search.myia.io)
- Config drift between machines (`roosync_compare_config`)
- Heartbeat registration (all 6 machines should be registered)

**How to act:**
1. When a meta-analyst or executor reports an environment issue, **verify it** (skepticism protocol)
2. If confirmed, send a targeted RooSync message with the fix (full `.env` block, config patch, etc.)
3. Track resolution: machine must confirm fix applied
4. If systemic (affects multiple machines), create a GitHub issue and broadcast

**Guard rail:** The coordinator does NOT fix environments directly on remote machines. It sends instructions and tracks compliance.

### 5. INTERCOM Local (bidirectional with Roo)

The scheduled coordinator MUST read and write the local INTERCOM file (`.claude/local/INTERCOM-{MACHINE}.md`).

**Read (start of cycle):** Check for recent Roo messages with these tags:

| Tag | Meaning | Coordinator Action |
|-----|---------|-------------------|
| `[DONE]` | Roo completed a task | Analyze results, adjust escalation |
| `[WAKE-CLAUDE]` | Unhandled RooSync messages detected | Process RooSync inbox with priority |
| `[PATROL]` | Idle patrol exploration completed | Note domain covered, avoid re-exploring |
| `[FRICTION-FOUND]` | Problem detected during patrol | Verify friction, create issue if confirmed |
| `[ERROR]` / `[WARN]` | Operational problem | Investigate |

**Write (end of cycle):** Append a `[COORDINATION]` message with cycle summary (traffic, git, actions taken, recommendations for Roo).

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
- **Trivial auto-merge** (#1582) : approve+merge PRs matching narrow patterns defined in [`.claude/rules/pr-mandatory.md`](../../../.claude/rules/pr-mandatory.md) section "Exception : Trivial Auto-Merge". See next section for the phase procedure.

### Coordinator scheduler MUST NOT:
- Modify harness files (same restriction as meta-analysts)
- Force-push or destructive git operations
- Close issues without verification (checklists must be 100%)
- Auto-merge PRs that do NOT match the trivial patterns — rule 16 (`CLAUDE.md`) still applies to anything touching `src/`, `.claude/`, `.roo/`, config, or CI workflows.

---

## Trivial Auto-Merge Phase (#1582 pilot 2026-04-21 → 2026-05-05)

Run this phase **after** the standard coordinator analysis, **before** writing the cycle summary.

### Step 1 : List candidate PRs

```powershell
# Parent repo
gh pr list --repo jsboige/roo-extensions --state open --json number,title,author,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,files,additions,deletions

# Submodule
gh pr list --repo jsboige/jsboige-mcp-servers --state open --json number,title,author,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,files,additions,deletions
```

### Step 2 : Filter by pattern

For each PR, accept **ALL** conditions :
- Title matches one of : `^test(\(coverage\))?: .+` | `^chore\(submod\): bump pointer [a-f0-9]{7,} -> [a-f0-9]{7,}.*$` | `^docs\([^)]+\): .+`
- `mergeable == "MERGEABLE"`
- `mergeStateStatus` in `["BLOCKED" (awaiting review only), "CLEAN"]`
- `reviewDecision != "CHANGES_REQUESTED"`
- All `statusCheckRollup[].conclusion == "SUCCESS"` (no `FAILURE`, no `IN_PROGRESS` — wait next cycle if IN_PROGRESS)
- Diff inspection : `files[*].path` NOT in forbidden list (`src/`, `lib/`, `mcps/internal/servers/*/src/`, `.claude/`, `.roo/`, `CLAUDE.md`, `.roomodes`, `package*.json`, `.github/workflows/`, `*.env*`, `*.yml`)
- For pointer bumps : exactly 1 file changed (`mcps/internal`), `additions: 1, deletions: 1`

### Step 3 : Approve + merge (per accepted PR)

```powershell
# Approve as myia-ai-01 (independent review)
gh auth switch --user myia-ai-01
gh pr review <N> --repo <repo> --approve --body "LGTM trivial per #1582 (pattern: <matched-regex>)"

# Merge as jsboige (author-merger split preserved)
gh auth switch --user jsboige
gh pr merge <N> --repo <repo> --squash --delete-branch
```

**Max 5 trivial-merges per cycle** (blast radius cap).

### Step 4 : Log to dashboard workspace

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  tags: ["TRIVIAL-MERGE", "claude-coordinator-scheduled"],
  content: "### [ai-01 scheduled] Trivial merge phase — <timestamp>\n\nMerged N PRs:\n- #<num> <title> (+<add>/-<del> LOC, pattern: <regex>)\n...\n\nSkipped M PRs (reasons):\n- #<num> CI pending → retry next cycle\n- #<num> files outside scope (src/foo.ts) → interactive review required\n...\n\nTotal: X merged, Y skipped, Z seconds"
)
```

### Step 5 : Stop conditions

Stop the phase immediately if :
- Any merge fails (report error, continue to next PR without retrying)
- Any 2 consecutive merges fail (circuit breaker — something is off, escalate to dashboard `[ERROR]`)
- A post-merge CI on `main` fails (self-audit)

### Step 6 : Interactive coordinator audit (retroactive, at every `/coordinate`)

The interactive coordinator MUST :
1. Read all `[TRIVIAL-MERGE]` messages since last interactive cycle
2. Verify each merge still holds (no regression, tests green on main)
3. If anomaly detected : open `needs-approval` issue, set `TRIVIAL_MERGE_DISABLED=1` in `~/.claude/settings.json` locally, broadcast via RooSync

### Pilot exit criteria (2026-05-05)

- **Success** : zero regression, clear latency win (>=10 PRs auto-merged, average latency <1 cycle) → promote to stable
- **Failure** : >=1 regression, or no measurable latency win → revert via issue `needs-approval`, disable clause in `pr-mandatory.md`

---

## References

- #540: Coordinator tier (this protocol)
- #551: Meta-Analyst tier (local analysis, separate protocol)
- `docs/harness/reference/meta-analysis.md`: Local meta-analysis protocol
- `.claude/commands/coordinate.md`: Interactive coordination command

---

**Last updated:** 2026-04-21 (#1582 trivial auto-merge phase added, pilot 2 weeks)
