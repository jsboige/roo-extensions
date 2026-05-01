# Hermes Deployment Guide

**Issue:** #1862
**Version:** 1.0.0
**Date:** 2026-05-01

---

## Prerequisites

1. Target machine has Claude Code CLI installed
2. MCP roo-state-manager is configured in `~/.claude.json` (global config)
3. Google Drive shared state is accessible (`ROOSYNC_SHARED_PATH` env var set)
4. Git is available (for workspace versioning)

---

## Quick Deploy (any machine)

### 1. Create workspace directory

```bash
# Choose a location (any drive/path works)
mkdir -p /c/dev/hermes
cd /c/dev/hermes
git init
```

### 2. Copy templates

```bash
# From roo-extensions repo
cp -r docs/hermes/templates/.claude .claude
```

### 3. Verify MCP access

Open Claude Code in the hermes directory and verify:

```
roosync_dashboard(action: "list")
```

Should return ~30 dashboards including `global`, workspace, and machine types.

### 4. Test cross-workspace read

```
roosync_dashboard(action: "read", type: "global")
roosync_dashboard(action: "read", type: "workspace", workspace: "roo-extensions", section: "status")
```

### 5. Post first message

```
roosync_dashboard(
  action: "append",
  type: "global",
  tags: ["ONLINE", "INFO"],
  content: "Hermes workspace online on {machine-id}",
  author: {machineId: "{machine-id}", workspace: "hermes"}
)
```

---

## Cross-Workspace Validation Results

Tested from myia-po-2025 (roo-extensions workspace) on 2026-05-01:

| Operation | Tool Call | Result |
|-----------|-----------|--------|
| List all dashboards | `roosync_dashboard(action: "list")` | 30 dashboards found |
| Read global dashboard | `roosync_dashboard(action: "read", type: "global")` | OK (0.4% util, empty) |
| Read nanoclaw workspace | `roosync_dashboard(action: "read", type: "workspace", workspace: "nanoclaw")` | OK (89.7% util, 24 msgs) |
| Read CoursIA workspace | `roosync_dashboard(action: "read", type: "workspace", workspace: "CoursIA")` | OK (78.6% util, 27 msgs) |
| Read roo-extensions workspace | `roosync_dashboard(action: "read", type: "workspace")` | OK (56.9% util, 17 msgs) |

**Conclusion:** All Hermes operations work from any workspace. No new MCP tools needed.

---

## Active Workspaces (as of 2026-05-01)

| Workspace | Machine | Utilization | Status |
|-----------|---------|-------------|--------|
| roo-extensions | 6 machines | 56.9% | Active |
| CoursIA | 5 machines | 78.6% | Active |
| roo-state-manager | po-2024 | 80.4% | Active |
| nanoclaw | web1/nanoclaw-cluster | 89.7% | Active |
| vllm | ai-01 | 62.6% | Active |
| 2025-Epita-Intelligence-Symbolique | po-2023 | 46.2% | Active |
| Argumentum | po-2023 | 78.2% | Active |
| Maintenance | ai-01 | 40.4% | Active |

---

## Machine Selection

| Machine | Pros | Cons | Verdict |
|---------|------|------|---------|
| **po-2026** | Design recommends it, familiar with OMC | Currently working #1854 | Best if available |
| **po-2025** | Available now, intermittent is OK for Hermes | Personal machine, not always on | Viable for demo |
| **web1** | Has nanoclaw cross-workspace experience | Often offline, needs restart | Backup |

**Recommendation:** po-2025 for Phase 2 demo (immediate), po-2026 for production deployment.
