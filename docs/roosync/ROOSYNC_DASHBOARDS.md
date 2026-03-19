# RooSync Dashboards - Documentation

**Version:** 1.0.0
**Created:** 2026-03-18
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

| Type | Scope | Key | Replaces |
|------|-------|-----|---------|
| `global` | All machines, all workspaces | `global` | — |
| `machine` | One machine, all its workspaces | `machine-{machineId}` | — |
| `workspace` | One workspace, all machines | `workspace-{workspaceName}` | — |
| `workspace+machine` | One machine + one workspace | `workspace-{name},machine-{id}` | **INTERCOM** ⭐ |

### Storage Location

```
.shared-state/dashboards/
  global.json
  machine-{machineId}.json
  workspace-{workspaceName}.json
  workspace-{workspaceName},machine-{machineId}.json
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
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
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
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
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
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
  content: string,          // Message content (markdown)
  tags?: string[],          // Optional: ['INFO', 'WARN', 'ERROR', 'TASK', 'DONE']
  author?: Author,          // Default: local machine
  createIfNotExists?: boolean  // Default: true
})
```

**Auto-condensation:** When messages exceed 500, the oldest 400 are archived automatically.

### Action: `condense`

Manually condense intercom messages (archive old, keep recent).

```typescript
roosync_dashboard({
  action: 'condense',
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
  keepMessages?: number     // Messages to keep (default: 100)
})
```

**Returns:** `{ condensed: boolean, archivedCount: number }`

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
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
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
  type: 'global' | 'machine' | 'workspace' | 'workspace+machine',
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

### 3. INTERCOM Local Replacement (workspace+machine)

The `workspace+machine` dashboard is the intended replacement for the local INTERCOM files (`INTERCOM-{MACHINE}.md`).

```typescript
// Claude writes a task for Roo (replaces writing to INTERCOM file)
roosync_dashboard({
  action: 'append',
  type: 'workspace+machine',
  content: '## [TASK] Issue #656 Phase 3\n\nPlease run the idle consolidation task...',
  tags: ['TASK'],
  author: { machineId: 'myia-po-2025', workspace: 'roo-extensions' }
})

// Roo reads recent messages (replaces reading the INTERCOM file)
roosync_dashboard({
  action: 'read',
  type: 'workspace+machine',
  section: 'intercom',
  intercomLimit: 20
})

// Roo replies
roosync_dashboard({
  action: 'append',
  type: 'workspace+machine',
  content: '## [DONE] Task completed\n\nExecuted idle consolidation. Results: ...',
  tags: ['DONE'],
  author: { machineId: 'myia-po-2025', workspace: 'roo-extensions' }
})

// Claude updates persistent session status
roosync_dashboard({
  action: 'write',
  type: 'workspace+machine',
  content: '# Session en cours\n\n**Issue:** #675 Phase 4\n**Status:** Documentation\n',
})
```

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

// Manually condense if intercom is getting large
roosync_dashboard({
  action: 'condense',
  type: 'workspace+machine',
  keepMessages: 50
})
```

---

## Auto-Condensation

When `intercom.messages.length > 500`:

1. The oldest 400 messages are moved to `archive/{key}-{datetime}.json`
2. The 100 most recent messages are kept
3. A system notice is prepended to the kept messages

```
---
**CONDENSATION** - 2026-03-18T10:00:00Z

400 messages archived in `archive/global-2026-03-18T10-00-00.json`
100 messages kept (most recent)
---
```

**Manual condensation** is also available via `action: 'condense'` with custom `keepMessages`.

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
- `workspace+machine` type is the direct replacement for INTERCOM

**Key differences vs INTERCOM files:**

| Aspect | INTERCOM file | roosync_dashboard |
|--------|--------------|-------------------|
| Location | `.claude/local/INTERCOM-{MACHINE}.md` (local) | `.shared-state/dashboards/` (GDrive shared) |
| Access | Read-only from other machines | Accessible from all 6 machines |
| Format | Markdown text file | Structured JSON (Zod validated) |
| Condensation | Manual (intercom-compactor agent) | Automatic (>500 messages) |
| Search | Grep | By type, section, intercomLimit |

---

## Implementation Details

**Source:** `mcps/internal/servers/roo-state-manager/src/tools/roosync/dashboard.ts`
**Tests:** `src/tools/roosync/__tests__/dashboard.test.ts` (26 tests)
**Atomic writes:** Files written via tmp → rename pattern (prevents corruption)
**Archive format:** `{key}-{YYYY-MM-DDTHH-MM-SS}.json` in `dashboards/archive/`

---

**Last updated:** 2026-03-18
**Maintainer:** RooSync Multi-Agent Team
