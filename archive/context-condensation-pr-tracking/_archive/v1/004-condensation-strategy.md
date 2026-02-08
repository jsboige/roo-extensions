# Condensation Strategy - Lossless and Lossy Algorithms

**Date**: 2025-10-01  
**Version**: 1.0  
**Status**: Algorithm Specification

## Executive Summary

This document specifies the detailed algorithms for smart context condensation using a two-phase approach: **Lossless Optimization** (deduplication and consolidation without information loss) followed by **Lossy Compression** (prioritized summarization when needed). The strategy aims for 60-75% total token reduction while preserving conversation quality.

## 1. Two-Phase Overview

### 1.1 Strategy Philosophy

**Phase 1 - Lossless (30-50% reduction)**:
- File read deduplication
- Tool result consolidation  
- Reference system creation
- Deterministic, fast (<1s)
- Zero information loss
- No API costs

**Phase 2 - Lossy (additional 30-50% reduction)**:
- Content-type aware compression
- Prioritized by importance
- LLM-based when needed
- Preserves conversation messages
- 2-5 seconds
- Minimal API costs

### 1.2 Expected Outcomes

- **Total reduction**: 60-75% vs current 50-70%
- **Conversation preservation**: Significantly improved
- **User messages**: 100% preserved
- **Performance**: <6 seconds total

## 2. Lossless Optimization Phase

### 2.1 File Read Deduplication

**Algorithm**:
```
1. Scan messages for tool_result blocks from read_file
2. Extract: file path, content, content hash
3. Group by file path
4. For each file with duplicates:
   - Keep first occurrence with full content
   - Replace duplicates with reference: "⟨ See message #N for content ⟩"
5. Calculate token savings
```

**Example**:
```
Before:
  Msg 10: read_file(utils.ts) → 2000 tokens
  Msg 15: read_file(utils.ts) → 2000 tokens [DUPLICATE]
  Msg 22: read_file(utils.ts, lines 1-50) → 500 tokens [PARTIAL]

After:
  Msg 10: read_file(utils.ts) → 2000 tokens
  Msg 15: ⟨ See message #10 for content ⟩ → 20 tokens
  Msg 22: ⟨ Lines 1-50 in message #10 ⟩ → 25 tokens

Savings: 2455 tokens (55% reduction)
```

### 2.2 Tool Result Consolidation

**Rules**:
1. **List operations** (same directory) → Merge into single list
2. **Search operations** (same pattern) → Combine results
3. **Execute command** (repeated) → Keep latest output only
4. **Similar small results** → Group and summarize

**Example**:
```
Before:
  Msg 12: list_files(src/) → [file1, file2, file3] (200 tokens)
  Msg 18: list_files(src/) → [file1, file2, file3, file4] (250 tokens)  
  Msg 25: list_files(src/) → [file1, file2, file3, file4, file5] (300 tokens)

After:
  Msg 12: list_files(src/) - Consolidated
  ⟨ 3 list operations merged ⟩
  Total: [file1, file2, file3, file4, file5] (150 tokens)

Savings: 600 tokens (80% reduction)
```

### 2.3 Reference System

**Format**:
```typescript
interface ContentReference {
  type: 'file' | 'tool_result' | 'output'
  originalIndex: number
  path?: string
  hash: string
  referenceText: string
}
```

**Reference Text Examples**:
- Files: `⟨ See message #10 for src/utils.ts content ⟩`
- Tools: `⟨ See message #15 for list_files result ⟩`
- Output: `⟨ See message #20 for command output ⟩`

### 2.4 Complete Lossless Algorithm

```typescript
async function optimizeLossless(messages, apiHandler) {
  // 1. Classify messages by type
  const classified = await classifyMessages(messages)
  
  // 2. Detect and deduplicate file reads
  const fileReads = detectFileReads(classified)
  const deduped = deduplicateFiles(classified, fileReads)
  
  // 3. Consolidate tool results
  const consolidated = consolidateToolResults(deduped)
  
  // 4. Count final tokens
  const finalTokens = await countTokens(consolidated)
  
  // 5. Validate no growth
  if (finalTokens >= originalTokens) throw Error('Growth detected')
  
  return {
    messages: consolidated,
    tokenCount: finalTokens,
    metrics: {
      filesDeduped: fileReads.size,
      resultsConsolidated: consolidationCount,
      tokensSaved: originalTokens - finalTokens
    }
  }
}
```

## 3. Lossy Compression Phase

### 3.1 Content-Type Classification

```typescript
enum MessageType {
  TOOL_RESULT,         // Priority 1 (compress first)
  TOOL_CALL,          // Priority 2
  ASSISTANT_THINKING,  // Priority 3
  ASSISTANT_MESSAGE,   // Priority 4
  USER_MESSAGE,       // Priority 5 (preserve)
  SYSTEM_MESSAGE      // Never compress
}
```

### 3.2 Prioritized Compression

**Phase 2.1 - Tool Results (80-90% reduction)**:
```typescript
async function compressToolResult(message) {
  // Extract structure
  const structure = analyzeContent(message)
  
  // Compress based on type
  if (structure.type === 'file') {
    return `File: ${path}
Lines: ${totalLines}
Key sections: ${keySections}
⟨ Full content compressed ⟩`
  }
  
  if (structure.type === 'list') {
    return `Directory: ${dir}
Total: ${count} entries
Sample: ${first5}
⟨ ${remaining} more entries ⟩`
  }
  
  if (structure.type === 'output') {
    return `Command: ${cmd}
Exit code: ${code}
Summary: ${summary}
⟨ Full output compressed ⟩`
  }
}
```

**Phase 2.2 - Tool Calls (50-70% reduction)**:
```typescript
function simplifyToolCall(toolUse) {
  // Truncate long strings
  // Summarize large arrays
  // Remove verbose parameters
  
  return {
    ...toolUse,
    input: simplifiedParameters
  }
}
```

**Phase 2.3 - Thinking (40-60% reduction)**:
```typescript
function condenseThinking(text) {
  // Extract key points
  // Preserve conclusion
  
  return `⟨ Reasoning condensed ⟩
Key points:
1. ${point1}
2. ${point2}
...
Conclusion: ${conclusion}`
}
```

**Phase 2.4 - Conversation (0-20% reduction)**:
```typescript
function preserveConversation(messages) {
  // NEVER compress user messages
  // Keep assistant decisions
  // Only condense very long explanations
  
  return messages.map(msg => {
    if (msg.type === 'USER_MESSAGE') return msg // 100% preserved
    if (msg.type === 'ASSISTANT_MESSAGE' && msg.length < 300) return msg
    return condenseOnlyIfNecessary(msg)
  })
}
```

### 3.3 Complete Lossy Algorithm

```typescript
async function compressLossy(messages, context, options) {
  let current = messages
  let targetReduction = options.targetReduction
  
  // Phase 2.1: Compress tool results
  if (shouldContinue(current, targetReduction)) {
    current = await compressToolResults(current)
  }
  
  // Phase 2.2: Simplify tool calls
  if (shouldContinue(current, targetReduction)) {
    current = await simplifyToolCalls(current)
  }
  
  // Phase 2.3: Condense thinking
  if (shouldContinue(current, targetReduction)) {
    current = await condenseThinking(current)
  }
  
  // Phase 2.4: Minimal conversation compression (last resort)
  if (shouldContinue(current, targetReduction)) {
    current = await preserveConversation(current)
  }
  
  return {
    messages: current,
    metrics: calculateMetrics()
  }
}
```

## 4. Complete Smart Condensation

### 4.1 Integrated Flow

```typescript
export async function smartCondense(context, options) {
  const startTime = Date.now()
  const initial = context.totalTokens
  
  // Phase 1: Lossless
  const lossless = await optimizeLossless(
    context.messages,
    context.apiHandler
  )
  
  const afterLossless = lossless.tokenCount
  const losslessPercent = ((initial - afterLossless) / initial) * 100
  
  // Check if target achieved
  if (losslessPercent >= options.targetReductionPercent) {
    return formatResult(lossless, 'lossless-only')
  }
  
  // Phase 2: Lossy (if needed)
  const lossy = await compressLossy(
    lossless.messages,
    context,
    { targetReduction: options.targetReductionPercent - losslessPercent }
  )
  
  return formatResult({
    messages: lossy.messages,
    losslessMetrics: lossless.metrics,
    lossyMetrics: lossy.metrics,
    totalReduction: ((initial - lossy.tokenCount) / initial) * 100,
    timeElapsed: Date.now() - startTime
  }, 'two-phase')
}
```

### 4.2 Result Formatting

```typescript
function formatResult(data, strategy) {
  return {
    messages: data.messages,
    summary: strategy === 'lossless-only'
      ? formatLosslessSummary(data.metrics)
      : formatCombinedSummary(data.losslessMetrics, data.lossyMetrics),
    cost: calculateCost(data),
    newContextTokens: data.tokenCount,
    prevContextTokens: data.initial,
    metrics: {
      lossless: data.losslessMetrics,
      lossy: data.lossyMetrics,
      totalTokensSaved: data.initial - data.tokenCount,
      reductionPercent: data.totalReduction,
      phasesExecuted: data.phases,
      timeElapsed: data.timeElapsed
    }
  }
}

function formatCombinedSummary(lossless, lossy) {
  return `Smart condensation complete:

Lossless Phase:
- ${lossless.filesDeduped} files deduplicated
- ${lossless.resultsConsolidated} results consolidated
- ${lossless.tokensSaved} tokens saved

Lossy Phase:
- ${lossy.toolResultsCompressed} tool results compressed
- ${lossy.toolCallsSimplified} tool calls simplified
- ${lossy.conversationPreserved} conversation messages preserved
- ${lossy.tokensSaved} tokens saved

Total: ${lossless.tokensSaved + lossy.tokensSaved} tokens saved`
}
```

## 5. Edge Cases and Error Handling

### 5.1 Edge Cases

**Case 1: No tool results**
```typescript
if (noToolResults) {
  // Skip lossless, minimal lossy only
  return minimalCompression()
}
```

**Case 2: Context grew**
```typescript
if (newTokens >= originalTokens) {
  // Rollback and use truncation fallback
  return truncationFallback()
}
```

**Case 3: Invalid reference**
```typescript
if (referenceTargetMissing) {
  // Restore original content
  restoreContent()
}
```

**Case 4: Only user messages**
```typescript
if (onlyUserMessages) {
  // Cannot condense, return as-is
  return originalMessages
}
```

### 5.2 Error Recovery

```typescript
try {
  const lossless = await optimizeLossless()
} catch (error) {
  console.warn('Lossless failed, continuing:', error)
  // Continue with original messages
}

try {
  const lossy = await compressLossy()
} catch (error) {
  console.error('Lossy failed, fallback:', error)
  return nativeProvider.condense() // Fallback to current
}
```

## 6. Performance Optimization

### 6.1 Token Count Caching

```typescript
const tokenCache = new Map<string, number>()

async function cachedCount(content, apiHandler) {
  const hash = hashContent(content)
  if (tokenCache.has(hash)) return tokenCache.get(hash)
  
  const count = await apiHandler.countTokens(content)
  tokenCache.set(hash, count)
  return count
}
```

### 6.2 Batch Processing

```typescript
async function batchTokenCount(messages, apiHandler) {
  // Count all in parallel
  return Promise.all(
    messages.map(m => apiHandler.countTokens(m.content))
  )
}
```

## 7. Testing Strategy

### 7.1 Unit Tests

```typescript
describe('Lossless Phase', () => {
  it('deduplicates file reads', async () => {
    const result = await optimizeLossless(duplicateMessages)
    expect(result.metrics.filesDeduped).toBeGreaterThan(0)
  })
  
  it('never increases token count', async () => {
    const result = await optimizeLossless(messages)
    expect(result.tokenCount).toBeLessThanOrEqual(originalCount)
  })
})

describe('Lossy Phase', () => {
  it('compresses tool results first', async () => {
    const result = await compressLossy(messages)
    expect(result.metrics.toolResultsCompressed).toBeGreaterThan(0)
  })
  
  it('preserves user messages 100%', async () => {
    const result = await compressLossy(messages)
    expect(getUserMessages(result)).toEqual(getUserMessages(original))
  })
})
```

### 7.2 Integration Tests

```typescript
describe('Smart Condensation', () => {
  it('achieves 60-75% reduction', async () => {
    const result = await smartCondense(context, options)
    expect(result.metrics.reductionPercent).toBeGreaterThanOrEqual(60)
    expect(result.metrics.reductionPercent).toBeLessThanOrEqual(75)
  })
  
  it('preserves conversation quality', async () => {
    const result = await smartCondense(context, options)
    const quality = assessQuality(original, result.messages)
    expect(quality).toBeGreaterThan(0.9) // >90% preservation
  })
})
```

## 8. Success Metrics

### 8.1 Performance Targets

**Lossless Phase**:
- Reduction: 30-50%
- Speed: <1 second
- Quality: 100% preservation
- Cost: $0

**Lossy Phase**:
- Reduction: 30-50% additional
- Speed: 2-5 seconds
- Quality: >90% preservation
- Cost: $0.01-0.05

**Combined**:
- Total: 60-75%
- Better than current: 50-70%
- Speed: <6 seconds total
- Conversation: Significantly improved

### 8.2 Quality Metrics

- User message preservation: 100%
- Conversation continuity: >90%
- Decision traceability: >85%
- Information completeness: >80%

---

**Next Document**: `005-implementation-roadmap.md`