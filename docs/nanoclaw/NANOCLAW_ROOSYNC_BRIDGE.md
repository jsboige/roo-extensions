# NanoClaw ↔ RooSync Bridge Design

**Issue:** #1319
**Author:** Claude Code (myia-po-2024)
**Date:** 2026-04-11
**Status:** Design Phase

---

## Executive Summary

This document describes the integration layer between NanoClaw agents and the RooSync coordination system.

**Recommended Approach:** Option A - MCP Server Bridge (NanoClaw Skill)

```
NanoClaw Container → MCP Client → roo-state-manager → RooSync Dashboard/Messages
```

---

## Architecture Overview

### Current State

#### NanoClaw (from #1318)
- **Runtime:** Docker container on ai-01
- **State:** SQLite (per-group isolation)
- **SDK:** Claude Agent SDK (Anthropic)
- **Communication:** Polling loop (channels → SQLite → container → response)
- **Customization:** Skills-based (CLAUDE.md per group)

#### RooSync (roo-state-manager MCP)
- **State:** Google Drive shared state
- **Protocol:** MCP (Model Context Protocol)
- **Transport:** Stdio (local)
- **Tools:** 34 tools for coordination, dashboard, conversations
- **Dashboard:** 3 types (global, machine, workspace)

### Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         NanoClaw Container                          │
│  ┌──────────────┐      ┌──────────────────────────────────────┐   │
│  │  CLAUDE.md   │──────│       NanoClaw Core                  │   │
│  │  (Group      │      │  (Claude Agent SDK + Skills)         │   │
│  │   Context)   │      │                                      │   │
│  └──────────────┘      │  ┌────────────────────────────────┐  │   │
│                        │  │  RooSync Skill (NEW)          │  │   │
│                        │  │  - roosync_dashboard()         │  │   │
│                        │  │  - roosync_send()              │  │   │
│                        │  │  - roosync_read()              │  │   │
│                        │  │  - roosync_heartbeat()         │  │   │
│                        │  └────────────────────────────────┘  │   │
│                        └──────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ MCP Stdio
                                    │ (via volume mount)
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Host (myia-ai-01)                                │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  roo-state-manager MCP Server                                │  │
│  │  - 34 tools (dashboard, RooSync, conversations, etc.)       │  │
│  │  - GDrive shared state access                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ GDrive API
                                    ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Google Drive Shared State                        │
│  - Dashboards (global, machine, workspace)                         │
│  - RooSync messages (inbox, sent)                                  │
│  - Heartbeat status                                                │
└─────────────────────────────────────────────────────────────────────┘
```

---

## NanoClaw RooSync Skill Design

### Skill Structure

```
nanoclaw/skills/roosync/
├── SKILL.md              # Skill definition (NanoClaw format)
├── index.ts              # MCP client wrapper
├── tools/
│   ├── dashboard.ts      # Dashboard operations
│   ├── messaging.ts      # Send/receive messages
│   └── heartbeat.ts      # Heartbeat registration
└── config/
    └── mcp-config.json   # MCP client configuration
```

### SKILL.md Format

```markdown
# RooSync Integration Skill

## Purpose
Enables NanoClaw agents to participate in the RooSync coordination system.

## MCP Tools

### roosync_dashboard
Read/write workspace dashboards for cross-machine coordination.

**Actions:**
- `read`: Read dashboard messages
- `append`: Post a new message with tags
- `write`: Replace status section

**Usage:**
```
roosync_dashboard(action="read", type="workspace")
roosync_dashboard(action="append", type="workspace", tags=["NANOCLAW", "INFO"], content="...")
```

### roosync_send
Send inter-machine messages to other agents.

**Parameters:**
- `to`: Target machine (e.g., "myia-ai-01")
- `subject`: Message subject
- `body`: Message body (markdown)
- `priority`: LOW/MEDIUM/HIGH/URGENT
- `tags`: Optional tags

**Usage:**
```
roosync_send(to="myia-ai-01", subject="Task complete", body="...", tags=["NANOCLAW"])
```

### roosync_read
Read the RooSync inbox.

**Usage:**
```
roosync_read(mode="inbox", status="unread", limit=20)
```

### roosync_heartbeat
Register agent heartbeat for cluster visibility.

**Actions:**
- `register`: Register/refresh heartbeat
- `status`: Check all machine heartbeats

**Usage:**
```
roosync_heartbeat(action="register", machineId="nanoclaw-ai-01", metadata={...})
```

## Best Practices

1. Always tag messages with `[NANOCLAW]` for visibility
2. Use workspace dashboard for coordination, not machine dashboard
3. Check heartbeat status before sending critical messages
4. Report task completion with `[DONE]` tags

## Integration Notes

- MCP server runs on host at `stdio:/path/to/roo-state-manager`
- Config mounted at `/nanoclaw/config/mcp-config.json`
- GDrive credentials injected via environment (not in container)
```

---

## MCP Client Configuration

### config/mcp-config.json

```json
{
  "mcpServers": {
    "roo-state-manager": {
      "command": "node",
      "args": [
        "/workspace/mcps/internal/servers/roo-state-manager/dist/index.js"
      ],
      "cwd": "/workspace",
      "env": {
        "ROOSYNC_MACHINE_ID": "nanoclaw-ai-01",
        "ROOSYNC_SHARED_PATH": "/mnt/gdrive/roosync",
        "GOOGLE_APPLICATION_CREDENTIALS": "/tmp/credentials.json"
      }
    }
  }
}
```

### Docker Volume Mounts

```yaml
volumes:
  # Workspace mount
  - C:/dev/roo-extensions:/workspace

  # MCP server access
  - C:/dev/roo-extensions/mcps/internal/servers/roo-state-manager:/workspace/mcps/internal/servers/roo-state-manager

  # GDrive shared state (read-only for container)
  - G:/roosync:/mnt/gdrive/roosync:ro

  # Credentials (injected at runtime, not in Docker image)
  - ${APPDATA}/gdrive-credentials.json:/tmp/credentials.json:ro
```

---

## Implementation Steps

### Phase 1: Infrastructure (PREREQUISITE from #1318)
- [x] Docker Desktop on ai-01 (#1171)
- [ ] Fork qwibitai/nanoclaw into jsboige org
- [ ] Set up Docker Compose on ai-01
- [ ] Configure z.ai endpoint for Claude Agent SDK

### Phase 2: MCP Integration (this issue)
- [ ] Create `nanoclaw/skills/roosync/` directory structure
- [ ] Implement SKILL.md with tool definitions
- [ ] Create MCP client wrapper (`index.ts`)
- [ ] Implement dashboard operations (`tools/dashboard.ts`)
- [ ] Implement messaging (`tools/messaging.ts`)
- [ ] Implement heartbeat (`tools/heartbeat.ts`)
- [ ] Add unit tests for MCP client wrapper

### Phase 3: Docker Configuration
- [ ] Update Docker Compose with volume mounts
- [ ] Configure environment variables
- [ ] Set up credentials injection (separate from image)

### Phase 4: Testing
- [ ] Test dashboard read/write from container
- [ ] Test bidirectional messaging
- [ ] Test heartbeat registration
- [ ] Verify GDrive credentials isolation

### Phase 5: Documentation
- [ ] Update CLAUDE.md with RooSync cluster context
- [ ] Document NanoClaw-specific patterns
- [ ] Create troubleshooting guide

---

## Acceptance Criteria

1. ✅ NanoClaw agent can post to RooSync workspace dashboard
2. ✅ NanoClaw agent can read RooSync inbox messages
3. ✅ Dashboard messages from NanoClaw are tagged `[NANOCLAW]`
4. ✅ Heartbeat visible in `roosync_heartbeat` status
5. ✅ GDrive credentials never stored in container/image

---

## Security Considerations

### Zero-Trust Credentials
- GDrive credentials mounted at runtime (not baked into image)
- Credentials file read-only within container
- Credentials injected via host volume mount

### Isolation
- Container has no access to host filesystem except explicit mounts
- GDrive shared state mounted read-only (`:ro` flag)
- MCP communication via stdio (no network exposure)

### Audit Trail
- All dashboard messages tagged with `[NANOCLAW]`
- Heartbeat includes container metadata (image version, start time)
- RooSync messages include machine ID `nanoclaw-ai-01`

---

## Alternative Options (Rejected)

### Option B: Direct GDrive Access
**Rejected:** Bypasses MCP validation layer, requires Google SDK in container

### Option C: Webhook/API Bridge
**Rejected:** More infrastructure, additional attack surface

---

## References

- Issue #1318: Deploy NanoClaw v1 on ai-01
- Issue #1073: Claw ecosystem comparison
- Issue #921: OpenClaw deployment study
- RooSync Technical Guide: `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- roo-state-manager: `mcps/internal/servers/roo-state-manager/`

---

**Next Steps:**
1. Complete #1318 (NanoClaw deployment) first
2. Create PR with RooSync skill implementation
3. Test in Docker environment on ai-01
4. Document lessons learned

**Status:** Design complete, awaiting NanoClaw deployment (#1318)
