# RooSync Dashboards - Documentation

**Version:** 1.1.0
**Created:** 2026-03-18
**Updated:** 2026-06-23
**Issue:** #675
**Tool:** `roosync_dashboard`

---

## Overview

Shared markdown dashboards for cross-machine and cross-workspace collaboration. The `roosync_dashboard` MCP tool provides a unified API for reading and writing structured dashboard data stored in `.shared-state/dashboards/`.

**Intended as a replacement for local INTERCOM files** (`INTERCOM-{MACHINE}.md`) in the long term, with the advantage of being:
- Accessible from all machines (via GDrive sync)
- Auto-condensed when messages exceed threshold
- Searchable and filterable by tags
- Structured (JSON with Zod validation)

---

## Dashboard Types

| Type | Scope | Key |
|------|-------|-----|
| `global` | All machines, all workspaces | `global` |
| `machine` | One machine, all its workspaces | `machine-{machineId}` |
| `workspace` | One workspace, all machines | `workspace-{workspaceName}` |

> **Removed (#836):** A fourth `workspace+machine` type (one machine + one workspace) previously existed. Only the 3 types above are valid now. The `workspace` type is the channel for cross-machine coordination (replacing local INTERCOM files).

### Storage Location

```
.shared-state/dashboards/
  global.json
  machine-{machineId}.json
  workspace-{workspaceName}.json
  archive/
    {key}-{datetime}.json
```

---

## API Reference

### Action: `read`

Read a dashboard (full or by section).

```typescript
roosync_dashboard({
  action: 'read',
  type: 'global' | 'machine' | 'workspace',
  machineId?: string,      // Default: local machine (ROOSYNC_MACHINE_ID env var)
  workspace?: string,      // Default: local workspace (ROOSYNC_WORKSPACE_ID env var)
  section?: 'status' | 'intercom' | 'all',  // Default: 'all'
  intercomLimit?: number   // Max messages returned (default: 50)
})
```

**Returns:**
```typescript
{
  success: boolean,
  key: string,
  data?: {
    status?: { markdown: string },
    intercom?: { messages: IntercomMessage[], totalMessages: number },
    lastModified?: string,
    lastModifiedBy?: Author
  },
  messageCount?: number
}
```

### Action: `write`

Overwrite the `status` section (diff-style edit).

```typescript
roosync_dashboard({
  action: 'write',
  type: 'global' | 'machine' | 'workspace',
  content: string,          // New markdown content (replaces status.markdown)
  author?: Author,          // Default: local machine
  createIfNotExists?: boolean  // Default: true
})
```

### Action: `append`

Append a message to the `intercom` section (FIFO queue).

```typescript
roosync_dashboard({
  action: 'append',
  type: 'global' | 'machine' | 'workspace',
  content: string,          // Message content (markdown)
  tags?: string[],          // Optional: ['INFO', 'WARN', 'ERROR', 'TASK', 'DONE']
  author?: Author,          // Default: local machine
  createIfNotExists?: boolean  // Default: true
})
```

**Auto-condensation:** When the dashboard file exceeds 50KB, old messages are archived automatically (keeping the 10 most recent). LLM-based intelligent summary is generated before archiving (#858).

### Action: `condense` — REMOVED

The manual `condense` action has been **removed from the schema**. Condensation is now **automatic and preemptive** at 92% utilization (~46 KB of the 50 KB threshold): old messages are archived with an LLM-generated summary, keeping the most recent messages. No manual intervention is needed (or possible). See `.claude/rules/intercom-protocol.md` for the current behavior.

### Action: `list`

List all available dashboards.

```typescript
roosync_dashboard({ action: 'list' })
// type is NOT required for this action
```

**Returns:** `{ dashboards: DashboardSummary[] }` sorted by `lastModified` descending.

### Action: `delete`

Delete a dashboard by key.

```typescript
roosync_dashboard({
  action: 'delete',
  type: 'global' | 'machine' | 'workspace',
  machineId?: string,
  workspace?: string
})
```

### Action: `read_archive`

List or read archived intercom messages.

```typescript
// List archives for a key
roosync_dashboard({
  action: 'read_archive',
  type: 'global',
  // No archiveFile → lists available archives
})
// Returns: { archives: string[] }

// Read a specific archive
roosync_dashboard({
  action: 'read_archive',
  type: 'global',
  archiveFile: 'global-2026-03-18T10-30-00.json'
})
// Returns: { archiveData: { key, archivedAt, messageCount, messages[] } }
```

---

## Data Structures

### Dashboard

```typescript
{
  type: 'global' | 'machine' | 'workspace',
  key: string,
  lastModified: string,   // ISO 8601
  lastModifiedBy: Author,
  status: {
    markdown: string,     // Editable via write (diff mode)
    lastDiffCommit?: string
  },
  intercom: {
    messages: IntercomMessage[],
    totalMessages: number,
    lastCondensedAt?: string
  }
}
```

### Author

```typescript
{
  machineId: string,
  workspace: string,
  worktree?: string    // e.g. 'wt-feature-123'
}
```

### IntercomMessage

```typescript
{
  id: string,          // 'ic-{timestamp}'
  timestamp: string,   // ISO 8601
  author: Author,
  content: string,     // Markdown content
  tags?: string[]      // Optional: ['INFO', 'WARN', 'ERROR', 'TASK', 'DONE', 'REPLY']
}
```

### DashboardSummary (for `list` action)

```typescript
{
  key: string,
  type: string,
  lastModified: string,
  lastModifiedBy: Author,
  messageCount: number,
  statusLength: number
}
```

---

## Usage Examples

### 1. Global Coordination Dashboard

```typescript
// Initialize global status
roosync_dashboard({
  action: 'write',
  type: 'global',
  content: '# RooSync Coordination\n\n## System State\n- 6 machines operational\n- Scheduler: Active\n',
  author: { machineId: 'myia-ai-01', workspace: 'roo-extensions' }
})

// Broadcast announcement to intercom
roosync_dashboard({
  action: 'append',
  type: 'global',
  content: '**[INFO]** Sync tour completed — all machines OK',
  tags: ['INFO'],
  author: { machineId: 'myia-ai-01', workspace: 'roo-extensions' }
})
```

### 2. Machine Status Dashboard

```typescript
// Check another machine's status
roosync_dashboard({
  action: 'read',
  type: 'machine',
  machineId: 'myia-po-2026',
  section: 'status'
})

// Update own machine status
roosync_dashboard({
  action: 'write',
  type: 'machine',
  content: '# myia-po-2025\n\n**Status:** Active\n**Current:** Issue #675 Phase 4\n',
})
```

### 3. INTERCOM Local Replacement

> **Superseded (#836):** This section previously documented the `workspace+machine` type, which was removed. Cross-machine coordination within a workspace now uses the `workspace` type (see examples 1 and 2 above). Local INTERCOM files (`INTERCOM-{MACHINE}.md`) are a deprecated fallback, used only when the dashboard MCP is unavailable.

### 4. Archive Management

```typescript
// List all dashboards
roosync_dashboard({ action: 'list' })

// View archives for a dashboard
roosync_dashboard({ action: 'read_archive', type: 'global' })

// Read a specific archive
roosync_dashboard({
  action: 'read_archive',
  type: 'global',
  archiveFile: 'global-2026-03-18T10-30-00.json'
})
```

---

## Auto-Condensation

When `intercom.messages.length > 500`:

1. When the dashboard exceeds 50KB, the oldest messages are moved to `archive/{key}-{datetime}.md`
2. **LLM-based intelligent summary** is generated from the archived messages (#858)
3. **LLM status update** rewrites the dashboard status integrating archived message info
4. A summary message (`CONDENSATION-SUMMARY`) is prepended (if LLM succeeds)
5. A system notice (`CONDENSATION`) is prepended with timing and size info
6. The 10 most recent messages are kept

### LLM Summary Feature (#858)

**If configured**, the dashboard will use an LLM to generate a structured summary of the archived messages before archiving them. This preserves key decisions, patterns, and context that would otherwise be lost.

**Configuration required in `.env`:**
```bash
OPENAI_API_KEY=your-api-key
OPENAI_BASE_URL=https://api.medium.text-generation-webui.myia.io/v1
OPENAI_CHAT_MODEL_ID=qwen3.6-35b-a3b
```

**Summary format:**
```markdown
---
**CONDENSATION-SUMMARY** - 2026-03-25T15:00:00Z

## Résumé Thématique
- Theme 1 : description
- Theme 2 : description

## Actions Clés
- Action 1 : [status] description
- Action 2 : [status] description

## Points d'Attention
- Point 1
- Point 2

## Métriques
- X messages traités
- Y issues/bugs
- Z bloquages
---
```

**Fallback behavior:** If the LLM is unavailable or returns empty, the condensation is **cancelled entirely** (#864). All messages are preserved unchanged. No data is lost.

**Result example:**
```
---
**CONDENSATION-SUMMARY** - 2026-03-25T15:00:00Z
[LLM summary content here]
---

---
**CONDENSATION** - 2026-03-25T15:00:00Z

400 messages archived in `archive/global-2026-03-25T15-00-00.json`
100 messages kept (most recent)
✅ Résumé LLM généré
---
```

Condensation is **automatic only** — the manual `action: 'condense'` was removed from the schema.

---

## Auto-Detection of machineId and workspace

When `machineId` and `workspace` are not specified, the tool uses environment variables:
- `ROOSYNC_MACHINE_ID` → machineId
- `ROOSYNC_WORKSPACE_ID` → workspace

These are set in the `.env` file of the roo-state-manager server.

---

## Migration from INTERCOM Files

**Phase 5 of issue #675** will handle the full migration. Until then:
- Local INTERCOM files (`INTERCOM-{MACHINE}.md`) remain the primary channel
- Dashboards can be used in parallel for cross-machine visibility
- The `workspace` type is the direct replacement for INTERCOM (the `workspace+machine` type was removed in #836)

**Key differences vs INTERCOM files:**

| Aspect | INTERCOM file | roosync_dashboard |
|--------|--------------|-------------------|
| Location | `.claude/local/INTERCOM-{MACHINE}.md` (local) | `.shared-state/dashboards/` (GDrive shared) |
| Access | Read-only from other machines | Accessible from all 6 machines |
| Format | Markdown text file | Structured JSON (Zod validated) |
| Condensation | Manual (intercom-compactor agent) | **Automatic LLM summary** + truncation (>500 messages) |
| Search | Grep | By type, section, intercomLimit |

---

## Implementation Details

**Source:** `mcps/internal/servers/roo-state-manager/src/tools/roosync/dashboard.ts`
**Tests:** `src/tools/roosync/__tests__/dashboard.test.ts` (26 tests)
**Atomic writes:** Files written via tmp → rename pattern (prevents corruption)
**Archive format:** `{key}-{YYYY-MM-DDTHH-MM-SS}.json` in `dashboards/archive/`

---

**Last updated:** 2026-06-23
**Maintainer:** RooSync Multi-Agent Team
