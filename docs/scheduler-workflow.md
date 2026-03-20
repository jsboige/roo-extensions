# Unified Scheduler Workflows - Technical Reference

**Version:** 1.0.0
**Issue:** #689
**Last Updated:** 2026-03-15

---

## Overview

The RooSync multi-agent system uses **3 types of scheduled workflows** running on 6 machines, coordinated through Windows Task Scheduler and unified PowerShell modules.

### Architecture

| Tier | Workflow | Machines | Interval | Role |
|------|----------|-----------|----------|------|
| **Executor** | `workflow-executor.ps1` | myia-po-2023/2024/2025/2026, myia-web1 | 6h | Execute assigned tasks, report to coordinator |
| **Coordinator** | `workflow-coordinator.ps1` | myia-ai-01 ONLY | 8h | Dispatch tasks, monitor heartbeats, analyze Project #67 |
| **Meta-Analyst** | `workflow-meta-analyst.ps1` | ALL machines | 72h | Independent analysis of BOTH schedulers (Roo + Claude) |

### Key Principles

1. **Shared Modules**: All workflows use 4 common PowerShell modules from `scripts/scheduler/`
2. **Pre-flight Check**: OBLIGATORY verification of critical MCPs before any work
3. **INTERCOM Protocol**: Local communication via `.claude/local/INTERCOM-{MACHINE}.md`
4. **META-INTERCOM Protocol**: Meta-analyst reporting via `.claude/local/META-INTERCOM-{MACHINE}.md`
5. **Git Workflow**: Pull → Execute → Report (Roo commits, Claude validates)

---

## Location

**All workflow files and modules:** `scripts/scheduler/`

```
scripts/scheduler/
├── workflow-executor.ps1        # Executor workflow (myia-po-*, web1)
├── workflow-coordinator.ps1     # Coordinator workflow (myia-ai-01 ONLY)
├── workflow-meta-analyst.ps1    # Meta-analyst workflow (ALL machines)
├── PreFlightCheck.psm1           # Shared: MCP availability check
├── INTERCOMReporting.psm1        # Shared: INTERCOM write/read
├── EscalationProtocol.psm1       # Shared: Escalation rules
└── WinCliPatterns.psm1           # Shared: Shell command wrappers
```

---

## Shared PowerShell Modules

### 1. PreFlightCheck.psm1

**Purpose:** Verify critical MCP tools are available before workflow execution.

**Key Function:** `Test-PreFlightCheck`

**Checks:**
- **win-cli** (9 tools expected): `execute_command` responder
- **roo-state-manager** (34 tools expected): `conversation_browser(action: "current")` responder

**Returns:**
```powershell
@{
    WinCliAvailable = $true/false
    RooStateManagerAvailable = $true/false
    WinCliToolCount = 9
    RooStateManagerToolCount = 36
    Timestamp = Get-Date
}
```

**Usage in Workflows:**
```powershell
$preFlightResult = Test-PreFlightCheck
$preFlightSuccess = Write-PreFlightCheckToINTERCOM -Result $preFlightResult -MachineName $MachineName

if (-not $preFlightSuccess) {
    throw "Pre-flight check FAILED. Cannot proceed without critical MCPs."
}
```

**Protocol:** If check fails → **STOP IMMEDIATELY**. No degraded mode. Document in INTERCOM with `[CRITICAL]` tag.

---

### 2. INTERCOMReporting.psm1

**Purpose:** Write structured messages to INTERCOM (local session history file).

**Key Functions:**
- `Write-INTERCOMMessage` - INFO, TASK, DONE, WARN, ERROR, ASK, REPLY
- `Write-INTERCOMError` - ERROR with details
- `Get-INTERCOMPath` - Get machine-specific INTERCOM file path

**Message Format:**
```markdown
## [YYYY-MM-DD HH:MM:SS] sender → receiver [TYPE]

### Title

Content...

---
```

**File Location:**
```
.claude/local/INTERCOM-{MACHINE_NAME}.md
```

**Rules:**
- **ALWAYS append to the end** of the file (chronological order)
- Use `Edit` tool with `replace_all: false` (Claude Code)
- Use `Add-Content` (PowerShell)
- NEVER insert at the beginning (breaks chronological order)

**Message Types:**

| Type | Usage |
|------|-------|
| `INFO` | General information, status updates |
| `TASK` | Request task from other agent |
| `DONE` | Signal task completion |
| `WARN` | Non-blocking warning |
| `ERROR` | Blocking error, need help |
| `ASK` | Ask a question |
| `REPLY` | Respond to ASK |

**Usage Example:**
```powershell
Write-INTERCOMMessage -Type "INFO" -Title "Workflow step: Pre-flight" -Content "**Step:** Pre-flight Check`n`nVerifying critical MCPs" -MachineName $MachineName
```

---

### 3. EscalationProtocol.psm1

**Purpose:** Implement 3-layer escalation mechanism for task delegation.

**Key Functions:**
- `Test-EscalationCriteria` - Evaluate if escalation needed
- `Get-EscalationChain` - Get full escalation path
- `Format-DelegationInstruction` - Format delegation message
- `Write-EscalationEvent` - Log escalation to INTERCOM
- `Test-SkipSimpleMode` - Evaluate if should start in complex mode

**Escalation Criteria (Layer 1: Scheduler → orchestrator-simple → orchestrator-complex):**

| Condition | Escalate to orchestrator-complex |
|-----------|----------------------------------|
| 2+ failures in orchestrator-simple | ✅ |
| Task complexity = "complex" | ✅ |
| 3+ dependencies | ✅ |
| 3+ files to modify | ✅ |
| Terminal required (not available in -simple) | ✅ |

**Escalation Criteria (Layer 2: Modes -simple → -complex):**

| Condition | Escalate to *-complex |
|-----------|---------------------|
| 2+ failures in current mode | ✅ |
| Task complexity = "complex" | ✅ |
| 3+ files to modify | ✅ |
| 3+ dependencies | ✅ |

**Escalation Chains:**

| Mode Family | Chain |
|-------------|-------|
| `code` | code-simple → code-complex → orchestrator-complex |
| `debug` | debug-simple → debug-complex → orchestrator-complex |
| `ask` | ask-simple → ask-complex → orchestrator-complex |
| `orchestrator` | orchestrator-simple → orchestrator-complex |

**Usage Example:**
```powershell
$escalationResult = Test-EscalationCriteria -CurrentMode "code-simple" -FailureCount 2 -TaskComplexity "complex" -FilesToModify 5

if ($escalationResult.ShouldEscalate) {
    Write-EscalationEvent -FromMode "code-simple" -ToMode $escalationResult.RecommendedMode -Reason $escalationResult.Reason -MachineName $MachineName
}
```

---

### 4. WinCliPatterns.psm1

**Purpose:** Standardized shell command execution via win-cli MCP.

**Key Functions:**
- `Invoke-WinCliCommand` - Execute any shell command (powershell, cmd, bash)
- `Invoke-GitCommand` - Git commands with error handling
- `Get-GitBranch` - Current branch name
- `Test-GitWorkspaceClean` - Check for uncommitted changes
- `Get-GitCommitHash` - Short commit hash
- `Read-WinCliFile` - Read file contents
- `Write-WinCliFile` - Write file contents
- `Get-WinCliFiles` - List directory files
- `Test-WinCliFileExists` - Check file existence
- `Get-WinCliFileMetadata` - Get file metadata

**Usage Example:**
```powershell
# Execute Git command
$result = Invoke-GitCommand -GitCommand "status --porcelain" -NoLog

if (-not $result.Success -or -not [string]::IsNullOrWhiteSpace($result.Output)) {
    Write-INTERCOMMessage -Type "WARN" -Title "Workspace not clean" -Content "Git workspace is dirty" -MachineName $MachineName
}

# Read file
$content = Read-WinCliFile -Path "path/to/file.txt" -Encoding "UTF8"

# List files
$files = Get-WinCliFiles -Path "scripts/" -Filter "*.ps1" -Recurse
```

**Return Format:**
```powershell
@{
    Success = $true/false
    Output = "command output"
    Error = "error message if any"
    ExitCode = 0
}
```

---

## Workflow 1: Executor (workflow-executor.ps1)

**Machines:** myia-po-2023, myia-po-2024, myia-po-2025, myia-po-2026, myia-web1
**Interval:** 6 hours
**Entry Point:** `Start-ExecutorWorkflow`

### Cycle Steps

**STEP 0: Pre-flight Check (OBLIGATORY)**
- Verify win-cli and roo-state-manager availability
- Report to INTERCOM
- **ABORT if failed**

**STEP 0b: Heartbeat (OBLIGATORY)**
- Register heartbeat via roosync_heartbeat MCP
- Mark machine as online

**STEP 1: Git Pull + Read INTERCOM**
- Pull latest changes: `git pull origin main`
- Read INTERCOM for [SCHEDULED], [TASK], [URGENT] messages

**STEP 2: Process Tasks**

**2a: Scheduled tasks**
- Process [SCHEDULED] messages via Get-INTERCOMTasks
- Delegate via new_task (Roo) or execute directly

**2a: Urgent tasks**
- Process [URGENT] messages with priority

**2a: RooSync messages**
- Check RooSync inbox for coordinator messages
- Process [DONE], [FRICTION], [ASK], [WORK] messages

**2b: Default tasks** (if no scheduled/urgent tasks)
- Verify workspace status (git status)
- Check for build requirement
- Check GitHub issues

**2c-idle: Idle consolidation** (if still nothing to do)
- Execute consolidation tasks per issue #656:
  - Scripts datés (P0)
  - Scripts dupliqués (P1)
  - Docs obsolètes (P0)
  - Synthèse rapports (P2)
  - Index docs (P2)

**STEP 3: Report to INTERCOM (OBLIGATORY)**
- Write cycle report with metrics
- Include: scheduled tasks count, urgent tasks count, default tasks executed, idle consolidation, errors

### Example Output

```markdown
## [2026-03-15 09:00:00] claude-code -> roo [COORDINATION]

### Executor cycle report

**Cycle Type:** Executor
**Machine:** myia-po-2023
**Timestamp:** 2026-03-15 09:00:00

**Scheduled Tasks:** 2
**Urgent Tasks:** 0
**Default Tasks:** Executed
**Idle Consolidation:** Yes

**Errors:** None

---
```

---

## Workflow 2: Coordinator (workflow-coordinator.ps1)

**Machine:** myia-ai-01 ONLY
**Interval:** 8 hours
**Entry Point:** `Start-CoordinatorWorkflow`

### Cycle Steps

**STEP 0: Pre-flight Check (OBLIGATORY)**
- Same as executor

**STEP 1b: Check Heartbeats**
- Query heartbeat status for all 6 machines
- Identify offline or warning machines
- Report to INTERCOM

**STEP 1c: Config-Sync (optional, if >24h since last)**
- Check last config-sync timestamp
- If >24h or forced:
  - roosync_config(action: "collect") → Collect local config
  - roosync_config(action: "publish") → Publish to GDrive
  - roosync_config(action: "apply") → Apply to all machines
  - Update timestamp file

**STEP 1d: Auto-Review Commits (OBLIGATOIRE if HEAD changed)**
- Review commits since last run (default: 24h)
- Check for suspicious patterns:
  - revert, force, breaking, temp, wip, fixup, squash
- Report findings to INTERCOM

**STEP 1e: Analyze GitHub Project #67**
- Query Project #67 for issue status
- Analyze:
  - Issues per machine
  - Status distribution (Todo/In Progress/Done)
  - Overdue items
  - Idle machines (>48h no activity)

**STEP 2: Process Tasks**

**2a: Execute INTERCOM tasks**
- Read INTERCOM for scheduled tasks

**2a-bis: Create Cross-Workspace tasks**
- Generate tasks for other machines/workspaces via new_task delegation

**2b: Default tasks**
- RooSync dispatch, GitHub issues, etc.

**2c-idle: Coordinator Idle Tasks**
- Review and dispatch GitHub issues
- Update coordination documentation
- Analyze patterns from recent cycles

**STEP 3: Report to INTERCOM (OBLIGATORY)**
- Write coordinator cycle report
- Include: heartbeat status, messages processed, cross-workspace tasks, config-sync, auto-review commits, errors

### Coordinator-Specific Functions

**Get-HeartbeatStatus**
```powershell
$result = @{
    Online = @("myia-ai-01", "myia-po-2023", ...)
    Offline = @()
    Warning = @()
    LastChecked = Get-Date
}
```

**Invoke-RooSyncDispatch**
- Process RooSync inbox messages from executor machines
- Handle [DONE], [FRICTION], [ASK], [WORK] messages

**Invoke-CrossWorkspaceTasks**
- Create tasks for other machines/workspaces
- Uses new_task delegation

**Invoke-ConfigSync**
- Execute config-sync across machines
- Uses roosync_config MCP tool

**Invoke-AutoReviewCommits**
- Review commits since last coordinator run
- Detect suspicious patterns

**Get-GitHubProjectStatus**
- Analyze Project #67
- Identify idle machines, overdue tasks

**Invoke-CoordinatorIdleTasks**
- Review unassigned GitHub issues
- Review deferred proposals
- Update coordination documentation
- Analyze communication patterns

---

## Workflow 3: Meta-Analyst (workflow-meta-analyst.ps1)

**Machines:** ALL (including myia-ai-01)
**Interval:** 72 hours
**Entry Point:** `Start-MetaAnalystWorkflow`

### Purpose

Independently analyze **BOTH** schedulers (Roo + Claude) on the local machine, then reconcile findings via META-INTERCOM.

### What Meta-Analysts Analyze

**1. Local Roo scheduler traces**
- Path: `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/`
- Success/failure rates per mode
- Escalation patterns
- Tool usage patterns
- Delegation effectiveness

**2. Local Claude session transcripts**
- Path: `~/.claude/projects/*/`
- Worker execution logs
- Error patterns
- Model escalation frequency

**3. Both harnesses (cross-analysis)**
- Roo analyzes `.claude/rules/`, `CLAUDE.md`, `.claude/commands/`, `.claude/skills/`
- Claude analyzes `.roo/rules/`, `.roomodes`, `scheduler-workflow-*.md`, `modes-config.json`

**4. Operational metrics**
- Issues created vs closed
- Machine utilization
- Guard rail violations

### Cycle Steps

**STEP 0: Pre-flight Check (OBLIGATORY)**
- Same as other workflows

**STEP 1: Collect Traces**

**1a: Collect Roo traces**
```powershell
$tasksPath = "$env:APPDATA\Code\User\globalStorage\rooveterinaryinc.roo-cline\tasks"
$tasks = Get-ChildItem $tasksPath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

**1b: Collect Claude traces**
```powershell
$cclaudePath = "$env:USERPROFILE\.claude\projects"
$sessions = Get-ChildItem $cclaudePath -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

**STEP 2: Analyze Traces**

**2a: Analyze Roo scheduler**
- Success/failure rates per mode
- Escalation patterns
- Tool usage patterns
- Delegation effectiveness

**2b: Analyze Claude scheduler**
- Worker execution logs
- Error patterns
- Model escalation frequency

**2c: Cross-analysis**
- Roo analyzes Claude harness files
- Claude analyzes Roo harness files
- Each more free to critique the OTHER harness

**STEP 3: Reconcile via META-INTERCOM**

**3a: Write analysis to META-INTERCOM**
- File: `.claude/local/META-INTERCOM-{MACHINE}.md`
- Separate from operational INTERCOM
- Same format as INTERCOM but for meta-analysis

**3b: Cross-machine consultation (OPTIONAL)**
- If both local agents agree on a non-trivial finding
- Send RooSync message with tag `[META-CONSULT]`
- Collect responses at next cycle (24h)

**STEP 4: Create GitHub Issues (if needed)**

**Decision Chain:**
| Finding type | Action |
|-------------|--------|
| Informational (stats, rates) | Append to analysis doc + META-INTERCOM (Autonomous) |
| Operational suggestion | Write to META-INTERCOM, coordinator picks up (Autonomous) |
| Environment issue | Write to META-INTERCOM + flag for coordinator (Autonomous) |
| New issue (bug, friction) | Create with `needs-approval` label (Semi-autonomous) |
| Harness change | Create with `needs-approval` + `harness-change` (**BLOCKED until user approval**) |

**STEP 5: Report**
- Write meta-analysis report to INTERCOM
- Store detailed analysis on GDrive: `.shared-state/meta-analysis/{machine}/`

### META-INTERCOM Protocol

**File:** `.claude/local/META-INTERCOM-{MACHINE}.md`

**Template:** `.claude/local/META-INTERCOM_TEMPLATE.md`

**Dedicated channel** for meta-analysis reconciliation. Separate from operational INTERCOM.

**Workflow:**
1. Agent A writes its analysis (self + cross) to META-INTERCOM
2. Agent B reads Agent A's analysis, writes its own + reconciliation notes
3. Both agents can comment on the other's findings
4. Actionable findings become GitHub issues with `needs-approval`

**Cross-Machine Consultation:**
- When both local meta-analysts AGREE on a non-trivial finding
- Send RooSync message with tag `[META-CONSULT]`
- Include reconciled finding + specific question
- Collect responses at next meta-analysis cycle (24h)
- If consensus reached → create issue with `needs-approval`
- If disagreement → document in META-INTERCOM, escalate to coordinator

---

## INTERCOM vs META-INTERCOM vs RooSync

**CRITICAL DISTINCTION:**

| Channel | Scope | Usage | Tool |
|---------|-------|-------|------|
| **INTERCOM** | Local (same machine, same workspace) | Roo ↔ Claude Code communication | File: `.claude/local/INTERCOM-{MACHINE}.md` |
| **META-INTERCOM** | Local (same machine) | Meta-analysis reconciliation | File: `.claude/local/META-INTERCOM-{MACHINE}.md` |
| **RooSync** | **INTER-MACHINES** and **INTER-WORKSPACES** | Messages between different machines/workspaces | MCP `roosync_send/read/manage` |

**Common mistake:**
- ❌ Using INTERCOM for inter-machine communication
- ❌ Using RooSync for local Roo ↔ Claude communication
- ✅ INTERCOM = Local file, RooSync = GDrive shared state

---

## Windows Task Scheduler Integration

### Task Names

| Task | Machine | Interval | Script |
|------|---------|----------|--------|
| `Claude-Worker` | myia-po-*, myia-web1 | 6h | `scripts/scheduling/start-claude-worker.ps1` |
| `Claude-Coordinator` | myia-ai-01 | 8h | `scripts/scheduling/start-claude-coordinator.ps1` |
| `Claude-Meta-Analyst` | ALL | 72h | `scripts/scheduling/start-claude-meta-analyst.ps1` |

### Setup Script

**Location:** `scripts/scheduling/setup-scheduler.ps1`

**Actions:**
```powershell
# Install worker
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType worker

# Install coordinator
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType coordinator

# Install meta-analyst
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType meta-analyst

# List status
.\scripts\scheduling\setup-scheduler.ps1 -Action list -TaskType worker

# Test (dry run)
.\scripts\scheduling\setup-scheduler.ps1 -Action test -TaskType worker

# Remove
.\scripts\scheduling\setup-scheduler.ps1 -Action remove -TaskType worker
```

### ⚠️ CRITICAL: Never Install from a Worktree (Issue #731)

**`setup-scheduler.ps1` uses `$scriptDir` to resolve script paths.** If installed from inside a worktree, the schtask will be hardcoded to the worktree's temporary path.

**When the worktree is deleted**, the scheduled task continues to "run" every 6h but **silently fails** (script not found, no log created, no error shown).

**Incident:** 2026-03-14 — Both `Claude-Worker` and `Claude-MetaAudit` tasks were pointing to a deleted worktree path for 76h before detection.

**Rule:** ALWAYS run `setup-scheduler.ps1` from the **main repository**:

```powershell
# CORRECT: From main repo
cd D:\dev\roo-extensions\scripts\scheduling
.\setup-scheduler.ps1 -Action install

# WRONG: From inside a worktree (will fail after worktree cleanup)
cd D:\dev\roo-extensions\.claude\worktrees\wt-feature-xyz\scripts\scheduling
.\setup-scheduler.ps1 -Action install  # ❌ DO NOT DO THIS
```

**After any worktree cleanup**, verify and reinstall tasks from main repo:

```powershell
# Verify task paths
schtasks /Query /TN "Claude-Worker" /FO LIST | findstr "Task To Run"
schtasks /Query /TN "Claude-MetaAudit" /FO LIST | findstr "Task To Run"

# Reinstall if paths contain ".claude/worktrees/"
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType worker
.\scripts\scheduling\setup-scheduler.ps1 -Action install -TaskType meta-audit
```

The script now detects worktree installation and aborts with an error (added in commit `7f66ea3e`).

### Staggering

**Start times are staggered** to avoid all machines running simultaneously:

| Machine | Start Minute |
|---------|--------------|
| myia-ai-01 | 00 |
| myia-po-2023 | 30 |
| myia-po-2024 | 00 |
| myia-po-2025 | 30 |
| myia-po-2026 | 00 |
| myia-web1 | 30 |

---

## Guard Rails

### Meta-Analysts MUST NOT:
- Modify any harness file (`.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/`)
- Modify `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md`
- Close, archive, or dispatch GitHub issues (coordinator's job)
- Force-push, rebase, or destructive git operations
- Create issues WITHOUT `needs-approval` label

### Meta-Analysts CAN:
- Read all local traces (Roo tasks, Claude sessions)
- Read all harness files (both systems)
- Create issues with `needs-approval` (proposals, not decisions)
- Write to META-INTERCOM
- Write analysis docs to GDrive
- Comment on existing issues with analysis findings

### All Workflows:
- **NEVER proceed without pre-flight check passing**
- **NEVER use degraded mode** (stop and repair if critical MCP missing)
- **ALWAYS report to INTERCOM** (operational) or META-INTERCOM (meta-analysis)
- **ALWAYS preserve chronological order** when writing to INTERCOM/META-INTERCOM

---

## Troubleshooting

### Pre-flight Check Fails

**Symptom:** `Test-PreFlightCheck` returns false

**Actions:**
1. Check MCP configuration:
   - Roo: `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/settings/mcp_settings.json`
   - Claude Code: VS Code settings UI or `~/.claude.json`
2. Verify win-cli points to fork local (NOT `npx @anthropic/win-cli`)
3. Verify roo-state-manager server is running
4. Restart VS Code after MCP config changes
5. Document in INTERCOM with `[CRITICAL]` tag

### INTERCOM File Corruption

**Symptom:** Messages not in chronological order, missing separators

**Cause:** Agent wrote at beginning instead of appending to end

**Prevention:**
- **ALWAYS append to end** (use `Add-Content` in PowerShell, `Edit` with `replace_all: false` in Claude Code)
- Read file first to find last separator `---`

**Recovery:**
- Use `intercompactor` agent to condense and restructure
- Restore from backup if available

### Workflow Hangs

**Symptom:** Workflow running for >2 hours without progress

**Actions:**
1. Check traces in `%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/`
2. Check INTERCOM for last message
3. Look for infinite loops in Git operations or file reads
4. Check for MCP timeout (win-cli, roo-state-manager)
5. Kill and restart scheduled task if needed

### Heartbeat Not Registered

**Symptom:** Machine not appearing in coordinator heartbeat status

**Actions:**
1. Verify `roosync_heartbeat(action: "register")` is being called
2. Check ROOSYNC_MACHINE_ID environment variable
3. Verify roo-state-manager MCP is available
4. Check GDrive shared state is accessible
5. Restart heartbeat monitoring: `roosync_heartbeat(action: "start")`

---

## References

- **Issue #689:** "[SCHEDULER] Unifier workflows scheduler"
- **Issue #540:** "Coordinator tier - 6-12h scheduled analysis"
- **Issue #551:** "Meta-Analyst tier - 72h independent analysis"
- **`.claude/rules/tool-availability.md`:** Pre-flight check protocol
- **`.claude/rules/intercom-protocol.md`:** INTERCOM writing rules
- **`.claude/rules/meta-analysis.md`:** META-INTERCOM protocol
- **`docs/roosync/GUIDE-TECHNIQUE-v2.3.md`:** RooSync technical guide
- **`docs/roo-code/SCHEDULER_SYSTEM.md`:** Roo scheduler reference

---

**Last updated:** 2026-03-15
**Maintainer:** Coordinateur RooSync (myia-ai-01)
