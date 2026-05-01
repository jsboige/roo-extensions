# Agent: cluster-monitor

**Workspace:** Hermes
**Trigger:** Scheduled (4x/day) or on-demand
**Output:** `[CLUSTER-HEALTH]` on global dashboard

---

## Purpose

Periodically audit all workspace dashboards and produce a cluster health report. Identify anomalies, stale workspaces, capacity issues, and cross-workspace coordination gaps.

---

## Workflow

### Step 1: List all dashboards
```
roosync_dashboard(action: "list")
```

### Step 2: Read active workspace dashboards

For each workspace with activity in the last 7 days:
```
roosync_dashboard(action: "read", type: "workspace", workspace: "{name}", section: "status")
```

### Step 3: Read machine dashboards

For each machine:
```
roosync_dashboard(action: "read", type: "machine", machineId: "{id}", section: "status")
```

### Step 4: Compile health report

Generate the following metrics per workspace:
- **Utilization %** (current / 51200 bytes)
- **Last activity** (timestamp of last modification)
- **Message count** (intercom messages)
- **Condensation status** (approaching threshold? >80%)
- **Active tasks** (from status section)

### Step 5: Identify anomalies

Flag:
- Workspaces >80% utilization (condensation imminent)
- Workspaces with no activity >48h (stale)
- Machines not reporting heartbeat >2h
- Dashboard contradictions (from #1502 markers)

### Step 6: Post report

```
roosync_dashboard(
  action: "append",
  type: "global",
  tags: ["CLUSTER-HEALTH"],
  content: "..."
)
```

---

## Report Format

```markdown
## [CLUSTER-HEALTH] — {timestamp}

### Cluster Summary
| Workspace | Utilization | Last Activity | Messages | Status |
|-----------|-------------|---------------|----------|--------|
| roo-extensions | {X}% | {time} | {N} | Active/Stale/Alert |
| CoursIA | {X}% | {time} | {N} | Active/Stale/Alert |
| nanoclaw | {X}% | {time} | {N} | Active/Stale/Alert |
| ... | ... | ... | ... | ... |

### Machine Health
| Machine | Last Heartbeat | Status |
|---------|---------------|--------|
| myia-ai-01 | {time} | Online/Offline |
| myia-po-2023 | {time} | Online/Offline |
| ... | ... | ... |

### Alerts
- {workspace}: approaching condensation ({X}%)
- {machine}: no heartbeat for {Y}h
- {workspace}: stale dashboard ({Z} days)

### Hand-off Stats
- Active hand-offs: {N}
- SLA compliance: {X}%
- Average completion: {Y}h

### Recommendations
- {actionable recommendation 1}
- {actionable recommendation 2}
```

---

## Constraints

- Read-only: never modify workspace dashboards
- Report to global dashboard only
- Include all active workspaces (not just roo-extensions)
- Respect condensation thresholds — don't overload dashboards
