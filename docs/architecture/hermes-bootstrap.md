# ADR: Hermes Workspace Bootstrap — Cross-Workspace Orchestrator

**Issue:** #1862
**EPIC:** #1864 (Cycle 26 — Cluster Expansion)
**Status:** Phase 2 Complete (Bootstrap + Demo)
**Author:** myia-po-2024 (Phase 1), myia-po-2026 (Phase 2)
**Date:** 2026-04-30 (Phase 1), 2026-05-01 (Phase 2)

---

## 1. Context

### 1.1 Vision

The user's strategic vision (2026-04-30) calls for expanding beyond a single workspace toward a **cluster of specialized harnesses** that interact with each other. The successful `nanoclaw` workspace (dashboard utilization 89.7%, 24 messages, autonomous agents) demonstrated the viability of cross-workspace coordination via RooSync dashboards.

**Hermes** is the codename for a new workspace specialized in messaging, routing, and orchestration across the cluster.

### 1.2 Existing Architecture

```
┌─────────────────────────────────────────────────────┐
│                   RooSync Layer                      │
│  (GDrive shared storage, dashboards, messages)      │
│                                                      │
│  ┌─────────────────┐  ┌──────────────────┐          │
│  │ workspace-       │  │ workspace-       │          │
│  │ roo-extensions   │  │ nanoclaw         │          │
│  │                  │  │                  │          │
│  │ 6 machines       │  │ 1 machine (web1) │          │
│  │ Roo+Claude       │  │ NanoClaw agents  │          │
│  │ 16 MCP tools     │  │ Docker+IPC       │          │
│  └─────────────────┘  └──────────────────┘          │
│                                                      │
│  ┌─────────────────┐                                │
│  │ dashboard-       │ ← global coordination layer    │
│  │ global           │                                │
│  └─────────────────┘                                │
└─────────────────────────────────────────────────────┘
```

### 1.3 Gap

Currently:
- **Cross-workspace communication** is ad-hoc: agents read/write different workspace dashboards manually
- **No routing**: tasks dispatched to wrong workspaces sit unclaimed
- **No audit trail**: cross-workspace hand-offs are not tracked
- **No archiving policy**: old workspace data accumulates without lifecycle management

---

## 2. Decision

Create **Hermes** as a dedicated workspace with specialized agents for cross-cluster messaging, routing, and audit.

### 2.1 Hermes Identity

| Attribute | Roo+Claude (current) | Hermes |
|-----------|---------------------|--------|
| **Role** | Code implementation, coordination | Message routing, audit, hand-offs |
| **Tasks** | Build features, fix bugs, review PRs | Route tasks, archive data, track cluster health |
| **Scope** | Per-workspace (roo-extensions) | Cross-workspace (all workspaces) |
| **Agent type** | Claude Code + Roo Code | Claude Code (lightweight) |
| **Primary tool** | roo-state-manager (16 tools) | roo-state-manager (read-only subset) |
| **Communication** | Dashboard workspace | Dashboard **global** |

**Key differentiator**: Hermes doesn't write code. It reads dashboards, routes messages, and maintains cluster-level metadata.

### 2.2 Hermes Capabilities

#### Cap 1: Task Routing

Hermes monitors the global dashboard for tasks posted by any workspace. When a task doesn't match the posting workspace's expertise, Hermes routes it:

```markdown
## [ROUTED] Task #{issue} → {target-workspace}

**From:** workspace-{source}
**To:** workspace-{target}
**Reason:** {routing rationale}
**Expires:** {deadline}
```

**Routing rules (Phase 1 — simple heuristic):**
- Code changes → `roo-extensions`
- Container/Docker tasks → `nanoclaw`
- Documentation-only → any available workspace
- Unknown → `roo-extensions` (default)

#### Cap 2: Cluster Health Audit

Hermes periodically reads all workspace dashboards and produces a cluster health report:

```markdown
## [CLUSTER-HEALTH] — {timestamp}

| Workspace | Utilization | Last Activity | Status |
|-----------|-------------|---------------|--------|
| roo-extensions | 44% | 5 min ago | Active |
| nanoclaw | 89.7% | 1h ago | Active |
| hermes | 12% | Just now | Active |

### Alerts
- nanoclaw: approaching condensation threshold (89.7%)
- po-2023: CRITICAL win-cli MCP down

### Recommendations
- Condense nanoclaw workspace
- Investigate po-2023 MCP issue
```

**Frequency:** On-demand or scheduled (4x/day).

#### Cap 3: Cross-Workspace Hand-off Tracking

When a task moves between workspaces, Hermes records the hand-off:

```markdown
## [HAND-OFF] Task #{issue}

**Origin:** workspace-roo-extensions (machine: myia-po-2024)
**Destination:** workspace-nanoclaw
**Type:** Delegation (specialized processing)
**Timestamp:** {ISO 8601}
**Status:** In transit
**SLA:** Response within 2h
```

**Lifecycle:** `In transit → Acknowledged → Processing → Complete → Closed`

### 2.3 Interaction Protocol

```
┌──────────────────┐         ┌─────────┐         ┌──────────────────┐
│ workspace-       │         │ Hermes  │         │ workspace-       │
│ roo-extensions   │         │         │         │ nanoclaw         │
│                  │         │         │         │                  │
│  1. Post task    │────────▶│         │         │                  │
│     [TASK-ROUTE] │  global │  2.     │         │                  │
│                  │  dash   │  Route  │         │                  │
│                  │         │         │────────▶│  3. Pick up      │
│                  │         │         │  target │     task         │
│                  │         │         │  dash   │                  │
│  5. Result       │◀────────│  4.     │         │                  │
│     posted       │  global │  Track  │         │                  │
│                  │  dash   │  hand-  │         │                  │
│                  │         │  off    │         │                  │
└──────────────────┘         └─────────┘         └──────────────────┘
```

**Protocol steps:**
1. Source workspace posts `[TASK-ROUTE]` on global dashboard
2. Hermes reads global dashboard, evaluates routing rules
3. Hermes posts task on target workspace dashboard with `[DELEGATED]`
4. Hermes tracks hand-off status on global dashboard
5. Target workspace completes task, posts result
6. Hermes records completion, optionally notifies source

### 2.4 Workspace Bootstrap

#### Machine Selection

| Criteria | po-2026 | web1 |
|----------|---------|------|
| Available | Yes (idle after cycle 25) | Pending user restart |
| Existing workspaces | roo-extensions | nanoclaw |
| Capacity | Good | Good |
| Cross-workspace experience | Yes | Yes (nanoclaw) |

**Recommendation:** Phase 1 on **po-2026** (available now, familiar with OMC patterns from #1854).

#### Directory Structure

```
/c/dev/hermes/                    # Distinct workspace root
├── .claude/
│   ├── CLAUDE.md                 # Hermes-specific instructions
│   ├── rules/                    # Hermes rules
│   │   ├── routing-rules.md      # Task routing heuristics
│   │   └── hand-off-protocol.md  # Cross-workspace hand-off rules
│   ├── agents/                   # Hermes agents
│   │   ├── cluster-monitor.md    # Health audit agent
│   │   └── task-router.md        # Routing agent
│   └── commands/
│       └── cluster-tour.md       # Hermes sync-tour equivalent
├── docs/
│   └── architecture/
│       └── hermes-bootstrap.md   # This document
└── .gitignore
```

#### Hermes CLAUDE.md Core

```markdown
# Hermes — Cross-Workspace Orchestrator

## Identity
Hermes is a **read-only** agent cluster. It does NOT write code. It routes tasks,
tracks hand-offs, and audits cluster health across all RooSync workspaces.

## Scope
- READ dashboards from all workspaces
- WRITE to global dashboard only (routing decisions, health reports)
- NEVER write to workspace-specific dashboards (that's each workspace's domain)

## Communication
- **Primary:** `roosync_dashboard(type: "global")` for routing + health
- **Secondary:** `roosync_send` for urgent cross-machine notifications
- **NEVER:** Direct INTERCOM (deprecated), code modifications

## Agents
1. `cluster-monitor` — Periodic health audit across workspaces
2. `task-router` — Route tasks to appropriate workspaces

## Constraints
- No git operations (read-only repos)
- No code modifications
- No MCP server management
- Dashboard writes limited to global type
```

### 2.5 Dashboard Integration

Hermes uses the **global dashboard** as its primary communication channel:

| Action | Dashboard type | Usage |
|--------|---------------|-------|
| Read all workspaces | `workspace` (each) | Cluster health monitoring |
| Post routing decisions | `global` | `[TASK-ROUTE]`, `[HAND-OFF]` |
| Post health reports | `global` | `[CLUSTER-HEALTH]` |
| Read messages | RooSync inbox | Cross-machine notifications |
| Send notifications | RooSync send | Urgent alerts to specific machines |

**No new MCP tools needed.** Hermes uses existing `roosync_dashboard` and `roosync_read/send` tools.

---

## 3. Implementation Phases

### Phase 1 (Design — MERGED via PR #1869)

- [x] Define Hermes identity and differentiation
- [x] Define interaction protocol with existing cluster
- [x] Define workspace bootstrap plan
- [x] Define dashboard integration strategy
- [x] Get coordinator/user approval
- [x] Select host machine: **po-2026** (confirmed)

### Phase 2 (Bootstrap — DONE 2026-05-01 by myia-po-2026)

- [x] Create workspace directory on host machine (`C:\dev\hermes\`)
- [x] Write Hermes CLAUDE.md and rules (routing-rules.md, hand-off-protocol.md)
- [x] Create `cluster-monitor` and `task-router` agents
- [x] Create `/cluster-tour` command
- [x] Test: read global dashboard + all workspace dashboards (32 dashboards found)
- [x] Test: post routing decision on global dashboard

**Workspace structure (commit `f2003d0`):**

```text
C:\dev\hermes\
├── .claude/
│   ├── CLAUDE.md              # Hermes identity + scope
│   ├── rules/
│   │   ├── routing-rules.md   # Keyword-based routing heuristics
│   │   └── hand-off-protocol.md  # Cross-workspace tracking lifecycle
│   ├── agents/
│   │   ├── task-router.md     # Route tasks to workspaces
│   │   └── cluster-monitor.md # Health audit agent
│   └── commands/
│       └── cluster-tour.md    # Cluster health check command
├── scripts/
│   └── router.py              # Routing prototype (Python)
├── docs/architecture/
├── README.md
└── .gitignore
```

### Phase 2.5 (Demo — DONE 2026-05-01)

- [x] Demo scenario: post task on `roo-extensions` workspace → Hermes routes → target workspace picks up
- [x] Measure: routing latency (~10 seconds)
- [x] Document lessons learned

#### Demo Evidence

**Scenario:** A `[TASK-ROUTE]` message was posted on the global dashboard requesting a fix for `dashboard.test.ts` failing tests. The Python router script processed it.

**Timeline:**

1. `11:03:31Z` — `[TASK-ROUTE]` posted on global dashboard by `myia-po-2026:roo-extensions`
2. `11:03:41Z` — `[ROUTED]` posted on global dashboard by `hermes|hermes` (10s latency)
3. `11:03:41Z` — `[DELEGATED]` posted on `workspace-roo-extensions` dashboard

**Routing result:**

- Target: `workspace-roo-extensions` (correct)
- Reason: `keyword(6 matches)` — code, build, test, vitest, fix, bug
- Confidence: 100%

**Limitations observed:**

- Message ID extraction from MCP-generated messages is fragile (regex-based)
- Source workspace extraction not implemented (falls back to "unknown")
- No deduplication — running the router twice would create duplicate `[ROUTED]` messages
- Router operates on raw GDrive files, not through MCP — bypasses locking/condensation

### Phase 3 (Next Steps — Future)

- [ ] Cluster health report demo (`cluster-monitor` agent)
- [ ] Add deduplication to router (check for existing [ROUTED] responses)
- [ ] Add source workspace extraction from message metadata
- [ ] Scheduler integration (automated routing every 30min)
- [ ] ML-based routing via `codebase_search` embeddings
- [ ] Remote git repository for hermes workspace

---

## 4. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Hermes becomes another Roo (code agent) | High | CLAUDE.md explicitly forbids code writes; rules enforced |
| Routing heuristics too simplistic | Medium | Phase 1 starts simple; Phase 2 adds ML-based routing via codebase_search |
| Global dashboard noise from Hermes posts | Medium | Use structured tags `[TASK-ROUTE]`, `[CLUSTER-HEALTH]` for filtering |
| No machine available for Hermes | Low | po-2026 is idle; web1 can host after restart |
| Cross-workspace permissions issue | Medium | RooSync uses same GDrive; workspace isolation is logical, not physical |

---

## 5. Alternatives Considered

1. **Hermes as MCP tool** — Add `roosync_route_task` to roo-state-manager. Rejected for Phase 1: routing is a workflow pattern, better as an agent that uses existing tools. Phase 2 could add a `roosync_pipeline` tool if routing logic stabilizes.

2. **Hermes as Roo mode** — Create a Roo mode "hermes-orchestrator" on existing machines. Rejected: Hermes needs cross-workspace visibility, which Roo modes don't have (each Roo is workspace-scoped).

3. **No Hermes, enhance existing coordinator** — Add routing to the ai-01 coordinator. Rejected: coordinator already has 18 agents + 6 skills. Adding routing would increase cognitive load. Separation of concerns is better.

4. **Hermes as Docker container** — Run Hermes like NanoClaw in a container. Rejected for Phase 1: unnecessary complexity. Claude Code CLI is sufficient.

---

## 6. References

- Issue #1862 — Hermes workspace bootstrap
- Issue #1853 — Team pipeline (OMC extraction, source of routing pattern)
- Issue #1864 — EPIC Cycle 26
- Issue #1802 — oh-my-claudecode evaluation (OMC patterns)
- Issue #1805 — Harness & Framework Investigations wrapup
- nanoclaw workspace — precedent for distinct workspace in cluster
- [RooSync Guide Technique v2.3](../../docs/roosync/GUIDE-TECHNIQUE-v2.3.md)
- [Dashboard Architecture](../architecture/roosync-real-diff-detection-design.md)
