# Routing Rules — Hermes Task Router

**Version:** 1.0.0
**Issue:** #1862

---

## Routing Heuristics (Phase 1 — Simple)

Tasks are routed based on content keywords and metadata. Phase 1 uses simple pattern matching. Phase 2 may use semantic search via `codebase_search`.

### Default Routing

| Task Type | Keywords | Target Workspace | Rationale |
|-----------|----------|-----------------|-----------|
| Code changes | `fix`, `feat`, `refactor`, `build`, `test` | `roo-extensions` | Primary code workspace |
| Container/Docker | `docker`, `container`, `nanoclaw` | `nanoclaw` | Container infrastructure |
| Documentation | `docs`, `README`, `CLAUDE.md` | Any available | Low priority, flexible |
| ML/Training | `train`, `model`, `GPU`, `epoch` | `CoursIA` | ML/AI workspace |
| Infrastructure | `MCP`, `server`, `config`, `deploy` | `roo-extensions` | Infra managed by primary |
| Unknown | — | `roo-extensions` | Safe default |

### Routing Decision Format

```markdown
## [TASK-ROUTE] Task #{issue} → {target-workspace}

**From:** workspace-{source}
**To:** workspace-{target}
**Reason:** {routing rationale}
**Keywords matched:** {matched keywords}
**Confidence:** HIGH/MEDIUM/LOW
**Expires:** {deadline (default: 48h)}
```

### Confidence Levels

- **HIGH**: Multiple keyword matches + workspace has capacity
- **MEDIUM**: Single keyword match OR workspace near capacity (>75%)
- **LOW**: No keyword match, defaulting to roo-extensions

### Capacity Check

Before routing to a workspace, check:
1. Dashboard utilization < 80% (below condensation threshold)
2. Last activity < 2h ago (workspace is active)
3. No `[BLOCKED]` status on the workspace

If capacity check fails → route to next best workspace or keep on global dashboard.

### Fallback

If no workspace matches → post `[UNROUTED]` on global dashboard with task details. Coordinator (ai-01) will handle manually.

---

## Phase 2 Enhancements (Future)

- Semantic routing via `codebase_search` on task description
- Workspace specialization profiles (auto-learned from past activity)
- Load balancing based on workspace utilization trends
- Priority-based routing (URGENT tasks get fastest workspace)
