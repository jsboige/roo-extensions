# Context Explosion Runbook (#2577)

**Issue:** #2577
**MAJ:** 2026-06-24
**Scope:** Diagnostic, mitigation, and prevention of context explosion in Claude Code sessions (interactive + worker). Complements the [Restart-on-Saturation runbook](restart-on-saturation.md) (#2578) which covers the worker-side empty-response detection.

---

## Problem

Claude Code sessions accumulate `.jsonl` traces that grow unbounded. Large sessions (>100 MB) cause:

- Context saturation → auto-compaction → loss of instructions → agent loops
- Empty-response crashes on executor machines (po-2024/2025/2026 — see #2578)
- Performance degradation on ai-01 (CoursIA 419 MB, Argumentum 168 MB, Coordinator 154 MB)

Observed instances (measured 2026-06-12):

| Session | Size | Messages | Machine |
|---------|------|----------|---------|
| CoursIA | 419.4 MB | 78 161 | ai-01 |
| Argumentum | 168.3 MB | 25 469 | ai-01 |
| Coordinator ai-01 | 154.9 MB | 35 706 | ai-01 |
| Coordinator (8 doublons) | 153.9 MB | 8 sessions | ai-01 |

## Sanctuary Mandate (user 2026-06-19)

**Agent traces are a SANCTUARY. NEVER GC, NEVER delete, NEVER purge.**

- The `.jsonl` history captures how the user works — it is a knowledge asset, not waste.
- The correct response to saturation is **restart** (start a fresh session), not **cleanup**.
- Large sessions may be **split/externalized** to an archive via copy+verify — source stays intact.

---

## Diagnostic — identify large and duplicate sessions

### Quick scan

```powershell
# Report sessions > 100 MB (default)
.\scripts\claude\archive-large-sessions.ps1

# Lower threshold for early detection
.\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 50

# Scan for duplicate sessions (coordinator doublons detection)
.\scripts\claude\archive-large-sessions.ps1 -DetectDuplicates
```

### Combined diagnostic (large + duplicates)

```powershell
.\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 80 -DetectDuplicates
```

The script reports:
- Top 10 largest sessions (project, session ID, size, file count)
- Duplicate groups (sessions with identical file structures — manual review needed)
- Total large-session footprint

### What "duplicate" means here

Duplicates are detected by **file structure similarity** (same file names + similar sizes). This catches the "8 coordinator doublons" pattern where the same workspace spawned multiple session directories. Manual review is required — some "duplicates" may be legitimate parallel sessions (e.g., coordinator + executor running simultaneously in the same workspace).

---

## Mitigation — restart-on-saturation

### For worker sessions (scheduled)

The `start-claude-worker.ps1` script (enhanced in #2578) detects empty-response saturation and breaks the iteration loop after 2 consecutive empty responses. The next scheduled cycle spawns a fresh `claude -p` with a clean context window. See [Restart-on-Saturation](restart-on-saturation.md) for details.

### For interactive sessions (VS Code)

1. **Detect:** Session feels slow, responses are truncated, or Claude seems to forget earlier instructions.
2. **Verify:** Run `.\scripts\claude\archive-large-sessions.ps1` to confirm session size.
3. **Restart:**
   - Close the current Claude Code tab (Ctrl+W in VS Code)
   - Open a new session (Ctrl+Esc)
   - The fresh session starts with a clean context window
4. **Source preserved:** The old session `.jsonl` remains intact in `~/.claude/projects/<hash>/`

**NEVER** delete or truncate the `.jsonl` file. If disk space is a concern, use the archive procedure below.

---

## Mitigation — non-destructive archive (externalization WITHOUT LOSS)

For sessions > 100 MB that are no longer actively used but must be preserved:

```powershell
# Dry run first (see what would be copied)
.\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 100 -ArchivePath "D:\Archives\claude-sessions" -DryRun

# Actual archive (copy + verify byte-count)
.\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 100 -ArchivePath "D:\Archives\claude-sessions"

# Archive top 5 largest only
.\scripts\claude\archive-large-sessions.ps1 -ThresholdMB 100 -ArchivePath "D:\Archives\claude-sessions" -MaxSessions 5
```

The archive procedure:
1. **Copies** session directory to archive location (never moves)
2. **Verifies** byte-count: source bytes == destination bytes
3. **Source stays intact** — the session remains in `~/.claude/projects/`
4. Reports verified/failed counts

### Archive verification checklist

- [ ] Byte-count matches (script does this automatically)
- [ ] Spot-check: open a few `.jsonl` files from the archive, confirm readable
- [ ] Source session still present in `~/.claude/projects/`
- [ ] New Claude Code sessions in the same workspace start fresh (not loading the archived session)

---

## Mitigation — duplicate session consolidation

The 8 coordinator doublons (153.9 MB) were sessions spawned in the same workspace with identical file structures. To consolidate WITHOUT LOSS:

1. **Identify** duplicates: `.\scripts\claude\archive-large-sessions.ps1 -DetectDuplicates`
2. **Review** each group manually — determine which is the "canonical" session (usually the one with the most messages or latest activity)
3. **Archive** the non-canonical sessions to external storage (copy + verify)
4. **Source remains** on disk — no deletion

> There is no automated "merge" — merging `.jsonl` traces would corrupt conversation ordering. The correct approach is archival + restart-from-fresh.

---

## Prevention — reducing session growth

### Context window settings (already deployed fleet-wide)

| Setting | Value | Effect |
|---------|-------|--------|
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 200000 | Compact at 200k tokens |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | 90 | Trigger at 90% (= 180k effective) |

These cause auto-compaction *within* a session, but the `.jsonl` still grows. The compaction prevents runtime saturation but not disk growth.

### Operational best practices

1. **Restart interactive sessions periodically** — don't let a VS Code session run for days without restart
2. **Use worktrees for separate tasks** — each worktree gets its own project hash, distributing session growth
3. **Monitor with the diagnostic script** — run weekly to catch >100 MB sessions early
4. **Archive proactively** — sessions > 200 MB should be archived even if not causing issues yet

### Scheduled monitoring (recommended)

```powershell
# Add to Task Scheduler for weekly session size report
schtasks /create /tn "Claude-SessionSizeCheck" /tr "powershell -ExecutionPolicy Bypass -File scripts\claude\archive-large-sessions.ps1 -ThresholdMB 80" /sc weekly /d MON /st 06:00
```

---

## Anti-patterns INTERDITS

- ❌ `Remove-Item` on `.jsonl` session files
- ❌ Automated GC of sessions > N MB
- ❌ Purging `~/.claude/projects/` for disk space
- ❌ Archiving without byte-count verification
- ❌ Merging `.jsonl` traces (corrupts conversation ordering)
- ❌ Truncating session files to "reduce size"

---

## Related

- **#2578 / [Restart-on-Saturation](restart-on-saturation.md)** — Worker-side empty-response detection + auto-restart
- **[Condensation Thresholds](condensation-thresholds.md)** — 200k/90% universal threshold documentation
- **[Context Window Rule](../../../.claude/rules/context-window.md)** — Auto-loaded rule with threshold settings
- **Issues:** #1608, #1486, #1808 (closed without structural resolution), #2577 (this issue), #2578 (worker fix)
