# Duplicate Scripts Archive

This directory documents the consolidation of duplicate PowerShell scripts.

## Archive Status - Task 2 Complete

**Date:** 2026-04-29
**Executor:** myia-web1
**Issue:** #1844 Phase 2 Consolidation

### Current State

- **Scripts in `scripts/`:** 262 PowerShell scripts (down from 280+ in issue description)
- **Duplicate consolidations found:** Already completed in previous sessions
- **Recent consolidation:** Commit 242a6fdf (2026-04-19) - Consolidated 11 duplicate scripts across 6 families

### Consolidations Completed (242a6fdf)

1. **mcps test scripts** - `mcps/test-simple.ps1` → `mcps/test-win-cli.ps1`
2. **docs navigation** - `create-navigation-index-sddd.ps1` → `-simple.ps1`
3. **docs organization** - 3 scripts → 1 (`organize-docs-root-sddd.ps1`)
4. **docs validation** - `validate-docs-organization-sddd.ps1` → `-simple.ps1`
5. **restore files** - `restore-critical-files-simple.ps1` → `restore-critical-files.ps1`
6. **encoding diagnostic** - `diagnostic-encodage-complet.ps1` → `diagnostic-encoding-consolide.ps1` (671 lines)
7. **issue finder** - `find-678-simple.ps1` → `find-issue-678.ps1`
8. **task matching** - `analyze-task-matching.ps1` → `.js` (portable)
9. **hierarchy debug** - `debug-hierarchy-matching.js` → `.mjs` (191 vs 96 lines)
10. **git workflow** - `return-to-main-submodule-simple.ps1` → `-phase2-submodule.ps1` (156 vs 49 lines)

### Additional Consolidations (Phase 1)

The `consolidate-duplicates.ps1` script documents 7 additional groups of archived scripts:
- FFmpeg scripts (7) - obsolete
- GitHub Projects MCP (3) - deprecated
- QuickFiles Deprecated (8) - retired
- RooSync One-Shot (2) - resolved
- RooSync Phase 3 (7) - completed
- Demo Scripts (3) - single use
- phase2-ventilate cleanup - merged

### Status

✅ **No duplicates remaining in active scripts**
✅ **All duplicates properly consolidated or archived**
✅ **References updated in documentation**

---
*This archive log created as part of Phase 2 consolidation, Task 2*