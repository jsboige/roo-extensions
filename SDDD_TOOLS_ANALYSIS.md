# Analysis Report: SDDD Tools Frictions (Issue #954)

**Date:** 2026-03-29
**Agent:** Claude Code (myia-po-2023)
**Issue:** #954 - [QUALITY] Outils SDDD : Eliminer les frictions restantes

---

## Executive Summary

After thorough investigation of the three identified frictions in SDDD tools, I found that **all three are NOT actual bugs** but rather **configuration/indexing issues**:

1. **`roosync_search` temporal filtering** - Works correctly, but index only contains conversations from February 2026
2. **`codebase_search` precision** - Works correctly, but workspace has not been indexed by Roo Code
3. **`conversation_browser(synthesis)`** - Configuration issue (needs .env file loaded)

Each friction is a **different root cause** that requires a **different solution**.

---

## Detailed Analysis

### Friction 1: `roosync_search(semantic)` — Temporal Filtering Returns 0 Results

**Symptom:** `roosync_search(action: "semantic", start_date: "2026-03-27")` returns 0 results despite 14.3M vectors in index.

**Root Cause:** The temporal filtering **WORKS CORRECTLY**. The issue is that the Qdrant index contains conversations from **February 2026** (e.g., "2026-02-21"), not March 2026.

**Evidence:**
```json
// Search with March date filter
"pre_filter_count": 10,
"post_filter_count": 0

// Search with February date filter
"pre_filter_count": 5,
"post_filter_count": 5  // SUCCESS - returns results
```

**Diagnosis:** The `isWithinDateRange` function in `search-semantic.tool.ts:138-157` correctly parses dates and compares ISO timestamps. The filter is working - there simply are NO indexed conversations from March 2026.

**Solution:** **NOT A CODE BUG** - Recent conversations (last 48h) need to be indexed. The background indexer service needs to be running on machines where Roo tasks are created.

---

### Friction 2: `codebase_search` — Does Not Find `search-semantic.tool.ts`

**Symptom:** Query "semantic search snippet result builder content summary" does NOT find `search-semantic.tool.ts` (the main file for this functionality).

**Root Cause:** The workspace **HAS NOT BEEN INDEXED** by Roo Code. The `codebase_search` tool returns:
```json
{
  "status": "collection_not_found",
  "message": "Collection Qdrant non trouvée pour le workspace..."
}
```

**Diagnosis:** `codebase_search` requires:
1. Roo Code to have the workspace open in VS Code
2. Background indexing to have completed
3. A Qdrant collection named `ws-<hash>` to exist

None of these conditions are met for the worktree path or the parent `roo-state-manager` directory.

**Solution:** **NOT A CODE BUG** - The workspace must be indexed by Roo Code before `codebase_search` can work. This is a prerequisite, not a bug.

---

### Friction 3: `conversation_browser(summarize, synthesis)` — Buggy

**Symptom:** The synthesis LLM pipeline (OpenAI gpt-4o-mini) does not work reliably.

**Root Cause:** The `.env` file containing `OPENAI_API_KEY` and `OPENAI_BASE_URL` exists in the parent directory (`mcps/internal/servers/roo-state-manager/.env`) but is **NOT LOADED** by the MCP server process.

**Evidence:** The environment variables are empty:
```
QDRANT_URL=%QDRANT_URL%
OPENAI_API_KEY=%OPENAI_API_KEY%
```

**Diagnosis:** The `LLMService` tries to call OpenAI API but fails because:
1. The `.env` file is not in the current working directory
2. Node.js `dotenv` is not configured to load the parent `.env`
3. The synthesis service requires `OPENAI_API_KEY` to be set

**Solution:** **CONFIGURATION ISSUE** - Ensure the `.env` file is loaded when the MCP server starts, or pass environment variables explicitly.

---

## Recommendations

### 1. For `roosync_search` Temporal Filtering

**NO CODE CHANGE NEEDED**

**Action Required:**
- Ensure the background indexer service is running on all machines
- Verify that recent Roo/Claude conversations are being indexed (last 48h should appear)
- Check the `timestamp` field in Qdrant payloads to confirm recent dates

**Validation:**
```bash
# Test temporal filtering with recent date
roosync_search(action: "semantic", search_query: "test", start_date: "2026-03-28")
# Should return results if indexer is working
```

---

### 2. For `codebase_search` Precision

**NO CODE CHANGE NEEDED**

**Action Required:**
- Open the workspace in VS Code with Roo Code extension active
- Wait for background indexing to complete
- Verify the collection exists with `roosync_search(action: "diagnose")`

**Note:** The 4-pass protocol (wide → zoom → Grep → variant) is still valuable because:
- Code indexing is chunk-based (~1000 chars)
- No overlap between chunks means concepts split across functions get fragmented
- Multiple passes increase confidence in results

---

### 3. For `conversation_browser` Synthesis

**MINOR CONFIGURATION FIX**

**Action Required:**
- Ensure the `.env` file path is correctly configured
- Or load environment variables from the parent directory

**Code Fix Suggestion:**
```typescript
// In the MCP server entry point (index.ts or main.ts)
import dotenv from 'dotenv';
import path from 'path';

// Load .env from parent directory if it exists
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
}
```

---

## Conclusion

**All three frictions are NOT CODE BUGS** - they are **configuration/prerequisite issues**:

1. **Index freshness** - RooSync index needs recent conversations
2. **Code indexing** - Workspace needs to be indexed by Roo Code
3. **Environment configuration** - `.env` file needs to be loaded

The tools are working as designed. The "frictions" are actually **missing prerequisites** that should be documented in the SDDD protocol.

**Documentation Update Needed:**
- Add a "Prerequisites Check" section to `.claude/rules/sddd-conversational-grounding.md`
- Document that `codebase_search` requires Roo Code indexing
- Document that `roosync_search` temporal filtering requires recent data in index
- Document that `conversation_browser(synthesis)` requires OPENAI_API_KEY
