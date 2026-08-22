# RooSync Integration Skill

**Version:** 1.0.0
**NanoClaw Skill:** RooSync Coordination
**Dependencies:** MCP Client (Stdio)

---

## Purpose

Enables NanoClaw agents to participate in the RooSync coordination system for multi-machine agent orchestration.

---

## MCP Tools Available

### roosync_dashboard

Dashboard operations for cross-machine coordination.

**Actions:**
- `read`: Read dashboard messages
- `append`: Post a new message with tags
- `write`: Replace status section
- `condense`: Condense old messages
- `list`: List all dashboards

**Parameters:**
- `action` (required): Action to perform
- `type` (required): Dashboard type - "global", "machine", or "workspace"
- `section` (optional): "status", "intercom", or "all" (for read)
- `tags` (optional): Array of tags for append (e.g., ["NANOCLAW", "INFO"])
- `content` (required for write/append): Markdown content

**Examples:**
```
# Read workspace dashboard
roosync_dashboard(action="read", type="workspace", section="intercom", intercomLimit=20)

# Post status update
roosync_dashboard(action="append", type="workspace", tags=["NANOCLAW", "DONE"], content="Task completed successfully")

# Update machine status
roosync_dashboard(action="write", type="machine", content="## Status\n\nActive: Working on issue #1319")
```

---

### roosync_send

Send inter-machine messages to other agents.

**Parameters:**
- `to` (required): Target machine ID (e.g., "myia-ai-01", "all")
- `subject` (required): Message subject
- `body` (required): Message body (markdown supported)
- `priority` (optional): "LOW" (default), "MEDIUM", "HIGH", "URGENT"
- `tags` (optional): Array of tags

**Examples:**
```
# Send to coordinator
roosync_send(to="myia-ai-01", subject="Task Complete", body="Finished bridge implementation", tags=["NANOCLAW", "DONE"])

# Broadcast to all machines
roosync_send(to="all", subject="Cluster Notice", body="Maintenance window starting", priority="HIGH")
```

---

### roosync_read

Read the RooSync inbox.

**Parameters:**
- `mode` (required): "inbox" (list messages), "message" (single message), "attachments" (list attachments)
- `status` (optional): "unread", "read", or "all"
- `limit` (optional): Max messages to return (default: 10)
- `message_id` (optional): For mode="message" or "attachments"

**Examples:**
```
# List unread messages
roosync_read(mode="inbox", status="unread", limit=20)

# Get specific message
roosync_read(mode="message", message_id="msg-123")

# List attachments
roosync_read(mode="attachments", message_id="msg-123")
```

---

### roosync_heartbeat

Register and check agent heartbeat for cluster visibility.

**Actions:**
- `register`: Register/refresh heartbeat for this agent
- `status`: Check heartbeat status of all machines

**Parameters (register):**
- `machineId` (required): This machine's ID
- `metadata` (optional): Key-value pairs (version, tasks, etc.)

**Parameters (status):**
- `filter` (optional): "all", "online", "offline", "warning"
- `includeHeartbeats` (optional): Include full heartbeat data

**Examples:**
```
# Register heartbeat
roosync_heartbeat(action="register", machineId="nanoclaw-ai-01", metadata={"version": "1.0.0", "task": "bridge"})

# Check cluster status
roosync_heartbeat(action="status", filter="all", includeHeartbeats=true)
```

---

## Best Practices

### 1. Always Tag Messages
Tag all dashboard messages and RooSync messages with `[NANOCLAW]`:
```
tags=["NANOCLAW", "INFO"]
tags=["NANOCLAW", "DONE"]
tags=["NANOCLAW", "ERROR"]
```

### 2. Use Workspace Dashboard for Coordination
- `type="workspace"` for cross-machine coordination
- `type="machine"` for machine-specific status
- `type="global"` only for cluster-wide announcements

### 3. Check Heartbeat Before Critical Operations
```
status = roosync_heartbeat(action="status", filter="all")
if "myia-ai-01" not in status["online"]:
    # Coordinator offline, defer critical operations
```

### 4. Report Task Completion
Always report task completion with `[DONE]` tag:
```
roosync_dashboard(action="append", type="workspace", tags=["NANOCLAW", "DONE"], content="Completed issue #1319 bridge implementation")
```

### 5. Use Appropriate Priority Levels
- `LOW`: Routine status updates
- `MEDIUM`: Normal task completion
- `HIGH`: Important but not urgent
- `URGENT`: Immediate attention required

---

## Integration Notes

### MCP Server Connection
- **Server:** roo-state-manager
- **Transport:** Stdio (via volume mount)
- **Config:** `/nanoclaw/config/mcp-config.json`

### Environment Variables
- `ROOSYNC_MACHINE_ID`: This machine's identifier (e.g., "nanoclaw-ai-01")
- `ROOSYNC_SHARED_PATH`: Path to GDrive shared state (host-side)
- `GOOGLE_APPLICATION_CREDENTIALS`: Path to GDrive credentials (injected at runtime)

### Docker Volume Mounts
```
volumes:
  # Workspace
  - /path/to/roo-extensions:/workspace

  # MCP server
  - /path/to/roo-extensions/mcps:/workspace/mcps

  # GDrive shared state (read-only)
  - G:/roosync:/mnt/gdrive/roosync:ro

  # Credentials (injected at runtime)
  - ${CREDENTIALS_PATH}:/tmp/credentials.json:ro
```

---

## Common Patterns

### Pattern 1: Start of Session
```
# Check for new messages
messages = roosync_read(mode="inbox", status="unread", limit=10)

# Check coordinator status
status = roosync_heartbeat(action="status", filter="all")

# Read workspace dashboard
dashboard = roosync_dashboard(action="read", type="workspace", section="intercom", intercomLimit=10)
```

### Pattern 2: Report Task Completion
```
roosync_dashboard(
    action="append",
    type="workspace",
    tags=["NANOCLAW", "DONE"],
    content=f"""
    Completed task: {task_name}
    Result: {result}
    Next: {next_action}
    """
)
```

### Pattern 3: Request Coordinator Action
```
roosync_dashboard(
    action="append",
    type="workspace",
    tags=["NANOCLAW", "ASK"],
    content=f"Need approval for: {action_required}"
)
```

### Pattern 4: Error Reporting
```
roosync_dashboard(
    action="append",
    type="workspace",
    tags=["NANOCLAW", "ERROR"],
    content=f"Error in {task}: {error_message}",
)
roosync_send(
    to="myia-ai-01",
    subject="[NANOCLAW] Error Report",
    body=error_details,
    priority="HIGH"
)
```

---

## Troubleshooting

### MCP Connection Failed
- Verify volume mount for MCP server path
- Check `mcp-config.json` syntax
- Ensure roo-state-manager is built (`npm run build`)

### GDrive Access Denied
- Verify credentials file path
- Check file permissions (read-only)
- Ensure credentials are valid (not expired)

### Dashboard Not Found
- First write uses `createIfNotExists: true` (automatic)
- Verify `ROOSYNC_SHARED_PATH` is correct
- Check GDrive connection

### Heartbeat Not Visible
- Verify `machineId` matches expected format
- Check `roosync_heartbeat(action="status")` response
- Ensure metadata is JSON-serializable

---

## Related Documentation

- RooSync Technical Guide: `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- Bridge Design: `docs/nanoclaw/NANOCLAW_ROOSYNC_BRIDGE.md`
- Issue #1319: Bridge NanoClaw ↔ RooSync
- Issue #1318: Deploy NanoClaw v1 on ai-01
