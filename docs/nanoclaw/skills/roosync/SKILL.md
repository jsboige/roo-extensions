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
- `list`: List all dashboards

> Note: condensation is automatic (preemptive at 92% utilization) — there is no `condense` action.

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

### roosync_messages (send)

Send inter-machine messages to other agents. The `action` is required and must be `send` for outbound messages.

**Parameters:**
- `action` (required): "send" — outbound message
- `to` (required): Target machine ID (e.g., "myia-ai-01", "all")
- `subject` (required): Message subject
- `body` (required): Message body (markdown supported)
- `priority` (optional): "LOW" (default), "MEDIUM", "HIGH", "URGENT"
- `tags` (optional): Array of tags

**Examples:**
```
# Send to coordinator
roosync_messages(action="send", to="myia-ai-01", subject="Task Complete", body="Finished bridge implementation", tags=["NANOCLAW", "DONE"])

# Broadcast to all machines
roosync_messages(action="send", to="all", subject="Cluster Notice", body="Maintenance window starting", priority="HIGH")
```

---

### roosync_messages (inbox / message / attachments)

Read the RooSync inbox, a single message, or a message's attachments. The `action` selects the operation.

**Parameters:**
- `action` (required): `"inbox"` (list messages), `"message"` (single message), `"attachments_list"` (list attachments)
- `status` (optional): "unread", "read", or "all" (for action="inbox")
- `limit` (optional): Max messages to return (default: 10)
- `message_id` (optional): For action="message" or "attachments_list"

**Examples:**
```
# List unread messages
roosync_messages(action="inbox", status="unread", limit=20)

# Get specific message
roosync_messages(action="message", message_id="msg-123")

# List attachments
roosync_messages(action="attachments_list", message_id="msg-123")
```

---

### roosync_inventory

Check the cluster's health/heartbeat status. This is a read-only inventory of machines and their liveness.

**Parameters:**
- `type` (required): `"machines"` (full roster), `"heartbeat"` (heartbeat-focussed), `"status"` (compact status)
- `machineId` (optional): Filter to a single machine
- `includeHeartbeats` (optional): Include full heartbeat data
- `includeDetails` (optional): Include detailed metrics

**Examples:**
```
# Check cluster status / heartbeat liveness
roosync_inventory(type="machines", includeHeartbeats=true)
```

> **Note:** Registering a heartbeat is **not** an MCP operation — it is managed by the host RooSync listener
> process (the listener writes heartbeat files). A NanoClaw agent signals presence through the
> coordination channel it does control (see Pattern 1 below): append to the workspace dashboard.

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
status = roosync_inventory(type="machines", includeHeartbeats=true)
if "myia-ai-01" not in status:
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
messages = roosync_messages(action="inbox", status="unread", limit=10)

# Check cluster / coordinator status
status = roosync_inventory(type="machines", includeHeartbeats=true)

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
roosync_messages(
    action="send",
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
- Heartbeat registration is managed by the host listener, not via an MCP call
- Check `roosync_inventory(type="machines", includeHeartbeats=true)` to confirm the machine is reported
- Ensure the listener process on the host is running and writing heartbeat files

---

## Related Documentation

- RooSync Technical Guide: `docs/roosync/GUIDE-TECHNIQUE-v2.3.md`
- Bridge Design: `docs/nanoclaw/NANOCLAW_ROOSYNC_BRIDGE.md`
- Issue #1319: Bridge NanoClaw ↔ RooSync
- Issue #1318: Deploy NanoClaw v1 on ai-01
