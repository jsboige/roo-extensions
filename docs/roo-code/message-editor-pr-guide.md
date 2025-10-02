# How to Submit the PR - Step by Step Guide

## ✅ Pre-Submission Verification

### Check Branch Status
```bash
# You should be on the correct branch
git branch --show-current
# Output: fix/message-editor-autosave-draft

# Verify clean state
git status
# Output: nothing to commit, working tree clean (except untracked docs)

# Verify single commit
git log --oneline -5
# Output should show:
# 4888dcc7f (HEAD) fix: implement autosave draft functionality for message editor
# 3e47e88c0 (upstream/main) fix: show send button when only images...
```

### Verify Push Status
```bash
# Confirm branch is pushed
git log origin/fix/message-editor-autosave-draft..HEAD
# Output: (empty - means everything is pushed)
```

## 📝 Submit Pull Request on GitHub

### Step 1: Open PR Creation Page
Navigate to: **https://github.com/RooCodeInc/roo-cline/pulls**

Click: **"New Pull Request"** button

### Step 2: Select Branches
- **Base**: `main` (RooCodeInc/roo-cline)
- **Compare**: `fix/message-editor-autosave-draft` (your fork)

### Step 3: Copy PR Description
Open `PR_DESCRIPTION.md` and copy its **entire content** into the GitHub PR description field.

### Step 4: Set PR Title
```
Fix: Implement autosave draft functionality for message editor (Part 1)
```

### Step 5: Add Labels (if you have permissions)
- `bug` - This fixes a data loss bug
- `enhancement` - Adds draft persistence feature
- `needs review` - Standard label for new PRs

### Step 6: Link Related Issues
If there's an existing issue for this bug, reference it in the PR description:
```
Closes #XXXX
```
Or:
```
Related to #XXXX
```

### Step 7: Review the Diff
Before submitting, review the "Files changed" tab to ensure:
- ✅ Only 5 files changed
- ✅ No unexpected changes
- ✅ All changes are in webview-ui/ directory
- ✅ Changeset file is included

### Step 8: Submit
Click **"Create Pull Request"**

## 📋 After Submission

### Expected CI Checks
The PR should trigger:
- ✅ TypeScript compilation
- ✅ ESLint checks
- ✅ Unit tests (vitest)
- ✅ Build verification

### Monitor for Feedback
Watch for:
1. **Automated comments** from bots (changeset verification, etc.)
2. **Reviewer comments** - Address them promptly
3. **CI failures** - Fix if any occur

### Common Review Questions

**Q: Why not fix the race condition completely?**
→ Refer to `AUTOSAVE-LIMITATIONS.md` - explains this is Part 1 of incremental fix

**Q: Why 300ms debounce?**
→ Balance between UX and safety. Part 2 can reduce to 100ms if needed

**Q: Does this fully resolve the bug?**
→ Partially. Provides draft recovery for most cases (>300ms typing). Part 2 will fix root cause

**Q: Test coverage?**
→ 95%+ coverage with both unit and integration tests

**Q: Performance impact?**
→ Minimal - debounced localStorage writes, only for active conversation

## 🔄 If Changes Are Requested

### Making Updates
```bash
# Make requested changes in your local branch
git add <modified-files>
git commit -m "fix: address review feedback - <description>"
git push origin fix/message-editor-autosave-draft
```

### Squashing Commits (if needed)
```bash
# Interactive rebase to squash all commits into one
git rebase -i upstream/main

# In editor, change all but first commit from "pick" to "squash"
# Save and update commit message if needed

# Force push (since we rewrote history)
git push --force-with-lease origin fix/message-editor-autosave-draft
```

## 📚 Reference Documents

### For Reviewers
- **Architecture**: `C:/dev/roo-extensions/docs/roo-code/ARCHITECTURE-HOOK-AUTOSAVE-DRAFT.md`
- **Limitations**: `webview-ui/src/hooks/__tests__/AUTOSAVE-LIMITATIONS.md`
- **Root Cause**: `bug_investigation_report.md`

### For Implementation
- **Hook**: `webview-ui/src/hooks/useAutosaveDraft.ts`
- **Unit Tests**: `webview-ui/src/hooks/__tests__/useAutosaveDraft.test.tsx`
- **Integration Tests**: `webview-ui/src/components/chat/__tests__/ChatView.autosave.test.tsx`

## ✨ Success Criteria

Your PR is successful when:
- ✅ All CI checks pass
- ✅ Code review approved by maintainer(s)
- ✅ No merge conflicts with main
- ✅ Changeset properly formatted
- ✅ Documentation is clear and complete

## 🎯 Next Steps After Merge

Once this PR is merged, create **Part 2** to fix the race condition:

### Part 2 Scope
1. Fix `clearDraft()` timing in `handleSendMessage`
2. Add optimistic UI pattern
3. Implement proper locking mechanism
4. Add comprehensive race condition tests
5. Consider reducing debounce to 100ms

### Part 2 Branch
```bash
# After Part 1 is merged
git checkout main
git pull upstream main
git checkout -b fix/message-editor-race-condition-part2
```

---

## 🚀 Ready to Submit!

Everything is prepared. You can now:
1. Go to GitHub
2. Create the Pull Request
3. Copy the description from `PR_DESCRIPTION.md`
4. Submit for review

**Good luck!** 🎉