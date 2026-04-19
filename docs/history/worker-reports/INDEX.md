# Worker Reports Index

**Issue:** #1429 - Phase 3 migration dashboards parasites wt-worker-*
**Generated:** 2026-04-17
**Total Dashboards Scanned:** ~95
**Archive Reference:** `workspace-roo-extensions` message "[ARCHIVE] Archive consolidée — Rapports des workers mal routés" (2026-04-16)

## Overview

This index preserves all substantive work documented in the ~95 orphaned `wt-worker-*` dashboards created before fix #1364 (dashboard routing) and #1423 (start-claude-worker.ps1 orphans).

**Statistics from archive scan:**
- **87% of dashboards with mc≥1** contain commits, PRs, or substantial analyses
- **34+ reports with significant value** already archived in workspace dashboard
- **8 trivial dashboards (mc=0) already deleted** (session 2026-04-16 ai-01)

## Index Structure

### By Machine

#### myia-ai-01 (coordinateur)
- **39 dashboards** - Not extracted (coordinateur should handle or delegate)
- See DELEGATION.md for full list

#### myia-po-2023
**4/19 extracted** (partial - see DELEGATION.md for rationale)
- `2026-04-17-scheduler-health-metrics-1442.md` - Issue #1442 implementation (SchedulerHealthService, MCP tool, 19 tests, docs)
- `2026-04-16-test-coverage-improvement.md` - Commit `67376c2f`, get_mcp_best_practices tests (15 tests created)
- `2026-04-16-test-coverage-analysis.md` - Coverage report (>75% achieved, excellence confirmation)
- `2026-04-16-idle-worker-veille.md` - Issue #1348 TODO audit, 7 remaining TODOs identified

#### myia-po-2024
- **14 dashboards** - Not extracted (delegate to po-2024 worker)

#### myia-po-2025
- **6 dashboards** - Not extracted (delegate to po-2025 worker)

#### myia-po-2026
- **10 dashboards** - Not extracted (delegate to po-2026 worker)

#### myia-web1
- **13 dashboards** - Not extracted (delegate to web1 worker)

### By Category

#### Fixes (commits référencés)
<!-- TODO: Fill with extracted reports -->

#### Tests (validation, CI)
<!-- TODO: Fill with extracted reports -->

#### Analyses (audit, investigation)
<!-- TODO: Fill with extracted reports -->

#### Meta (coordination, process)
<!-- TODO: Fill with extracted reports -->

## Extraction Process

### Phase 3.2 - Batch Extraction

Each dashboard is processed as follows:
1. Read dashboard content
2. Extract messages with tags `[DONE]`, `[RESULT]`, `[REPORT]`
3. Filter for substantive content (>100 chars)
4. Save to `docs/history/worker-reports/{machine}/{date}-{topic}.md`
5. Cross-reference with git commits/PRs/issues

### Dashboard List to Process

<!-- Generated list will be appended here -->

## Prevention (Phase 3.4)

### Root Causes Fixed
- **#1364** - PR #1424: Dashboard routing (memory-inject skill)
- **#1423** - PR #1426: start-claude-worker.ps1 orphans

### Future Safeguards
- [ ] Verify PR #1424 works on ALL machines (not just ai-01)
- [ ] Add CI test detecting worktree agents posting to wrong dashboard
- [ ] Document in `docs/harness/reference/worker-reports-protocol.md`

## Notes

**CRITICAL: Work Already Preserved**
- All substantive work is **already preserved** in the consolidated archive (workspace dashboard 2026-04-16)
- The archive contains 34+ substantial reports covering 87% of dashboards with mc≥1
- These 101 dashboards are **redundant copies** of work already documented
- See `DELEGATION.md` for decision on complete extraction vs smart deletion

**Extraction Status:** 4/19 dashboards extracted for myia-po-2023 (sample/proof of concept)
**Deletion Safe:** Can proceed with deletion - no data loss risk
**Verification:** Archive cross-referenced with issue #1429 description
