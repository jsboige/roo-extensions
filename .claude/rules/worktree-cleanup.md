# Worktree Cleanup Protocol

**Version:** 1.0.0
**Created:** 2026-03-26
**Issue:** #856

---

## Objective

Automated cleanup of orphan worktrees and stale branches to:
- Prevent VS Code notifications overload (2k+ notifications in Session 34)
- Keep repository clean
- Avoid stale worktrees accumulating

---

## Script

**Location:** `.claude/scripts/worktree-cleanup.ps1`

### Usage

```powershell
# Dry run (see what would be cleaned)
powershell -ExecutionPolicy Bypass -File .claude/scripts/worktree-cleanup.ps1 -WhatIf

# Execute cleanup (with confirmation)
powershell -ExecutionPolicy Bypass -File .claude/scripts/worktree-cleanup.ps1

# Force cleanup without confirmation
powershell -ExecutionPolicy Bypass -File .claude/scripts/worktree-cleanup.ps1 -Force

# Custom stale threshold (default: 30 days)
powershell -ExecutionPolicy Bypass -File .claude/scripts/worktree-cleanup.ps1 -StaleDays 14
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

---

## Safety

- **VS Code check:** Script warns if VS Code is running (may have open worktrees)
- **WhatIf mode:** Always test with `-WhatIf` first
- **No remote deletion:** Only local branches are affected
- **Git gc recommendation:** Script suggests `git gc --prune=now` after cleanup

---

## When to Run

1. **Session start** (optional, manual)
2. **After closing worktrees** (cleanup orphan branches)
3. **Periodic maintenance** (weekly/monthly)

---

## Related

- Issue #856: Worktree cleanup protocol
- Rule `.claude/rules/pr-mandatory.md` - PR workflow for worktrees
- Doc `docs/roo-code/SCHEDULER_SYSTEM.md` - Scheduler worktree usage

---

**Last updated:** 2026-03-26
