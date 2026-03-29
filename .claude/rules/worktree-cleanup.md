# Worktree Cleanup Protocol

**Version:** 2.0.0
**Created:** 2026-03-26
**Updated:** 2026-03-29
**Issue:** #856

---

## Objective

Automated cleanup of orphan worktrees and stale branches to:
- Prevent VS Code notifications overload (2k+ notifications in Session 34)
- Keep repository clean
- Avoid stale worktrees accumulating

---

## Script

**Location:** `scripts/claude/worktree-cleanup.ps1` (consolidated from `.claude/scripts/` per #866)

**Legacy path still works:** `.claude/scripts/worktree-cleanup.ps1`

### Usage

```powershell
# Dry run (see what would be cleaned)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -WhatIf

# Execute cleanup (with confirmation)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1

# Force cleanup without confirmation
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -Force

# Custom stale threshold (default: 30 days)
powershell -ExecutionPolicy Bypass -File scripts/claude/worktree-cleanup.ps1 -StaleDays 14
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | switch | false | Dry run mode (show what would be done) |
| `-Force` | switch | false | Skip confirmation prompts |
| `-StaleDays` | int | 30 | Days threshold for stale branches |
| `-WorktreePath` | string | `.claude/worktrees` | Path to worktrees directory |

---

## What It Cleans

### 1. Orphan Worktree Directories

Directories in `.claude/worktrees/` that are not active git worktrees.

**Detection:** Compare directory listing with `git worktree list`

### 2. Stale Branches

Local `wt/` branches with no active worktree and last commit > N days old.

**Detection:** `git branch --list "wt/*"` + commit date check

### 3. Git Worktree Prune (v2.0)

Cleans stale administrative records in `.git/worktrees/`.

**Detection:** `git worktree prune` (run automatically after cleanup)

### 4. Git GC (v2.0)

Runs `git gc --prune=now` automatically when orphans or stale branches are removed.

---

## Windows-Specific Handling (v2.0)

On Windows, long paths and locked files can prevent removal. The script uses a 4-strategy fallback:

1. **Standard `Remove-Item -Recurse -Force`** — works in most cases
2. **Long path prefix `\\?\`** — handles paths exceeding MAX_PATH (260 chars)
3. **cmd.exe `rmdir /s /q`** — handles some locked file cases better
4. **robocopy empty mirror** — nuclear option for stubborn directories

---

## Integration Points (v2.0)

### git-sync skill

Added **Etape 5b** after pull: check worktree count and run cleanup if > 2 active worktrees.

### debrief skill

Added **Phase 5b** at end of session: check worktrees and run cleanup before closing.

### Scheduler patrol (executor workflow)

Added worktree check in **Etape 1** after git pull: count worktrees and cleanup if needed.

---

## Safety

- **VS Code check:** Script warns if VS Code is running (may have open worktrees)
- **WhatIf mode:** Always test with `-WhatIf` first
- **No remote deletion:** Only local branches are affected
- **No force push:** Only local branches are affected
- **Git gc recommendation:** Script suggests `git gc --prune=now` after cleanup
- **VS Code restart required** if worktrees were removed while VS Code was running

---

## When to Run

1. **Session start** (optional, manual)
2. **After closing worktrees** (cleanup orphan branches)
3. **Periodic maintenance** (weekly/monthly)
4. **Automatically** via git-sync, debrief, and scheduler patrol (v2.0)

---

## Related

- Issue #856: Worktree cleanup protocol
- Rule `.claude/rules/pr-mandatory.md` - PR workflow for worktrees
- Doc `docs/roo-code/SCHEDULER_SYSTEM.md` - Scheduler worktree usage
- `.roo/scheduler-workflow-executor.md` - Executor workflow with worktree check

---

**Last updated:** 2026-03-29
