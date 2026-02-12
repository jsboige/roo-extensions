# Global Claude Code Instructions (Machine-Level)

These instructions apply to ALL projects on this machine.
Deploy to `~/.claude/CLAUDE.md` on each machine.

**Source of truth:** `.claude/configs/user-global-claude.md` in the **roo-extensions** repository (workspace d'harmonisation inter-machines)
**Deployed to:** `~/.claude/CLAUDE.md` (local, not in git, applies to ALL workspaces on this machine)
**Update workflow:** Edit the source in roo-extensions, commit+push, then each machine pulls and copies to `~/.claude/CLAUDE.md`

---

## Terminology & User Preferences

### "Consolider" (Consolidate) != "Archiver" (Archive)

When the user asks to **consolidate** scripts/files, this is a 3-step process:

1. **ANALYZE**: Read the script to consolidate. Understand every function and feature it provides.
2. **MERGE**: For each feature, either:
   - Verify it already exists in the target script (cite the exact line), OR
   - Merge the feature into the target script
3. **ARCHIVE**: Only THEN move the old script to `_archives/` with a header comment:
   ```
   # Archived: [date] - Superseded by [target_script]
   # Features merged: [list of features]
   ```

**What consolidation is NOT:**
- Simply moving a file to `_archives/` without verifying feature coverage
- Deleting code without ensuring its functionality lives elsewhere
- Assuming two scripts with similar names do the same thing

**Verification checklist before archiving:**
- [ ] Every function/feature in the old script has been identified
- [ ] Each feature exists in the replacement (with line numbers as proof)
- [ ] Any missing features have been merged into the replacement
- [ ] Scripts that CALL the old script have been updated to call the replacement
- [ ] The replacement has been tested (or at minimum, syntax-checked)

This rule was established after a Session 101 incident where 8+ scripts were archived without verifying their features were preserved, breaking the deployment pipeline.

---

## General Conventions

### Language
- The user communicates in French
- Code, commits, and technical docs can be in English
- User-facing messages and INTERCOM should be in French when relevant

### Safety
- Never delete files without verifying their content is preserved elsewhere
- Always backup before destructive operations
- Prefer reversible actions over irreversible ones
