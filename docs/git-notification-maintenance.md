# Git Notification & Maintenance Workflow

**Version:** 1.0.0
**Created:** 2026-03-19
**Issue:** #741
**Frequency:** Daily (notifications), Weekly (cleanup)

---

## Overview

This document defines the regular git maintenance routine for all agents on all machines. It prevents accumulation of stale notifications, branches, and uncommitted changes that clutter the workspace and slow down productivity.

---

## Daily Routine: Git Notification Verification

**Frequency:** Daily (integrated into scheduler cycles)
**Time estimate:** 5-10 minutes
**Responsible:** All agents (Roo + Claude Code)

### Checklist

- [ ] **Check GitHub notifications**
  ```bash
  gh notification list
  ```
  - Review all unread notifications
  - Mark read/unread appropriately
  - Close outdated notifications if possible

- [ ] **Check open pull requests**
  ```bash
  gh pr list --state open
  ```
  - Identify PRs awaiting review
  - Check if any PRs are blocking your work
  - Note deadlines or urgent reviews

- [ ] **Check workspace status**
  ```bash
  git status
  ```
  - Verify no uncommitted changes
  - If changes exist:
    - Commit them if they're work-in-progress
    - Stash them if they should be preserved
    - Discard them if they're accidental

### Commands Reference

```bash
# List unread notifications
gh notification list --state unread

# List notifications by repo
gh notification list --repo jsboige/roo-extensions

# Mark all notifications as read (optional)
gh notification mark --all

# List open PRs
gh pr list --repo jsboige/roo-extensions --state open

# Check current git status
git status

# Check recent commits
git log --oneline -5
```

---

## Weekly Routine: Git Cleanup

**Frequency:** Weekly (integrated into extended sync cycles)
**Time estimate:** 15-30 minutes
**Responsible:** All agents (primarily Roo scheduler or Claude Code on demand)

### Checklist

- [ ] **Verify git stashes**
  ```bash
  git stash list
  ```
  - Review each stash (use `git stash show -p stash@{N}`)
  - Evaluate if the stash is still needed
  - If recoverable: create a branch from it
  - If obsolete: drop it (`git stash drop stash@{N}`)

- [ ] **Clean up local branches**
  ```bash
  git branch --list
  ```
  - Remove merged branches: `git branch -d branch-name`
  - Remove stale worktree branches (branches for deleted worktrees)
  - Keep only active branches

- [ ] **Verify submodule status**
  ```bash
  git status
  cd mcps/internal
  git status
  ```
  - Ensure no uncommitted changes in submodules
  - Verify submodule is synchronized with main repo

- [ ] **Clean up worktrees** (AI-01 primary responsibility)
  ```bash
  git worktree list
  ```
  - Remove orphaned worktrees: `git worktree remove --force worktree-path`
  - Remove associated branches if necessary

### Decision Tree for Stashes

```
Stash detected → Examine with: git stash show -p stash@{N}

├─ Recent work in progress (< 1 week)
│  └─ → Create branch: git stash branch new-branch-name stash@{N}
│
├─ Configuration changes (scheduler, settings)
│  └─ → DROP (reapply manually if needed)
│
├─ Test fixtures or obsolete test data
│  └─ → DROP
│
├─ Partially implemented feature
│  └─ → Evaluate:
│     ├─ If valuable → Create branch
│     └─ If feature obsolete → DROP
│
└─ Unknown content
   └─ → KEEP TEMPORARILY (inspect in next cycle)
```

---

## Machine-Specific Actions

### myia-ai-01 (Coordinator)

**Additional responsibilities:**
- Verify coordinator scheduler is running
- Check RooSync message queue for backlogs
- Monitor project #67 for stale issues
- Ensure cross-machine git history is clean

```bash
# Verify git history is clean
git log --oneline -10

# Check for hanging processes
ps aux | grep node  # Check for zombie Roo processes
ps aux | grep npm
```

### All Other Machines (po-2023, po-2024, po-2025, po-2026, web1)

**Standard cleanup routine:**
- Verify local stashes are cleaned
- Confirm no local branches clutter the workspace
- Ensure submodule is synchronized
- Check git status for uncommitted changes

---

## Notification Types & Actions

| Notification Type | Action |
|------------------|--------|
| **PR review requested** | → Prioritize if blocking |
| **PR merged** | → Mark read, verify local branch cleanup |
| **Issue comment** | → Review context, respond if needed |
| **CI failure** | → Investigate root cause if applicable |
| **Security alert** | → URGENT - Address immediately |
| **Discussion mention** | → Review, respond if relevant |

---

## Integration Points

### 1. Sync-Tour Skill (Phase 1)

The `sync-tour` skill should include a new step in Phase 1 (Environment Check):

```yaml
Phase 1: Environment Verification
  - [ ] Check MCP availability
  - [ ] Verify workspace health
  - [ ] **NEW: Verify git notifications & PRs**
      - Command: gh notification list --state unread
      - Command: gh pr list --state open
      - Action: Note any blocking PRs or urgent notifications
```

### 2. /executor Command (Phase 1)

The `/executor` command should include git verification before starting work:

```yaml
Phase 1: Pre-execution checks
  - [ ] Git status clean
  - [ ] **NEW: Check for unread notifications**
      - If blocking notifications found: report and pause
      - If urgent PRs: note context
  - [ ] Proceed with task execution
```

### 3. Scheduler Roo (Daily Cycle)

Add to the daily scheduler cycle (06:00 UTC / ~8h interval):

```yaml
daily-git-maintenance:
  schedule: 0 6 * * *  # 06:00 UTC daily
  description: "Check git notifications and verify workspace health"
  steps:
    1. Execute: gh notification list
    2. Execute: gh pr list
    3. Execute: git status
    4. If any issues: report via INTERCOM [PATROL]
```

### 4. Weekly Cleanup Cycle

Add to the scheduler for weekly extended maintenance:

```yaml
weekly-git-cleanup:
  schedule: 0 12 * * MON  # Monday 12:00 UTC
  description: "Weekly git stash and branch cleanup"
  machines:
    - myia-po-2023: Standard cleanup
    - myia-po-2024: Standard cleanup + custom workspace checks
    - myia-po-2025: Standard cleanup
    - myia-po-2026: Standard cleanup
    - myia-web1: Standard cleanup (limited to 1 worker)
    - myia-ai-01: Coordinator cleanup + worktree management
  expected_duration: 30 minutes per machine
```

---

## Reporting Format

When git maintenance is executed, report findings using this template:

### Daily Notification Report

```markdown
## [DATE TIME] roo/claude-code -> all [PATROL]
### Daily Git Notification Check

**GitHub Notifications:**
- Total unread: X
- Blocking: [list if any]
- Urgent: [list if any]

**Open PRs:**
- Total: X
- Review pending: Y
- Awaiting author: Z

**Workspace Status:**
- Uncommitted changes: [yes/no]
- Stashes: X
- Worktrees: [normal/needs cleanup]

**Actions taken:**
- [list any cleanup actions]

**Recommendations:**
- [list any follow-ups needed]
```

### Weekly Cleanup Report

```markdown
## [DATE TIME] roo/claude-code -> all [DONE]
### Weekly Git Cleanup - Machine [NAME]

**Stashes processed:** X total
- Recoverable: Y (created branches)
- Dropped: Z
- Kept for review: W

**Branches cleaned:** X removed
**Worktrees (ai-01):** X cleaned

**Result:** [OK/ISSUES_FOUND]

**Details:**
[List specific actions if non-standard]
```

---

## Troubleshooting

### Issue: `gh notification list` timeout

**Solution:**
```bash
# Try with explicit repo
gh notification list --repo jsboige/roo-extensions --limit 10

# Check GitHub status
# If API is slow, retry later
```

### Issue: Git stash is corrupted

**Solution:**
```bash
# List corrupted stashes
git stash list

# Backup before removing
git stash show -p stash@{N} > stash-backup.patch

# Drop the corrupted stash
git stash drop stash@{N}
```

### Issue: Too many local branches

**Solution:**
```bash
# List merged branches
git branch --merged

# Remove merged branches
git branch --merged | grep -v '\*\|main\|develop' | xargs -n 1 git branch -d

# Force remove if needed (use with caution)
git branch -D branch-name
```

---

## FAQ

**Q: Should I clean up branches immediately after merge?**
A: Yes. Run cleanup at least weekly, ideally after each sprint or release cycle.

**Q: What if I need to recover a dropped stash?**
A: Check git reflog (`git reflog`) to find the stash commit, then recreate it manually.

**Q: How often should I check notifications?**
A: Daily (integrated into scheduler). Urgent notifications (security alerts) require immediate action.

**Q: Can I automate this further?**
A: Yes - the scheduler can run these checks autonomously. See integration points above.

**Q: What if a PR blocks my work?**
A: Report via INTERCOM/RooSync immediately. Don't wait for the next scheduled maintenance.

---

## Success Metrics

A healthy git notification & maintenance routine should result in:
- ✅ No unread notifications older than 48h
- ✅ All open PRs tracked and prioritized
- ✅ < 5 local stashes on average
- ✅ All branches merged or actively worked on
- ✅ Workspace git status = clean (no uncommitted changes)
- ✅ No duplicate branch names across machines

---

## References

- GitHub CLI docs: https://cli.github.com/manual/
- Git stash guide: https://git-scm.com/book/en/v2/Git-Tools-Stashing-and-Cleaning
- Git worktree docs: https://git-scm.com/docs/git-worktree
- Issue #741 (this task)
- Issue #646 (git stashes recovery)
- Issue #652 (worktree cleanup)

---

**Last updated:** 2026-03-19
**Maintained by:** Roo Scheduler + Claude Code Coordinator
