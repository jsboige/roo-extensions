# Inter-Agent Communication Protocol (INTERCOM)

**Version:** 1.1
**Date:** 2026-01-18
**Purpose:** Local communication between Claude Code and Roo agents in same VS Code instance

---

## ⚠️ RÈGLE CRITIQUE - ORDRE DES MESSAGES

> **CHRONOLOGIQUE : Messages récents EN BAS du fichier !**
>
> - Lire les nouveaux messages → regarder la **FIN** du fichier
> - Ajouter un message → l'ajouter **APRÈS** le dernier `---`
> - **JAMAIS** insérer au début !

---

## 🎯 Overview

**INTERCOM** enables local communication between:
- **Claude Code agent** (via Claude Code extension)
- **Roo Code agent** (via Roo Code extension)

Running in the **same VS Code instance** on the **same machine**.

### Distinction from RooSync

| Channel | Scope | Purpose |
|---------|-------|---------|
| **INTERCOM** | Single VS Code instance | Claude Code ↔ Roo (local) |
| **RooSync** | Multi-machine | Machine ↔ Machine (distributed) |

**Example:**
- Claude Code asks Roo to run tests → **INTERCOM** (same machine)
- myia-ai-01 coordinates with myia-po-2023 → **RooSync** (different machines)

---

## 📁 File Structure

### Location

```
.claude/local/INTERCOM-{MACHINE_NAME}.md
```

### Example Files

```
.claude/local/
├── INTERCOM-myia-ai-01.md      # Communication on myia-ai-01
├── INTERCOM-myia-po-2023.md    # Communication on myia-po-2023 (if accessible)
├── INTERCOM-myia-po-2024.md    # Communication on myia-po-2024 (if accessible)
├── INTERCOM-myia-po-2026.md    # Communication on myia-po-2026 (if accessible)
└── INTERCOM-myia-web1.md     # Communication on myia-web1 (if accessible)
```

### Why Machine-Specific Files?

1. **Grounding:** Agents see which machine they're on
2. **Clarity:** No confusion about source/destination
3. **Multi-machine ready:** Future GDrive RooSync integration can share these files
4. **Debug:** Easy to identify machine-specific issues

---

## 📝 Message Format

### Structure

```markdown
## [YYYY-MM-DD HH:MM:SS] FROM → TO [TYPE]

Message content here...

Can span multiple lines.

---
```

### Fields

| Field | Values | Description |
|-------|--------|-------------|
| `TIMESTAMP` | `YYYY-MM-DD HH:MM:SS` | Local time (ISO 8601) |
| `FROM` | `claude-code` \| `roo` | Sender agent |
| `TO` | `claude-code` \| `roo` | Receiver agent |
| `TYPE` | See table below | Message type |

### Message Types

| Type | Purpose | Example |
|------|---------|---------|
| `INFO` | General information | "MCP setup complete" |
| `TASK` | Request action | "Run tests on module X" |
| `DONE` | Task completed | "Tests passed: 15/15" |
| `WARN` | Warning | "Build has 3 warnings" |
| `ERROR` | Error report | "MCP server crashed" |
| `ASK` | Question | "Which branch to use?" |
| `REPLY` | Answer | "Use main branch" |

---

## 🔄 Workflow

### ⚠️ CRITICAL: Message Placement

**Messages MUST be appended at the END of the file, NOT at the beginning.**

The file is a **chronological log** - newest messages go at the bottom.

**Correct:**
```
[older messages...]
---

## [2026-01-12 23:50:00] claude-code → roo [SYNC]
New message here...
---
```

**WRONG - Never do this:**
```
## [2026-01-12 23:50:00] claude-code → roo [SYNC]  ← WRONG!
New message inserted at top...
---

[older messages below...]  ← Other agent won't see it!
```

**Why this matters:** Agents read from the end of the file to find new messages. If you insert at the beginning, the other agent will miss your message entirely.

### For Claude Code Agent

**When starting work:**
1. Check if `.claude/local/INTERCOM-{MACHINE}.md` exists
2. Read recent messages from Roo (at the END of the file)
3. Look for `[TASK]` or `[ASK]` messages

**When sending to Roo:**
1. Open the file in VS Code
2. **Go to the END of the file** (after the last `---` separator)
3. Add new message with proper format
4. Save and close
   - **This triggers VS Code to notify Roo agent**

### For Roo Agent

**When starting work:**
1. Check if `.claude/local/INTERCOM-{MACHINE}.md` exists
2. Read recent messages from Claude Code (at the END of the file)
3. Look for `[TASK]` or `[ASK]` messages

**When sending to Claude Code:**
1. Open the file in VS Code
2. **Go to the END of the file** (after the last `---` separator)
3. Add new message with proper format
4. Save and close
   - **This triggers VS Code to notify Claude Code agent**

---

## 🧹 Maintenance

### Compaction Rules

**When file exceeds 100 messages:**
1. Keep last 50 messages
2. Add compaction marker:
   ```markdown
   ### COMPACTED: X older messages archived (YYYY-MM-DD HH:MM:SS)
   ```
3. Remove archived messages

**Example:**
```markdown
### COMPACTED: 53 older messages archived (2026-01-05 17:00:00)

## [2026-01-05 16:55:00] claude-code → roo [TASK]
Run deployment script...

---
```

### Manual Cleanup

Agents can manually compact when file gets too large:
```bash
# Keep last 50 messages
# Add compaction marker
# Delete older messages
```

---

## 🔒 Security & Privacy

### Git Ignore

**`.gitignore` includes:**
```gitignore
# Claude Code local inter-agent communication (machine-specific)
.claude/local/
```

**Rationale:**
- Messages contain temporary, local context
- Not meant for version control
- Machine-specific (not portable)
- RooSync handles inter-machine communication

### Human-Readable

Users can manually inspect the file to:
- Debug agent coordination issues
- Understand what agents are doing
- Verify communication flow

---

## 🚀 Getting Started

### Initial Setup (Per Machine)

Each machine should create its INTERCOM file:

1. **Create the directory:**
   ```bash
   mkdir -p .claude/local
   ```

2. **Create the template:**
   ```bash
   cp .claude/INTERCOM_TEMPLATE.md .claude/local/INTERCOM-{MACHINE}.md
   ```

3. **Update machine name in file header**

4. **Add initial message:**
   ```markdown
   ## [YYYY-MM-DD HH:MM:SS] claude-code → roo [INFO]
   Intercom system initialized. Ready for local coordination.
   ---
   ```

### First Message Example

**Claude Code to Roo:**
```markdown
## [2026-01-05 16:30:00] claude-code → roo [TASK]
Please run the test suite for module X. I need results before deploying.
---
```

**Roo to Claude Code:**
```markdown
## [2026-01-05 16:35:00] roo → claude-code [DONE]
Tests completed. 15 passed, 0 failed. Ready to deploy.
---
```

---

## 📚 Examples

### Scenario 1: Coordinated Deployment

```markdown
## [2026-01-05 16:00:00] claude-code → roo [TASK]
Deploy version v2.3.0 to production. Use branch `main`.

---

## [2026-01-05 16:05:00] roo → claude-code [ASK]
Should I run tests before deploying?

---

## [2026-01-05 16:06:00] claude-code → roo [REPLY]
Yes, run full test suite first.

---

## [2026-01-05 16:15:00] roo → claude-code [DONE]
Tests passed (15/15). Deployment complete. Version v2.3.0 is live.

---
```

### Scenario 2: Error Handling

```markdown
## [2026-01-05 17:00:00] roo → claude-code [ERROR]
Build failed. Module X has compilation errors.

---

## [2026-01-05 17:01:00] claude-code → roo [TASK]
Send me the error logs. I'll investigate.

---

## [2026-01-05 17:02:00] roo → claude-code [INFO]
Logs sent to GitHub issue #274.

---
```

### Scenario 3: Task Coordination

```markdown
## [2026-01-05 18:00:00] claude-code → roo [TASK]
I'm working on documentation update. Can you handle the deployment?

---

## [2026-01-05 18:01:00] roo → claude-code [DONE]
Sure, I'll take care of deployment. Focus on docs.

---
```

---

## 🔮 Future Enhancements

### Potential Features

1. **Message Priorities:** Add `[URGENT]` marker
2. **Message IDs:** Unique identifiers for tracking
3. **Threading:** Group related messages
4. **Status Codes:** Structured status updates
5. **Automated Compaction:** MCP tool for cleanup

### RooSync Integration

**Future GDrive sharing:**
- Share `.claude/local/INTERCOM-*.md` via RooSync GDrive
- Allow cross-machine visibility
- Maintain separation of concerns

---

## 📖 Related Documentation

- [CLAUDE.md](../CLAUDE.md) - Workspace context
- [MCP_SETUP.md](./MCP_SETUP.md) - MCP configuration

---

**Last Updated:** 2026-01-12
**Maintained by:** Claude Code agents on all RooSync machines
