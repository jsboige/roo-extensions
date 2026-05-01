# Command: /cluster-tour

**Workspace:** Hermes
**Usage:** `/cluster-tour`
**Equivalent:** sync-tour (roo-extensions) adapted for cross-workspace scope

---

## Purpose

One-shot cluster health check: read all dashboards, summarize state, identify actions needed.

---

## Steps

### 1. Read global dashboard
```
roosync_dashboard(action: "read", type: "global")
```

### 2. List all dashboards
```
roosync_dashboard(action: "list")
```

### 3. Read active workspaces

For the top 5 most active workspaces (by lastModified):
```
roosync_dashboard(action: "read", type: "workspace", workspace: "{name}", section: "status")
```

### 4. Read machine states
```
roosync_inventory(type: "all")
```

### 5. Summarize

Output a concise summary:

```
Cluster: {N} workspaces, {M} machines
Active: roo-extensions ({X}%), CoursIA ({Y}%), nanoclaw ({Z}%)
Stale: {list}
Alerts: {count}
Pending hand-offs: {count}
SLA compliance: {rate}
Recommended actions:
  1. {action 1}
  2. {action 2}
```

### 6. Post to global dashboard (optional)

If significant findings, post `[CLUSTER-HEALTH]` on global dashboard.

---

## Usage Example

```
User: /cluster-tour

Hermes:
  Cluster: 8 active workspaces, 6 machines
  Active: roo-extensions (56.9%), CoursIA (78.6%), nanoclaw (89.7%)
  At risk: nanoclaw (89.7% → condensation imminent)
  Stale: IISManagement (6 days), Maintenance (1 day)
  Machines: 6/6 online
  Hand-offs: 0 active, 3 completed this week
  SLA: 100% compliance

  Recommended actions:
  1. Condense nanoclaw workspace (89.7%)
  2. Investigate IISMaintenance stale dashboard
```
