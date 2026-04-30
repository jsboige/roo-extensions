# SDDD Reliability - Best Practices & Metrics

**Version:** 1.0.0
**Date:** 2026-04-30
**Issue:** #1861
**Status:** Implemented

## Overview

This document provides best practices and metrics for ensuring reliable SDDD (Semantically Driven Development) workflows across the Roo extensions ecosystem. The focus is on improving the `codebase_search` tool's workspace detection, multi-pass search UX, and indexing health monitoring.

## 1. Workspace Detection Reliability

### Problem Statement

The `codebase_search` tool's auto-detection was pointing to the MCP server directory instead of the actual workspace, causing failed searches and poor user experience.

### Root Cause

```typescript
// server-config.ts (BEFORE)
DEFAULT_WORKSPACE: process.env.WORKSPACE_PATH || process.cwd(),
```

When `WORKSPACE_PATH` was not set, it fell back to `process.cwd()`, which is the server directory when spawned with `cwd: __dirname`.

### Solution Implemented

Created `ServerWorkspaceDetector` that:
1. **Priority 1**: Use `WORKSPACE_PATH` if defined
2. **Priority 2**: Search for workspace markers (.git, CLAUDE.md, package.json)
3. **Priority 3**: Fallback to parent of `mcps/` directory

```typescript
// server-config.ts (AFTER)
DEFAULT_WORKSPACE: () => ServerWorkspaceDetector.detectWorkspace(),
```

### Markers Used

| Marker | Confidence | Purpose |
|--------|------------|---------|
| `.git` | High | Git repository root |
| `.claude/CLAUDE.md` | High | Claude project marker |
| `package.json` | Medium | Node.js project |
| `README.md` | Low | Documentation |
| `.vscode/` | Low | VS Code workspace |
| `mcps/` | Medium | MCP directory structure |

## 2. Multi-Pass Search UX

### Current Protocol

The SDDD bookend pattern uses 4 passes:

1. **Pass 1 (Broad)**: English query with code vocabulary
   - Example: "authentication middleware implementation"
   - Scope: Entire workspace

2. **Pass 2 (Filtered)**: Add `directory_prefix`
   - Example: `"authentication middleware", "directory_prefix": "src/services"`
   - Scope: Specific directory

3. **Pass 3 (Exact)**: Grep for exact names
   - Example: `"AuthMiddleware"`, `"authenticate function"`
   - Scope: Precise matches

4. **Pass 4 (Semantic)**: Use `roosync_search` for concepts
   - Example: `"user login flow"`
   - Scope: Semantic understanding

### Best Practices

#### Query Formulation
- **Use code vocabulary**, not natural language
- **Include technical terms**: "rate limiting", "authentication", "caching strategy"
- **Be specific but not overly constrained**
- **Avoid generic terms**: "login", "user", "system"

#### Example Good Queries
```typescript
// Good: Specific technical concept
"JWT token validation with refresh tokens"

// Good: Implementation pattern
"repository pattern with dependency injection"

// Good: Technical constraint
"rate limiting algorithm with sliding window"
```

#### Example Bad Queries
```typescript
// Bad: Too generic
"login system"

// Bad: Business logic
"how to authenticate users"

// Bad: Vague
"database stuff"
```

#### Directory Prefix Strategy
- Use relative paths from workspace root
- Start broad, then narrow down
- Example progression:
  1. `"authentication"` → no prefix
  2. `"authentication"` → `"src/auth"`
  3. `"authentication"` → `"src/auth/middleware"`

## 3. Indexing Health Check

### New Tool: `roosync_indexing`

```typescript
// Check workspace indexing health
roosync_indexing(action: "check", workspace: "C:/dev/roo-extensions")
```

### Response Format

```json
{
  "status": "healthy",
  "workspace": "C:/dev/roo-extensions",
  "collection": "ws-abcdef1234567890",
  "lastUpdated": "2026-04-30T10:30:00Z",
  "chunkCount": 15420,
  "averageScore": 0.78,
  "issues": [],
  "recommendations": []
}
```

### Health Indicators

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| Chunk Count | >10,000 | 5,000-10,000 | <5,000 |
| Average Score | >0.7 | 0.5-0.7 | <0.5 |
| Last Updated | <1 day | 1-7 days | >7 days |
| Missing Files | 0 | 1-5 | >5 |

### Common Issues & Fixes

#### Issue: Collection Not Found
```json
{
  "status": "error",
  "issue": "collection_not_found",
  "fix": "Open workspace in VS Code with Roo to start indexing"
}
```

#### Issue: Low Average Score
```json
{
  "status": "warning",
  "issue": "low_quality_embeddings",
  "fix": "Run roosync_indexing(action: 'rebuild')"
}
```

#### Issue: Outdated Index
```json
{
  "status": "warning",
  "issue": "stale_index",
  "fix": "Run roosync_indexing(action: 'update')"
}
```

## 4. Telemetry & Metrics

### Key Metrics to Track

1. **Workspace Detection Success Rate**
   - Target: >95%
   - Measurement: `detection_success / total_attempts`

2. **Bookend Adoption Rate**
   - Target: >50% of significant tasks
   - Measurement: `bookend_tasks / total_significant_tasks`

3. **Search Success Rate**
   - Target: >80% with score >0.5
   - Measurement: `successful_searches / total_searches`

4. **Multi-Pass Efficiency**
   - Target: Pass 1 provides 60%+ of results
   - Measurement: `pass1_results / total_results`

5. **Index Health Score**
   - Target: Average >0.7 across all workspaces
   - Measurement: `workspace_average_scores.mean()`

### Dashboard Integration

Metrics are reported to `roosync_dashboard` with tags:
- `[SDDD] Workspace detected: success|failure`
- `[SDDD] Bookend pattern used: yes|no`
- `[SDDD] Search recall: score`
- `[SDDD] Index health: status`

## 5. Testing Strategy

### Unit Tests

```typescript
// Test workspace detection
describe('ServerWorkspaceDetector', () => {
  test('detects roo-extensions workspace', async () => {
    const result = await ServerWorkspaceDetector.detectWorkspace();
    expect(result.workspacePath).toContain('roo-extensions');
    expect(result.confidence).toBe('high');
  });
});
```

### Integration Tests

```typescript
// Test end-to-end search workflow
describe('codebase_search workflow', () => {
  test('multi-pass search with bookend pattern', async () => {
    // Pass 1: Broad search
    const results1 = await codebaseSearch({
      query: 'authentication middleware',
      workspace: 'C:/dev/roo-extensions'
    });

    // Pass 2: Filtered search
    const results2 = await codebaseSearch({
      query: 'authentication middleware',
      workspace: 'C:/dev/roo-extensions',
      directory_prefix: 'src/services'
    });

    expect(results2.results_count <= results1.results_count).toBe(true);
  });
});
```

### Cross-Machine Testing

Test on all 6 machines:
- `myia-ai-01` (coordinator)
- `myia-po-2023/2024/2025/2026` (po machines)
- `myia-web1` (web machine)

Verify consistent behavior across Windows and Linux environments.

## 6. Troubleshooting Guide

### Issue: "Collection not found"

**Steps:**
1. Verify workspace is open in VS Code
2. Check if Roo is indexing: `roosync_indexing(action: "status")`
3. If not indexing, wait 5-10 minutes for auto-indexing
4. Manual trigger: `roosync_indexing(action: "rebuild")`

### Issue: Poor search results

**Steps:**
1. Check query with code vocabulary
2. Try multi-pass approach with directory_prefix
3. Verify index health: `roosync_indexing(action: "check")`
4. Rebuild if necessary: `roosync_indexing(action: "rebuild")`

### Issue: Wrong workspace detected

**Steps:**
1. Check environment: `process.env.WORKSPACE_PATH`
2. Verify markers exist in workspace root
3. Use explicit workspace parameter: `workspace: "C:/dev/roo-extensions"`
4. Report bug with reproduction script

## 7. Implementation Checklist

- [x] Implement ServerWorkspaceDetector
- [x] Update server-config.ts to use detector
- [x] Create reproduction scripts
- [x] Add telemetry to dashboard
- [ ] Implement multi-pass UX improvements
- [ ] Create comprehensive test suite
- [ ] Add documentation to CLAUDE.md
- [ ] Update agent training materials
- [ ] Monitor metrics in production
- [ ] Set up alerting for critical issues

## 8. Future Improvements

### Short-term (1-2 cycles)
- Add fuzzy matching for workspace paths
- Implement automatic workspace suggestions
- Improve error messages with actionable hints

### Medium-term (3-5 cycles)
- AI-assisted query reformulation
- Cross-references between code and documentation
- Real-time search result ranking

### Long-term (6+ cycles)
- Distributed indexing across machines
- Semantic understanding of search intent
- Automatic optimization of search parameters

## 9. References

- [SDDD Protocol](.claude/rules/sddd-grounding.md)
- [codebase_search Tool](mcps/internal/servers/roo-state-manager/src/tools/search/search-codebase.tool.ts)
- [Workspace Detection Bug](#1861)
- [RooSync Guide](../../roosync/GUIDE-TECHNIQUE-v2.3.md)

---

**Last Updated:** 2026-04-30
**Maintainer:** Claude Code Team
**Review Cycle:** Every major release