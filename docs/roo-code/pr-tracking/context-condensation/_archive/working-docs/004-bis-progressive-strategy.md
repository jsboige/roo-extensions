# Progressive Condensation Strategy - Granular Approach

**Date**: 2025-10-01  
**Version**: 2.0 (Revised based on user feedback)  
**Status**: Updated Design

## Executive Summary

This document revises the condensation strategy to follow a more progressive, pragmatic approach with three distinct versions of increasing sophistication. Each version is production-ready and delivers value, building incrementally toward the full smart condensation system.

## 1. Strategic Vision - Progressive Evolution

### 1.1 Philosophy Change

**Previous Approach**: Complex two-phase system with lossless + lossy
**New Approach**: Three progressive versions, each adding capability

**Key Insight**: Start with radical but simple mechanical truncation, then add intelligence progressively.

### 1.2 Version Progression

```
Version 1: Mechanical Truncation
    ↓ (adds threshold-based selection)
Version 2: Smart Truncation  
    ↓ (adds LLM summarization, parallelized)
Version 3: LLM-Enhanced Condensation
```

## 2. Version 1 - Mechanical Truncation (Radical but Simple)

### 2.1 Core Principle

**"Supprimer ou tronquer purement et simplement les tool parameters et tool results plus vieux que n-messages"**

**Target**: Messages older than N recent messages
**Method**: Mechanical deletion or truncation
**No LLM**: Pure deterministic processing
**Fast**: <100ms execution time

### 2.2 What Gets Processed

**Scope**:
1. Preserve first message (always - slash commands)
2. Preserve last N messages (default N=5)
3. **Process everything in between**:
   - Tool results → Delete or truncate to summary
   - Tool parameters → Delete verbose parameters
   - Keep user messages (always)
   - Keep assistant messages (always)

### 2.3 Detailed Algorithm

```typescript
interface V1Config {
  preserveRecentCount: number  // default: 5
  truncateToolResults: boolean  // default: true
  truncateToolParams: boolean   // default: true
  maxToolResultLines: number    // default: 5
  maxParamLength: number        // default: 100
}

async function mechanicalTruncation(
  messages: ApiMessage[],
  config: V1Config
): Promise<CondensationResult> {
  
  // 1. Identify zones
  const first = messages[0]
  const recent = messages.slice(-config.preserveRecentCount)
  const oldMessages = messages.slice(1, -config.preserveRecentCount)
  
  // 2. Process old messages
  const processed = oldMessages.map(msg => {
    
    // Always preserve user and assistant text messages
    if (msg.role === 'user' && !hasToolResult(msg)) return msg
    if (msg.role === 'assistant' && !hasToolUse(msg)) return msg
    
    // Process tool results
    if (hasToolResult(msg)) {
      return truncateToolResult(msg, config)
    }
    
    // Process tool calls
    if (hasToolUse(msg)) {
      return truncateToolParams(msg, config)
    }
    
    return msg
  })
  
  // 3. Reconstruct
  return {
    messages: [first, ...processed, ...recent],
    metrics: calculateMetrics(messages, processed)
  }
}
```

### 2.4 Tool Result Truncation

```typescript
function truncateToolResult(
  message: ApiMessage,
  config: V1Config
): ApiMessage {
  
  const content = Array.isArray(message.content) 
    ? message.content 
    : [{ type: 'text', text: message.content }]
  
  const truncated = content.map(block => {
    if (block.type !== 'tool_result') return block
    
    // Extract info
    const toolName = extractToolName(block)
    const resultText = extractContent(block)
    const lines = resultText.split('\n')
    
    if (lines.length <= config.maxToolResultLines) {
      return block // Keep as-is if small
    }
    
    // Truncate to first N lines + summary
    const truncatedContent = [
      ...lines.slice(0, config.maxToolResultLines),
      '',
      `⟨ Truncated: ${lines.length - config.maxToolResultLines} more lines ⟩`,
      `⟨ Tool: ${toolName} ⟩`
    ].join('\n')
    
    return {
      ...block,
      content: truncatedContent
    }
  })
  
  return {
    ...message,
    content: truncated
  }
}
```

### 2.5 Tool Parameter Truncation

```typescript
function truncateToolParams(
  message: ApiMessage,
  config: V1Config
): ApiMessage {
  
  const content = Array.isArray(message.content)
    ? message.content
    : [{ type: 'text', text: message.content }]
  
  const truncated = content.map(block => {
    if (block.type !== 'tool_use') return block
    
    // Truncate each parameter
    const truncatedInput = Object.entries(block.input).reduce(
      (acc, [key, value]) => {
        if (typeof value === 'string' && value.length > config.maxParamLength) {
          acc[key] = value.substring(0, config.maxParamLength) + '...'
        } else {
          acc[key] = value
        }
        return acc
      },
      {} as Record<string, any>
    )
    
    return {
      ...block,
      input: truncatedInput
    }
  })
  
  return {
    ...message,
    content: truncated
  }
}
```

### 2.6 Example V1 Execution

**Before**:
```
Message 1: User "create app"
Message 2: Assistant thinking... [500 tokens]
Message 3: Tool call read_file(longfile.ts) params:[long path] [50 tokens]
Message 4: Tool result [5000 tokens of file content]
Message 5: Assistant "found issue" [100 tokens]
Message 6: Tool call search(pattern) params:[verbose] [80 tokens]
Message 7: Tool result [3000 tokens of search results]
Message 8: User "fix it" [10 tokens]
Message 9: Assistant "fixing..." [50 tokens]

Total: ~8800 tokens
```

**After V1** (preserveRecentCount=3):
```
Message 1: User "create app" [PRESERVED]
Message 2: Assistant thinking... [500 tokens] [PRESERVED - text]
Message 3: Tool call read_file params:[trunc...] [30 tokens] [TRUNCATED]
Message 4: Tool result [first 5 lines + summary] [100 tokens] [TRUNCATED]
Message 5: Assistant "found issue" [100 tokens] [PRESERVED - text]
Message 6: Tool call search params:[trunc...] [40 tokens] [TRUNCATED]
Message 7: Tool result [first 5 lines + summary] [80 tokens] [TRUNCATED]
Message 8: User "fix it" [10 tokens] [PRESERVED - recent]
Message 9: Assistant "fixing..." [50 tokens] [PRESERVED - recent]

Total: ~910 tokens (90% reduction!)
```

### 2.7 V1 Characteristics

**Pros**:
- ✅ Extremely fast (<100ms)
- ✅ Deterministic and predictable
- ✅ No API costs
- ✅ Simple to implement
- ✅ Massive token reduction

**Cons**:
- ❌ Loses detailed tool results
- ❌ Not context-aware (treats all equally)
- ❌ Might truncate important information
- ❌ Fixed N messages preserved

**Best For**:
- Quick wins with minimal implementation
- Cost-conscious users
- Situations where tool results are verbose but not critical

## 3. Version 2 - Smart Truncation (Threshold-Based)

### 3.1 Core Principle

**"Sont tronqués ou supprimés les paramètres et résultats qui dépassent un seuil et à hauteur d'un objectif de condensation"**

**Target**: Messages exceeding size thresholds
**Method**: Selective truncation based on size + target
**No LLM**: Still deterministic but selective
**Fast**: <200ms execution time

### 3.2 What Gets Processed

**Scope**:
1. Preserve first message (always)
2. Preserve last N messages (always)
3. **In old messages zone**:
   - Identify oversized tool results (> threshold)
   - Identify oversized tool params (> threshold)
   - Truncate in priority order until target reduction achieved
   - Stop when target met

### 3.3 Detailed Algorithm

```typescript
interface V2Config {
  preserveRecentCount: number      // default: 5
  targetReductionPercent: number   // default: 50%
  toolResultThreshold: number      // default: 500 tokens
  toolParamThreshold: number       // default: 100 tokens
  truncationPriority: 'size' | 'age' | 'type'  // default: 'size'
}

async function smartTruncation(
  messages: ApiMessage[],
  config: V2Config,
  apiHandler: ApiHandler
): Promise<CondensationResult> {
  
  // 1. Calculate current tokens
  const currentTokens = await countTokens(messages, apiHandler)
  const targetTokens = currentTokens * (1 - config.targetReductionPercent / 100)
  
  // 2. Identify zones
  const first = messages[0]
  const recent = messages.slice(-config.preserveRecentCount)
  const oldMessages = messages.slice(1, -config.preserveRecentCount)
  
  // 3. Identify truncation candidates
  const candidates = await identifyOversizedContent(
    oldMessages,
    config,
    apiHandler
  )
  
  // 4. Sort by priority
  const sorted = sortByPriority(candidates, config.truncationPriority)
  
  // 5. Truncate until target met
  let processed = [...oldMessages]
  let currentSize = await countTokens(processed, apiHandler)
  
  for (const candidate of sorted) {
    if (currentSize <= targetTokens) break
    
    // Truncate this candidate
    const truncated = await truncateCandidate(candidate, config)
    const oldSize = candidate.tokenCount
    const newSize = await countTokens([truncated], apiHandler)
    
    // Replace in processed array
    processed[candidate.index] = truncated
    currentSize -= (oldSize - newSize)
  }
  
  // 6. Reconstruct
  return {
    messages: [first, ...processed, ...recent],
    metrics: {
      originalTokens: currentTokens,
      finalTokens: currentSize + await countTokens([first, ...recent], apiHandler),
      candidatesIdentified: candidates.length,
      candidatesTruncated: sorted.length
    }
  }
}
```

### 3.4 Candidate Identification

```typescript
interface TruncationCandidate {
  index: number              // Index in oldMessages array
  message: ApiMessage        // The message
  type: 'tool_result' | 'tool_param'
  tokenCount: number         // Current size
  priority: number           // For sorting
  toolName?: string          // For context
}

async function identifyOversizedContent(
  messages: ApiMessage[],
  config: V2Config,
  apiHandler: ApiHandler
): Promise<TruncationCandidate[]> {
  
  const candidates: TruncationCandidate[] = []
  
  for (const [index, message] of messages.entries()) {
    
    // Check tool results
    if (hasToolResult(message)) {
      const size = await countTokens([message], apiHandler)
      if (size > config.toolResultThreshold) {
        candidates.push({
          index,
          message,
          type: 'tool_result',
          tokenCount: size,
          priority: calculatePriority(size, index, 'tool_result'),
          toolName: extractToolName(message)
        })
      }
    }
    
    // Check tool params
    if (hasToolUse(message)) {
      const size = await countTokens([message], apiHandler)
      if (size > config.toolParamThreshold) {
        candidates.push({
          index,
          message,
          type: 'tool_param',
          tokenCount: size,
          priority: calculatePriority(size, index, 'tool_param'),
          toolName: extractToolName(message)
        })
      }
    }
  }
  
  return candidates
}
```

### 3.5 Priority Calculation

```typescript
function calculatePriority(
  size: number,
  index: number,
  type: string
): number {
  // Higher priority = truncate first
  
  switch (config.truncationPriority) {
    case 'size':
      // Largest first
      return size
      
    case 'age':
      // Oldest first (lower index = older)
      return -index
      
    case 'type':
      // Tool results before tool params
      return type === 'tool_result' ? 1000 : 500
      
    default:
      // Combined: size * age factor
      const ageFactor = 1 + (index * 0.1)
      return size / ageFactor
  }
}

function sortByPriority(
  candidates: TruncationCandidate[],
  priority: string
): TruncationCandidate[] {
  return candidates.sort((a, b) => b.priority - a.priority)
}
```

### 3.6 Example V2 Execution

**Before**:
```
Same as V1 example: 8800 tokens
```

**After V2** (targetReduction=50%, resultThreshold=500, paramThreshold=100):

**Step 1 - Identify candidates**:
```
Candidate 1: Message 4 (tool result, 5000 tokens, priority: 5000)
Candidate 2: Message 7 (tool result, 3000 tokens, priority: 3000)
Candidate 3: Message 6 (tool params, 80 tokens, priority: 80)
```

**Step 2 - Sort by size priority**:
```
1. Message 4 (5000 tokens)
2. Message 7 (3000 tokens)
3. Message 6 (80 tokens) - below threshold, skip
```

**Step 3 - Truncate until target (4400 tokens)**:
```
Current: 8800 tokens
Target: 4400 tokens

Truncate Message 4: 5000 → 150 tokens (saved 4850)
Current: 3950 tokens ✓ Target met!
Stop here.
```

**Result**:
```
Message 1: User "create app"
Message 2: Assistant thinking...
Message 3: Tool call [full params kept - below threshold]
Message 4: Tool result [TRUNCATED - was oversized]
Message 5: Assistant "found issue"
Message 6: Tool call [full params kept - below threshold]
Message 7: Tool result [KEPT - target already met]
Message 8-9: Recent messages [PRESERVED]

Total: ~3950 tokens (55% reduction)
```

### 3.7 V2 Characteristics

**Pros**:
- ✅ Fast (<200ms)
- ✅ Target-aware (stops when goal met)
- ✅ Threshold-based (only truncates oversized)
- ✅ Priority configurable (size, age, type)
- ✅ No API costs
- ✅ More selective than V1

**Cons**:
- ❌ Still loses detailed results
- ❌ Not semantic/importance aware
- ❌ Fixed thresholds might not fit all cases

**Best For**:
- Balance between speed and intelligence
- When you know some results are verbose but others needed
- Cost-conscious with need for selectivity

## 4. Version 3 - LLM-Enhanced (Future Evolution)

### 4.1 Core Principle

**"L'utilisation d'un résumé LLM plutôt qu'une troncature comme 2nde évolution"**

**Target**: Candidates identified by V2 algorithm
**Method**: LLM summarization in parallel
**Multiple Small Requests**: Not one big summarization
**Smart**: Semantic understanding

### 4.2 Key Innovation - Parallelization

**Current System Problem**: One large LLM call for entire conversation
**V3 Solution**: Multiple small parallel LLM calls per candidate

```typescript
// Current (slow, expensive)
summarizeConversation([all middle messages]) // One big call

// V3 (fast, granular)
Promise.all([
  summarizeToolResult(candidate1),  // Small parallel calls
  summarizeToolResult(candidate2),
  summarizeToolResult(candidate3),
  ...
])
```

### 4.3 Detailed Algorithm

```typescript
interface V3Config extends V2Config {
  useLLMSummarization: boolean     // default: true
  maxParallelCalls: number         // default: 5
  summaryMaxTokens: number         // default: 100 per summary
}

async function llmEnhancedCondensation(
  messages: ApiMessage[],
  config: V3Config,
  apiHandler: ApiHandler
): Promise<CondensationResult> {
  
  // 1-4. Same as V2 (identify candidates, sort, etc.)
  const candidates = await identifyOversizedContent(...)
  const sorted = sortByPriority(candidates, config.truncationPriority)
  
  // 5. NEW: Summarize candidates in parallel
  const summaries = await summarizeCandidatesInParallel(
    sorted,
    config,
    apiHandler
  )
  
  // 6. Apply summaries
  let processed = [...oldMessages]
  for (const [candidate, summary] of summaries) {
    processed[candidate.index] = replaceWithSummary(
      candidate.message,
      summary
    )
  }
  
  // 7. Reconstruct
  return {
    messages: [first, ...processed, ...recent],
    metrics: { ... }
  }
}
```

### 4.4 Parallel Summarization

```typescript
async function summarizeCandidatesInParallel(
  candidates: TruncationCandidate[],
  config: V3Config,
  apiHandler: ApiHandler
): Promise<Map<TruncationCandidate, string>> {
  
  const summaries = new Map()
  
  // Process in batches to respect maxParallelCalls
  for (let i = 0; i < candidates.length; i += config.maxParallelCalls) {
    const batch = candidates.slice(i, i + config.maxParallelCalls)
    
    // Parallel calls for this batch
    const batchSummaries = await Promise.all(
      batch.map(candidate => 
        summarizeCandidate(candidate, config, apiHandler)
      )
    )
    
    // Store results
    batch.forEach((candidate, idx) => {
      summaries.set(candidate, batchSummaries[idx])
    })
  }
  
  return summaries
}

async function summarizeCandidate(
  candidate: TruncationCandidate,
  config: V3Config,
  apiHandler: ApiHandler
): Promise<string> {
  
  const content = extractContent(candidate.message)
  
  // Small, focused summarization prompt
  const prompt = `Summarize this ${candidate.type} concisely (max ${config.summaryMaxTokens} tokens):

${content}

Focus on key information and results. Omit verbose details.`

  const stream = apiHandler.createMessage(
    prompt,
    [], // No context needed
    { maxTokens: config.summaryMaxTokens }
  )
  
  let summary = ''
  for await (const chunk of stream) {
    if (chunk.type === 'text') {
      summary += chunk.text
    }
  }
  
  return summary.trim()
}
```

### 4.5 Summary Application

```typescript
function replaceWithSummary(
  message: ApiMessage,
  summary: string
): ApiMessage {
  
  const content = Array.isArray(message.content)
    ? message.content
    : [{ type: 'text', text: message.content }]
  
  const replaced = content.map(block => {
    if (block.type === 'tool_result') {
      return {
        ...block,
        content: `⟨ Summarized by LLM ⟩\n\n${summary}\n\n⟨ Original was ${extractContent(block).length} chars ⟩`
      }
    }
    return block
  })
  
  return {
    ...message,
    content: replaced
  }
}
```

### 4.6 Example V3 Execution

**Same starting point as V2, but candidates get LLM summaries**:

**Candidate 1** (Message 4, 5000 token file content):
```
Original: [5000 tokens of TypeScript code]

LLM Summary (100 tokens):
"TypeScript utility module containing helper functions for string manipulation,
date formatting, and validation. Exports 12 functions including formatDate(),
validateEmail(), truncateText(). Uses external lodash dependency."
```

**Result**:
```
Message 4: Tool result
⟨ Summarized by LLM ⟩

TypeScript utility module containing helper functions for string manipulation,
date formatting, and validation. Exports 12 functions including formatDate(),
validateEmail(), truncateText(). Uses external lodash dependency.

⟨ Original was 45,230 chars ⟩

Tokens: ~120 (vs 5000 original = 98% reduction!)
```

### 4.7 V3 Characteristics

**Pros**:
- ✅ Semantic understanding (LLM)
- ✅ Preserves meaning better
- ✅ Parallel execution (fast)
- ✅ Granular (per-candidate)
- ✅ Configurable summary size
- ✅ Falls back to V2 if LLM fails

**Cons**:
- ❌ API costs (but minimal - small requests)
- ❌ Slight latency (but parallelized)
- ❌ Complexity (more code)

**Best For**:
- Best quality preservation
- When tool results contain important semantic info
- Users willing to pay for quality

## 5. Progressive Implementation Roadmap

### 5.1 Phase 1: V1 - Mechanical (Week 1-2)

**Deliverables**:
- Mechanical truncation algorithm
- Configuration for N preserved messages
- Fixed line/char limits
- Basic metrics

**Effort**: 2 weeks
**Risk**: Low
**Value**: High (immediate 80-90% reduction)

### 5.2 Phase 2: V2 - Smart (Week 3-4)

**Deliverables**:
- Candidate identification
- Threshold configuration
- Priority system (size/age/type)
- Target-based truncation
- Enhanced metrics

**Effort**: 2 weeks
**Risk**: Low
**Value**: Medium (better selectivity)

### 5.3 Phase 3: V3 - LLM (Week 5-7)

**Deliverables**:
- Parallel summarization system
- Per-candidate LLM calls
- Batch processing
- Fallback to V2
- Cost tracking
- Quality metrics

**Effort**: 3 weeks
**Risk**: Medium
**Value**: High (best quality)

### 5.4 Configuration Migration

```typescript
interface CondensationConfig {
  version: 'v1' | 'v2' | 'v3'  // User choice
  
  // V1 settings
  v1: {
    preserveRecentCount: number
    maxToolResultLines: number
    maxParamLength: number
  }
  
  // V2 settings (includes V1)
  v2: {
    ...v1,
    targetReductionPercent: number
    toolResultThreshold: number
    toolParamThreshold: number
    truncationPriority: 'size' | 'age' | 'type'
  }
  
  // V3 settings (includes V2)
  v3: {
    ...v2,
    useLLMSummarization: boolean
    maxParallelCalls: number
    summaryMaxTokens: number
  }
}
```

## 6. Comparison Matrix

| Feature | V1 Mechanical | V2 Smart | V3 LLM |
|---------|--------------|----------|---------|
| Speed | <100ms | <200ms | 2-5s |
| Token Reduction | 80-90% | 50-70% | 60-80% |
| Quality | Low | Medium | High |
| Cost | $0 | $0 | ~$0.01-0.05 |
| Selectivity | None | Threshold | Semantic |
| Complexity | Low | Medium | High |
| API Calls | 0 | 0 | N parallel |
| User Messages | 100% | 100% | 100% |
| Conversation | 100% | 100% | 100% |

## 7. Migration from Current System

### 7.1 Native Provider → V1

**Easy**: Just replace summarization with mechanical truncation
**No breaking changes**: Still in provider pattern
**Instant benefit**: Much faster, no API cost

### 7.2 V1 → V2

**Smooth**: Add threshold and target logic
**Config addition**: New thresholds and priority settings
**Backward compatible**: V1 is V2 with thresholds at 0

### 7.3 V2 → V3

**Optional**: User chooses to enable LLM
**Fallback**: V3 falls back to V2 on error
**Gradual**: Can test on subset of candidates first

## 8. Success Metrics Per Version

### V1 Success Criteria
- [ ] 80-90% token reduction
- [ ] <100ms execution
- [ ] Zero API cost
- [ ] User/assistant messages preserved

### V2 Success Criteria
- [ ] 50-70% token reduction
- [ ] <200ms execution
- [ ] Target-aware stopping
- [ ] Only oversized content truncated

### V3 Success Criteria
- [ ] 60-80% token reduction with better quality
- [ ] <5s execution (parallelized)
- [ ] Semantic meaning preserved
- [ ] Cost <$0.10 per condensation

## 9. Recommendations

**Start with V1**:
- Immediate value
- Low risk
- Fast to implement
- Validates approach

**Add V2 quickly**:
- Natural evolution
- Better user experience
- Still no cost

**V3 as premium**:
- Optional upgrade
- For quality-conscious users
- Clear value proposition

**Configuration**:
- Default: V2 (smart, free)
- V1 available for maximum speed
- V3 opt-in for quality

---

**Revised Strategy**: Progressive, pragmatic, production-ready at each stage.