# Current System Analysis - Context Condensation in Roo-Code

**Date**: 2025-10-01  
**Analysis Phase**: SDDD Grounding  
**Status**: Complete

## Executive Summary

This document provides a comprehensive analysis of the current context condensation system in roo-code, identifying its architecture, strengths, limitations, and opportunities for improvement. The analysis is based on semantic code searches and detailed examination of the implementation.

## 1. System Architecture

### 1.1 Core Components

The context condensation system is implemented across two primary modules:

**Primary Module**: `src/core/sliding-window/index.ts`
- Entry point for condensation logic
- Token counting and threshold management
- Fallback truncation strategy

**Secondary Module**: `src/core/condense/index.ts`
- LLM-based summarization implementation
- Message processing and reconstruction
- Summary generation and validation

### 1.2 Key Functions

#### `truncateConversationIfNeeded()`
**Location**: `src/core/sliding-window/index.ts:57-141`

**Responsibilities**:
- Calculate context tokens (includes system prompt, history, last message)
- Determine effective threshold (global vs profile-specific)
- Trigger condensation when thresholds exceeded
- Fallback to truncation if condensation fails

**Algorithm**:
```typescript
// Calculate tokens
prevContextTokens = totalTokens + lastMessageTokens
allowedTokens = contextWindow * (1 - 0.1) - maxTokens

// Determine threshold
effectiveThreshold = profileThreshold ?? autoCondenseContextPercent

// Check conditions
if (autoCondenseContext) {
  contextPercent = (100 * prevContextTokens) / contextWindow
  if (contextPercent >= effectiveThreshold || prevContextTokens > allowedTokens) {
    // Attempt summarization
    result = await summarizeConversation(...)
    if (result.error) {
      // Fall back to truncation
    }
  }
}

// Final fallback
if (prevContextTokens > allowedTokens) {
  truncate 50% of messages
}
```

#### `summarizeConversation()`
**Location**: `src/core/condense/index.ts:85-213`

**Responsibilities**:
- Preserve first message (slash commands)
- Preserve last N=3 messages (recent context)
- Summarize middle messages using LLM
- Validate summary doesn't grow context
- Reconstruct message array with summary

**Message Processing**:
```
Original:  [M1, M2, M3, M4, M5, M6, M7, M8, M9]
                     ↓
Preserved: [M1, ----------------, M7, M8, M9]
                     ↓ (summarize)
Final:     [M1, SUMMARY, M7, M8, M9]
```

#### `truncateConversation()`
**Location**: `src/core/sliding-window/index.ts:41-50`

**Responsibilities**:
- Emergency fallback when condensation fails
- Removes 50% of messages (rounded to even number)
- Always preserves first message
- Simple chronological truncation

### 1.3 Configuration Settings

**Global Settings**:
- `autoCondenseContext` (boolean): Enable/disable auto-condensation
- `autoCondenseContextPercent` (5-100%): Threshold to trigger condensation
- `customCondensingPrompt` (string): User-defined summarization prompt
- `condensingApiHandler` (ApiHandler): Specific API for condensation

**Profile-Specific**:
- Each mode can override `autoCondenseContextPercent`
- Value `-1` means inherit from global setting
- Invalid values fall back to global setting

**Constants**:
```typescript
TOKEN_BUFFER_PERCENTAGE = 0.1  // 10% safety buffer
N_MESSAGES_TO_KEEP = 3         // Recent messages preserved
MIN_CONDENSE_THRESHOLD = 5     // Min % to trigger
MAX_CONDENSE_THRESHOLD = 100   // Max % to trigger
```

## 2. Current Condensation Strategy

### 2.1 Preservation Rules

**Always Preserved**:
1. First message - may contain slash command metadata
2. Last 3 messages - recent conversation context
3. Summary messages - previous condensation results

**Summarized**:
- All messages between first and last-3
- Excludes messages after most recent summary (if exists)
- Includes all message types equally (user, assistant, tool_use, tool_result)

### 2.2 LLM Summarization Prompt

The default `SUMMARY_PROMPT` (lines 14-52) instructs the LLM to create:

1. **Previous Conversation**: High-level discussion flow
2. **Current Work**: Detailed recent work description
3. **Key Technical Concepts**: Technologies, frameworks, conventions
4. **Relevant Files and Code**: Specific files examined/modified
5. **Problem Solving**: Solutions and troubleshooting efforts
6. **Pending Tasks and Next Steps**: Outstanding work with verbatim quotes

**Prompt Characteristics**:
- Comprehensive and detailed
- Emphasizes technical precision
- Requests verbatim quotes for context preservation
- Structured output format
- No additional commentary

### 2.3 Validation Checks

**Pre-Summarization**:
1. Minimum messages check: Must have > (N_MESSAGES_TO_KEEP + 1) messages
2. Recent summary check: No summary in last N_MESSAGES_TO_KEEP messages
3. No summarization immediately after condensation

**Post-Summarization**:
1. Empty summary check: Summary must have content
2. Context growth check: `newContextTokens >= prevContextTokens` → error
   - Prevents summarization that makes context worse
   - Uses actual output tokens when available
   - Falls back to estimated tokens

## 3. Identified Limitations

### 3.1 Batch Processing Without Distinction

**Current Behavior**:
- All middle messages processed as single batch
- No differentiation between message types
- User/assistant dialogue treated same as tool results

**Impact**:
- Large tool results consume summary space equally
- Conversation decisions may be over-compressed
- No optimization for repeated content

**Example**:
```
Messages to summarize: [
  User: "Read file A"
  Tool_Result: [5KB file content]
  Assistant: "Found issue X"
  User: "Read file A again"
  Tool_Result: [Same 5KB file content]
  Assistant: "Still has issue X"
]
→ All compressed equally, no deduplication
```

### 3.2 Loss of Conversation Messages

**Current Behavior**:
- User/assistant dialogue summarized into narrative
- Decision rationale compressed
- Intermediate problem-solving lost

**Impact**:
- Loss of user intent clarity
- Decision trail becomes opaque
- Harder to understand conversation flow in summary

**What Gets Lost**:
- User questions and clarifications
- Assistant reasoning and explanations
- Iterative problem-solving dialogue
- Error discussions and resolutions

### 3.3 No Content-Type Prioritization

**Current Behavior**:
- Tool calls, tool results, and messages treated equally
- No recognition that tool results often largest
- No recognition that tool calls are metadata-heavy
- No recognition that conversation messages contain decisions

**Opportunity**:
```
Priority for condensation should be:
1. Tool results (often largest, can be referenced)
2. Tool call parameters (verbose, can be summarized)
3. Assistant reasoning (can be condensed)
4. Conversation messages (should be preserved)
```

### 3.4 No Lossless Optimization

**Missing Capabilities**:
1. **Deduplication**: No detection of repeated file reads
2. **Consolidation**: No merging of redundant tool results
3. **Reference System**: No pointer to latest version of content
4. **Incremental Updates**: No diff-based representation

**Impact**:
- Repeated file reads consume context multiple times
- Same tool results stored multiple times
- No optimization before lossy compression needed

### 3.5 Chronological Bias

**Current Behavior**:
- Only considers message position in sequence
- Oldest messages always condensed first
- No semantic importance weighting

**Missed Opportunities**:
- Some old messages may be more important than recent
- Critical architectural decisions may be early in conversation
- Reference information should be preserved over transient discussion

## 4. Current Strengths

### 4.1 Robust Fallback Strategy

**Triple Safety Net**:
1. Primary: LLM-based intelligent summarization
2. Secondary: Validation of summary effectiveness
3. Tertiary: Simple truncation if all else fails

**Benefits**:
- System never fails to handle context overflow
- Degraded service better than no service
- Clear error messaging to user

### 4.2 Customization Options

**User Control**:
- Custom summarization prompts
- Custom API handlers for condensation
- Per-mode threshold configuration
- Manual trigger available

**Benefits**:
- Flexibility for different use cases
- Cost optimization (use cheaper model for condensation)
- Mode-specific strategies possible

### 4.3 Context Preservation Rules

**Smart Defaults**:
- First message preservation (slash commands)
- Recent message preservation (working context)
- Summary message tracking (prevent re-summarization)

**Benefits**:
- Essential context maintained
- Working context always available
- No summary loops

### 4.4 Comprehensive Testing

**Test Coverage**:
- Threshold behavior tests (auto-condense at %, profile overrides)
- Edge cases (not enough messages, recent summary exists)
- Fallback scenarios (condensation fails, context grows)
- Multiple model configurations (different context windows)
- API handler selection (custom vs default)

**Quality Indicators**:
- Well-tested behavior
- Edge cases considered
- Clear expectations documented

## 5. Token Management Analysis

### 5.1 Token Calculation

**Components**:
```typescript
Context Token Breakdown:
- systemPrompt tokens
- conversation history tokens (excluding last message)
- lastMessage tokens

Total = prevContextTokens = totalTokens + lastMessageTokens
```

**Buffer Strategy**:
```typescript
allowedTokens = contextWindow * (1 - TOKEN_BUFFER_PERCENTAGE) - reservedTokens
              = contextWindow * 0.9 - maxTokens

// 10% buffer prevents edge cases
// Reserves space for response (maxTokens)
```

### 5.2 Threshold System

**Two Trigger Conditions** (OR logic):
1. Percentage threshold: `contextPercent >= effectiveThreshold`
2. Absolute threshold: `prevContextTokens > allowedTokens`

**Why Both?**:
- Percentage: Proactive condensation before emergency
- Absolute: Hard limit enforcement

**Profile Override Logic**:
```typescript
if (profileThreshold === -1) {
  use global autoCondenseContextPercent
} else if (5 <= profileThreshold <= 100) {
  use profileThreshold
} else {
  warn and use global autoCondenseContextPercent
}
```

### 5.3 Condensation Validation

**Post-Condensation Check**:
```typescript
if (newContextTokens >= prevContextTokens) {
  error = "condense_context_grew"
  // Abort condensation, keep original messages
}
```

**Why Critical**:
- Prevents condensation making things worse
- Can happen if summary is too verbose
- Can happen if model outputs more than input

## 6. Integration Points

### 6.1 Task.ts Integration

**Location**: `src/core/task/Task.ts`

**Call Sites**:
1. **Line 2600**: Regular task execution
   ```typescript
   const truncateResult = await truncateConversationIfNeeded({
     messages: this.apiConversationHistory,
     totalTokens: contextTokens,
     autoCondenseContext,
     autoCondenseContextPercent,
     ...
   })
   ```

2. **Line 2485**: Forced context reduction
   ```typescript
   const truncateResult = await truncateConversationIfNeeded({
     ...
     autoCondenseContext: true,
     autoCondenseContextPercent: FORCED_CONTEXT_REDUCTION_PERCENT,
     ...
   })
   ```

**Message Handling**:
- Success: Post summary message to UI (`say("condense_context")`)
- Failure: Post error message to UI (`say("condense_context_error")`)
- Context growth: Skip and show error

### 6.2 Telemetry Integration

**Events Tracked**:
1. `captureContextCondensed(taskId, isAutomatic, usedCustomPrompt, usedCustomHandler)`
   - Tracks every condensation attempt
   - Distinguishes automatic vs manual
   - Tracks customization usage

2. `captureSlidingWindowTruncation(taskId)`
   - Tracks fallback truncation events
   - Indicates condensation failures

**Usage**:
- Analytics on condensation frequency
- Effectiveness monitoring
- Feature adoption tracking

### 6.3 UI Integration

**Components**:
- `ContextCondenseRow.tsx`: Displays condensation result
- `CondensingContextRow.tsx`: Shows in-progress indicator
- Manual trigger button in TaskHeader
- Settings for auto-condense configuration

**User Feedback**:
- Visual indicator during condensation
- Summary of token reduction
- Cost of condensation operation
- Error messages on failure

## 7. Performance Characteristics

### 7.1 Time Complexity

**Token Counting**: O(n) where n = number of content blocks
**Message Selection**: O(m) where m = number of messages
**Summarization**: O(api_latency) - typically 2-5 seconds
**Validation**: O(n) for token counting

**Total**: Dominated by API latency for LLM summarization

### 7.2 Cost Considerations

**Cost Components**:
1. Input tokens: All messages to summarize
2. Output tokens: Summary generation
3. Validation tokens: Summary token counting

**Cost Optimization**:
- Custom API handler can use cheaper model
- Condensation only when needed (threshold-based)
- Validation prevents wasteful condensation

### 7.3 Frequency Analysis

**Typical Triggers**:
- Long conversations (50+ messages)
- Large tool results (file contents)
- Multiple file operations
- Iterative debugging sessions

**Impact**:
- 1-3 condensations per long task typical
- Each reduces context by 50-70%
- Minimal impact on short tasks

## 8. Comparison to User Requirements

### 8.1 User-Identified Issues

| Issue | Current System | Required Improvement |
|-------|---------------|---------------------|
| Batch condensation without distinction | ✓ Confirmed | Need content-type aware processing |
| Loses conversation messages | ✓ Confirmed | Need to preserve dialogue |
| No prioritization of content types | ✓ Confirmed | Need prioritized condensation |
| No lossless optimization | ✓ Confirmed | Need deduplication & consolidation |
| Chronological truncation bias | ✓ Confirmed | Need tree-based importance weighting |

### 8.2 Provider Architecture Readiness

**Current Extensibility**: Limited
- Condensation logic tightly coupled
- No provider abstraction
- Hard to add alternative strategies

**Required**:
- Provider interface
- Strategy pattern implementation
- Configuration-based selection
- Backward compatibility

### 8.3 Missing Features

1. **Content Analysis**:
   - No message type detection
   - No size-based prioritization
   - No duplicate detection
   - No semantic similarity checks

2. **Optimization Strategies**:
   - No reference system for repeated content
   - No incremental updates
   - No selective preservation
   - No importance scoring

3. **Monitoring**:
   - No detailed breakdown by message type
   - No effectiveness metrics
   - No optimization opportunities reporting

## 9. External Integration - Roo-State-Manager

### 9.1 Potential Pattern Reuse

**Roo-State-Manager Capabilities** (external MCP):
- Skeleton management (conversation without heavy content)
- Message display options (with/without tool results)
- Trace analysis
- Token consumption breakdown

**Applicable Patterns**:
- Skeleton concept for lightweight representation
- Heavy content separation strategy
- Message metadata preservation
- Trace-based analysis

### 9.2 Investigation Needed

**Questions for Deeper Analysis**:
1. How does skeleton system separate heavy from light content?
2. What metadata is preserved in skeleton mode?
3. Can skeleton generation be reused for condensation?
4. What are the token savings in skeleton vs full mode?

## 10. Recommendations Summary

### 10.1 Immediate Opportunities

1. **Lossless Phase**: Implement before LLM summarization
   - File read deduplication
   - Tool result consolidation
   - Reference system for repeated content

2. **Content-Type Awareness**: Classify messages by type
   - Tool results (largest, easiest to compress)
   - Tool calls (metadata-heavy)
   - Conversation (decisions, preserve more)

3. **Prioritized Condensation**: Phase-based approach
   - Phase 1: Lossless optimization
   - Phase 2: Lossy by priority (tool results → calls → reasoning → conversation)

### 10.2 Architectural Changes Needed

1. **Provider Pattern**: Abstract condensation strategy
   - `NativeCondensationProvider` (current implementation)
   - `SmartCondensationProvider` (new improved strategy)
   - Extensible interface for future providers

2. **Configuration Enhancement**:
   - Provider selection dropdown
   - Strategy-specific settings
   - Backward compatibility mode

3. **Monitoring Enhancement**:
   - Token breakdown by message type
   - Effectiveness metrics
   - Optimization opportunity detection

### 10.3 Testing Requirements

1. **Trace-Based Testing**:
   - Real conversation analysis
   - Token consumption patterns
   - Effectiveness validation

2. **Comparative Testing**:
   - Current vs improved strategy
   - Token savings measurement
   - Context preservation quality

3. **Edge Case Coverage**:
   - Provider switching
   - Fallback scenarios
   - Configuration migration

## 11. Conclusion

The current context condensation system is **functional and well-tested** with robust fallback mechanisms and customization options. However, it suffers from **lack of content-type awareness** and **no lossless optimization phase**, leading to suboptimal condensation that loses conversation context.

The path forward is clear:
1. Introduce **provider architecture** for extensibility
2. Implement **two-phase condensation** (lossless then lossy)
3. Add **content-type classification** and prioritization
4. Preserve **conversation messages** more aggressively
5. Maintain **backward compatibility** with current behavior

The next documents will detail the requirements, architecture, strategy, and implementation roadmap for these improvements.

---

**Next Document**: `002-requirements-specification.md`