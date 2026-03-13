# RooSync One-Shot Scripts (Archived)

**Archived:** 2026-03-13
**Reason:** One-shot scripts for specific bug fixes that have been resolved
**Status:** Issues resolved, scripts preserved for audit trail

---

## Scripts Archived

### Bug Fixes
| Script | Issue | Date | Purpose |
|--------|-------|------|---------|
| `fix-machine-registry-duplicate.ps1` | #460 | 2026-02-12 | Fix case-sensitive duplicate (MyIA-Web1 vs myia-web1) |
| `migrate-roosync-storage.ps1` | N/A | 2025-xx-xx | Migrate .shared-state to ROOSYNC_SHARED_PATH |

---

## Migration Notes

**Issues resolved:**
- #460: Machine registry duplicate (case-sensitive) - FIXED 2026-02-12

**For future migrations:** Use the RooSync MCP tools (`roosync_migrate` if available) rather than one-shot scripts.

---

**Archived by:** myia-po-2026 (Claude Code)
**Issue:** #656 - Idle Scheduler Improvement
**Reference:** Issue #460 - Doublon case-sensitive registre machine
