# Agent: task-router

**Workspace:** Hermes
**Trigger:** On-demand (when `[TASK-ROUTE]` appears on global dashboard)
**Output:** `[DELEGATED]` on target workspace dashboard

---

## Purpose

Monitor the global dashboard for task routing requests. Evaluate routing rules and delegate tasks to appropriate workspaces with hand-off tracking.

---

## Workflow

### Step 1: Read global dashboard
```
roosync_dashboard(action: "read", type: "global", section: "intercom")
```

### Step 2: Identify unrouted tasks

Look for messages tagged `[TASK-ROUTE]` that haven't been delegated yet.

### Step 3: Evaluate routing rules

For each unrouted task:
1. Extract task description, keywords, and priority
2. Apply routing heuristics (see `.claude/rules/routing-rules.md`)
3. Check target workspace capacity (utilization <80%, active <2h ago)
4. Determine confidence level (HIGH/MEDIUM/LOW)

### Step 4: Delegate to target workspace

```
roosync_dashboard(
  action: "append",
  type: "workspace",
  workspace: "{target}",
  tags: ["DELEGATED"],
  content: "## [DELEGATED] Task #{issue} from workspace-{source}\n\n..."
)
```

### Step 5: Track hand-off

Post hand-off status on global dashboard:
```
roosync_dashboard(
  action: "append",
  type: "global",
  tags: ["HAND-OFF"],
  content: "## [HAND-OFF] Task #{issue}\n\n**Status:** In Transit\n..."
)
```

### Step 6: Monitor completion

Periodically check target workspace for:
- `[ACK]` acknowledgment message
- `[RESULT]` completion message
- SLA breach (timeout without acknowledgment)

### Step 7: Close hand-off

When target workspace posts `[RESULT]`:
```
roosync_dashboard(
  action: "append",
  type: "global",
  tags: ["HAND-OFF", "CLOSED"],
  content: "## [CLOSED] Task #{issue}\n\n**SLA met:** YES/NO\n..."
)
```

---

## Routing Decision Process

```
Input: Task description + keywords + priority
  ↓
1. Match keywords → candidate workspaces
  ↓
2. Check capacity → filter out full workspaces
  ↓
3. Check activity → filter out stale workspaces
  ↓
4. Select best candidate (highest confidence)
  ↓
5. Delegate → track hand-off
  ↓
6. If no candidate → [UNROUTED] on global dashboard
```

---

## Constraints

- Never route to a workspace >80% utilization
- Never route to a workspace inactive >48h
- Always set an SLA based on priority
- Log all routing decisions on global dashboard for audit trail
- If uncertain, keep task on global dashboard and flag for coordinator
