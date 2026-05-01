# Hand-off Protocol — Cross-Workspace Task Tracking

**Version:** 1.0.0
**Issue:** #1862

---

## Hand-off Lifecycle

```
Initiated → In Transit → Acknowledged → Processing → Complete → Closed
```

### States

| State | Meaning | Who sets it |
|-------|---------|-------------|
| `Initiated` | Source workspace posts task on global dashboard | Source workspace |
| `In Transit` | Hermes routes task to target workspace | Hermes |
| `Acknowledged` | Target workspace confirms receipt | Target workspace |
| `Processing` | Target workspace starts working on task | Target workspace |
| `Complete` | Target workspace posts result | Target workspace |
| `Closed` | Hermes records completion | Hermes |

---

## Hand-off Message Format

### Initiation (source → global dashboard)

```markdown
## [TASK-ROUTE] Task #{issue} → {target}

**Origin:** workspace-{source} (machine: {machine-id})
**Task:** {brief description}
**Priority:** LOW/MEDIUM/HIGH/URGENT
**SLA:** {deadline}
**Status:** Initiated
```

### Routing (Hermes → target workspace dashboard)

```markdown
## [DELEGATED] Task #{issue} from workspace-{source}

**Routed by:** Hermes
**Reason:** {routing rationale}
**Origin:** workspace-{source} (machine: {machine-id})
**Deadline:** {deadline}
**Status:** In Transit
```

### Acknowledgment (target → global dashboard)

```markdown
## [ACK] Task #{issue}

**Workspace:** workspace-{target}
**Machine:** {machine-id}
**Status:** Acknowledged
**ETA:** {estimated completion time}
```

### Completion (target → global dashboard)

```markdown
## [RESULT] Task #{issue}

**Workspace:** workspace-{target}
**Machine:** {machine-id}
**Status:** Complete
**Result:** {brief summary}
**Artifacts:** {PR URL, commit SHA, etc.}
```

### Closure (Hermes → global dashboard)

```markdown
## [CLOSED] Task #{issue}

**Origin:** workspace-{source}
**Target:** workspace-{target}
**Total duration:** {time from initiation to completion}
**SLA met:** YES/NO
**Status:** Closed
```

---

## SLA Rules

| Priority | Acknowledgment | Processing | Completion |
|----------|---------------|------------|------------|
| URGENT | 15 min | 1h | 4h |
| HIGH | 30 min | 4h | 24h |
| MEDIUM | 2h | 24h | 48h |
| LOW | 24h | 48h | 1 week |

### SLA Violations

If acknowledgment SLA is breached:
1. Hermes posts `[SLA-ALERT]` on global dashboard
2. Hermes sends `roosync_send` to target machine
3. After 2x SLA breach, Hermes routes task to next available workspace

---

## Audit Trail

All hand-offs are tracked on the global dashboard with `[HAND-OFF]` tags. Hermes maintains a running count:

- Total hand-offs initiated
- Currently in transit
- SLA compliance rate
- Average completion time

This data is included in `[CLUSTER-HEALTH]` reports.
