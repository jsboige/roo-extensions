# Requirements Specification - Context Condensation System v2.0

**Date**: 2025-10-02  
**Version**: 2.0 - Consolidated  
**Status**: Ready for Implementation

## Executive Summary

This document specifies the requirements for a comprehensive context condensation system in roo-code. The system introduces a **modular provider architecture** supporting multiple condensation strategies:

1. **Native Provider**: Backward-compatible wrapper for existing LLM-based summarization
2. **Lossless Provider**: Pure optimization without information loss (deduplication, consolidation)
3. **Truncation Provider**: Fast mechanical truncation/suppression
4. **Smart Provider**: Ultra-configurable pass-based architecture with fine-grained control

The system leverages **API profiles** for cost optimization, **dynamic thresholds** per profile, and a **three-level content model** (message text, tool parameters, tool results) with **four operations** (keep, suppress, truncate, summarize).

## 1. Problem Statement

### 1.1 Current Issues

The existing context condensation system has five critical limitations:

1. **Indiscriminate Batch Processing**: All message types condensed equally without regard to content type or importance
2. **Conversation Message Loss**: User/assistant dialogue gets summarized away, losing decision context
3. **No Content-Type Prioritization**: Tool results (largest) condensed same as conversation (most important)
4. **No Lossless Optimization**: Repeated file reads and redundant tool results stored multiple times
5. **Chronological Bias**: Only message position considered, not semantic importance
6. **Single Strategy**: No flexibility in condensation approach based on use case
7. **Cost Inefficiency**: Always uses conversation model for condensation (expensive)

### 1.2 Impact on Users

**User Experience Problems**:
- Loss of conversation context after condensation
- Inability to trace decision-making rationale
- Repeated information consuming context unnecessarily
- Suboptimal token usage leading to more frequent condensation
- High API costs for condensation operations

**Technical Problems**:
- Inefficient context usage
- Higher API costs due to suboptimal condensation
- Difficulty continuing work after condensation
- No optimization before expensive LLM summarization
- Lack of control over condensation strategy

## 2. Goals and Objectives

### 2.1 Primary Goals

1. **Preserve Conversation Quality**: Maintain user/assistant dialogue with minimal loss
2. **Optimize Token Usage**: Achieve better compression through lossless optimization
3. **Content-Type Awareness**: Prioritize condensation by message type importance
4. **Backward Compatibility**: Existing behavior available as default option
5. **User Control**: Allow users to choose condensation strategy and configure it
6. **Cost Optimization**: Enable use of cheaper models for condensation via API profiles
7. **Flexibility**: Support multiple strategies from simple to complex

### 2.2 Success Metrics

**Quantitative Metrics**:
- 30-50% reduction in token consumption through lossless phase
- 10-20% improvement in conversation message preservation rate
- 50-95% reduction in condensation costs (with optimized profiles)
- <5% regression in overall condensation effectiveness
- Zero breaking changes to existing API

**Qualitative Metrics**:
- User-reported improvement in context continuity
- Reduced frequency of "lost context" reports
- Positive feedback on strategy selection options
- Easy configuration of condensation strategies

### 2.3 Non-Goals

**Out of Scope**:
- Real-time streaming condensation
- Automatic strategy selection based on conversation type
- Cross-conversation context sharing
- Distributed condensation (splitting across multiple API calls)
- ML-based importance scoring (future)

## 3. Functional Requirements

### 3.1 Provider Architecture

#### FR-PA-001: Provider Interface
**Requirement**: Define a standard interface that all condensation providers must implement

**Specification**:
```typescript
interface ICondensationProvider {
  // Identification
  readonly id: string
  readonly name: string
  readonly description: string
  readonly version: string
  
  // Capabilities
  getCapabilities(): ProviderCapabilities
  
  // Configuration
  getConfigSchema(): ConfigSchema
  validateConfig(config: any): ValidationResult
  
  // UI Integration
  getConfigComponent?(): ConfigComponentDescriptor
  
  // Core functionality
  condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult>
  
  estimateReduction(
    context: ConversationContext,
    config?: any
  ): Promise<TokenEstimate>
  
  // Dynamic cost estimation based on configuration
  estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number>
}

interface ProviderCapabilities {
  supportsLossless: boolean
  supportsBatchMode: boolean
  supportsIndividualMode: boolean
  supportsMultiPass: boolean
  supportsLLMSummarization: boolean
  estimatedSpeed: 'fast' | 'medium' | 'slow'
  // Cost is now computed dynamically
}
```

**Acceptance Criteria**:
- [ ] Interface defined in TypeScript
- [ ] All methods documented with JSDoc
- [ ] Return types fully specified
- [ ] Error handling patterns defined
- [ ] Dynamic cost estimation implemented

#### FR-PA-002: Provider Manager
**Requirement**: Implement a manager to orchestrate providers and handle configuration

**Specification**:
```typescript
class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider>
  private activeProviderId: string
  
  registerProvider(provider: ICondensationProvider): void
  getProvider(id: string): ICondensationProvider | null
  listProviders(): ProviderInfo[]
  setActiveProvider(id: string): void
  getActiveProvider(): ICondensationProvider
  
  // Configuration management
  getEffectiveConfig(profileId: string): CondensationConfig
  setProfileThreshold(profileId: string, threshold: number): void
  
  // Orchestration
  shouldCondense(
    tokens: number,
    contextWindow: number,
    config: CondensationConfig
  ): boolean
  
  async condenseIfNeeded(
    messages: ApiMessage[],
    config: CondensationConfig
  ): Promise<CondensationResult>
}
```

**Acceptance Criteria**:
- [ ] Manager handles provider registration
- [ ] Manager determines when to condense
- [ ] Manager orchestrates condensation execution
- [ ] Manager handles fallback strategies
- [ ] Manager manages profile configurations

#### FR-PA-003: Native Provider
**Requirement**: Implement wrapper for current condensation logic as `NativeCondensationProvider`

**Specification**:
- Wraps existing `summarizeConversation()` function
- Maintains exact current behavior for backward compatibility
- Default provider when no selection made
- Handles API profile selection for cost optimization
- Supports custom prompts
- Zero regression in existing functionality

**Acceptance Criteria**:
- [ ] All existing tests pass without modification
- [ ] Behavior identical to current implementation
- [ ] Configuration mapping preserved
- [ ] Telemetry events unchanged
- [ ] Profile-aware API handler selection
- [ ] Custom prompt support

#### FR-PA-004: Provider Selection
**Requirement**: Allow users to select condensation provider via settings

**Specification**:
- Dropdown in settings UI
- Providers: "Native", "Lossless", "Truncation", "Smart"
- Per-workspace or global setting
- Runtime provider switching supported
- Provider-specific configuration UI

**Acceptance Criteria**:
- [ ] Setting persisted correctly
- [ ] UI reflects current selection
- [ ] Provider switch takes effect immediately
- [ ] Migration path from old settings
- [ ] Provider-specific config displayed

### 3.2 API Profiles and Configuration

#### FR-PR-001: API Profile System
**Requirement**: Support multiple API profiles for different purposes (conversation vs condensation)

**Specification**:
Based on analysis in 007-native-system-deep-dive.md:

```typescript
interface ApiProfileConfig {
  // Profile identification
  profileId: string
  profileName: string
  
  // API configuration
  provider: 'anthropic' | 'openai' | 'bedrock' | 'vertex' | 'openrouter'
  model: string
  
  // Cost information
  inputPrice: number      // per 1M tokens
  outputPrice: number     // per 1M tokens
  cacheWritesPrice?: number
  cacheReadsPrice?: number
  
  // Capabilities
  supportsPromptCache: boolean
  contextWindow: number
  maxOutputTokens: number
}

interface CondensationProfileConfig {
  // Global settings
  autoCondenseContext: boolean
  autoCondenseContextPercent: number  // Global threshold
  
  // Profile-specific settings
  condensingApiConfigId?: string      // ID of profile for condensation
  customCondensingPrompt?: string     // Custom prompt (optional)
  profileThresholds: Record<string, number>  // Per-profile thresholds
}
```

**Acceptance Criteria**:
- [ ] Multiple API profiles supported
- [ ] Separate profile for condensation operations
- [ ] Profile selection persisted
- [ ] Fallback to conversation profile if condensing profile unavailable
- [ ] Profile validation and error handling

#### FR-PR-002: Profile-Aware API Handler Selection
**Requirement**: Automatically select appropriate API handler based on configuration

**Specification**:
From 007 analysis (lines 136-159):

1. **Priority order**:
   - Use `condensingApiHandler` if specified and valid
   - Fall back to `apiHandler` (conversation handler)
   - Validate handler has required methods

2. **Selection logic**:
```typescript
selectApiHandler(config: CondensationConfig): ApiHandler {
  // Priority 1: Specific condensing handler
  if (config.condensingApiConfigId) {
    const handler = getHandlerForProfile(config.condensingApiConfigId)
    if (handler && validateHandler(handler)) {
      return handler
    }
  }
  
  // Priority 2: Conversation handler (fallback)
  const conversationHandler = config.apiHandler
  if (validateHandler(conversationHandler)) {
    return conversationHandler
  }
  
  throw new Error('No valid API handler available')
}
```

**Acceptance Criteria**:
- [ ] Handler selection follows priority order
- [ ] Handler validation prevents errors
- [ ] Clear error messages on handler issues
- [ ] Fallback chain works correctly
- [ ] Telemetry tracks handler selection

#### FR-PR-003: Custom Condensation Prompts
**Requirement**: Support user-defined prompts for condensation

**Specification**:
- Global custom prompt setting
- Profile-specific custom prompts
- Fallback to default system prompt
- Prompt validation for length and content

**Acceptance Criteria**:
- [ ] Custom prompts stored and retrieved
- [ ] Prompts applied correctly during condensation
- [ ] Validation prevents invalid prompts
- [ ] UI for prompt editing
- [ ] Preview of prompt before use

### 3.3 Dynamic Thresholds

#### FR-TH-001: Per-Profile Threshold Configuration
**Requirement**: Allow different condensation thresholds per API profile

**Specification**:
From 007 analysis (lines 126-142):

```typescript
interface ProfileThresholds {
  [profileId: string]: number  // -1 = inherit global, or 5-100 = custom %
}

// Threshold determination logic
function getEffectiveThreshold(
  profileId: string,
  globalThreshold: number,
  profileThresholds: ProfileThresholds
): number {
  const profileThreshold = profileThresholds[profileId]
  
  if (profileThreshold === undefined) {
    // No override → use global
    return globalThreshold
  }
  
  if (profileThreshold === -1) {
    // Explicit inherit → use global
    return globalThreshold
  }
  
  if (profileThreshold >= MIN_CONDENSE_THRESHOLD && 
      profileThreshold <= MAX_CONDENSE_THRESHOLD) {
    // Valid custom threshold
    return profileThreshold
  }
  
  // Invalid → warn and use global
  console.warn(`Invalid threshold ${profileThreshold}, using global`)
  return globalThreshold
}
```

**Acceptance Criteria**:
- [ ] Per-profile thresholds stored
- [ ] Threshold validation (5-100%)
- [ ] -1 value for explicit inheritance
- [ ] Global threshold as fallback
- [ ] UI for threshold configuration
- [ ] Clear indication of effective threshold

#### FR-TH-002: Threshold Constants
**Requirement**: Define system-wide threshold constants

**Specification**:
From 007 analysis:

```typescript
export const MIN_CONDENSE_THRESHOLD = 5    // 5% minimum
export const MAX_CONDENSE_THRESHOLD = 100  // 100% maximum
export const TOKEN_BUFFER_PERCENTAGE = 0.1 // 10% safety buffer
```

**Acceptance Criteria**:
- [ ] Constants defined and exported
- [ ] Validation uses constants
- [ ] UI respects min/max values
- [ ] Buffer applied in calculations

#### FR-TH-003: Trigger Decision Logic
**Requirement**: Determine when to trigger condensation based on thresholds

**Specification**:
From 007 analysis (lines 109-123):

```typescript
function shouldCondense(
  messages: ApiMessage[],
  config: CondensationConfig
): boolean {
  const effectiveThreshold = getEffectiveThreshold(
    config.currentProfileId,
    config.globalThreshold,
    config.profileThresholds
  )
  
  const reservedTokens = config.maxTokens || DEFAULT_MAX_TOKENS
  const lastMessageTokens = estimateLastMessageTokens(messages)
  const prevContextTokens = config.totalTokens + lastMessageTokens
  const allowedTokens = config.contextWindow * (1 - TOKEN_BUFFER_PERCENTAGE) 
                       - reservedTokens
  
  const contextPercent = (100 * prevContextTokens) / config.contextWindow
  
  // Trigger if percentage ≥ threshold OR absolute tokens > allowed
  return contextPercent >= effectiveThreshold || 
         prevContextTokens > allowedTokens
}
```

**Acceptance Criteria**:
- [ ] Percentage-based trigger implemented
- [ ] Absolute token-based trigger implemented
- [ ] Safety buffer applied
- [ ] Reserved tokens accounted for
- [ ] Last message tokens included

### 3.4 Cost Estimation

#### FR-CO-001: Dynamic Cost Calculation
**Requirement**: Calculate costs dynamically based on provider, model, and caching

**Specification**:
From 007 analysis (cost.ts):

```typescript
// Internal calculation shared by all providers
function calculateApiCostInternal(
  modelInfo: ModelInfo,
  inputTokens: number,
  outputTokens: number,
  cacheCreationInputTokens: number,
  cacheReadInputTokens: number,
): number {
  const cacheWritesCost = ((modelInfo.cacheWritesPrice || 0) / 1_000_000) 
                        * cacheCreationInputTokens
  const cacheReadsCost = ((modelInfo.cacheReadsPrice || 0) / 1_000_000) 
                       * cacheReadInputTokens
  const baseInputCost = ((modelInfo.inputPrice || 0) / 1_000_000) 
                      * inputTokens
  const outputCost = ((modelInfo.outputPrice || 0) / 1_000_000) 
                   * outputTokens
  
  return cacheWritesCost + cacheReadsCost + baseInputCost + outputCost
}
```

**Acceptance Criteria**:
- [ ] Cost calculation for all providers
- [ ] Cache writes/reads accounted for
- [ ] Provider-specific token accounting (Anthropic vs OpenAI)
- [ ] Cost displayed to user
- [ ] Cost tracking in telemetry

#### FR-CO-002: Provider-Specific Token Accounting
**Requirement**: Handle different token accounting between Anthropic and OpenAI

**Specification**:
From 007 analysis:

**Anthropic**: `inputTokens` does NOT include cached tokens
```typescript
function calculateApiCostAnthropic(
  modelInfo: ModelInfo,
  inputTokens: number,              // Non-cached only
  outputTokens: number,
  cacheCreationInputTokens?: number,
  cacheReadInputTokens?: number,
): number {
  return calculateApiCostInternal(
    modelInfo,
    inputTokens,                     // Use as-is
    outputTokens,
    cacheCreationInputTokens || 0,
    cacheReadInputTokens || 0,
  )
}
```

**OpenAI**: `inputTokens` INCLUDES cached tokens
```typescript
function calculateApiCostOpenAI(
  modelInfo: ModelInfo,
  inputTokens: number,               // Total including cache
  outputTokens: number,
  cacheCreationInputTokens?: number,
  cacheReadInputTokens?: number,
): number {
  const cacheTotal = (cacheCreationInputTokens || 0) + (cacheReadInputTokens || 0)
  const nonCachedInputTokens = Math.max(0, inputTokens - cacheTotal)
  
  return calculateApiCostInternal(
    modelInfo,
    nonCachedInputTokens,            // Recalculated
    outputTokens,
    cacheCreationInputTokens || 0,
    cacheReadInputTokens || 0,
  )
}
```

**Acceptance Criteria**:
- [ ] Anthropic token accounting correct
- [ ] OpenAI token accounting correct
- [ ] Other providers handled appropriately
- [ ] Cost accuracy validated
- [ ] Documentation of differences

#### FR-CO-003: Cost Optimization via Profiles
**Requirement**: Enable significant cost reduction through profile selection

**Specification**:
Example cost comparison:

| Scenario | Handler | Model | Typical Cost |
|----------|---------|-------|--------------|
| No optimization | Main | Claude Sonnet 4 | $0.015-0.030 |
| With optimization | Condensing | GPT-4o-mini | $0.001-0.003 |
| **Savings** | - | - | **90%+** |

**Acceptance Criteria**:
- [ ] Cost displayed for selected profile
- [ ] Cost comparison shown in UI
- [ ] Savings calculated and displayed
- [ ] Profile recommendation based on cost
- [ ] Cost tracking per condensation operation

#### FR-CO-004: Cost Estimation Before Execution
**Requirement**: Estimate condensation cost before execution

**Specification**:
```typescript
interface ICondensationProvider {
  estimateCost(
    context: ConversationContext,
    config?: any
  ): Promise<number>
}

// Implementation considers:
// - Input token count
// - Estimated output tokens (from history or heuristics)
// - Selected API profile pricing
// - Number of LLM calls (for multi-pass strategies)
// - Caching potential
```

**Acceptance Criteria**:
- [ ] Estimation within 20% of actual cost
- [ ] Fast estimation (<100ms)
- [ ] Displayed before user confirmation
- [ ] Updated when configuration changes
- [ ] Includes all LLM operations

### 3.5 Lossless Condensation Provider

#### FR-LC-001: File Read Deduplication
**Requirement**: Detect and deduplicate repeated file read operations

**Specification**:
```typescript
Detection:
- Identify tool_result messages from read_file tool
- Extract file path from tool call parameters
- Compare content hashes

Deduplication:
- Keep first occurrence with full content
- Replace subsequent reads with reference
- Format: "⟨ File content already provided above ⟩"
- Preserve metadata (line numbers, excerpts if different)

Token Savings:
- Typical file: 500-2000 tokens
- Typical read count: 2-4 times
- Expected savings: 1000-6000 tokens per file
```

**Acceptance Criteria**:
- [ ] Detects repeated exact file reads
- [ ] Creates reference to first occurrence
- [ ] Preserves line number differences
- [ ] Handles partial file reads (excerpts)
- [ ] Maintains traceability

#### FR-LC-002: Tool Result Consolidation
**Requirement**: Consolidate similar or redundant tool results

**Specification**:
```typescript
Consolidation Rules:
1. List operations: Merge if same directory, combine entries
2. Search operations: Merge if same pattern, combine results
3. Execute command: Keep latest output if multiple runs
4. Multiple small similar results: Group and summarize count

Format:
"⟨ Consolidated N operations: <summary> ⟩"

Preservation:
- Always keep different results
- Always keep error results separate
- Preserve chronological order in summary
```

**Acceptance Criteria**:
- [ ] Identifies consolidatable results
- [ ] Preserves semantic differences
- [ ] Clear indication of consolidation
- [ ] Reversible if needed (metadata preserved)

#### FR-LC-003: Reference System
**Requirement**: Implement pointer system for repeated content

**Specification**:
```typescript
interface ContentReference {
  type: 'file' | 'tool_result' | 'output'
  originalIndex: number    // Message index of original
  path?: string           // For file references
  operation?: string      // For tool references
  hash: string           // Content hash for verification
}

Format in messages:
"⟨ Reference: See message #{index} for {description} ⟩"
```

**Acceptance Criteria**:
- [ ] References created correctly
- [ ] Original content identifiable
- [ ] Hash validation works
- [ ] UI can optionally expand references

#### FR-LC-004: Lossless Provider Implementation
**Requirement**: Complete Lossless Provider with all optimizations

**Specification**:
```typescript
class LosslessCondensationProvider implements ICondensationProvider {
  readonly id = 'lossless'
  
  async condense(context, options): Promise<CondensationResult> {
    let messages = [...context.messages]
    const operations: string[] = []
    
    // Step 1: Deduplicate file reads
    if (config.deduplicateFileReads) {
      messages = await this.deduplicateFileReads(messages)
      operations.push('file_deduplication')
    }
    
    // Step 2: Consolidate tool results
    if (config.consolidateToolResults) {
      messages = await this.consolidateToolResults(messages)
      operations.push('result_consolidation')
    }
    
    // Step 3: Remove obsolete state
    if (config.removeObsoleteState) {
      messages = await this.removeObsoleteState(messages)
      operations.push('state_cleanup')
    }
    
    return {
      messages,
      stats: { /* token reduction metrics */ }
    }
  }
}
```

**Acceptance Criteria**:
- [ ] All optimizations implemented
- [ ] 30-50% token reduction achieved
- [ ] Zero information loss
- [ ] Fast execution (<1s)
- [ ] No API calls

### 3.6 Truncation Provider

#### FR-TR-001: Mechanical Truncation Strategy
**Requirement**: Implement fast, deterministic truncation

**Specification**:
```typescript
class TruncationCondensationProvider implements ICondensationProvider {
  readonly id = 'truncation'
  
  config: {
    preserveRecentCount: number      // Recent messages to keep
    truncationMode: 'suppress' | 'truncate'
    maxToolResultLines: number       // For truncate mode
    maxToolParamChars: number
    preserveUserMessages: boolean    // Always keep user input
    preserveAssistantText: boolean   // Always keep assistant text
  }
  
  async condense(context, options): Promise<CondensationResult> {
    const { first, recent, oldZone } = this.selectZones(context.messages)
    
    const processed = oldZone.map(msg => {
      if (shouldPreserve(msg)) return msg
      if (hasToolResult(msg)) return this.processToolResult(msg)
      if (hasToolUse(msg)) return this.processToolParams(msg)
      return msg
    })
    
    return {
      messages: [first, ...processed, ...recent],
      stats: { /* reduction metrics */ }
    }
  }
}
```

**Acceptance Criteria**:
- [ ] Fast execution (<100ms)
- [ ] Deterministic results
- [ ] User/assistant text preserved
- [ ] Configurable truncation thresholds
- [ ] No API calls

#### FR-TR-002: Suppression vs Truncation Modes
**Requirement**: Support both suppression and truncation of content

**Specification**:
- **Suppress mode**: Replace with marker `⟨ Content suppressed ⟩`
- **Truncate mode**: Keep first N lines/chars + `⟨ ... truncated ⟩`
- User configures per content type
- Clear visual indication of action taken

**Acceptance Criteria**:
- [ ] Suppress mode implemented
- [ ] Truncate mode implemented
- [ ] Mode configurable per content type
- [ ] Visual markers clear
- [ ] Token savings measured

### 3.7 Smart Provider - Pass-Based Architecture

#### FR-SM-001: Three-Level Content Model
**Requirement**: Decompose messages into three content types

**Specification**:
From 008 refined architecture:

```typescript
interface DecomposedMessage {
  messageText: string | null      // User/assistant natural language
  toolParameters: any[] | null    // Tool call inputs
  toolResults: any[] | null       // Tool execution outputs
}

// Every message can contain 0-3 of these content types
// Each type can be processed independently with different operations
```

**Acceptance Criteria**:
- [ ] Decomposition correctly extracts all content types
- [ ] Handles mixed content blocks
- [ ] Preserves original structure information
- [ ] Recomposition reconstructs valid messages

#### FR-SM-002: Four Operations
**Requirement**: Support four operations per content type

**Specification**:
```typescript
type ContentOperation = 'keep' | 'suppress' | 'truncate' | 'summarize'

interface ContentOperationConfig {
  operation: ContentOperation
  params?: OperationParams
}

interface OperationParams {
  truncate?: {
    maxChars?: number
    maxLines?: number
    addEllipsis?: boolean
  }
  summarize?: {
    apiProfile?: string
    maxTokens?: number
    customPrompt?: string
  }
}
```

Operations:
- **KEEP**: Preserve unchanged (0% reduction)
- **SUPPRESS**: Remove entirely (100% reduction)
- **TRUNCATE**: Mechanical reduction (80-95% reduction)
- **SUMMARIZE**: LLM-based semantic reduction (40-90% reduction)

**Acceptance Criteria**:
- [ ] All four operations implemented
- [ ] Operation selection per content type
- [ ] Parameters validated
- [ ] Token savings measured per operation

#### FR-SM-003: Pass-Based Configuration
**Requirement**: Configure condensation as sequence of passes

**Specification**:
From 008 architecture:

```typescript
interface SmartProviderConfig {
  losslessPrelude?: {
    enabled: boolean
    operations: {
      deduplicateFileReads: boolean
      consolidateToolResults: boolean
      removeObsoleteState: boolean
    }
  }
  
  passes: PassConfig[]
}

interface PassConfig {
  id: string
  name: string
  description?: string
  selection: SelectionStrategy
  mode: 'batch' | 'individual'
  batchConfig?: BatchModeConfig
  individualConfig?: IndividualModeConfig
  execution: ExecutionCondition
}

interface SelectionStrategy {
  type: 'preserve_recent' | 'preserve_percent' | 'custom'
  keepRecentCount?: number
  keepPercentage?: number
}

interface ExecutionCondition {
  type: 'always' | 'conditional'
  condition?: {
    tokenThreshold: number
  }
}
```

**Acceptance Criteria**:
- [ ] Multiple passes can be configured
- [ ] Passes execute sequentially
- [ ] Each pass has clear purpose
- [ ] Execution conditions work
- [ ] Early exit when target reached

#### FR-SM-004: Batch Mode
**Requirement**: Support batch processing like Native Provider

**Specification**:
```typescript
interface BatchModeConfig {
  operation: 'keep' | 'summarize'
  summarizationConfig?: {
    apiProfile?: string
    customPrompt?: string
    keepFirst: number
    keepLast: number
  }
}

// Batch mode:
// - Processes selected messages as single block
// - Uses LLM for summarization (like native)
// - Keeps first N and last N messages
// - Summarizes middle section
```

**Acceptance Criteria**:
- [ ] Batch summarization works like native
- [ ] keepFirst/keepLast respected
- [ ] API profile selection works
- [ ] Custom prompts supported
- [ ] Single summary message created

#### FR-SM-005: Individual Mode
**Requirement**: Process each message independently

**Specification**:
```typescript
interface IndividualModeConfig {
  defaults: ContentTypeOperations
  overrides?: {
    messageIndex: number
    operations: Partial<ContentTypeOperations>
  }[]
}

interface ContentTypeOperations {
  messageText: ContentOperation
  toolParameters: ContentOperation
  toolResults: ContentOperation
}

// Individual mode:
// - Each message processed separately
// - Different operation per content type
// - Per-message overrides possible
// - Parallel processing when possible
```

**Acceptance Criteria**:
- [ ] Per-message processing implemented
- [ ] Content type operations applied correctly
- [ ] Overrides work
- [ ] Parallel processing where safe
- [ ] Messages remain in order

#### FR-SM-006: Execution Conditions
**Requirement**: Support always and conditional pass execution

**Specification**:
- **Always**: Execute every time (systematic multi-pass refinement)
- **Conditional**: Execute only if `currentTokens > threshold` (fallback pattern)

```typescript
// Always execution: Progressive refinement
passes: [
  { /* Pass 1: Truncate old results */, execution: { type: 'always' } },
  { /* Pass 2: Suppress very old */, execution: { type: 'always' } },
  { /* Pass 3: Summarize if needed */, execution: { type: 'conditional', condition: { tokenThreshold: 40000 } } }
]

// Execution flow:
// 1. Execute all 'always' passes sequentially
// 2. After each pass, check if target reached
// 3. Execute 'conditional' passes only if threshold exceeded
// 4. Stop when target reached or all passes done
```

**Acceptance Criteria**:
- [ ] Always passes execute sequentially
- [ ] Conditional passes check threshold
- [ ] Early exit when target reached
- [ ] Execution order maintained
- [ ] Condition evaluation correct

#### FR-SM-007: Message Decomposition and Recomposition
**Requirement**: Safely decompose and recompose messages

**Specification**:
```typescript
class SmartCondensationProvider {
  private decomposeMessage(msg: ApiMessage): DecomposedMessage {
    // Extract text blocks, tool_use blocks, tool_result blocks
    // Handle both string content and block arrays
    // Preserve all metadata
  }
  
  private recomposeMessage(
    original: ApiMessage,
    messageText: string | null,
    toolParameters: any[] | null,
    toolResults: any[] | null
  ): ApiMessage {
    // Reconstruct content array or string
    // Maintain original message structure
    // Preserve metadata (role, etc.)
  }
}
```

**Acceptance Criteria**:
- [ ] Decomposition extracts all content
- [ ] Recomposition creates valid messages
- [ ] Metadata preserved
- [ ] Edge cases handled (empty blocks, etc.)
- [ ] Round-trip produces equivalent message

#### FR-SM-008: Smart Provider Implementation
**Requirement**: Complete Smart Provider with pass execution engine

**Specification**:
```typescript
class SmartCondensationProvider implements ICondensationProvider {
  async condense(context, options): Promise<CondensationResult> {
    let messages = [...context.messages]
    const operations: string[] = []
    let totalCost = 0
    
    // Step 1: Optional lossless prelude
    if (config.losslessPrelude?.enabled) {
      const result = await this.runLosslessPrelude(messages)
      messages = result.messages
      operations.push(...result.operations)
      if (await this.reachedTarget(messages, options)) return result
    }
    
    // Step 2: Execute passes sequentially
    for (const pass of config.passes) {
      if (!await this.shouldExecutePass(pass, messages, options)) {
        operations.push(`skip_${pass.id}`)
        continue
      }
      
      const result = await this.executePass(pass, messages, options)
      messages = result.messages
      operations.push(`${pass.id}_completed`)
      totalCost += result.cost
      
      if (await this.reachedTarget(messages, options)) break
    }
    
    return this.buildResult(messages, operations, context.tokenCount, totalCost)
  }
  
  private async executePass(pass, messages, options) {
    if (pass.mode === 'batch') {
      return this.executeBatchPass(pass, messages, options)
    } else {
      return this.executeIndividualPass(pass, messages, options)
    }
  }
  
  private async executeIndividualPass(pass, messages, options) {
    const selected = this.selectMessages(messages, pass.selection)
    const processed = await Promise.all(
      selected.map(msg => this.processMessage(msg, pass.individualConfig, options))
    )
    return { messages: processed, cost: /* sum */ }
  }
  
  private async processMessage(msg, config, options) {
    const decomposed = this.decomposeMessage(msg)
    
    const processedText = await this.processContent(
      decomposed.messageText,
      config.defaults.messageText,
      options
    )
    
    const processedParams = await this.processContent(
      decomposed.toolParameters,
      config.defaults.toolParameters,
      options
    )
    
    const processedResults = await this.processContent(
      decomposed.toolResults,
      config.defaults.toolResults,
      options
    )
    
    return this.recomposeMessage(
      msg,
      processedText.content,
      processedParams.content,
      processedResults.content
    )
  }
}
```

**Acceptance Criteria**:
- [ ] Pass execution engine complete
- [ ] Batch and individual modes work
- [ ] Message processing correct
- [ ] Cost tracking accurate
- [ ] Early exit optimized

### 3.8 Configuration and Settings

#### FR-CS-001: Provider Selection Setting
**Requirement**: UI for selecting condensation provider

**Specification**:
```typescript
interface CondensationSettings {
  provider: 'native' | 'lossless' | 'truncation' | 'smart'
  
  // Global settings (apply to all)
  autoCondenseContext: boolean
  autoCondenseContextPercent: number
  profileThresholds: Record<string, number>
  
  // Provider-specific configurations
  nativeConfig?: NativeProviderConfig
  losslessConfig?: LosslessProviderConfig
  truncationConfig?: TruncationProviderConfig
  smartConfig?: SmartProviderConfig
}
```

**Acceptance Criteria**:
- [ ] Dropdown for provider selection
- [ ] Provider descriptions clear
- [ ] Default is 'native'
- [ ] Configuration saved per provider
- [ ] Migration from old settings

#### FR-CS-002: Smart Provider Configuration UI
**Requirement**: Rich UI for configuring Smart Provider passes

**Specification**:
From 008 architecture:

```typescript
// Pass ListView with:
// - List of passes (drag & drop reordering)
// - Add/delete pass buttons
// - Select pass to edit details
// - Pass summary badges (mode, execution condition)

// Pass Editor with:
// - Basic info (name, description)
// - Selection strategy (preserve recent, percentage, custom)
// - Processing mode (batch vs individual)
// - Mode-specific configuration
// - Execution condition (always vs conditional)

// Content Type Operation Editor with:
// - Operation selection (keep, suppress, truncate, summarize)
// - Operation-specific parameters
// - Visual preview of effect
```

**Acceptance Criteria**:
- [ ] ListView with drag & drop
- [ ] Pass editor with all options
- [ ] Content type operation editor
- [ ] Configuration validation
- [ ] Preview before applying

#### FR-CS-003: Configuration Presets
**Requirement**: Provide pre-configured strategies for common use cases

**Specification**:
```typescript
Presets:
1. Speed Optimized: Fast truncation, no LLM calls
2. Quality Optimized: LLM summarization, best preservation
3. Cost Optimized: Mechanical first, cheap LLM fallback
4. Balanced: Mix of strategies
5. Custom: User-defined

// Preset application:
// - One-click to apply preset
// - Can customize after applying
// - Save custom as new preset
```

**Acceptance Criteria**:
- [ ] At least 4 presets provided
- [ ] Presets well-documented
- [ ] Easy to apply preset
- [ ] Custom presets saveable
- [ ] Import/export presets

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-P-001: Condensation Latency
**Requirement**: Total condensation time should not significantly increase

**Specification**:
- Lossless phase: <1 second
- Truncation: <100ms
- Native/batch LLM: 2-5 seconds (LLM-dependent)
- Smart individual mode: varies by operations (0-10 seconds)
- Total overhead: <20% increase vs current

**Acceptance Criteria**:
- [ ] Lossless benchmarked <1s
- [ ] Truncation benchmarked <100ms
- [ ] Performance tests for all providers
- [ ] No blocking UI operations

#### NFR-P-002: Token Counting Performance
**Requirement**: Token counting must be efficient

**Specification**:
- O(n) complexity maintained
- Caching for repeated counts
- Batch counting where possible
- No memory leaks

**Acceptance Criteria**:
- [ ] Complexity analysis done
- [ ] Caching implemented
- [ ] Memory profiling clean
- [ ] Large context tests pass

#### NFR-P-003: Memory Usage
**Requirement**: Memory usage must remain bounded

**Specification**:
- No more than 2x message size in memory
- Reference system lightweight
- Cleanup after condensation
- No memory leaks

**Acceptance Criteria**:
- [ ] Memory profiling done
- [ ] Peak usage measured
- [ ] Cleanup verified
- [ ] Leak tests pass

### 4.2 Reliability Requirements

#### NFR-R-001: Backward Compatibility
**Requirement**: Existing functionality must not break

**Specification**:
- Native provider 100% compatible
- All existing tests pass
- Configuration migration automatic
- No breaking API changes

**Acceptance Criteria**:
- [ ] All existing tests pass
- [ ] Regression suite complete
- [ ] Migration tested
- [ ] API unchanged

#### NFR-R-002: Graceful Degradation
**Requirement**: System must handle failures gracefully

**Specification**:
```typescript
Failure Scenarios:
1. Lossless phase fails → Skip to next pass
2. Pass execution fails → Skip to fallback pass
3. Provider errors → Fall back to native
4. Configuration errors → Use defaults
5. API handler unavailable → Use conversation handler

User Communication:
- Clear error messages
- Explanation of fallback
- No data loss
- Retry option where appropriate
```

**Acceptance Criteria**:
- [ ] All failure paths tested
- [ ] Fallback behavior correct
- [ ] Error messages clear
- [ ] No data loss scenarios

#### NFR-R-003: Validation and Verification
**Requirement**: Condensation results must be validated

**Specification**:
```typescript
Validation Checks:
1. Token count reduced (not increased)
2. No message loss (references valid)
3. Semantic coherence maintained
4. Format correctness
5. Message structure valid

Verification:
- Pre/post token comparison
- Reference integrity check
- Conversation flow check
- Format validation
- Cost calculation accuracy
```

**Acceptance Criteria**:
- [ ] All checks implemented
- [ ] Validation catches errors
- [ ] Rollback on failure
- [ ] Metrics logged

### 4.3 Usability Requirements

#### NFR-U-001: Clear Documentation
**Requirement**: Users must understand provider options

**Specification**:
- In-UI help text
- Settings descriptions
- Strategy comparison table
- Examples of each approach
- Video tutorials (future)

**Acceptance Criteria**:
- [ ] Help text written
- [ ] Examples documented
- [ ] Comparison table provided
- [ ] User testing positive

#### NFR-U-002: Visual Feedback
**Requirement**: Users must see what happened during condensation

**Specification**:
```typescript
Feedback Elements:
- Provider used
- Passes executed
- Token reduction metrics
- Cost information
- Time elapsed
- Operations performed

Format:
"Context condensed using Smart strategy:
 - Lossless prelude: 8,500 → 5,200 tokens (-39%)
 - Pass 1 (Truncate): 5,200 → 3,800 tokens (-27%)
 - Pass 2 (Suppress): 3,800 → 2,800 tokens (-26%)
 - Total reduction: 67% (saved $0.0036)
 - Time: 1.8 seconds"
```

**Acceptance Criteria**:
- [ ] All metrics displayed
- [ ] Format clear and readable
- [ ] Cost calculated correctly
- [ ] User feedback positive

#### NFR-U-003: Settings Discoverability
**Requirement**: Users must easily find and understand settings

**Specification**:
- Settings in logical location
- Grouped by provider
- Progressive disclosure (advanced collapsed)
- Tooltips for complex options
- Search functionality

**Acceptance Criteria**:
- [ ] Settings location intuitive
- [ ] Grouping logical
- [ ] Tooltips helpful
- [ ] User testing successful

### 4.4 Maintainability Requirements

#### NFR-M-001: Code Organization
**Requirement**: Code must be well-organized and documented

**Specification**:
```typescript
Directory Structure:
src/core/condense/
  ├── index.ts (exports)
  ├── types.ts (interfaces)
  ├── manager.ts (CondensationProviderManager)
  ├── providers/
  │   ├── base.ts (interface)
  │   ├── native.ts
  │   ├── lossless.ts
  │   ├── truncation.ts
  │   └── smart/
  │       ├── index.ts
  │       ├── pass-executor.ts
  │       ├── message-processor.ts
  │       └── operations.ts
  ├── lossless/
  │   ├── deduplication.ts
  │   ├── consolidation.ts
  │   └── references.ts
  └── __tests__/
```

**Acceptance Criteria**:
- [ ] Structure implemented
- [ ] Files organized logically
- [ ] Imports clean
- [ ] Tests co-located

#### NFR-M-002: Testing Coverage
**Requirement**: Comprehensive test coverage

**Specification**:
```typescript
Test Categories:
1. Unit tests: Each function/class (>90% coverage)
2. Integration tests: Provider workflows
3. Regression tests: Current behavior preserved
4. Performance tests: Benchmarking
5. Edge case tests: Boundary conditions
6. Pass configuration tests: All pass types
7. Cost calculation tests: All providers

Coverage Target: >90%
```

**Acceptance Criteria**:
- [ ] Unit tests complete
- [ ] Integration tests pass
- [ ] Regression suite complete
- [ ] Coverage target met

#### NFR-M-003: Documentation
**Requirement**: Comprehensive code and user documentation

**Specification**:
```typescript
Documentation:
1. JSDoc for all public APIs
2. README for each provider
3. Architecture decision records
4. User guide in docs
5. Migration guide
6. Pass configuration examples
7. Cost optimization guide

Maintenance:
- Update with code changes
- Examples kept current
- Version documentation
```

**Acceptance Criteria**:
- [ ] JSDoc complete
- [ ] READMEs written
- [ ] Architecture documented
- [ ] User guide complete

## 5. Constraints and Assumptions

### 5.1 Technical Constraints

**TC-1**: Must use TypeScript with full type safety

**TC-2**: Must integrate with existing API handler system

**TC-3**: Must work with all supported LLM providers (Anthropic, OpenAI, Bedrock, Vertex, OpenRouter)

**TC-4**: Must support existing message format

**TC-5**: Must be performant for large contexts (100K+ tokens)

### 5.2 Business Constraints

**BC-1**: Backward compatibility required - no breaking changes

**BC-2**: Cost-effective - optimize for lower API costs

**BC-3**: Timeline: ~8-10 weeks for full implementation
- Phase 1 (Foundation + Native): 2 weeks
- Phase 2 (Lossless + Truncation): 2 weeks
- Phase 3 (Smart Provider): 3 weeks
- Phase 4 (UI + Testing): 2 weeks
- Phase 5 (Polish + Docs): 1 week

### 5.3 Assumptions

**A-1**: Message structure is consistent across providers

**A-2**: Token counting is accurate and consistent

**A-3**: LLM summarization quality is acceptable baseline

**A-4**: Users will configure settings appropriately

**A-5**: API profiles are correctly configured

## 6. Dependencies

### 6.1 Internal Dependencies

**ID-1**: API Handler System - token counting, message creation, cost tracking

**ID-2**: Settings Management - configuration persistence, profile system, UI integration

**ID-3**: Telemetry System - event tracking, metrics collection, performance monitoring

### 6.2 External Dependencies

**ED-1**: LLM Providers - API availability, response latency, cost structure

**ED-2**: VSCode Extension API - settings persistence, UI components, workspace management

## 7. Acceptance Criteria Summary

### 7.1 Must Have (MVP)

- [ ] Provider architecture implemented
- [ ] CondensationProviderManager functional
- [ ] Native provider wraps existing logic
- [ ] Lossless provider with all optimizations
- [ ] Truncation provider implemented
- [ ] Smart provider with pass-based architecture
- [ ] Three-level content model working
- [ ] Four operations implemented
- [ ] API profile system functional
- [ ] Dynamic threshold configuration
- [ ] Cost estimation accurate
- [ ] Settings UI for all providers
- [ ] All existing tests passing
- [ ] Backward compatibility verified
- [ ] Performance acceptable
- [ ] Documentation complete

### 7.2 Should Have (Nice to Have)

- [ ] Advanced pass orchestration
- [ ] Configuration presets
- [ ] Visual diff of condensation
- [ ] Profile-specific customization
- [ ] Import/export configurations
- [ ] Detailed analytics dashboard
- [ ] Cost optimization recommendations

### 7.3 Could Have (Future)

- [ ] ML-based importance scoring
- [ ] Auto-strategy selection
- [ ] Cross-conversation optimization
- [ ] Real-time condensation
- [ ] Distributed condensation
- [ ] Custom provider plugins
- [ ] A/B testing framework

## 8. Success Criteria

### 8.1 Technical Success

**Metrics**:
1. Token reduction: 30-50% in lossless phase
2. Conversation preservation: >90% of user messages
3. Performance: <20% overhead vs current
4. Reliability: Zero data loss scenarios
5. Compatibility: All existing tests pass
6. Cost accuracy: Within 5% of actual
7. Pass execution: Correct order and conditions

### 8.2 User Success

**Metrics**:
1. User satisfaction: >80% prefer new system
2. Context continuity: Fewer "lost context" reports (-50%)
3. Feature adoption: >30% users try non-native providers
4. Documentation: >4/5 rating for clarity
5. Support tickets: <10% increase related to condensation
6. Cost awareness: Users understand cost implications

### 8.3 Business Success

**Metrics**:
1. Cost reduction: Average 15-25% lower token costs (or 90% with optimized profiles)
2. User retention: No negative impact
3. Performance: No negative UX reports
4. Maintenance: Development time within estimate
5. Quality: <5 critical bugs in first month
6. Adoption: Progressive increase in provider usage

## 9. Risks and Mitigation

### 9.1 Technical Risks

**R-1**: Pass-based system complexity
- Mitigation: Thorough testing, clear documentation
- Mitigation: Start with simple configurations
- Mitigation: Validation prevents invalid configs

**R-2**: Performance degradation with many passes
- Mitigation: Early exit optimization
- Mitigation: Parallel processing where safe
- Mitigation: Performance benchmarking

**R-3**: Cost estimation inaccuracy
- Mitigation: Conservative estimates
- Mitigation: Track actual vs estimated
- Mitigation: Adjust algorithms based on data

### 9.2 User Experience Risks

**R-4**: Configuration complexity overwhelming
- Mitigation: Good defaults
- Mitigation: Presets for common cases
- Mitigation: Progressive disclosure
- Mitigation: Clear help text

**R-5**: Unexpected behavior with custom configs
- Mitigation: Configuration validation
- Mitigation: Preview before execution
- Mitigation: Clear feedback on what happened

### 9.3 Business Risks

**R-6**: Timeline may slip
- Mitigation: Phased delivery
- Mitigation: MVP definition clear
- Mitigation: Regular checkpoints

**R-7**: Low adoption of new providers
- Mitigation: Native as safe default
- Mitigation: Clear benefits communication
- Mitigation: Gradual introduction

## 10. Provider Comparison Matrix

| Feature | Native | Lossless | Truncation | Smart |
|---------|--------|----------|------------|-------|
| **Speed** | Medium (2-5s) | Fast (<1s) | Very Fast (<100ms) | Variable (0-10s) |
| **Token Reduction** | 40-60% | 20-40% | 80-95% | 10-90% |
| **Information Loss** | Medium | None | High | Configurable |
| **API Cost** | $0.001-0.03 | $0 | $0 | $0-0.05 |
| **Configurability** | Low | Low | Medium | Very High |
| **Lossless Phase** | ❌ | ✅ | ❌ | ✅ (optional) |
| **Multi-Pass** | ❌ | ❌ | ❌ | ✅ |
| **Batch Mode** | ✅ | ❌ | ❌ | ✅ |
| **Individual Mode** | ❌ | ❌ | ✅ | ✅ |
| **Profile Support** | ✅ | ✅ | ✅ | ✅ |
| **Best For** | Default/Simple | Quality | Speed | Power Users |

## 11. Next Steps

After requirements approval:

1. **Architecture Implementation** (Week 1-2)
   - Provider interface and manager
   - Native provider extraction
   - Basic UI selector

2. **Simple Providers** (Week 3-4)
   - Lossless provider
   - Truncation provider
   - Testing and validation

3. **Smart Provider Core** (Week 5-7)
   - Pass-based engine
   - Content model
   - Four operations
   - Pass execution

4. **UI and Polish** (Week 8-10)
   - Configuration UI
   - Presets
   - Documentation
   - User testing

---

**Document Version**: 2.0 - Consolidated  
**Next Document**: Implementation begins with provider architecture
**Status**: Ready for Implementation
