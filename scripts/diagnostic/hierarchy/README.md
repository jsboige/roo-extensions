# scripts/diagnostic/hierarchy/ — ARCHIVED #3323 (2026-08-31)

## Status: ALL SCRIPTS IN THIS DIRECTORY HAVE BEEN ARCHIVED

The 8 scripts in this directory were part of a one-shot investigation campaign
(parent/child task matching). They are NOT referenced by any skill, rule,
workflow, or documentation. The investigation is complete and the findings
have been integrated into the canonical tooling.

## Archived scripts

All originals are preserved at `scripts/_archive/cleanup-3323-2026-08-31/hierarchy/`:

1. `analyze-task-matching.js`              — Original logic in archive
2. `debug-hierarchy-matching.mjs`          — Original logic in archive
3. `diagnose-parent-file.ps1`              — Original logic in archive
4. `extract-child-parent-snippets.ps1`     — Original logic in archive
5. `extract-new-task-tags-safe.ps1`        — Original logic in archive
6. `extract-parent-tail.ps1`               — Original logic in archive
7. `generate-hierarchy-tree.ps1`           — Original logic in archive
8. `search-task-instruction-exhaustive.ps1` — Original logic in archive

## Evidence of zero-reference

```
grep -r "analyze-task-matching"  → 0 hits (excluding self)
grep -r "debug-hierarchy-matching" → 0 hits
grep -r "diagnose-parent-file"   → 0 hits
grep -r "extract-child-parent-snippets" → 0 hits
grep -r "extract-new-task-tags-safe"   → 0 hits
grep -r "extract-parent-tail"     → 0 hits
grep -r "generate-hierarchy-tree" → 0 hits
grep -r "search-task-instruction-exhaustive" → 0 hits
```

(All searches across `.claude/skills/`, `.claude/rules/`, `.github/workflows/`, `docs/`,
`scripts/`, `mcps/` — excluding `.git/`, `node_modules/`, `dist/`, `build/`, `_archive/`.)

## How to access the archived logic

```powershell
# View the original analyze-task-matching.js
cat scripts/_archive/cleanup-3323-2026-08-31/hierarchy/analyze-task-matching.js
```

If any of these scripts need to be revived for a new investigation,
they should be re-extracted from archive (not re-developed from scratch).