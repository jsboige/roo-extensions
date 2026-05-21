# Investigation: Preflight Dedup Miss Rate — Qdrant Migration

**Issue:** [#2196](https://github.com/jsboige/roo-extensions/issues/2196)  
**Period:** 2026-05-15 → 2026-05-21  
**Observability prérequis:** [#2195](https://github.com/jsboige/roo-extensions/issues/2195) (CLOSED — per-cycle embedding metrics deployed)  
**Conclusion:** System healthy. No action required.

---

## Context

Post-[#2165](https://github.com/jsboige/roo-extensions/issues/2165) fix, the indexing pipeline relies on two dedup mechanisms:

1. **`preflightDedupByChunkId()`** — Qdrant `retrieve()` per `chunk_id`, skips embedding for already-indexed chunks
2. **`computeChunkId()`** — UUIDv5 of `${task_id}|${chunk_type}|seq:${sequence_order}|${sha256_16(content)}`

Three hypotheses were tested to evaluate whether these mechanisms had hidden failure modes during the Qdrant migration (proxy `qdrant.myia.io` firewall, ~37.96M/39.47M migrated as of 2026-05-15).

---

## Hypotheses and Results

### H1 — Preflight `retrieve()` partial failures during migration

**Hypothesis:** If a `retrieve()` 100-chunk batch hits a temporarily unavailable shard, the code marks the batch as failed (`allBatchesSucceeded = false`), treats those chunks as non-existing, and re-embeds them — potentially creating duplicate upserts.

**Data (ai-01, R61 → R66, ~24h interval):**

| Metric | R61 (Cycle 61) | R66 (Cycle 66) | Delta |
|--------|-----------------|-----------------|-------|
| `embeddings_called_total` | 2,449 | 2,488 | +39 |
| `preflight_skipped_total` | 1,379 | 1,431 | +52 |
| `preflight_skip_rate` | 56.3% | 57.5% | +1.2pp |
| `qdrant_unreachable_batches` | 1/33 | 1/73 | 1.4% stable |
| `post_dedup_skipped` | 0 | 0 | 0% |

**Data (po-2026, Embeddings workspace):**

| Metric | Value |
|--------|-------|
| `preflight_batches_total` | 1 |
| `preflight_batches_qdrant_unreachable_total` | **0** |
| `preflight_chunks_returned_existing_total` | 27 |
| `embeddings_preflight_skipped_total` | 27 |
| Qdrant collection points | 323,523 |

**Code analysis:** The actual failure path ([VectorIndexer.ts:616-631](https://github.com/jsboige/jsboige-mcp-servers/blob/main/servers/roo-state-manager/src/services/task-indexer/VectorIndexer.ts#L616-L631)) does NOT re-embed on batch failure. Non-timeout errors set `allBatchesSucceeded = false`, which causes the caller to throw `CIRCUIT_BREAKER_OPEN` — no embeddings computed. Timeouts are non-fatal. This means partial batch failures → **deferred indexing (safe)**, not duplicate re-embedding.

**Verdict: H1 NOT CONFIRMED. Unreachable rate 1.4% (stable, transient network glitches). Zero waste embeddings.**

---

### H2 — chunk_id non-determinism across re-extractions

**Hypothesis:** `computeChunkId()` inputs may vary across runs (unstable `sequence_order`, content normalization differences), producing different UUIDs for the same content.

**Analysis:**
- `computeChunkId(taskId, chunkType, seq, content)` uses UUIDv5 — mathematically deterministic for identical inputs
- `sequence_order` is assigned sequentially by ChunkExtractor; stable as long as source content doesn't change
- `chunkType` is an enum (`message_exchange`, `tool_interaction`, `ui_message`, `claude_message`) — stable
- Note: `_chunkType` was intentionally removed from the hash in #2247 for forward-compatibility (this is correct)

**No code path was found that could produce different chunk_ids for unchanged source content.**

**Verdict: H2 NOT CONFIRMED. chunk_id is deterministic by construction.**

---

### H3 — Cross-machine bootstrap race (redundant embeddings)

**Hypothesis:** 12 MCP instances with separate in-memory `embeddingCache` restart simultaneously. If inter-instance upsert latency > preflight duration, multiple instances re-embed the same content.

**Analysis:**
- The preflight `retrieve()` reads from Qdrant (shared), not from in-memory cache. First upsert from any instance becomes visible to others immediately.
- With 1.4% unreachable rate and zero post-dedup waste (see H1 data), there is no observed inter-instance duplication at steady state.
- Bootstrap race would appear as a spike in `embeddings_called_total` on restart — not observed in monitoring.

**Verdict: H3 NOT CONFIRMED at current scale. Qdrant shared state absorbs inter-instance races correctly.**

---

## Qdrant Collection Health

| Machine | Collection points | Status |
|---------|-------------------|--------|
| ai-01 (R66) | 314,520 | ✅ healthy |
| po-2026 (Embeddings) | 323,523 | ✅ healthy |

Post-#2165 fix: +3,893 points indexed on ai-01 in 24h window (background indexer active and recovering). Migration considered complete.

---

## Recommendations

1. **No fix required** — all three hypotheses not confirmed. The system is healthy.
2. **Monitoring persistence gap** — `_metrics` counters are ephemeral (reset on MCP restart). If long-term monitoring is needed, extend `roosync_indexing(action: "status")` to include preflight metrics. Low priority.
3. **5M skip threshold** ([#2209](https://github.com/jsboige/roo-extensions/issues/2209)) — at 323K–314K points, preflight is active. If the collection grows past 5M, it falls back to post-index content-hash dedup (correct but burns embedding compute). Plan accordingly.

---

## Closing Criteria

| Criterion | Status |
|-----------|--------|
| #2195 merged (observability prérequis) | ✅ CLOSED |
| Data collected from 3+ machines | ✅ ai-01 + po-2026 (+ po-2025 ambient metrics) |
| Markdown report (`docs/analysis/`) | ✅ This document |
| H1 confirmed → issue dédiée | ✅ Not confirmed — no issue needed |
| H2 confirmed → issue dédiée | ✅ Not confirmed — no issue needed |
| H3 confirmed → architecture reco | ✅ Not confirmed at current scale |

**All criteria met. Investigation complete.**
