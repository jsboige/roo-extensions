# Provider Implementations - Complete Architecture

**Date**: 2025-10-01  
**Version**: 3.0 (Consolidated Architecture)  
**Status**: Final Design

## Executive Summary

This document defines a **modular provider architecture** where multiple concrete condensation providers co-exist, each illustrating different mechanisms. The architecture supports:
- Multiple provider implementations (Native, Lossless, Truncation, Smart)
- Provider-specific UI configuration embedded in webview
- Progressive sophistication while preserving all nuances
- Full backward compatibility

## 1. Provider Architecture Overview

### 1.1 Core Interface

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
    context: ConversationContext
  ): Promise<TokenEstimate>
}

interface ProviderCapabilities {
  supportsLossless: boolean
  supportsLossy: boolean
  supportsLLMSummarization: boolean
  supportsParallelProcessing: boolean
  supportsMultiPass: boolean
  supportsFallback: boolean
  estimatedSpeed: 'fast' | 'medium' | 'slow'
  apiCostPerCall: number
}

interface ConfigComponentDescriptor {
  type: 'react' | 'html'
  component: string  // Component name or HTML
  bindings: ConfigBinding[]
}
```

### 1.2 Provider Manager

```typescript
class CondensationProviderManager {
  private providers: Map<string, ICondensationProvider>
  private activeProviderId: string
  
  registerProvider(provider: ICondensationProvider): void
  getProvider(id: string): ICondensationProvider | null
  listProviders(): ProviderInfo[]
  setActiveProvider(id: string): void
  getActiveProvider(): ICondensationProvider
}
```

## 2. Provider Implementations

### 2.1 Native Provider (Baseline)

**Purpose**: Wrap current system for backward compatibility

```typescript
class NativeCondensationProvider implements ICondensationProvider {
  readonly id = 'native'
  readonly name = 'Native Condensation'
  readonly description = 'Original LLM-based message summarization'
  readonly version = '1.0.0'
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsLossy: true,
      supportsLLMSummarization: true,
      supportsParallelProcessing: false,
      supportsMultiPass: false,
      supportsFallback: false,
      estimatedSpeed: 'medium',
      apiCostPerCall: 0.001  // ~$0.001 per call
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        maxMessagesToKeep: {
          type: 'number',
          default: 10,
          min: 5,
          max: 50,
          description: 'Number of recent messages to preserve'
        }
      }
    }
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    // Delegate to existing summarizeConversation
    const summarized = await summarizeConversation(
      context.messages,
      options.targetTokens,
      context.apiHandler
    )
    
    return {
      messages: summarized,
      stats: {
        originalTokens: context.tokenCount,
        finalTokens: await countTokens(summarized),
        reductionPercent: /* calculate */,
        operationsPerformed: ['llm_summarization']
      }
    }
  }
}
```

### 2.2 Lossless Provider

**Purpose**: Demonstrate pure optimization without information loss

**Core Mechanisms**:
- Deduplication of file reads
- Consolidation of redundant tool results
- Reference-based compression
- No data loss

```typescript
class LosslessCondensationProvider implements ICondensationProvider {
  readonly id = 'lossless'
  readonly name = 'Lossless Optimization'
  readonly description = 'Optimize without losing information'
  readonly version = '1.0.0'
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: true,
      supportsLossy: false,
      supportsLLMSummarization: false,
      supportsParallelProcessing: true,
      supportsMultiPass: false,
      supportsFallback: true,  // Falls back to Native
      estimatedSpeed: 'fast',
      apiCostPerCall: 0
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        deduplicateFileReads: {
          type: 'boolean',
          default: true,
          description: 'Replace duplicate file reads with references'
        },
        consolidateToolResults: {
          type: 'boolean',
          default: true,
          description: 'Merge identical tool results'
        },
        removeObsoleteState: {
          type: 'boolean',
          default: true,
          description: 'Remove intermediate states superseded by later versions'
        }
      }
    }
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    let messages = [...context.messages]
    const operations: string[] = []
    
    // Step 1: Deduplicate file reads
    if (this.config.deduplicateFileReads) {
      const result = await this.deduplicateFileReads(messages)
      messages = result.messages
      operations.push('file_deduplication')
    }
    
    // Step 2: Consolidate tool results
    if (this.config.consolidateToolResults) {
      const result = await this.consolidateToolResults(messages)
      messages = result.messages
      operations.push('result_consolidation')
    }
    
    // Step 3: Remove obsolete state
    if (this.config.removeObsoleteState) {
      const result = await this.removeObsoleteState(messages)
      messages = result.messages
      operations.push('state_cleanup')
    }
    
    return {
      messages,
      stats: {
        originalTokens: context.tokenCount,
        finalTokens: await countTokens(messages),
        reductionPercent: /* calculate */,
        operationsPerformed: operations
      }
    }
  }
  
  private async deduplicateFileReads(
    messages: ApiMessage[]
  ): Promise<{ messages: ApiMessage[] }> {
    const fileReads = new Map<string, number>()  // path -> latest index
    
    // Identify all file reads
    messages.forEach((msg, index) => {
      if (isToolResult(msg, 'read_file')) {
        const path = extractFilePath(msg)
        fileReads.set(path, index)  // Keep track of latest
      }
    })
    
    // Replace older reads with references
    const processed = messages.map((msg, index) => {
      if (isToolResult(msg, 'read_file')) {
        const path = extractFilePath(msg)
        const latestIndex = fileReads.get(path)!
        
        if (index < latestIndex) {
          // This is an older read - replace with reference
          return createFileReference(path, latestIndex, msg)
        }
      }
      return msg
    })
    
    return { messages: processed }
  }
  
  private async consolidateToolResults(
    messages: ApiMessage[]
  ): Promise<{ messages: ApiMessage[] }> {
    // Group identical tool results
    const resultGroups = new Map<string, number[]>()  // hash -> indices
    
    messages.forEach((msg, index) => {
      if (hasToolResult(msg)) {
        const hash = hashToolResult(msg)
        if (!resultGroups.has(hash)) {
          resultGroups.set(hash, [])
        }
        resultGroups.get(hash)!.push(index)
      }
    })
    
    // Keep only first occurrence of each group
    const processed = messages.map((msg, index) => {
      if (hasToolResult(msg)) {
        const hash = hashToolResult(msg)
        const group = resultGroups.get(hash)!
        
        if (group[0] === index) {
          // First occurrence - keep
          return msg
        } else {
          // Duplicate - replace with reference
          return createResultReference(group[0], msg)
        }
      }
      return msg
    })
    
    return { messages: processed }
  }
}
```

### 2.3 Truncation Provider

**Purpose**: Simple mechanical truncation/suppression

**Core Mechanisms**:
- Age-based selection (preserve recent N)
- Suppression of old tool results/params
- Line/character threshold truncation
- Deterministic, fast

```typescript
class TruncationCondensationProvider implements ICondensationProvider {
  readonly id = 'truncation'
  readonly name = 'Mechanical Truncation'
  readonly description = 'Fast suppression/truncation of old content'
  readonly version = '1.0.0'
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: false,
      supportsLossy: true,
      supportsLLMSummarization: false,
      supportsParallelProcessing: false,
      supportsMultiPass: false,
      supportsFallback: false,
      estimatedSpeed: 'fast',
      apiCostPerCall: 0
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        preserveRecentCount: {
          type: 'number',
          default: 5,
          min: 1,
          max: 20,
          description: 'Number of recent messages to keep untouched'
        },
        truncationMode: {
          type: 'string',
          enum: ['suppress', 'truncate'],
          default: 'truncate',
          description: 'Suppress entirely or truncate to summary'
        },
        maxToolResultLines: {
          type: 'number',
          default: 5,
          min: 1,
          max: 50,
          description: 'Max lines to keep from tool results (truncation mode)'
        },
        maxToolParamChars: {
          type: 'number',
          default: 100,
          min: 50,
          max: 500,
          description: 'Max characters for tool parameters'
        },
        preserveUserMessages: {
          type: 'boolean',
          default: true,
          description: 'Always preserve user messages regardless of age'
        },
        preserveAssistantText: {
          type: 'boolean',
          default: true,
          description: 'Always preserve assistant text messages'
        }
      }
    }
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    const messages = context.messages
    const config = this.config
    
    // Zones
    const first = messages[0]
    const recent = messages.slice(-config.preserveRecentCount)
    const oldZone = messages.slice(1, -config.preserveRecentCount)
    
    // Process old zone
    const processed = oldZone.map(msg => {
      // Always preserve user/assistant text
      if (config.preserveUserMessages && msg.role === 'user' && !hasToolResult(msg)) {
        return msg
      }
      if (config.preserveAssistantText && msg.role === 'assistant' && !hasToolUse(msg)) {
        return msg
      }
      
      // Handle tool results
      if (hasToolResult(msg)) {
        if (config.truncationMode === 'suppress') {
          return createSuppressedMarker(msg, 'tool_result')
        } else {
          return this.truncateToolResult(msg, config.maxToolResultLines)
        }
      }
      
      // Handle tool calls
      if (hasToolUse(msg)) {
        return this.truncateToolParams(msg, config.maxToolParamChars)
      }
      
      return msg
    })
    
    return {
      messages: [first, ...processed, ...recent],
      stats: {
        originalTokens: context.tokenCount,
        finalTokens: await countTokens([first, ...processed, ...recent]),
        reductionPercent: /* calculate */,
        operationsPerformed: ['mechanical_truncation']
      }
    }
  }
  
  private truncateToolResult(
    message: ApiMessage,
    maxLines: number
  ): ApiMessage {
    // Implementation from 004-bis document
    // Keep first N lines + add truncation marker
  }
  
  private truncateToolParams(
    message: ApiMessage,
    maxChars: number
  ): ApiMessage {
    // Truncate long parameter values
  }
}
```

### 2.4 Smart Provider (Ultra-Paramétrable)

**Purpose**: Combine all mechanisms with rich configuration

**Core Mechanisms**:
- Lossless optimizations (optional)
- Threshold-based selection
- Configurable truncation/suppression/summarization
- Multi-pass with fallback
- Full parameter control

```typescript
class SmartCondensationProvider implements ICondensationProvider {
  readonly id = 'smart'
  readonly name = 'Smart Condensation'
  readonly description = 'Configurable multi-strategy condensation'
  readonly version = '1.0.0'
  
  getCapabilities(): ProviderCapabilities {
    return {
      supportsLossless: true,
      supportsLossy: true,
      supportsLLMSummarization: true,
      supportsParallelProcessing: true,
      supportsMultiPass: true,
      supportsFallback: true,
      estimatedSpeed: 'medium',
      apiCostPerCall: 0.005  // Variable based on config
    }
  }
  
  getConfigSchema(): ConfigSchema {
    return {
      type: 'object',
      properties: {
        // Phase 1: Lossless
        losslessPhase: {
          type: 'object',
          properties: {
            enabled: { type: 'boolean', default: true },
            deduplicateFileReads: { type: 'boolean', default: true },
            consolidateResults: { type: 'boolean', default: true },
            removeObsoleteState: { type: 'boolean', default: true }
          }
        },
        
        // Phase 2: Selection
        selectionPhase: {
          type: 'object',
          properties: {
            preserveRecentCount: { type: 'number', default: 5, min: 1, max: 20 },
            preserveUserMessages: { type: 'boolean', default: true },
            preserveAssistantText: { type: 'boolean', default: true }
          }
        },
        
        // Phase 3: Lossy
        lossyPhase: {
          type: 'object',
          properties: {
            enabled: { type: 'boolean', default: true },
            targetReductionPercent: { type: 'number', default: 50, min: 10, max: 90 },
            
            // Content-type processing
            toolResults: {
              type: 'object',
              properties: {
                strategy: { 
                  type: 'string', 
                  enum: ['suppress', 'truncate', 'summarize'],
                  default: 'truncate'
                },
                threshold: { type: 'number', default: 500 },
                truncateLines: { type: 'number', default: 5 },
                summaryMaxTokens: { type: 'number', default: 100 }
              }
            },
            
            toolParams: {
              type: 'object',
              properties: {
                strategy: { 
                  type: 'string', 
                  enum: ['suppress', 'truncate', 'summarize'],
                  default: 'truncate'
                },
                threshold: { type: 'number', default: 100 },
                truncateChars: { type: 'number', default: 100 }
              }
            },
            
            assistantReasoning: {
              type: 'object',
              properties: {
                strategy: { 
                  type: 'string', 
                  enum: ['keep', 'truncate', 'summarize'],
                  default: 'keep'
                },
                threshold: { type: 'number', default: 1000 }
              }
            },
            
            // Priority order
            processingOrder: {
              type: 'array',
              items: { 
                type: 'string',
                enum: ['tool_results', 'tool_params', 'assistant_reasoning', 'user_messages']
              },
              default: ['tool_results', 'tool_params', 'assistant_reasoning', 'user_messages']
            }
          }
        },
        
        // Phase 4: LLM Summarization (optional)
        llmPhase: {
          type: 'object',
          properties: {
            enabled: { type: 'boolean', default: false },
            maxParallelCalls: { type: 'number', default: 5, min: 1, max: 10 },
            summaryMaxTokens: { type: 'number', default: 100, min: 50, max: 500 }
          }
        },
        
        // Phase 5: Fallback
        fallbackPhase: {
          type: 'object',
          properties: {
            enabled: { type: 'boolean', default: true },
            strategy: {
              type: 'string',
              enum: ['native', 'strict_truncation', 'multi_pass'],
              default: 'multi_pass'
            },
            multiPass: {
              type: 'object',
              properties: {
                maxPasses: { type: 'number', default: 3 },
                stricterThresholdsEachPass: { type: 'boolean', default: true },
                thresholdReductionFactor: { type: 'number', default: 0.5 }
              }
            }
          }
        }
      }
    }
  }
  
  getConfigComponent(): ConfigComponentDescriptor {
    return {
      type: 'react',
      component: 'SmartProviderConfig',
      bindings: [
        { prop: 'config', path: 'smartProvider.config' },
        { prop: 'onChange', event: 'configChange' }
      ]
    }
  }
  
  async condense(
    context: ConversationContext,
    options: CondensationOptions
  ): Promise<CondensationResult> {
    let messages = [...context.messages]
    const operations: string[] = []
    
    // Phase 1: Lossless
    if (this.config.losslessPhase.enabled) {
      const result = await this.runLosslessPhase(messages)
      messages = result.messages
      operations.push(...result.operations)
      
      // Check if target met
      const currentTokens = await countTokens(messages)
      if (currentTokens <= options.targetTokens) {
        return this.buildResult(messages, operations, context.tokenCount)
      }
    }
    
    // Phase 2: Lossy
    if (this.config.lossyPhase.enabled) {
      const result = await this.runLossyPhase(messages, options.targetTokens)
      messages = result.messages
      operations.push(...result.operations)
      
      // Check if target met
      const currentTokens = await countTokens(messages)
      if (currentTokens <= options.targetTokens) {
        return this.buildResult(messages, operations, context.tokenCount)
      }
    }
    
    // Phase 3: LLM (optional)
    if (this.config.llmPhase.enabled) {
      const result = await this.runLLMPhase(messages, options.targetTokens)
      messages = result.messages
      operations.push(...result.operations)
      
      // Check if target met
      const currentTokens = await countTokens(messages)
      if (currentTokens <= options.targetTokens) {
        return this.buildResult(messages, operations, context.tokenCount)
      }
    }
    
    // Phase 4: Fallback (if still over)
    if (this.config.fallbackPhase.enabled) {
      const result = await this.runFallbackPhase(messages, options.targetTokens)
      messages = result.messages
      operations.push(...result.operations)
    }
    
    return this.buildResult(messages, operations, context.tokenCount)
  }
  
  private async runLossyPhase(
    messages: ApiMessage[],
    targetTokens: number
  ): Promise<{ messages: ApiMessage[], operations: string[] }> {
    const config = this.config.lossyPhase
    const operations: string[] = []
    
    // Identify zones
    const first = messages[0]
    const recent = messages.slice(-config.selectionPhase.preserveRecentCount)
    const oldZone = messages.slice(1, -config.selectionPhase.preserveRecentCount)
    
    // Identify candidates
    const candidates = await this.identifyCandidates(oldZone)
    
    // Sort by processing order
    const sorted = this.sortByProcessingOrder(candidates, config.processingOrder)
    
    // Process until target met
    let processed = [...oldZone]
    let currentTokens = await countTokens([first, ...processed, ...recent])
    
    for (const candidate of sorted) {
      if (currentTokens <= targetTokens) break
      
      const strategy = this.getStrategyForType(candidate.type, config)
      const result = await this.applyStrategy(candidate, strategy)
      
      processed[candidate.index] = result.message
      currentTokens -= result.tokensSaved
      operations.push(`${strategy}_${candidate.type}`)
    }
    
    return {
      messages: [first, ...processed, ...recent],
      operations
    }
  }
  
  private async identifyCandidates(
    messages: ApiMessage[]
  ): Promise<CondensationCandidate[]> {
    const candidates: CondensationCandidate[] = []
    const config = this.config.lossyPhase
    
    for (const [index, message] of messages.entries()) {
      // Tool results
      if (hasToolResult(message)) {
        const size = await countTokens([message])
        if (size > config.toolResults.threshold) {
          candidates.push({
            index,
            message,
            type: 'tool_result',
            tokenCount: size,
            toolName: extractToolName(message)
          })
        }
      }
      
      // Tool params
      if (hasToolUse(message)) {
        const size = await countTokens([message])
        if (size > config.toolParams.threshold) {
          candidates.push({
            index,
            message,
            type: 'tool_param',
            tokenCount: size,
            toolName: extractToolName(message)
          })
        }
      }
      
      // Assistant reasoning
      if (message.role === 'assistant' && !hasToolUse(message)) {
        const size = await countTokens([message])
        if (size > config.assistantReasoning.threshold) {
          candidates.push({
            index,
            message,
            type: 'assistant_reasoning',
            tokenCount: size
          })
        }
      }
    }
    
    return candidates
  }
  
  private getStrategyForType(
    type: string,
    config: any
  ): 'suppress' | 'truncate' | 'summarize' | 'keep' {
    switch (type) {
      case 'tool_result':
        return config.toolResults.strategy
      case 'tool_param':
        return config.toolParams.strategy
      case 'assistant_reasoning':
        return config.assistantReasoning.strategy
      default:
        return 'keep'
    }
  }
  
  private async applyStrategy(
    candidate: CondensationCandidate,
    strategy: string
  ): Promise<{ message: ApiMessage, tokensSaved: number }> {
    const original = candidate.message
    const originalSize = candidate.tokenCount
    
    let processed: ApiMessage
    
    switch (strategy) {
      case 'suppress':
        processed = createSuppressedMarker(original, candidate.type)
        break
        
      case 'truncate':
        processed = await this.truncateMessage(original, candidate.type)
        break
        
      case 'summarize':
        processed = await this.summarizeMessage(original, candidate.type)
        break
        
      default:
        processed = original
    }
    
    const newSize = await countTokens([processed])
    
    return {
      message: processed,
      tokensSaved: originalSize - newSize
    }
  }
  
  private async runFallbackPhase(
    messages: ApiMessage[],
    targetTokens: number
  ): Promise<{ messages: ApiMessage[], operations: string[] }> {
    const config = this.config.fallbackPhase
    
    switch (config.strategy) {
      case 'native':
        // Delegate to native provider
        const native = new NativeCondensationProvider()
        const result = await native.condense(
          { messages, tokenCount: await countTokens(messages) },
          { targetTokens }
        )
        return { messages: result.messages, operations: ['fallback_native'] }
        
      case 'strict_truncation':
        // Apply truncation with stricter thresholds
        return await this.strictTruncation(messages, targetTokens)
        
      case 'multi_pass':
        // Run lossy phase again with stricter thresholds
        return await this.multiPassCondensation(messages, targetTokens)
    }
  }
  
  private async multiPassCondensation(
    messages: ApiMessage[],
    targetTokens: number
  ): Promise<{ messages: ApiMessage[], operations: string[] }> {
    const config = this.config.fallbackPhase.multiPass
    let current = messages
    const operations: string[] = []
    
    for (let pass = 0; pass < config.maxPasses; pass++) {
      // Make thresholds stricter each pass
      if (config.stricterThresholdsEachPass) {
        this.adjustThresholds(config.thresholdReductionFactor)
      }
      
      // Run lossy phase again
      const result = await this.runLossyPhase(current, targetTokens)
      current = result.messages
      operations.push(`multi_pass_${pass + 1}`)
      
      // Check if target met
      const currentTokens = await countTokens(current)
      if (currentTokens <= targetTokens) {
        break
      }
    }
    
    return { messages: current, operations }
  }
}

interface CondensationCandidate {
  index: number
  message: ApiMessage
  type: 'tool_result' | 'tool_param' | 'assistant_reasoning' | 'user_message'
  tokenCount: number
  toolName?: string
}
```

## 3. UI Configuration Integration

### 3.1 Configuration Component System

```typescript
// In webview
interface ConfigComponentProps {
  providerId: string
  config: any
  onChange: (config: any) => void
}

// Smart Provider Config Component
const SmartProviderConfig: React.FC<ConfigComponentProps> = ({
  config,
  onChange
}) => {
  return (
    <div className="smart-provider-config">
      <h3>Smart Condensation Configuration</h3>
      
      {/* Phase 1: Lossless */}
      <Section title="Phase 1: Lossless Optimization">
        <Checkbox
          label="Enable Lossless Phase"
          checked={config.losslessPhase.enabled}
          onChange={(v) => onChange({ 
            ...config, 
            losslessPhase: { ...config.losslessPhase, enabled: v }
          })}
        />
        {config.losslessPhase.enabled && (
          <>
            <Checkbox label="Deduplicate File Reads" {...} />
            <Checkbox label="Consolidate Results" {...} />
            <Checkbox label="Remove Obsolete State" {...} />
          </>
        )}
      </Section>
      
      {/* Phase 2: Selection */}
      <Section title="Phase 2: Message Selection">
        <NumberInput
          label="Preserve Recent Count"
          value={config.selectionPhase.preserveRecentCount}
          min={1}
          max={20}
          onChange={(v) => onChange({ ... })}
        />
        <Checkbox label="Always Preserve User Messages" {...} />
        <Checkbox label="Always Preserve Assistant Text" {...} />
      </Section>
      
      {/* Phase 3: Lossy */}
      <Section title="Phase 3: Lossy Condensation">
        <Checkbox label="Enable Lossy Phase" {...} />
        {config.lossyPhase.enabled && (
          <>
            <NumberInput
              label="Target Reduction %"
              value={config.lossyPhase.targetReductionPercent}
              min={10}
              max={90}
              onChange={(v) => onChange({ ... })}
            />
            
            {/* Tool Results */}
            <Subsection title="Tool Results">
              <Select
                label="Strategy"
                value={config.lossyPhase.toolResults.strategy}
                options={['suppress', 'truncate', 'summarize']}
                onChange={(v) => onChange({ ... })}
              />
              <NumberInput label="Threshold (tokens)" {...} />
              {config.lossyPhase.toolResults.strategy === 'truncate' && (
                <NumberInput label="Truncate Lines" {...} />
              )}
              {config.lossyPhase.toolResults.strategy === 'summarize' && (
                <NumberInput label="Summary Max Tokens" {...} />
              )}
            </Subsection>
            
            {/* Tool Params */}
            <Subsection title="Tool Parameters">
              <Select label="Strategy" {...} />
              <NumberInput label="Threshold (tokens)" {...} />
              {/* ... similar to tool results ... */}
            </Subsection>
            
            {/* Assistant Reasoning */}
            <Subsection title="Assistant Reasoning">
              <Select 
                label="Strategy"
                options={['keep', 'truncate', 'summarize']}
                {...}
              />
              <NumberInput label="Threshold (tokens)" {...} />
            </Subsection>
            
            {/* Processing Order */}
            <DragDropList
              label="Processing Order (drag to reorder)"
              items={config.lossyPhase.processingOrder}
              onChange={(order) => onChange({ 
                ...config,
                lossyPhase: { 
                  ...config.lossyPhase, 
                  processingOrder: order 
                }
              })}
            />
          </>
        )}
      </Section>
      
      {/* Phase 4: LLM */}
      <Section title="Phase 4: LLM Summarization (Optional)">
        <Checkbox label="Enable LLM Summarization" {...} />
        {config.llmPhase.enabled && (
          <>
            <NumberInput 
              label="Max Parallel Calls"
              value={config.llmPhase.maxParallelCalls}
              min={1}
              max={10}
              onChange={(v) => onChange({ ... })}
            />
            <NumberInput 
              label="Summary Max Tokens"
              value={config.llmPhase.summaryMaxTokens}
              min={50}
              max={500}
              onChange={(v) => onChange({ ... })}
            />
            <InfoBox>
              LLM summarization adds API costs but provides best quality.
              Estimated: ~$0.001-0.01 per condensation.
            </InfoBox>
          </>
        )}
      </Section>
      
      {/* Phase 5: Fallback */}
      <Section title="Phase 5: Fallback Strategy">
        <Checkbox label="Enable Fallback" {...} />
        {config.fallbackPhase.enabled && (
          <>
            <Select
              label="Fallback Strategy"
              value={config.fallbackPhase.strategy}
              options={[
                { value: 'native', label: 'Native Provider' },
                { value: 'strict_truncation', label: 'Strict Truncation' },
                { value: 'multi_pass', label: 'Multi-Pass Condensation' }
              ]}
              onChange={(v) => onChange({ ... })}
            />
            {config.fallbackPhase.strategy === 'multi_pass' && (
              <>
                <NumberInput label="Max Passes" {...} />
                <Checkbox label="Stricter Thresholds Each Pass" {...} />
                <NumberInput label="Threshold Reduction Factor" {...} />
              </>
            )}
          </>
        )}
      </Section>
      
      {/* Preview */}
      <Section title="Preview">
        <Button onClick={previewCondensation}>
          Preview with Current Settings
        </Button>
      </Section>
    </div>
  )
}
```

### 3.2 Provider Selector UI

```typescript
const ProviderSelector: React.FC = () => {
  const providers = useProviders()  // Get all registered providers
  const [selected, setSelected] = useState('smart')
  
  return (
    <div className="provider-selector">
      <h3>Condensation Strategy</h3>
      
      <RadioGroup
        value={selected}
        onChange={setSelected}
      >
        {providers.map(provider => (
          <RadioOption
            key={provider.id}
            value={provider.id}
            label={provider.name}
            description={provider.description}
          >
            {/* Provider-specific badges */}
            <Badges>
              {provider.capabilities.supportsLossless && (
                <Badge>Lossless</Badge>
              )}
              {provider.capabilities.supportsLLMSummarization && (
                <Badge variant="premium">LLM</Badge>
              )}
              <Badge variant="info">
                {provider.capabilities.estimatedSpeed}
              </Badge>
              {provider.capabilities.apiCostPerCall > 0 && (
                <Badge variant="cost">
                  ~${provider.capabilities.apiCostPerCall}/call
                </Badge>
              )}
            </Badges>
          </RadioOption>
        ))}
      </RadioGroup>
      
      {/* Dynamic config component */}
      <div className="provider-config">
        {selected && renderProviderConfig(selected)}
      </div>
    </div>
  )
}
```

## 4. Provider Comparison Matrix

| Feature | Native | Lossless | Truncation | Smart |
|---------|--------|----------|------------|-------|
| **Speed** | Medium | Fast | Very Fast | Medium |
| **Token Reduction** | 40-60% | 20-40% | 80-90% | 50-80% |
| **Information Loss** | Medium | None | High | Low-Medium |
| **API Cost** | ~$0.001 | $0 | $0 | ~$0-0.01 |
| **Configurability** | Low | Low | Medium | Very High |
| **Lossless Phase** | ❌ | ✅ | ❌ | ✅ (optional) |
| **Threshold-Based** | ❌ | ❌ | ✅ | ✅ |
| **LLM Summarization** | ✅ | ❌ | ❌ | ✅ (optional) |
| **Multi-Pass** | ❌ | ❌ | ❌ | ✅ (optional) |
| **Fallback** | ❌ | ✅ | ❌ | ✅ |
| **Best For** | Default | Quality | Speed | Power Users |

## 5. Implementation Strategy

### 5.1 Phase 1: Foundation (Week 1-2)
- Implement provider interface and manager
- Migrate current system to Native Provider
- Basic UI selector

### 5.2 Phase 2: Simple Providers (Week 3-4)
- Implement Lossless Provider
- Implement Truncation Provider
- Test and validate

### 5.3 Phase 3: Smart Provider (Week 5-7)
- Implement Smart Provider core
- Add all phases (lossless, lossy, LLM, fallback)
- Complex UI configuration

### 5.4 Phase 4: Polish (Week 8)
- Performance optimization
- Documentation
- User testing

## 6. Success Metrics

### Provider-Level Metrics
- Each provider achieves its target reduction %
- Speed within expected ranges
- API costs within estimates
- Configuration validation working

### System-Level Metrics
- User satisfaction with configurability
- Adoption of different providers
- Performance improvement over baseline
- Cost reduction (where applicable)

---

**Summary**: Modular provider architecture with 4 concrete implementations (Native, Lossless, Truncation, Smart), each illustrating different mechanisms. Smart provider combines all capabilities with rich configuration. UI integration allows dynamic configuration per provider.