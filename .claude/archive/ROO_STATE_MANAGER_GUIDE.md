# roo-state-manager MCP Guide for Claude Code Agents

**Version:** 1.0
**Date:** 2026-01-05
**Purpose:** Guide Claude Code agents to use RooSync messaging system

---

## ✅ Current Status

**DEPLOYED on myia-ai-01:** ✅ Working (2026-01-05)
**Template:** `.mcp.json.template` includes roo-state-manager
**Global Config:** `~/.claude.json` - Available after VS Code restart

---

## 🎯 What This Enables

As a Claude Code agent, you now have access to:

### 1. **Inter-Machine Communication**
- Send messages to Roo agents on other machines
- Read messages from the RooSync system
- Coordinate work across 5 machines

### 2. **Historical Context**
- Access conversation history
- Search past conversations
- Understand what previous agents did

### 3. **Presence Management**
- See which agents are active
- Update your own status
- Coordinate availability

---

## 🚀 Deployment Instructions

### For Each Machine (myia-po-2023, myia-po-2024, myia-po-2026, myia-web1)

#### Step 1: Pull Latest Changes
```bash
cd d:\roo-extensions
git pull origin main
```

#### Step 2: Run Initialization Script
```powershell
.\claude\scripts\init-claude-code.ps1 -Global
```

**Expected Output:**
```
[ADD] roo-state-manager
[OK] Global config updated: 2 added, 0 updated
```

#### Step 3: Restart VS Code
- Close VS Code completely
- Reopen VS Code
- Open a new Claude Code conversation

#### Step 4: Test MCP
In Claude Code, ask: "List the available MCP servers"
- You should see `roo-state-manager` listed

---

## 📋 Key MCP Tools

### Communication Tools

#### `get_recent_messages()`
**Purpose:** Read recent messages from RooSync system

**Usage:** Ask Claude Code: "Get the recent RooSync messages"

**Returns:** Array of recent messages (up to 20)

**Example:**
```
"Get the recent RooSync messages"
→ Returns: 20 messages with content, sender, timestamp
```

#### `send_message(content, target_machines)`
**Purpose:** Send messages to other machines

**Parameters:**
- `content`: Message text
- `target_machines`: Array of machine names (optional, defaults to all)

**Usage:** "Send message to myia-po-2023: Please run the tests"

**Example:**
```
"Send to myia-po-2023 and myia-po-2024: Deployment complete"
→ Broadcasts message to both machines
```

#### `mark_messages_read(message_ids)`
**Purpose:** Mark messages as read

**Usage:** "Mark these messages as read: [id1, id2, id3]"

### Historical Tools

#### `get_conversation_history(limit)`
**Purpose:** Get full conversation history

**Parameters:**
- `limit`: Number of recent conversations (optional)

**Usage:** "Get the last 10 conversation histories"

#### `semantic_search(query)`
**Purpose:** Search in conversation history

**Parameters:**
- `query`: Search query text

**Usage:** "Search conversations for: deployment errors"

**Note:** Use `codebase_search()` from Roo for workspace code search (Qdrant-indexed)

### Presence Tools

#### `get_presence()`
**Purpose:** See which agents are currently active

**Usage:** "Get the presence status of all agents"

**Returns:**
- Machine names
- Agent types (Roo/Claude)
- Last activity timestamps

#### `update_presence(status)`
**Purpose:** Update your presence status

**Parameters:**
- `status`: "active", "idle", "busy", "offline"

**Usage:** "Update my presence to busy"

---

## 🔄 Typical Workflows

### Workflow 1: Daily Coordination

```
1. "Get recent RooSync messages"
   → Read what happened overnight

2. "Get presence status of all agents"
   → See who's active

3. "Send message to all machines: Starting daily tasks"
   → Broadcast your status

4. [Do your work]

5. "Send message: Daily report - tasks X, Y completed"
   → Report progress
```

### Workflow 2: Cross-Machine Task

```
1. "Get presence status"
   → Verify target machine is active

2. "Send to myia-po-2023: Please run tests on module X"
   → Request action

3. "Get recent messages" (periodically)
   → Check for response

4. [When response received]
   → "Mark messages as read"
```

### Workflow 3: Historical Research

```
1. "Get conversation history (last 50)"
   → Retrieve recent context

2. "Search conversations for: deployment error"
   → Find relevant past discussions

3. Use context to inform current decisions
```

---

## 📊 Best Practices

### 1. **Check Before You Act**
Before creating new issues/tasks:
- Get recent messages (context might already exist)
- Search history (avoid repeating past mistakes)
- Check presence (don't message offline machines)

### 2. **Communicate Proactively**
- Send daily status updates
- Broadcast important changes
- Ask questions via RooSync messages

### 3. **Mark Messages Read**
- Keeps the system clean
- Avoids reprocessing
- Helps other agents

### 4. **Use Semantic Search Wisely**
- **codebase_search()** for workspace code (Qdrant-indexed)
- **semantic_search()** for conversation history
- Both are powerful but serve different purposes

---

## 🚨 Troubleshooting

### MCP Not Listed After Restart

**Problem:** roo-state-manager doesn't appear in `/mcp`

**Solution:**
1. Verify `~/.claude.json` contains roo-state-manager
2. Check the path exists: `mcps/internal/servers/roo-state-manager/dist/index.js`
3. Re-run: `.\init-claude-code.ps1 -Global`
4. Restart VS Code again

### No Messages Returned

**Problem:** `get_recent_messages()` returns empty

**Possible Causes:**
1. No messages in system (normal for first-time setup)
2. Qdrant database not initialized
3. Connection issue

**Solution:**
- Ask Roo agent for verification
- Check RooSync status via INTERCOM

### Can't Send Messages

**Problem:** `send_message()` fails

**Possible Causes:**
1. Target machine offline
2. RooSync not running on target
3. Network issue

**Solution:**
- Check presence status first
- Verify target machine is active
- Use INTERCOM for local fallback

---

## 📚 Related Documentation

- [MCP_SETUP.md](MCP_SETUP.md) - General MCP configuration
- [INTERCOM_PROTOCOL.md](INTERCOM_PROTOCOL.md) - Local communication
- [CLAUDE.md](../CLAUDE.md) - Workspace context
- [PROTOCOLE_SDDD.md](../docs/roosync/PROTOCOLE_SDDD.md) - RooSync protocol

---

## 🔗 Integration Points

### RooSync System (Roo Agents)
- **Messages:** Same system Roo agents use
- **Presence:** Shared presence database
- **History:** Common conversation store

### GitHub Projects (Claude Code)
- **Project #67:** RooSync Multi-Agent Tasks (Roo agents)
- **Project #70:** RooSync Multi-Agent Coordination (Claude agents)

### INTERCOM (Local)
- **File:** `.claude/local/INTERCOM-{MACHINE}.md`
- **Purpose:** Local Claude ↔ Roo communication
- **Fallback:** When RooSync unavailable

---

## ✅ Deployment Checklist

For each machine:

- [ ] Git pull completed
- [ ] Init script executed (`-Global` flag)
- [ ] VS Code restarted
- [ ] MCP visible in `/mcp`
- [ ] `get_recent_messages()` tested
- [ ] `get_presence()` tested
- [ ] First message sent
- [ ] Documentation reviewed

---

**Last Updated:** 2026-01-05
**Maintained by:** Claude Code agents (coordinated via Project #70)
