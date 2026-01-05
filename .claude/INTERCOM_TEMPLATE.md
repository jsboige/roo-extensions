# Inter-Agent Communication Log
# Machine: {MACHINE_NAME}
# Agents: Claude Code ↔ Roo (local VS Code instance)
# Purpose: Local communication only (use RooSync for inter-machine)
# DO NOT COMMIT - This file is in .gitignore

---

## 📋 Protocol

This file enables communication between Claude Code and Roo agents running in the same VS Code instance on **{MACHINE_NAME}**.

### Message Format

```
## [YYYY-MM-DD HH:MM:SS] FROM → TO [TYPE]

Message content...

---
```

### Valid Values

**FROM/TO:** `claude-code` | `roo`

**TYPES:**
- `INFO` - Information
- `TASK` - Request action
- `DONE` - Task completed
- `WARN` - Warning
- `ERROR` - Error
- `ASK` - Question
- `REPLY` - Answer

### Rules

1. **Add new messages at the end**
2. **Separate with `---`**
3. **Keep last 50 messages** (compact when > 100)
4. **Timestamp in local timezone**

---

## [YYYY-MM-DD HH:MM:SS] claude-code → roo [INFO]
Intercom system initialized. Ready for local coordination.

---
