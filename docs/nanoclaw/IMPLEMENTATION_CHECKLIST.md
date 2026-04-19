# NanoClaw ↔ RooSync Bridge - Implementation Checklist

**Issue:** #1319
**Related:** #1318 (NanoClaw deployment), #1073 (Claw ecosystem comparison)

---

## Phase 1: Infrastructure (PREREQUISITE - Issue #1318)

### Docker & Host Setup
- [x] Docker Desktop installed on ai-01 (#1171)
- [ ] Docker Compose installed
- [ ] GDrive mounted at G:/roosync on ai-01
- [ ] Credentials file path configured

### NanoClaw Fork & Build
- [ ] Fork qwibitai/nanoclaw into jsboige org
- [ ] Clone fork to ai-01
- [ ] Verify build succeeds (`npm run build`)
- [ ] Test basic container execution

---

## Phase 2: MCP Integration (This Issue)

### Core Files
- [x] Create design document (`docs/nanoclaw/NANOCLAW_ROOSYNC_BRIDGE.md`)
- [x] Create skill definition (`docs/nanoclaw/skills/roosync/SKILL.md`)
- [x] Create MCP client wrapper (`docs/nanoclaw/skills/roosync/index.ts`)
- [ ] Create Docker Compose config (`docs/nanoclaw/docker-compose.yml`)
- [ ] Create MCP config template (`docs/nanoclaw/skills/roosync/mcp-config.json`)

### Implementation (in nanoclaw fork)
- [ ] Copy skill files to nanoclaw/skills/roosync/
- [ ] Install MCP SDK dependency (`@modelcontextprotocol/sdk`)
- [ ] Build TypeScript wrapper
- [ ] Add skill to nanoclaw skill registry

---

## Phase 3: Docker Configuration

### Environment Setup
- [ ] Set Z_AI_API_KEY in .env file (NOT in git)
- [ ] Configure GDrive credentials path
- [ ] Verify G:/roosync mount exists on host
- [ ] Test volume mounts with docker-compose config

### Credential Security
- [ ] Ensure credentials NOT in Docker image
- [ ] Use separate .env file for secrets
- [ ] Add .env to .gitignore
- [ ] Document credential injection process

---

## Phase 4: Testing

### Connection Tests
- [ ] Test MCP server connection from container
- [ ] Verify tools list (should see roosync_dashboard, etc.)
- [ ] Test dashboard read (existing workspace dashboard)
- [ ] Test dashboard write (create if not exists)

### Functional Tests
- [ ] Post message with [NANOCLAW] tag
- [ ] Verify message appears in workspace dashboard
- [ ] Send RooSync message to myia-ai-01
- [ ] Read inbox from container
- [ ] Register heartbeat
- [ ] Verify heartbeat in roosync_heartbeat status

### Integration Tests
- [ ] Claude Code on ai-01 sees NanoClaw messages
- [ ] NanoClaw sees Claude Code messages
- [ ] Bidirectional communication verified
- [ ] Heartbeat visible on all machines

---

## Phase 5: Documentation

### CLAUDE.md Updates
- [ ] Add RooSync cluster context to nanoclaw CLAUDE.md
- [ ] Document machine topology (6 machines)
- [ ] Document MCP endpoints
- [ ] Add NanoClaw-specific patterns

### Project Documentation
- [ ] Update CLAUDE.md with NanoClaw section
- [ ] Update INTERCOM protocol (if needed)
- [ ] Create troubleshooting guide
- [ ] Document credential security

---

## Phase 6: Deployment

### Production Setup
- [ ] Create systemd service for docker-compose
- [ ] Configure auto-start on boot
- [ ] Set up log rotation
- [ ] Configure monitoring

### Verification
- [ ] Container starts automatically on boot
- [ ] Heartbeat registered within 1 minute of start
- [ ] Dashboard communication works
- [ ] No credential leaks in logs or image

---

## Acceptance Criteria

1. [ ] NanoClaw agent can post to RooSync workspace dashboard
2. [ ] NanoClaw agent can read RooSync inbox messages
3. [ ] Dashboard messages from NanoClaw are tagged `[NANOCLAW]`
4. [ ] Heartbeat visible in `roosync_heartbeat` status
5. [ ] GDrive credentials never stored in container/image

---

## Dependencies

- [ ] Issue #1318: Deploy NanoClaw v1 on ai-01 (MUST COMPLETE FIRST)
- [ ] roo-state-manager MCP server built and available
- [ ] GDrive shared state mounted on ai-01

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| NanoClaw MCP support limited | High | Use stdio MCP client, not native NanoClaw MCP |
| Credentials in container image | Critical | Mount credentials at runtime only |
| GDrive access from container | Medium | Read-only mount, separate credentials |
| Container escape | Low | Docker Sandboxes MicroVM (NanoClaw feature) |
| MCP protocol version mismatch | Medium | Pin specific MCP SDK version |

---

## Next Steps

1. **Immediate:** Complete #1318 (NanoClaw deployment)
2. **Then:** Copy skill files to nanoclaw fork
3. **Then:** Build and test in Docker
4. **Finally:** Deploy to ai-01 and verify

---

**Status:** Design complete, awaiting #1318
**Last Updated:** 2026-04-11
