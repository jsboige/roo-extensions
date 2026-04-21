# Architecture Agents, Skills & Commands

**Version:** 2.0.0 (condensed from audit #556, moved from .claude/rules/)
**MAJ:** 2026-04-21
**Location:** Moved to `docs/harness/reference/` as part of rules consolidation #1606

---

## Principe

Deleguer les taches verboses a des subagents. La conversation principale orchestre.

## Subagents

### Projet (`.claude/agents/`)

`github-tracker`, `intercom-handler`, `intercom-compactor`, `sddd-router`, `task-planner`