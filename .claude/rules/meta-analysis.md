# Meta-Analysis Protocol - 3x2 Scheduler Architecture

**Version:** 1.1.0
**Created:** 2026-03-04
**Updated:** 2026-03-05
**Issue:** #551 (Meta-Analyst tier)

---

## Overview

The meta-analysis tier is part of the **3-tier scheduling architecture** (3 types x 2 agents = 6 schedulers):

| Tier | Frequency | Machines | Role |
|------|-----------|----------|------|
| **Meta-Analyst** | 24h | ALL | Observe, analyze, PROPOSE |
| Coordinator | 6-12h | ai-01 only | Triage, dispatch, track |
| Executor | 3h | ALL | Execute assigned tasks |

Each tier has 2 agents: one Roo scheduler + one Claude scheduler.

---

## Meta-Analyst Role

**Mission:** Independently analyze BOTH schedulers (Roo + Claude) on the local machine, then reconcile findings via META-INTERCOM.

### What Meta-Analysts Analyze

1. **Local Roo scheduler traces** (`%APPDATA%/Code/User/globalStorage/rooveterinaryinc.roo-cline/tasks/`)
   - Success/failure rates per mode
   - Escalation patterns
   - Tool usage patterns
   - Delegation effectiveness

2. **Local Claude session transcripts** (`~/.claude/projects/*/`)
   - Worker execution logs
   - Error patterns
   - Model escalation frequency

3. **Both harnesses** (cross-analysis):
   - Roo analyzes `.claude/rules/`, `CLAUDE.md`, `.claude/commands/`, `.claude/skills/`
   - Claude analyzes `.roo/rules/`, `.roomodes`, `scheduler-workflow-*.md`, `modes-config.json`
   - Each is more free to critique the OTHER harness

4. **Operational metrics**:
   - Issues created vs closed
   - Machine utilization
   - Guard rail violations

### What Meta-Analysts Produce

- **Analysis docs** on GDrive (structured, timestamped)
- **META-INTERCOM entries** (reconciliation)
- **GitHub issues with `needs-approval`** (proposed improvements)
- **GitHub issues with `needs-approval` + `harness-change`** (proposed harness modifications, BLOCKED until user approval)

---

## META-INTERCOM Protocol

**File:** `.claude/local/META-INTERCOM-{MACHINE}.md`

Dedicated channel for meta-analysis reconciliation. Same format as INTERCOM but SEPARATE from operational communication.

**Template:** `.claude/local/META-INTERCOM_TEMPLATE.md`

### Workflow

1. Agent A writes its analysis (self + cross) to META-INTERCOM
2. Agent B reads Agent A's analysis, writes its own + reconciliation notes
3. Both agents can comment on the other's findings
4. Actionable findings become GitHub issues with `needs-approval`

### Cross-Machine Consultation (after local reconciliation)

When both local meta-analysts (Roo + Claude) **agree** on a finding via META-INTERCOM, they MAY consult other machines' agents via RooSync to gather broader perspective before creating an issue.

**Conditions for cross-machine consultation:**
- Both local agents have written their analysis to META-INTERCOM
- The finding is **non-trivial** (not just "everything is fine")
- The finding affects multiple machines or is architectural

**Procedure:**
1. The Claude meta-analyst sends a RooSync message with tag `[META-CONSULT]`
   - Subject: `[META-CONSULT] {finding summary}`
   - Body: The reconciled finding + specific question for other machines
   - To: `all` or specific machines relevant to the finding
2. Responses are collected at the next meta-analysis cycle (24h)
3. If consensus is reached across machines → create issue with `needs-approval`
4. If disagreement → document in META-INTERCOM, escalate to coordinator

**Guard rail:** Cross-machine consultation is READ-ONLY. Meta-analysts still cannot dispatch, modify files, or close issues on other machines.

### Agentic Deliberation (sk-agent, experimental)

For complex or high-impact findings, meta-analysts MAY trigger an **agentic conversation** via `sk-agent` to get structured multi-perspective deliberation before proposing an action.

**Use cases:**
- Architectural decisions affecting the scheduling pipeline
- Conflicting findings between machines
- Trade-offs requiring structured debate (e.g., tool removal vs retention)

**Procedure:**
1. Prepare a concise brief with the finding, context, and options
2. Call `run_conversation(conversation: "deep-think")` or `call_agent(agent: "critic")` with the brief
3. Capture the deliberation output
4. Include the deliberation summary in the `needs-approval` issue body

**Status:** Experimental. See issue tracking sk-agent capabilities (code access, git context).
Requires validation before production use.

---

## Decision Chain

| Finding type | Action | Authority |
|-------------|--------|-----------|
| Informational (stats, rates) | Append to analysis doc + META-INTERCOM | Autonomous |
| Operational suggestion | Write to META-INTERCOM, coordinator picks up | Autonomous |
| Environment issue (missing .env, MCP down, service unreachable) | Write to META-INTERCOM + flag for coordinator | Autonomous (coordinator acts) |
| New issue (bug, friction) | Create with `needs-approval` label | Semi-autonomous |
| Harness change | Create with `needs-approval` + `harness-change` | **BLOCKED until user approval** |

**Environment issues are a priority escalation path.** Meta-analysts detect these in execution traces (failed tool calls, missing configs, service timeouts) and flag them in META-INTERCOM. The coordinator is responsible for sending corrective instructions to affected machines. See `.claude/rules/scheduled-coordinator.md` section 4.

---

## Guard Rails (CRITICAL)

### Meta-analysts MUST NOT:
- Modify any file in `.roo/rules/`, `.claude/rules/`, `.claude/commands/`, `.claude/skills/`
- Modify `CLAUDE.md`, `.roomodes`, `modes-config.json`, `scheduler-workflow-*.md`
- Close, archive, or dispatch GitHub issues (that is the Coordinator's job)
- Force-push, rebase, or destructive git operations
- Create issues WITHOUT `needs-approval` label

### Meta-analysts CAN:
- Read all local traces (Roo tasks, Claude sessions)
- Read all harness files (both systems)
- Create issues with `needs-approval` (proposals, not decisions)
- Write to META-INTERCOM
- Write analysis docs to GDrive
- Comment on existing issues with analysis findings

---

## GDrive Storage

```
.shared-state/meta-analysis/
  +-- {machine}/
  |   +-- claude-analysis-{date}.md
  |   +-- roo-analysis-{date}.md
  +-- reconciliation/
      +-- {machine}-{date}.md
```

---

## References

- #551: Meta-Analyst tier (this protocol)
- #540: Coordinator tier — see `.claude/rules/scheduled-coordinator.md`
- `.claude/INTERCOM_PROTOCOL.md`: Operational INTERCOM (separate)
- `.claude/rules/condensation-thresholds.md`: GLM context limits

---

**Last updated:** 2026-03-06
