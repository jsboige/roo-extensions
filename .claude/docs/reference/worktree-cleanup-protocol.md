# Worktree Cleanup Protocol

**Version:** 1.0.0
**Created:** 2026-03-25
**Issue:** #856

---

## Problem

Orphan worktrees accumulate in `.claude/worktrees/` across sessions, causing:
- **~2k+ VS Code SCM notifications** (untracked files from worktree copies)
- **Disk space waste** (each worktree = full repo copy minus .git)
- **Confusion** for agents seeing unexpected files in SCM panel

### Root Causes

1. **Session timeout/crash** - Claude Code workers don't clean up on exit
2. **Windows "Filename too long"** errors prevent `git worktree remove`
3. **"Device busy"** errors when submodule mount points are locked by VS Code

---

## Detection

### Manual Check

```powershell
# List registered worktrees
git worktree list

# List physical directories in .claude/worktrees/
Get-ChildItem .claude/worktrees/ -Directory

# Compare - orphans are directories without git registration
```

### Automated Check (sync-checker)

Add to sync-checker agent checklist:
```powershell
$worktreeCount = (git worktree list).Count - 1  # -1 for main repo
if ($worktreeCount -gt 2) {
    Write-Warning "Worktree count elevated: $worktreeCount"
}
```

---

## Cleanup Procedure

### Step 1: Identify Orphans

```powershell
# Get registered worktrees
$registered = git worktree list | ForEach-Object { ($_ -split '\s+')[0] }

# Get physical directories
$physical = Get-ChildItem .claude/worktrees/ -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }

# Find orphans (physical but not registered)
$orphans = $physical | Where-Object { $_ -notin $registered }
```

### Step 2: Safe Removal

```powershell
# Remove registered worktrees first
git worktree prune -v

# For each orphan directory
foreach ($dir in $orphans) {
    # Try graceful removal
    git worktree remove $dir 2>$null

    # Force removal if graceful fails
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force $dir
        Write-Host "Force-removed orphan: $dir"
    }
}
```

### Step 3: Handle Locked Files (Windows)

```powershell
# If removal fails due to locked files
# 1. Close VS Code
# 2. Wait a few seconds
# 3. Retry removal

# Nuclear option (use with caution)
Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
```

---

## Script

See: `scripts/worktree-cleanup.ps1`

```powershell
# Quick one-liner for cleanup
powershell -ExecutionPolicy Bypass -File scripts/worktree-cleanup.ps1
```

---

## Integration Points

### 1. git-sync Skill

Add cleanup step after pull:
```markdown
### Phase X: Worktree Cleanup
- Run `git worktree prune`
- Check orphan count
- Alert if > 2 worktrees remain
```

### 2. /debrief Skill

Add cleanup step at end of session:
```markdown
### Cleanup
- Remove any worktrees created during session
- Run `git worktree prune`
```

### 3. Roo Scheduler Patrol

Add to patrol task list:
- Check worktree count
- Cleanup if elevated

---

## Thresholds

| Count | Action |
|-------|--------|
| 0-1 | Normal (main repo only) |
| 2-3 | Acceptable (active work) |
| 4-5 | Warning - cleanup recommended |
| 6+ | Alert - cleanup required |

---

## Checklist per Machine

Update issue #856 checklist after cleanup:

- [ ] myia-ai-01: Check `git worktree list` + `.claude/worktrees/`
- [ ] myia-po-2023: Check `git worktree list` + `.claude/worktrees/`
- [ ] myia-po-2024: Check `git worktree list` + `.claude/worktrees/`
- [x] myia-po-2025: ✅ Cleaned (8 worktrees removed, 2026-03-25)
- [ ] myia-po-2026: Check `git worktree list` + `.claude/worktrees/`
- [ ] myia-web1: Check `git worktree list` + `.claude/worktrees/`

---

## References

- Issue #856: Worktree cleanup protocol
- `scripts/worktree-cleanup.ps1`: Automation script
- `.claude/skills/git-sync.md`: Integration point

---

**Last updated:** 2026-03-25
