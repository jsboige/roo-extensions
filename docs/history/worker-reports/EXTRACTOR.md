# Worker Reports Extraction Plan

**Issue:** #1429
**Machine:** myia-po-2023
**Date:** 2026-04-17

## Dashboard Count Summary

Total: **101 dashboards**

| Machine | Count |
|---------|-------|
| myia-ai-01 | 39 |
| myia-po-2023 | 19 |
| myia-po-2024 | 14 |
| myia-po-2025 | 6 |
| myia-po-2026 | 10 |
| myia-web1 | 13 |

## Extraction Strategy

Given the scale (101 dashboards) and MCP limitations, extraction should be done in **batches of 10-20** per session.

### Phase 3.3 - Batch Extraction

Each batch:
1. Read 10-20 dashboards via `roosync_dashboard(action: "read")`
2. Extract substantive content (tags: `[DONE]`, `[RESULT]`, `[REPORT]`)
3. Save to `docs/history/worker-reports/{machine}/{date}-{topic}.md`
4. Track extracted dashboards in checklist

### Phase 3.4 - Batch Deletion

After extraction verified:
1. Delete each dashboard via `roosync_dashboard(action: "delete")`
2. Verify count decreases

### Phase 3.5 - Final Verification

Target: <30 active workspaces (currently 122)

## Progress Tracking

### Batch 1 (myia-po-2023): 0/19 extracted
### Batch 2 (myia-po-2024): 0/14 extracted
### Batch 3 (myia-po-2025): 0/6 extracted
### Batch 4 (myia-po-2026): 0/10 extracted
### Batch 5 (myia-web1): 0/13 extracted
### Batch 6 (myia-ai-01): 0/39 extracted (coordinateur should handle)

## Notes

- **Archive exists:** Consolidated archive already in workspace dashboard (2026-04-16)
- **Work preserved:** 87% of dashboards with mc≥1 contain substantive work already archived
- **Safe to delete:** After extraction, no data loss risk
- **Coordination:** ai-01 should handle its 39 dashboards to distribute load
