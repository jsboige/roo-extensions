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
- Never commit secrets (.env, API keys, credentials, tokens) - use .gitignore

---

## Git Best Practices

### Pull Strategy
- **Always `git pull --no-rebase`** (merge strategy, never rebase on shared branches)
- Before pull: `git fetch origin` to inspect incoming changes
- If multiple machines push simultaneously: fetch + pull + retry (may need 2-3 cycles)

### Commit Discipline
- **Conventional commits**: `type(scope): description` (fix, feat, docs, refactor, test, chore)
- Always include `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` when AI-assisted
- Atomic commits: one intention per commit, not batch dumps
- Reference issue numbers when applicable: `fix(auth): Fix #123 - token refresh loop`

### Submodule Workflow
- Commit inside submodule FIRST, push
- Then `git add submodule-path` in parent repo, commit, push
- Both repos push to their respective remotes
- Never modify submodule pointer without committing the inner change first

### Never Force Push
- `git push --force` is forbidden on shared branches (main, develop)
- Use `--force-with-lease` only in exceptional cases with explicit user approval
- If push is rejected: fetch, merge, retry

---

## Claude Code Tool Discipline

### Read Before Edit (CRITICAL)
- **ALWAYS read a file before editing it** - the Edit tool will fail otherwise
- Even for `replace_all` operations, read the file first
- This prevents blind edits and ensures you understand the current state

### Test Commands
- Many projects use `npm test` in watch mode (Vitest, Jest) which blocks forever
- **Always verify** if `npm test` blocks. If so, use `npx vitest run` or `npx jest --ci`
- General rule: prefer explicit non-interactive test commands

### Build Verification
- Always build + test after code changes before committing
- Never assume a change is safe without running the test suite
- If tests fail: fix BEFORE committing, never commit broken code

---

## Investigation Methodology

### Code Source > Documentation
- Documentation may be outdated, especially in active projects
- When investigating a feature or bug, **start from the code source** as truth
- Use Grep + Read for systematic exploration, then cross-reference docs
- If docs contradict code, trust the code and update the docs

### Announce Work Before Starting
- Before starting significant work, announce what files/areas you'll modify
- This prevents conflicts when multiple agents (Roo, Claude, other machines) work in parallel
- Use INTERCOM, RooSync, or issue comments depending on context

---

## Knowledge Preservation

### Session Continuity
- Claude Code has no memory between sessions beyond what's written to files
- **ALWAYS consolidate learnings before session ends**: update MEMORY.md, PROJECT_MEMORY.md
- Key patterns, bug fixes, and architectural decisions MUST be written down
- If context is running low: prioritize knowledge consolidation over finishing the current task

### Memory Hierarchy (roo-extensions specific, but pattern applies to all projects)
- **Global user** (`~/.claude/CLAUDE.md`): Cross-project rules (THIS FILE)
- **Project instructions** (`CLAUDE.md` at repo root): Project-specific architecture, workflows
- **Auto-memory** (`~/.claude/projects/<hash>/memory/MEMORY.md`): Per-machine state, session learnings
- **Shared memory** (`.claude/memory/PROJECT_MEMORY.md`): Cross-machine shared knowledge (via git)
- **Rules** (`.claude/rules/*.md`): Enforceable project-specific rules

---

## Windows / PowerShell Gotchas

### UTF-8 BOM
- PowerShell's `Set-Content` and `Out-File` add BOM by default, which breaks many parsers (JSON, YAML)
- **Always use** `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`
- Or in PowerShell 7+: `-Encoding utf8NoBOM`

### Join-Path (PowerShell 5.1)
- `Join-Path` only accepts 2 arguments on PS 5.1 (Windows default)
- `Join-Path $a "b" "c" "d"` FAILS - use string interpolation: `"$a/b/c/d"`
- Always test scripts with `powershell -ExecutionPolicy Bypass -File script.ps1`

### Line Endings
- Git on Windows: ensure `core.autocrlf = true` or use `.gitattributes`
- Some tools are sensitive to CRLF vs LF (Bash scripts, Docker, etc.)
